-- Migration 04: Match Results, Room History, and Persistent Statistics
-- Run this migration in the Supabase SQL Editor.

-- 1. Room Match History Table
CREATE TABLE IF NOT EXISTS public.room_match_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id UUID NOT NULL REFERENCES public.rooms(id) ON DELETE CASCADE,
  round_number INT NOT NULL,
  winner_id UUID REFERENCES auth.users(id),
  winner_name TEXT NOT NULL,
  total_calls INT NOT NULL DEFAULT 0,
  player_count INT NOT NULL DEFAULT 0,
  player_outcomes JSONB NOT NULL DEFAULT '[]'::jsonb,
  finished_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Enable RLS
ALTER TABLE public.room_match_history ENABLE ROW LEVEL SECURITY;

-- Select policy: Allow anyone to view room match history
CREATE POLICY "Room match history is viewable by authenticated users"
  ON public.room_match_history
  FOR SELECT
  USING (true);

-- Enable Realtime
ALTER PUBLICATION supabase_realtime ADD TABLE public.room_match_history;

-- 2. Server-Authoritative RPC: rpc_finish_round
CREATE OR REPLACE FUNCTION public.rpc_finish_round(
  p_game_id UUID,
  p_room_id UUID,
  p_winner_id UUID,
  p_winner_name TEXT,
  p_total_calls INT,
  p_player_outcomes JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_game RECORD;
  v_outcome JSONB;
  v_player_id UUID;
  v_lines INT;
  v_is_winner BOOLEAN;
  v_current_streak INT;
  v_best_streak INT;
BEGIN
  -- 1. Fetch and lock active game
  SELECT * INTO v_game
  FROM public.games
  WHERE id = p_game_id AND room_id = p_room_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Game not found');
  END IF;

  -- 2. Update game status to completed
  UPDATE public.games
  SET status = 'completed',
      winner_id = p_winner_id,
      updated_at = timezone('utc'::text, now())
  WHERE id = p_game_id;

  -- 3. Insert history record
  INSERT INTO public.room_match_history (
    room_id,
    round_number,
    winner_id,
    winner_name,
    total_calls,
    player_count,
    player_outcomes,
    finished_at
  ) VALUES (
    p_room_id,
    v_game.round_number,
    p_winner_id,
    p_winner_name,
    p_total_calls,
    jsonb_array_length(p_player_outcomes),
    p_player_outcomes,
    timezone('utc'::text, now())
  );

  -- 4. Update career player_statistics for each player
  FOR v_outcome IN SELECT * FROM jsonb_array_elements(p_player_outcomes)
  LOOP
    v_player_id := (v_outcome->>'user_id')::UUID;
    v_lines := COALESCE((v_outcome->>'lines_claimed_count')::INT, 0);
    v_is_winner := COALESCE((v_outcome->>'is_winner')::BOOLEAN, false);

    -- Ensure statistics row exists
    INSERT INTO public.player_statistics (user_id, total_matches, wins, losses, draws, current_streak, best_streak, highest_lines_claimed, updated_at)
    VALUES (v_player_id, 0, 0, 0, 0, 0, 0, 0, timezone('utc'::text, now()))
    ON CONFLICT (user_id) DO NOTHING;

    -- Fetch streak
    SELECT current_streak, best_streak INTO v_current_streak, v_best_streak
    FROM public.player_statistics
    WHERE user_id = v_player_id;

    IF v_is_winner THEN
      v_current_streak := v_current_streak + 1;
      v_best_streak := GREATEST(v_best_streak, v_current_streak);
      UPDATE public.player_statistics
      SET total_matches = total_matches + 1,
          wins = wins + 1,
          current_streak = v_current_streak,
          best_streak = v_best_streak,
          highest_lines_claimed = GREATEST(highest_lines_claimed, v_lines),
          updated_at = timezone('utc'::text, now())
      WHERE user_id = v_player_id;
    ELSE
      UPDATE public.player_statistics
      SET total_matches = total_matches + 1,
          losses = losses + 1,
          current_streak = 0,
          highest_lines_claimed = GREATEST(highest_lines_claimed, v_lines),
          updated_at = timezone('utc'::text, now())
      WHERE user_id = v_player_id;
    END IF;
  END LOOP;

  RETURN jsonb_build_object(
    'success', true,
    'round_number', v_game.round_number,
    'winner_id', p_winner_id
  );
END;
$$;

-- 3. Server-Authoritative RPC: rpc_start_next_round
CREATE OR REPLACE FUNCTION public.rpc_start_next_round(
  p_game_id UUID,
  p_room_id UUID,
  p_host_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_room RECORD;
  v_game RECORD;
  v_prep_seconds INT;
BEGIN
  -- 1. Validate caller is room host
  SELECT * INTO v_room
  FROM public.rooms
  WHERE id = p_room_id AND host_id = p_host_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Only the room host can start the next round');
  END IF;

  SELECT * INTO v_game
  FROM public.games
  WHERE id = p_game_id AND room_id = p_room_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Game not found');
  END IF;

  v_prep_seconds := COALESCE(v_room.prep_time_seconds, 45);

  -- 2. Reset and advance game
  UPDATE public.games
  SET round_number = v_game.round_number + 1,
      status = 'preparing',
      prep_deadline = timezone('utc'::text, now()) + (v_prep_seconds || ' seconds')::interval,
      turn_player_id = NULL,
      turn_deadline = NULL,
      called_numbers = '[]'::jsonb,
      winner_id = NULL,
      turn_start_time = NULL,
      updated_at = timezone('utc'::text, now())
  WHERE id = p_game_id;

  -- 3. Reset all players readiness and board locks
  UPDATE public.game_player_states
  SET is_board_confirmed = false,
      completed_lines = '[]'::jsonb,
      claimed_letters = '[]'::jsonb,
      lines_claimed_count = 0,
      board_numbers = '[]'::jsonb,
      updated_at = timezone('utc'::text, now())
  WHERE game_id = p_game_id;

  RETURN jsonb_build_object(
    'success', true,
    'round_number', v_game.round_number + 1,
    'prep_deadline', (timezone('utc'::text, now()) + (v_prep_seconds || ' seconds')::interval)
  );
END;
$$;
