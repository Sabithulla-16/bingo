-- Migration 03: Multiplayer Gameplay Synchronization and Server-Authoritative RPCs
-- Tables: games, game_player_states
-- Enums, RLS policies, Realtime publication, and PostgreSQL functions

CREATE TYPE game_status AS ENUM ('preparing', 'in_progress', 'completed', 'cancelled');

-- 1. Games table
CREATE TABLE IF NOT EXISTS public.games (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    room_id UUID NOT NULL REFERENCES public.rooms(id) ON DELETE CASCADE,
    status game_status NOT NULL DEFAULT 'preparing',
    prep_deadline TIMESTAMPTZ NOT NULL,
    current_turn_user_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    turn_deadline TIMESTAMPTZ,
    called_numbers INTEGER[] NOT NULL DEFAULT '{}',
    round_number INTEGER NOT NULL DEFAULT 1,
    winner_user_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- Index for querying active game by room
CREATE INDEX IF NOT EXISTS idx_games_room_id ON public.games(room_id);

-- 2. Game Player States table (stores secret board and line claims)
CREATE TABLE IF NOT EXISTS public.game_player_states (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    game_id UUID NOT NULL REFERENCES public.games(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    board_numbers INTEGER[] NOT NULL,
    board_confirmed BOOLEAN NOT NULL DEFAULT FALSE,
    lines_claimed INTEGER NOT NULL DEFAULT 0,
    claimed_line_types TEXT[] NOT NULL DEFAULT '{}',
    is_winner BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    UNIQUE(game_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_game_player_states_game ON public.game_player_states(game_id);

-- 3. Row Level Security
ALTER TABLE public.games ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.game_player_states ENABLE ROW LEVEL SECURITY;

-- Games policies: anyone in the room can view the game state
CREATE POLICY "Room participants can view game"
    ON public.games
    FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.room_players rp
            WHERE rp.room_id = games.room_id
              AND rp.user_id = auth.uid()
        )
    );

-- Game player states: players can see their own board numbers; public summary columns are readable by opponents
CREATE POLICY "Players can view own full state and others public states"
    ON public.game_player_states
    FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.games g
            JOIN public.room_players rp ON rp.room_id = g.room_id
            WHERE g.id = game_player_states.game_id
              AND rp.user_id = auth.uid()
        )
    );

CREATE POLICY "Players can update their own board and readiness"
    ON public.game_player_states
    FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- 4. Enable Supabase Realtime for games and player states
ALTER PUBLICATION supabase_realtime ADD TABLE public.games;
ALTER PUBLICATION supabase_realtime ADD TABLE public.game_player_states;

-- 5. RPC: Submit Board & Ready Up
CREATE OR REPLACE FUNCTION public.rpc_submit_board(
    p_game_id UUID,
    p_board INTEGER[]
) RETURNS VOID AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_room_id UUID;
    v_all_confirmed BOOLEAN;
    v_first_turn_user UUID;
    v_turn_time_sec INTEGER;
BEGIN
    -- Validate board contains 25 numbers
    IF array_length(p_board, 1) != 25 THEN
        RAISE EXCEPTION 'Board must contain exactly 25 numbers';
    END IF;

    -- Update or insert player state
    INSERT INTO public.game_player_states (game_id, user_id, board_numbers, board_confirmed)
    VALUES (p_game_id, v_user_id, p_board, TRUE)
    ON CONFLICT (game_id, user_id)
    DO UPDATE SET
        board_numbers = p_board,
        board_confirmed = TRUE,
        updated_at = timezone('utc'::text, now());

    -- Check if all players in the room have confirmed
    SELECT room_id INTO v_room_id FROM public.games WHERE id = p_game_id;

    SELECT bool_and(gps.board_confirmed)
    INTO v_all_confirmed
    FROM public.room_players rp
    LEFT JOIN public.game_player_states gps ON gps.game_id = p_game_id AND gps.user_id = rp.user_id
    WHERE rp.room_id = v_room_id;

    -- If all players confirmed, transition game to in_progress
    IF v_all_confirmed THEN
        SELECT host_id, turn_time_seconds INTO v_first_turn_user, v_turn_time_sec
        FROM public.rooms WHERE id = v_room_id;

        UPDATE public.games
        SET status = 'in_progress',
            current_turn_user_id = v_first_turn_user,
            turn_deadline = timezone('utc'::text, now()) + (v_turn_time_sec || ' seconds')::interval,
            updated_at = timezone('utc'::text, now())
        WHERE id = p_game_id;

        UPDATE public.rooms
        SET status = 'in_game',
            updated_at = timezone('utc'::text, now())
        WHERE id = v_room_id;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 6. RPC: Call Number
