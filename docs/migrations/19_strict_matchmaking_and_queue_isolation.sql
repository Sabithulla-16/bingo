-- ============================================================================
-- Migration 19: Strict Matchmaking Isolation, Dead Match Expiry & Atomic Queue Safety
-- Target: Supabase PostgreSQL (pqkrqppxbnrjcgxvmogn.supabase.co)
-- ============================================================================

-- 1. SCHEMA HARDENING & CLEANUP HISTORICAL STALE DATA
-- ============================================================================

-- Ensure game_player_states columns have safe defaults to prevent null constraint errors
ALTER TABLE public.game_player_states ALTER COLUMN board_numbers SET DEFAULT '{}'::INTEGER[];
ALTER TABLE public.game_player_states ALTER COLUMN board_confirmed SET DEFAULT FALSE;

-- Expire any lingering search entries
UPDATE public.matchmaking_queue
SET status = 'EXPIRED', updated_at = timezone('utc'::text, now())
WHERE status = 'SEARCHING';

-- Mark any historical abandoned quick matches as CANCELLED so they can never be restored
UPDATE public.quick_matches
SET status = 'CANCELLED', updated_at = timezone('utc'::text, now())
WHERE status IN ('COUNTDOWN', 'BOARD_PREPARATION')
  AND created_at < timezone('utc'::text, now()) - interval '5 minutes';

-- Ensure unique partial index so a user cannot have multiple SEARCHING entries
CREATE UNIQUE INDEX IF NOT EXISTS uq_idx_matchmaking_queue_searching
ON public.matchmaking_queue(user_id)
WHERE status = 'SEARCHING';

-- ============================================================================
-- 2. RPC: rpc_cancel_matchmaking_queue (TARGET ONLY CURRENT SEARCHING ENTRY)
-- ============================================================================

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

    -- Look ONLY for a currently SEARCHING entry for this caller
    SELECT * INTO v_queue
    FROM public.matchmaking_queue
    WHERE user_id = v_user_id AND status = 'SEARCHING'
    ORDER BY queued_at DESC
    LIMIT 1
    FOR UPDATE;

    IF NOT FOUND THEN
        -- No active searching entry; already idle. Never return historical MATCHED entries!
        RETURN jsonb_build_object('success', true, 'status', 'IDLE');
    END IF;

    -- Atomically mark CANCELLED
    UPDATE public.matchmaking_queue
    SET status = 'CANCELLED',
        updated_at = timezone('utc'::text, now())
    WHERE id = v_queue.id;

    RETURN jsonb_build_object('success', true, 'status', 'CANCELLED');
END;
$$;

GRANT EXECUTE ON FUNCTION public.rpc_cancel_matchmaking_queue() TO authenticated;

