-- ==============================================================================
-- Migration 17: Quick Match Authoritative 1v1 Matchmaking & Realtime Synchronization
-- ==============================================================================

-- 1. Create matchmaking_queue table
CREATE TABLE IF NOT EXISTS public.matchmaking_queue (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    status TEXT NOT NULL CHECK (status IN ('SEARCHING', 'MATCHED', 'CANCELLED', 'EXPIRED')) DEFAULT 'SEARCHING',
    queued_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    matched_at TIMESTAMPTZ,
    match_id UUID,
    region TEXT DEFAULT 'auto',
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- Unique index to prevent duplicate active queue entries per user
CREATE UNIQUE INDEX IF NOT EXISTS idx_matchmaking_queue_active_user
    ON public.matchmaking_queue(user_id)
    WHERE status = 'SEARCHING';

CREATE INDEX IF NOT EXISTS idx_matchmaking_queue_status_queued
    ON public.matchmaking_queue(status, queued_at ASC);

-- 2. Create quick_matches table
CREATE TABLE IF NOT EXISTS public.quick_matches (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    room_id UUID NOT NULL REFERENCES public.rooms(id) ON DELETE CASCADE,
    game_id UUID NOT NULL REFERENCES public.games(id) ON DELETE CASCADE,
    player1_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    player2_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    status TEXT NOT NULL CHECK (status IN ('COUNTDOWN', 'BOARD_PREPARATION', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED', 'FORFEITED')) DEFAULT 'COUNTDOWN',
    countdown_deadline TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE INDEX IF NOT EXISTS idx_quick_matches_players
    ON public.quick_matches(player1_id, player2_id);

CREATE INDEX IF NOT EXISTS idx_quick_matches_room_game
    ON public.quick_matches(room_id, game_id);

-- 3. Enable Full Replica Identity for Supabase Realtime broadcast of updates
ALTER TABLE public.matchmaking_queue REPLICA IDENTITY FULL;
ALTER TABLE public.quick_matches REPLICA IDENTITY FULL;

-- Publish to realtime publication
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'matchmaking_queue'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.matchmaking_queue;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'quick_matches'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.quick_matches;
    END IF;
END $$;

-- 4. Enable Row Level Security
ALTER TABLE public.matchmaking_queue ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.quick_matches ENABLE ROW LEVEL SECURITY;

-- Matchmaking queue policies
CREATE POLICY "Users can read own queue entries"
    ON public.matchmaking_queue FOR SELECT
    TO authenticated
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own queue entries"
    ON public.matchmaking_queue FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own queue entries"
    ON public.matchmaking_queue FOR UPDATE
    TO authenticated
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own queue entries"
    ON public.matchmaking_queue FOR DELETE
    TO authenticated
    USING (auth.uid() = user_id);

-- Quick matches policies
CREATE POLICY "Matched players can view their quick match"
    ON public.quick_matches FOR SELECT
    TO authenticated
    USING (auth.uid() = player1_id OR auth.uid() = player2_id);

-- 5. Helper function to generate unique 6-character room code
CREATE OR REPLACE FUNCTION public.fn_generate_quick_match_room_code()
RETURNS TEXT
LANGUAGE plpgsql
AS $$
DECLARE
    v_code TEXT;
    v_exists BOOLEAN;
BEGIN
    LOOP
        v_code := upper(substring(replace(gen_random_uuid()::text, '-', '') from 1 for 6));
        SELECT EXISTS(SELECT 1 FROM public.rooms WHERE code = v_code) INTO v_exists;
        EXIT WHEN NOT v_exists;
    END LOOP;
    RETURN v_code;
END;
$$;

-- 6. RPC: rpc_enter_matchmaking_queue
-- Atomically pairs two waiting players or places the caller into SEARCHING queue.
CREATE OR REPLACE FUNCTION public.rpc_enter_matchmaking_queue(
    p_region TEXT DEFAULT 'auto'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_user_profile public.profiles%ROWTYPE;
    v_opponent_queue public.matchmaking_queue%ROWTYPE;
    v_opponent_profile public.profiles%ROWTYPE;
    v_room_id UUID;
    v_game_id UUID;
    v_quick_match_id UUID;
    v_room_code TEXT;
    v_countdown_deadline TIMESTAMPTZ;
    v_queue_id UUID;
    v_existing_active_match RECORD;
BEGIN
    -- Check authentication
    IF v_user_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
    END IF;

    -- Verify user profile exists
    SELECT * INTO v_user_profile FROM public.profiles WHERE id = v_user_id;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'User profile not found');
    END IF;

    -- Clean up stale searching entries older than 3 minutes
    UPDATE public.matchmaking_queue
    SET status = 'EXPIRED', updated_at = timezone('utc'::text, now())
    WHERE status = 'SEARCHING' AND queued_at < timezone('utc'::text, now()) - interval '3 minutes';

    -- Check if caller already has an active committed quick match
    SELECT qm.*, r.code as room_code INTO v_existing_active_match
    FROM public.quick_matches qm
    JOIN public.rooms r ON r.id = qm.room_id
    WHERE (qm.player1_id = v_user_id OR qm.player2_id = v_user_id)
      AND qm.status IN ('COUNTDOWN', 'BOARD_PREPARATION', 'IN_PROGRESS')
    ORDER BY qm.created_at DESC
    LIMIT 1;

    IF FOUND THEN
        RETURN jsonb_build_object(
            'success', true,
            'status', 'MATCHED',
            'match_id', v_existing_active_match.id,
            'room_id', v_existing_active_match.room_id,
            'room_code', v_existing_active_match.room_code,
            'game_id', v_existing_active_match.game_id,
            'countdown_deadline', v_existing_active_match.countdown_deadline,
            'is_existing_match', true
        );
    END IF;

    -- Cancel any existing SEARCHING queue record for this caller
    UPDATE public.matchmaking_queue
    SET status = 'CANCELLED', updated_at = timezone('utc'::text, now())
    WHERE user_id = v_user_id AND status = 'SEARCHING';

    -- ATOMIC PAIRING: Look for an available opponent waiting in queue
    SELECT * INTO v_opponent_queue
    FROM public.matchmaking_queue
    WHERE status = 'SEARCHING'
      AND user_id != v_user_id
    ORDER BY queued_at ASC
    LIMIT 1
    FOR UPDATE SKIP LOCKED;

    IF FOUND THEN
        -- Eligible opponent locked! Fetch opponent profile
        SELECT * INTO v_opponent_profile FROM public.profiles WHERE id = v_opponent_queue.user_id;

        -- Verify opponent has no conflicting active match
        IF EXISTS (
            SELECT 1 FROM public.quick_matches
            WHERE (player1_id = v_opponent_queue.user_id OR player2_id = v_opponent_queue.user_id)
              AND status IN ('COUNTDOWN', 'BOARD_PREPARATION', 'IN_PROGRESS')
        ) THEN
            -- Opponent is already in an active match, expire their queue entry and retry as searching
            UPDATE public.matchmaking_queue
            SET status = 'EXPIRED', updated_at = timezone('utc'::text, now())
            WHERE id = v_opponent_queue.id;
            
            -- Insert caller into SEARCHING queue
            INSERT INTO public.matchmaking_queue (user_id, status, region, queued_at)
            VALUES (v_user_id, 'SEARCHING', p_region, timezone('utc'::text, now()))
            RETURNING id INTO v_queue_id;

            RETURN jsonb_build_object(
                'success', true,
                'status', 'SEARCHING',
                'queue_id', v_queue_id
            );
        END IF;

        -- Atomically create shared Room
        v_room_code := public.fn_generate_quick_match_room_code();
        v_room_id := gen_random_uuid();
        v_game_id := gen_random_uuid();
        v_quick_match_id := gen_random_uuid();
        v_countdown_deadline := timezone('utc'::text, now()) + interval '10 seconds';

        INSERT INTO public.rooms (
            id, code, name, host_id, max_players, prep_time_seconds, turn_time_seconds, status, created_at, updated_at
        ) VALUES (
            v_room_id,
            v_room_code,
            'Quick Match 1v1',
            v_opponent_queue.user_id,
            2,
            30,
            20,
            'preparing',
            timezone('utc'::text, now()),
            timezone('utc'::text, now())
        );

        -- Add both players into room_players
        -- Seat 0: Opponent (Player 1)
        INSERT INTO public.room_players (
            room_id, user_id, is_host, is_ready, seat_index, joined_at
        ) VALUES (
            v_room_id,
            v_opponent_queue.user_id,
            true,
            false,
            0,
            timezone('utc'::text, now())
        );

        -- Seat 1: Caller (Player 2)
        INSERT INTO public.room_players (
            room_id, user_id, is_host, is_ready, seat_index, joined_at
        ) VALUES (
            v_room_id,
            v_user_id,
            false,
            false,
            1,
            timezone('utc'::text, now())
        );

        -- Atomically create shared Game record
        INSERT INTO public.games (
            id,
            room_id,
            status,
            prep_deadline,
            current_turn_user_id,
            round_number,
            called_numbers,
            created_at,
            updated_at
        ) VALUES (
            v_game_id,
            v_room_id,
            'preparing',
            v_countdown_deadline + interval '30 seconds',
            v_opponent_queue.user_id,
            1,
            '{}',
            timezone('utc'::text, now()),
            timezone('utc'::text, now())
        );

        -- Initialize blank game player states for both participants
        INSERT INTO public.game_player_states (
            game_id, user_id, board_numbers, board_confirmed, lines_claimed, claimed_line_types
        ) VALUES
            (v_game_id, v_opponent_queue.user_id, '{}', false, 0, '{}'),
            (v_game_id, v_user_id, '{}', false, 0, '{}');

        -- Create Quick Match tracking record
        INSERT INTO public.quick_matches (
            id, room_id, game_id, player1_id, player2_id, status, countdown_deadline, created_at, updated_at
        ) VALUES (
            v_quick_match_id,
            v_room_id,
            v_game_id,
            v_opponent_queue.user_id,
            v_user_id,
            'COUNTDOWN',
            v_countdown_deadline,
            timezone('utc'::text, now()),
            timezone('utc'::text, now())
        );

        -- Mark opponent queue row as MATCHED
        UPDATE public.matchmaking_queue
        SET status = 'MATCHED',
            matched_at = timezone('utc'::text, now()),
            match_id = v_quick_match_id,
            updated_at = timezone('utc'::text, now())
        WHERE id = v_opponent_queue.id;

        -- Record caller queue entry as MATCHED
        INSERT INTO public.matchmaking_queue (
            user_id, status, queued_at, matched_at, match_id, region, created_at, updated_at
        ) VALUES (
            v_user_id,
            'MATCHED',
            timezone('utc'::text, now()),
            timezone('utc'::text, now()),
            v_quick_match_id,
            p_region,
            timezone('utc'::text, now()),
            timezone('utc'::text, now())
        )
        RETURNING id INTO v_queue_id;

        -- Return full matched payload
        RETURN jsonb_build_object(
            'success', true,
            'status', 'MATCHED',
            'queue_id', v_queue_id,
            'match_id', v_quick_match_id,
            'room_id', v_room_id,
            'room_code', v_room_code,
            'game_id', v_game_id,
            'player1_id', v_opponent_queue.user_id,
            'player2_id', v_user_id,
            'countdown_deadline', v_countdown_deadline,
            'opponent', jsonb_build_object(
                'id', v_opponent_profile.id,
                'display_name', v_opponent_profile.display_name,
                'avatar_color_hex', v_opponent_profile.avatar_color_hex
            )
        );
    ELSE
        -- No opponent currently waiting -> Enter queue with status SEARCHING
        INSERT INTO public.matchmaking_queue (
            user_id, status, region, queued_at, created_at, updated_at
        ) VALUES (
            v_user_id,
            'SEARCHING',
            p_region,
            timezone('utc'::text, now()),
            timezone('utc'::text, now()),
            timezone('utc'::text, now())
        )
        RETURNING id INTO v_queue_id;

        RETURN jsonb_build_object(
            'success', true,
            'status', 'SEARCHING',
            'queue_id', v_queue_id
        );
    END IF;
END;
$$;

-- 7. RPC: rpc_cancel_matchmaking_queue
-- Cancels active searching entry atomically. If match was already committed, prevents cancel.
CREATE OR REPLACE FUNCTION public.rpc_cancel_matchmaking_queue()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_queue public.matchmaking_queue%ROWTYPE;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
    END IF;

    -- Lock caller's active queue row
    SELECT * INTO v_queue
    FROM public.matchmaking_queue
    WHERE user_id = v_user_id
    ORDER BY queued_at DESC
    LIMIT 1
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', true, 'status', 'IDLE');
    END IF;

    IF v_queue.status = 'MATCHED' THEN
        -- Match is already atomically committed!
        RETURN jsonb_build_object(
            'success', false,
            'reason', 'ALREADY_MATCHED',
            'match_id', v_queue.match_id
        );
    END IF;

    UPDATE public.matchmaking_queue
    SET status = 'CANCELLED',
        updated_at = timezone('utc'::text, now())
    WHERE id = v_queue.id;

    RETURN jsonb_build_object('success', true, 'status', 'CANCELLED');
END;
$$;

-- 8. RPC: rpc_transition_to_board_prep
-- Server-authoritative transition from COUNTDOWN to BOARD_PREPARATION
CREATE OR REPLACE FUNCTION public.rpc_transition_to_board_prep(
    p_match_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_qm public.quick_matches%ROWTYPE;
    v_now TIMESTAMPTZ := timezone('utc'::text, now());
BEGIN
    IF v_user_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
    END IF;

    SELECT * INTO v_qm
    FROM public.quick_matches
    WHERE id = p_match_id AND (player1_id = v_user_id OR player2_id = v_user_id)
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Quick match not found');
    END IF;

    -- If already transitioned, return current state idempotently
    IF v_qm.status != 'COUNTDOWN' THEN
        RETURN jsonb_build_object(
            'success', true,
            'status', v_qm.status,
            'room_id', v_qm.room_id,
            'game_id', v_qm.game_id
        );
    END IF;

    -- Authoritatively transition quick match to BOARD_PREPARATION
    UPDATE public.quick_matches
    SET status = 'BOARD_PREPARATION',
        updated_at = v_now
    WHERE id = p_match_id;

    -- Update games prep_deadline to 30 seconds from now
    UPDATE public.games
    SET prep_deadline = v_now + interval '30 seconds',
        updated_at = v_now
    WHERE id = v_qm.game_id;

    RETURN jsonb_build_object(
        'success', true,
        'status', 'BOARD_PREPARATION',
        'room_id', v_qm.room_id,
        'game_id', v_qm.game_id,
        'prep_deadline', (v_now + interval '30 seconds')
    );
END;
$$;

-- 9. RPC: rpc_get_active_quick_match
-- Retrieves caller's active quick match (for reconnection or session restore)
CREATE OR REPLACE FUNCTION public.rpc_get_active_quick_match()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_qm public.quick_matches%ROWTYPE;
    v_opponent_id UUID;
    v_opponent_profile public.profiles%ROWTYPE;
    v_room public.rooms%ROWTYPE;
    v_game public.games%ROWTYPE;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN jsonb_build_object('has_active_match', false, 'error', 'Not authenticated');
    END IF;

    SELECT * INTO v_qm
    FROM public.quick_matches
    WHERE (player1_id = v_user_id OR player2_id = v_user_id)
      AND status IN ('COUNTDOWN', 'BOARD_PREPARATION', 'IN_PROGRESS')
    ORDER BY created_at DESC
    LIMIT 1;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('has_active_match', false);
    END IF;

    -- Identify opponent
    IF v_qm.player1_id = v_user_id THEN
        v_opponent_id := v_qm.player2_id;
    ELSE
        v_opponent_id := v_qm.player1_id;
    END IF;

    SELECT * INTO v_opponent_profile FROM public.profiles WHERE id = v_opponent_id;
    SELECT * INTO v_room FROM public.rooms WHERE id = v_qm.room_id;
    SELECT * INTO v_game FROM public.games WHERE id = v_qm.game_id;

    RETURN jsonb_build_object(
        'has_active_match', true,
        'match_id', v_qm.id,
        'room_id', v_qm.room_id,
        'room_code', v_room.code,
        'game_id', v_qm.game_id,
        'status', v_qm.status,
        'countdown_deadline', v_qm.countdown_deadline,
        'prep_deadline', v_game.prep_deadline,
        'game_status', v_game.status,
        'opponent', jsonb_build_object(
            'id', v_opponent_profile.id,
            'display_name', v_opponent_profile.display_name,
            'avatar_color_hex', v_opponent_profile.avatar_color_hex
        )
    );
END;
$$;

-- 10. RPC: rpc_get_quick_match_details
-- Fetches authoritative match state along with both player profiles
CREATE OR REPLACE FUNCTION public.rpc_get_quick_match_details(
    p_match_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_qm public.quick_matches%ROWTYPE;
    v_room public.rooms%ROWTYPE;
    v_game public.games%ROWTYPE;
    v_p1 public.profiles%ROWTYPE;
    v_p2 public.profiles%ROWTYPE;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
    END IF;

    SELECT * INTO v_qm
    FROM public.quick_matches
    WHERE id = p_match_id AND (player1_id = v_user_id OR player2_id = v_user_id);

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Match not found');
    END IF;

    SELECT * INTO v_room FROM public.rooms WHERE id = v_qm.room_id;
    SELECT * INTO v_game FROM public.games WHERE id = v_qm.game_id;
    SELECT * INTO v_p1 FROM public.profiles WHERE id = v_qm.player1_id;
    SELECT * INTO v_p2 FROM public.profiles WHERE id = v_qm.player2_id;

    RETURN jsonb_build_object(
        'success', true,
        'match_id', v_qm.id,
        'room_id', v_qm.room_id,
        'room_code', v_room.code,
        'game_id', v_qm.game_id,
        'status', v_qm.status,
        'countdown_deadline', v_qm.countdown_deadline,
        'prep_deadline', v_game.prep_deadline,
        'player1', jsonb_build_object(
            'id', v_p1.id,
            'display_name', v_p1.display_name,
            'avatar_color_hex', v_p1.avatar_color_hex
        ),
        'player2', jsonb_build_object(
            'id', v_p2.id,
            'display_name', v_p2.display_name,
            'avatar_color_hex', v_p2.avatar_color_hex
        )
    );
END;
$$;