CREATE OR REPLACE FUNCTION public.rpc_call_number(
    p_game_id UUID,
    p_number INTEGER
) RETURNS VOID AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_game public.games%ROWTYPE;
    v_room public.rooms%ROWTYPE;
    v_next_turn_user UUID;
    v_player_count INTEGER;
    v_current_seat INTEGER;
BEGIN
    SELECT * INTO v_game FROM public.games WHERE id = p_game_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Game not found';
    END IF;

    IF v_game.status != 'in_progress' THEN
        RAISE EXCEPTION 'Game is not in progress';
    END IF;

    IF v_game.current_turn_user_id != v_user_id THEN
        RAISE EXCEPTION 'Not your turn';
    END IF;

    IF p_number < 1 OR p_number > 25 THEN
        RAISE EXCEPTION 'Number must be between 1 and 25';
    END IF;

    IF p_number = ANY(v_game.called_numbers) THEN
        RAISE EXCEPTION 'Number already called';
    END IF;

    SELECT * INTO v_room FROM public.rooms WHERE id = v_game.room_id;

    -- Compute next player turn by seat_index order
    SELECT rp.seat_index INTO v_current_seat
    FROM public.room_players rp
    WHERE rp.room_id = v_room.id AND rp.user_id = v_user_id;

    SELECT rp.user_id INTO v_next_turn_user
    FROM public.room_players rp
    WHERE rp.room_id = v_room.id AND rp.seat_index > v_current_seat
    ORDER BY rp.seat_index ASC
    LIMIT 1;

    -- Wrap around if reached the last seat
    IF v_next_turn_user IS NULL THEN
        SELECT rp.user_id INTO v_next_turn_user
        FROM public.room_players rp
        WHERE rp.room_id = v_room.id
        ORDER BY rp.seat_index ASC
        LIMIT 1;
    END IF;

    -- Append called number and update next turn
    UPDATE public.games
    SET called_numbers = array_append(called_numbers, p_number),
        current_turn_user_id = v_next_turn_user,
        turn_deadline = timezone('utc'::text, now()) + (v_room.turn_time_seconds || ' seconds')::interval,
        updated_at = timezone('utc'::text, now())
    WHERE id = p_game_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 7. RPC: Claim Line
CREATE OR REPLACE FUNCTION public.rpc_claim_line(
    p_game_id UUID,
    p_line_type TEXT,
    p_numbers INTEGER[]
) RETURNS BOOLEAN AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_game public.games%ROWTYPE;
    v_gps public.game_player_states%ROWTYPE;
    v_num INTEGER;
    v_new_lines INTEGER;
    v_has_won BOOLEAN := FALSE;
BEGIN
    SELECT * INTO v_game FROM public.games WHERE id = p_game_id FOR UPDATE;
    IF v_game.status != 'in_progress' OR v_game.winner_user_id IS NOT NULL THEN
        RAISE EXCEPTION 'Game not active or already completed';
    END IF;

    SELECT * INTO v_gps FROM public.game_player_states
    WHERE game_id = p_game_id AND user_id = v_user_id FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Player state not found';
    END IF;

    IF p_line_type = ANY(v_gps.claimed_line_types) THEN
        RAISE EXCEPTION 'Line already claimed';
    END IF;

    -- Verify all numbers in the claimed line were actually called
    FOREACH v_num IN ARRAY p_numbers LOOP
        IF NOT (v_num = ANY(v_game.called_numbers)) THEN
            RAISE EXCEPTION 'Number % in claimed line has not been called yet', v_num;
        END IF;
    END LOOP;

    v_new_lines := v_gps.lines_claimed + 1;
    IF v_new_lines >= 5 THEN
        v_has_won := TRUE;
    END IF;

    UPDATE public.game_player_states
    SET lines_claimed = v_new_lines,
        claimed_line_types = array_append(claimed_line_types, p_line_type),
        is_winner = v_has_won,
        updated_at = timezone('utc'::text, now())
    WHERE id = v_gps.id;

    IF v_has_won THEN
        UPDATE public.games
        SET status = 'completed',
            winner_user_id = v_user_id,
            updated_at = timezone('utc'::text, now())
        WHERE id = p_game_id;

        UPDATE public.rooms
        SET status = 'completed',
            updated_at = timezone('utc'::text, now())
        WHERE id = v_game.room_id;
    END IF;

    RETURN v_has_won;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