-- ============================================================================
-- 3. RPC: rpc_get_active_quick_match (STRICT DEADLINE VALIDATION)
-- ============================================================================

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
    v_now TIMESTAMPTZ := timezone('utc'::text, now());
    v_is_dead BOOLEAN := FALSE;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN jsonb_build_object('has_active_match', false, 'error', 'Not authenticated');
    END IF;

    -- Look for potentially active quick match
    SELECT * INTO v_qm
    FROM public.quick_matches
    WHERE (player1_id = v_user_id OR player2_id = v_user_id)
      AND status IN ('COUNTDOWN', 'BOARD_PREPARATION', 'IN_PROGRESS')
    ORDER BY created_at DESC
    LIMIT 1;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('has_active_match', false);
    END IF;

    SELECT * INTO v_game FROM public.games WHERE id = v_qm.game_id;
    SELECT * INTO v_room FROM public.rooms WHERE id = v_qm.room_id;

    -- Check terminal states with explicit TEXT cast
    IF (v_game.status IN ('completed', 'cancelled')) OR (v_room.status::TEXT IN ('completed', 'finished', 'closed')) THEN
        v_is_dead := TRUE;
    END IF;

    -- Check deadline expiration:
    -- 1. COUNTDOWN matches must have an active or recent countdown deadline (max 25s elapsed)
    IF v_qm.status = 'COUNTDOWN' AND (v_qm.countdown_deadline + interval '25 seconds' < v_now) THEN
        v_is_dead := TRUE;
    END IF;

    -- 2. BOARD_PREPARATION matches must not have lapsed beyond prep_deadline
    IF v_qm.status = 'BOARD_PREPARATION' AND (v_game.prep_deadline + interval '30 seconds' < v_now) THEN
        v_is_dead := TRUE;
    END IF;

    -- 3. IN_PROGRESS matches older than 15 minutes are considered dead
    IF v_qm.status = 'IN_PROGRESS' AND (v_qm.created_at + interval '15 minutes' < v_now) THEN
        v_is_dead := TRUE;
    END IF;

    IF v_is_dead THEN
        -- Authoritatively close the dead match so it never influences matchmaking again
        UPDATE public.quick_matches
        SET status = 'CANCELLED', updated_at = v_now
        WHERE id = v_qm.id AND status IN ('COUNTDOWN', 'BOARD_PREPARATION', 'IN_PROGRESS');

        UPDATE public.games
        SET status = 'cancelled', updated_at = v_now
        WHERE id = v_qm.game_id AND status NOT IN ('completed', 'cancelled');

        UPDATE public.rooms
        SET status = 'completed', updated_at = v_now
        WHERE id = v_qm.room_id AND status::TEXT != 'completed';

        UPDATE public.matchmaking_queue
        SET status = 'EXPIRED', updated_at = v_now
        WHERE match_id = v_qm.id AND status = 'MATCHED';

        RETURN jsonb_build_object('has_active_match', false);
    END IF;

    -- Identify opponent
    IF v_qm.player1_id = v_user_id THEN
        v_opponent_id := v_qm.player2_id;
    ELSE
        v_opponent_id := v_qm.player1_id;
    END IF;

    SELECT * INTO v_opponent_profile FROM public.profiles WHERE id = v_opponent_id;

    RETURN jsonb_build_object(
        'has_active_match', true,
        'match_id', v_qm.id,
        'room_id', v_qm.room_id,
        'room_code', v_room.code,
        'game_id', v_qm.game_id,
        'status', v_qm.status,
        'countdown_deadline', v_qm.countdown_deadline,
        'opponent', jsonb_build_object(
            'id', v_opponent_profile.id,
            'display_name', COALESCE(v_opponent_profile.display_name, 'Opponent'),
            'avatar_color_hex', COALESCE(v_opponent_profile.avatar_color_hex, '#20243A')
        )
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.rpc_get_active_quick_match() TO authenticated;

-- ============================================================================
-- 4. RPC: rpc_enter_matchmaking_queue (STRICT QUEUE ELIGIBILITY & ATOMICITY)
-- ============================================================================

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
    v_now TIMESTAMPTZ := timezone('utc'::text, now());
    v_existing_active_match RECORD;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
    END IF;

    SELECT * INTO v_user_profile FROM public.profiles WHERE id = v_user_id;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'User profile not found');
    END IF;

    -- 1. STRICT EXPIRATION: Expire ANY search entries older than 30 seconds
    UPDATE public.matchmaking_queue
    SET status = 'EXPIRED', updated_at = v_now
    WHERE status = 'SEARCHING' AND queued_at < v_now - interval '30 seconds';

    -- 2. CHECK CALLER ACTIVE MATCH: Only truly live matches are restored
    SELECT qm.*, r.code as room_code, g.status as game_status, g.prep_deadline
    INTO v_existing_active_match
    FROM public.quick_matches qm
    JOIN public.rooms r ON r.id = qm.room_id
    JOIN public.games g ON g.id = qm.game_id
    WHERE (qm.player1_id = v_user_id OR qm.player2_id = v_user_id)
      AND qm.status IN ('COUNTDOWN', 'BOARD_PREPARATION', 'IN_PROGRESS')
      AND g.status NOT IN ('completed', 'cancelled')
      AND r.status::TEXT NOT IN ('completed', 'finished', 'closed')
    ORDER BY qm.created_at DESC
    LIMIT 1;

    IF FOUND THEN
        -- Validate deadline. If dead, close it and proceed with fresh search
        IF (v_existing_active_match.status = 'COUNTDOWN' AND v_existing_active_match.countdown_deadline + interval '25 seconds' < v_now) OR
           (v_existing_active_match.status = 'BOARD_PREPARATION' AND v_existing_active_match.prep_deadline + interval '30 seconds' < v_now) OR
           (v_existing_active_match.status = 'IN_PROGRESS' AND v_existing_active_match.created_at + interval '15 minutes' < v_now) THEN
            UPDATE public.quick_matches SET status = 'CANCELLED', updated_at = v_now WHERE id = v_existing_active_match.id;
            UPDATE public.games SET status = 'cancelled', updated_at = v_now WHERE id = v_existing_active_match.game_id;
            UPDATE public.rooms SET status = 'completed', updated_at = v_now WHERE id = v_existing_active_match.room_id;
        ELSE
            -- Genuinely active match exists; restore it
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
    END IF;

    -- 3. CANCEL ANY PRIOR SEARCHING QUEUE ENTRY FOR CALLER
    UPDATE public.matchmaking_queue
    SET status = 'CANCELLED', updated_at = v_now
    WHERE user_id = v_user_id AND status = 'SEARCHING';

    -- 4. ATOMIC OPPONENT SEARCH: Only match another player who is ACTIVELY searching right now
    SELECT * INTO v_opponent_queue
    FROM public.matchmaking_queue
    WHERE status = 'SEARCHING'
      AND user_id != v_user_id
      AND queued_at >= v_now - interval '30 seconds'
    ORDER BY queued_at ASC
    LIMIT 1
    FOR UPDATE SKIP LOCKED;

    IF FOUND THEN
        -- Verify opponent does not have conflicting active match
        IF EXISTS (
            SELECT 1 FROM public.quick_matches qm
            JOIN public.games g ON g.id = qm.game_id
            WHERE (qm.player1_id = v_opponent_queue.user_id OR qm.player2_id = v_opponent_queue.user_id)
              AND qm.status IN ('COUNTDOWN', 'BOARD_PREPARATION', 'IN_PROGRESS')
              AND g.status NOT IN ('completed', 'cancelled')
        ) THEN
            -- Opponent is busy; mark this queue entry expired
            UPDATE public.matchmaking_queue
            SET status = 'EXPIRED', updated_at = v_now
            WHERE id = v_opponent_queue.id;

            -- Place caller into SEARCHING queue
            INSERT INTO public.matchmaking_queue (user_id, status, region, queued_at)
            VALUES (v_user_id, 'SEARCHING', p_region, v_now)
            RETURNING id INTO v_queue_id;

            RETURN jsonb_build_object('success', true, 'status', 'SEARCHING', 'queue_id', v_queue_id);
        END IF;

        SELECT * INTO v_opponent_profile FROM public.profiles WHERE id = v_opponent_queue.user_id;

        -- CREATE AUTHORITATIVE ROOM & GAME
        v_room_code := public.fn_generate_quick_match_room_code();
        v_room_id := gen_random_uuid();
        v_game_id := gen_random_uuid();
        v_quick_match_id := gen_random_uuid();
        v_countdown_deadline := v_now + interval '10 seconds';

        INSERT INTO public.rooms (
            id, code, name, host_id, max_players, prep_time_seconds, turn_time_seconds, status, match_type, created_at, updated_at
        ) VALUES (
            v_room_id, v_room_code, 'Quick Match 1v1', v_opponent_queue.user_id, 2, 30, 20, 'preparing', 'QUICK_MATCH', v_now, v_now
        );

        INSERT INTO public.room_players (id, room_id, user_id, is_host, is_ready, seat_index, joined_at)
        VALUES
            (gen_random_uuid(), v_room_id, v_opponent_queue.user_id, TRUE, TRUE, 0, v_now),
            (gen_random_uuid(), v_room_id, v_user_id, FALSE, TRUE, 1, v_now);

        INSERT INTO public.games (
            id, room_id, status, prep_deadline, current_turn_user_id, round_number, created_at, updated_at
        ) VALUES (
            v_game_id, v_room_id, 'preparing', v_countdown_deadline + interval '30 seconds', v_opponent_queue.user_id, 1, v_now, v_now
        );

        -- Insert game player states with valid board_numbers and board_confirmed
        INSERT INTO public.game_player_states (
            id, game_id, user_id, board_numbers, board_confirmed, lines_claimed, claimed_line_types, is_winner, is_forfeited, created_at, updated_at
        ) VALUES
            (gen_random_uuid(), v_game_id, v_opponent_queue.user_id, '{}'::INTEGER[], FALSE, 0, '{}'::TEXT[], FALSE, FALSE, v_now, v_now),
            (gen_random_uuid(), v_game_id, v_user_id, '{}'::INTEGER[], FALSE, 0, '{}'::TEXT[], FALSE, FALSE, v_now, v_now);

        INSERT INTO public.quick_matches (
            id, room_id, game_id, player1_id, player2_id, status, countdown_deadline, created_at, updated_at
        ) VALUES (
            v_quick_match_id, v_room_id, v_game_id, v_opponent_queue.user_id, v_user_id, 'COUNTDOWN', v_countdown_deadline, v_now, v_now
        );

        -- Atomically update opponent's queue entry
        UPDATE public.matchmaking_queue
        SET status = 'MATCHED', match_id = v_quick_match_id, matched_at = v_now, updated_at = v_now
        WHERE id = v_opponent_queue.id;

        -- Record caller's matched entry
        INSERT INTO public.matchmaking_queue (user_id, status, region, match_id, queued_at, matched_at)
        VALUES (v_user_id, 'MATCHED', p_region, v_quick_match_id, v_now, v_now);

        RETURN jsonb_build_object(
            'success', true,
            'status', 'MATCHED',
            'match_id', v_quick_match_id,
            'room_id', v_room_id,
            'room_code', v_room_code,
            'game_id', v_game_id,
            'countdown_deadline', v_countdown_deadline,
            'opponent', jsonb_build_object(
                'id', v_opponent_profile.id,
                'display_name', COALESCE(v_opponent_profile.display_name, 'Opponent'),
                'avatar_color_hex', COALESCE(v_opponent_profile.avatar_color_hex, '#20243A')
            )
        );
    ELSE
        -- 5. NO OPPONENT FOUND: Insert single fresh SEARCHING entry
        INSERT INTO public.matchmaking_queue (user_id, status, region, queued_at)
        VALUES (v_user_id, 'SEARCHING', p_region, v_now)
        RETURNING id INTO v_queue_id;

        RETURN jsonb_build_object('success', true, 'status', 'SEARCHING', 'queue_id', v_queue_id);
    END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.rpc_enter_matchmaking_queue(TEXT) TO authenticated;

-- ============================================================================
-- 5. RPC: rpc_respond_quick_match_rematch (WITH BOARD NUMBERS FIX)
-- ============================================================================

CREATE OR REPLACE FUNCTION public.rpc_respond_quick_match_rematch(
    p_request_id UUID,
    p_accept BOOLEAN
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_req public.quick_match_rematch_requests%ROWTYPE;
    v_now TIMESTAMPTZ := timezone('utc'::text, now());
    v_prev_qm public.quick_matches%ROWTYPE;
    v_new_match_id UUID;
    v_room_id UUID;
    v_game_id UUID;
    v_room_code TEXT;
    v_countdown_deadline TIMESTAMPTZ;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
    END IF;

    SELECT * INTO v_req
    FROM public.quick_match_rematch_requests
    WHERE id = p_request_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Rematch request not found');
    END IF;

    IF v_req.opponent_user_id != v_user_id THEN
        RETURN jsonb_build_object('success', false, 'error', 'Only the designated opponent can respond');
    END IF;

    IF v_req.status != 'PENDING' THEN
        RETURN jsonb_build_object('success', false, 'error', 'Request is no longer pending', 'status', v_req.status);
    END IF;

    IF v_req.expires_at <= v_now THEN
        UPDATE public.quick_match_rematch_requests
        SET status = 'EXPIRED', updated_at = v_now
        WHERE id = v_req.id;
        RETURN jsonb_build_object('success', false, 'error', 'Rematch request has expired', 'status', 'EXPIRED');
    END IF;

    IF NOT p_accept THEN
        UPDATE public.quick_match_rematch_requests
        SET status = 'DECLINED', responded_at = v_now, updated_at = v_now
        WHERE id = v_req.id;

        RETURN jsonb_build_object('success', true, 'status', 'DECLINED');
    END IF;

    SELECT * INTO v_prev_qm FROM public.quick_matches WHERE id = v_req.previous_match_id;

    v_new_match_id := gen_random_uuid();
    v_room_id := gen_random_uuid();
    v_game_id := gen_random_uuid();
    v_room_code := public.fn_generate_quick_match_room_code();
    v_countdown_deadline := v_now + interval '10 seconds';

    INSERT INTO public.rooms (
        id, code, name, host_id, max_players, prep_time_seconds, turn_time_seconds, status, match_type, created_at, updated_at
    ) VALUES (
        v_room_id, v_room_code, 'Quick Match 1v1', v_req.requester_user_id, 2, 30, 20, 'preparing', 'QUICK_MATCH', v_now, v_now
    );

    INSERT INTO public.room_players (id, room_id, user_id, is_host, is_ready, seat_index, joined_at)
    VALUES
        (gen_random_uuid(), v_room_id, v_req.requester_user_id, TRUE, TRUE, 0, v_now),
        (gen_random_uuid(), v_room_id, v_req.opponent_user_id, FALSE, TRUE, 1, v_now);

    INSERT INTO public.games (
        id, room_id, status, prep_deadline, current_turn_user_id, round_number, created_at, updated_at
    ) VALUES (
        v_game_id, v_room_id, 'preparing', v_countdown_deadline + interval '30 seconds', v_req.requester_user_id, 1, v_now, v_now
    );

    -- Insert game player states with valid board_numbers and board_confirmed
    INSERT INTO public.game_player_states (
        id, game_id, user_id, board_numbers, board_confirmed, lines_claimed, claimed_line_types, is_winner, is_forfeited, created_at, updated_at
    ) VALUES
        (gen_random_uuid(), v_game_id, v_req.requester_user_id, '{}'::INTEGER[], FALSE, 0, '{}'::TEXT[], FALSE, FALSE, v_now, v_now),
        (gen_random_uuid(), v_game_id, v_req.opponent_user_id, '{}'::INTEGER[], FALSE, 0, '{}'::TEXT[], FALSE, FALSE, v_now, v_now);

    INSERT INTO public.quick_matches (
        id, room_id, game_id, player1_id, player2_id, status, countdown_deadline, created_at, updated_at
    ) VALUES (
        v_new_match_id, v_room_id, v_game_id, v_req.requester_user_id, v_req.opponent_user_id, 'COUNTDOWN', v_countdown_deadline, v_now, v_now
    );

    UPDATE public.quick_match_rematch_requests
    SET status = 'ACCEPTED', new_match_id = v_new_match_id, responded_at = v_now, updated_at = v_now
    WHERE id = v_req.id;

    RETURN jsonb_build_object(
        'success', true,
        'status', 'ACCEPTED',
        'request_id', v_req.id,
        'new_match_id', v_new_match_id,
        'room_id', v_room_id,
        'room_code', v_room_code,
        'game_id', v_game_id,
        'countdown_deadline', v_countdown_deadline
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.rpc_respond_quick_match_rematch(UUID, BOOLEAN) TO authenticated;
