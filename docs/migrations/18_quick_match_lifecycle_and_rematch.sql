-- Migration 18: Quick Match Lifecycle Correction, Result Separation, and Bilateral Rematch System
-- Authoritative Supabase PostgreSQL migration for BINGO Quick Match 1v1

-- ============================================================================
-- 1. EXTEND ROOMS WITH MATCH TYPE
-- ============================================================================

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public' AND table_name = 'rooms' AND column_name = 'match_type'
    ) THEN
        ALTER TABLE public.rooms
            ADD COLUMN match_type TEXT NOT NULL DEFAULT 'PRIVATE_ROOM'
            CHECK (match_type IN ('PRIVATE_ROOM', 'QUICK_MATCH'));
    END IF;
END $$;

-- Backfill existing quick match rooms
UPDATE public.rooms
SET match_type = 'QUICK_MATCH'
WHERE id IN (SELECT room_id FROM public.quick_matches);

CREATE INDEX IF NOT EXISTS idx_rooms_match_type ON public.rooms(match_type);

-- ============================================================================
-- 2. CREATE QUICK MATCH REMATCH REQUESTS TABLE
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.quick_match_rematch_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    previous_match_id UUID NOT NULL REFERENCES public.quick_matches(id) ON DELETE CASCADE,
    requester_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    opponent_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    status TEXT NOT NULL CHECK (status IN ('PENDING', 'ACCEPTED', 'DECLINED', 'EXPIRED', 'CANCELLED')) DEFAULT 'PENDING',
    new_match_id UUID REFERENCES public.quick_matches(id) ON DELETE SET NULL,
    expires_at TIMESTAMPTZ NOT NULL DEFAULT (timezone('utc'::text, now()) + interval '30 seconds'),
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    responded_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- Constraint: Only one active (PENDING) rematch request per previous match
CREATE UNIQUE INDEX IF NOT EXISTS idx_qm_active_rematch
    ON public.quick_match_rematch_requests(previous_match_id)
    WHERE status = 'PENDING';

CREATE INDEX IF NOT EXISTS idx_qm_rematch_users
    ON public.quick_match_rematch_requests(requester_user_id, opponent_user_id, status);

CREATE INDEX IF NOT EXISTS idx_qm_rematch_expires
    ON public.quick_match_rematch_requests(expires_at)
    WHERE status = 'PENDING';

-- Enable Realtime
ALTER TABLE public.quick_match_rematch_requests REPLICA IDENTITY FULL;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables
        WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'quick_match_rematch_requests'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.quick_match_rematch_requests;
    END IF;
END $$;

-- Row Level Security
ALTER TABLE public.quick_match_rematch_requests ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Participants can view their rematch requests" ON public.quick_match_rematch_requests;
CREATE POLICY "Participants can view their rematch requests"
    ON public.quick_match_rematch_requests FOR SELECT
    TO authenticated
    USING (requester_user_id = auth.uid() OR opponent_user_id = auth.uid());

-- ============================================================================
-- 3. TRIGGER: AUTOMATICALLY SYNC QUICK MATCH STATUS ON GAME COMPLETION
-- ============================================================================

CREATE OR REPLACE FUNCTION public.fn_sync_quick_match_completion()
RETURNS TRIGGER AS $$
DECLARE
    v_qm public.quick_matches%ROWTYPE;
    v_is_forfeited BOOLEAN := FALSE;
BEGIN
    SELECT * INTO v_qm FROM public.quick_matches WHERE game_id = NEW.id;
    IF FOUND THEN
        -- Check if any participant in this game has is_forfeited = true
        SELECT EXISTS (
            SELECT 1 FROM public.game_player_states
            WHERE game_id = NEW.id AND is_forfeited = TRUE
        ) INTO v_is_forfeited;

        -- Update quick match to COMPLETED or FORFEITED
        UPDATE public.quick_matches
        SET status = CASE WHEN v_is_forfeited THEN 'FORFEITED' ELSE 'COMPLETED' END,
            updated_at = timezone('utc'::text, now())
        WHERE id = v_qm.id;

        -- Update matchmaking queue entries for this match to COMPLETED
        UPDATE public.matchmaking_queue
        SET status = 'COMPLETED',
            updated_at = timezone('utc'::text, now())
        WHERE match_id = v_qm.id AND status = 'MATCHED';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

DROP TRIGGER IF EXISTS trg_sync_quick_match_completion ON public.games;
CREATE TRIGGER trg_sync_quick_match_completion
    AFTER UPDATE OF status ON public.games
    FOR EACH ROW
    WHEN (NEW.status IN ('completed', 'cancelled'))
    EXECUTE FUNCTION public.fn_sync_quick_match_completion();

-- ============================================================================
-- 4. RPC: rpc_get_quick_match_by_room
-- ============================================================================

CREATE OR REPLACE FUNCTION public.rpc_get_quick_match_by_room(
    p_room_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_qm public.quick_matches%ROWTYPE;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
    END IF;

    SELECT * INTO v_qm
    FROM public.quick_matches
    WHERE room_id = p_room_id AND (player1_id = v_user_id OR player2_id = v_user_id)
    ORDER BY created_at DESC
    LIMIT 1;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'is_quick_match', false);
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'is_quick_match', true,
        'match_id', v_qm.id,
        'room_id', v_qm.room_id,
        'game_id', v_qm.game_id,
        'status', v_qm.status
    );
END;
$$;

-- ============================================================================
-- 5. RPC: rpc_get_active_quick_match (STALE MATCH IMMUNITY)
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
BEGIN
    IF v_user_id IS NULL THEN
        RETURN jsonb_build_object('has_active_match', false, 'error', 'Not authenticated');
    END IF;

    -- Look for truly active quick match
    SELECT * INTO v_qm
    FROM public.quick_matches
    WHERE (player1_id = v_user_id OR player2_id = v_user_id)
      AND status IN ('COUNTDOWN', 'BOARD_PREPARATION', 'IN_PROGRESS')
    ORDER BY created_at DESC
    LIMIT 1;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('has_active_match', false);
    END IF;

    -- Verify linked room and game status
    SELECT * INTO v_game FROM public.games WHERE id = v_qm.game_id;
    SELECT * INTO v_room FROM public.rooms WHERE id = v_qm.room_id;

    -- If linked game or room is completed/cancelled, this match is NOT active
    IF (v_game.status IN ('completed', 'cancelled')) OR (v_room.status = 'completed') THEN
        UPDATE public.quick_matches
        SET status = 'COMPLETED',
            updated_at = timezone('utc'::text, now())
        WHERE id = v_qm.id;

        UPDATE public.matchmaking_queue
        SET status = 'COMPLETED',
            updated_at = timezone('utc'::text, now())
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
            'display_name', v_opponent_profile.display_name,
            'avatar_color_hex', v_opponent_profile.avatar_color_hex
        )
    );
END;
$$;

-- ============================================================================
-- 6. RPC: rpc_enter_matchmaking_queue (UPDATED WITH MATCH_TYPE & CLEANUP)
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
    v_existing_active_match RECORD;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
    END IF;

    SELECT * INTO v_user_profile FROM public.profiles WHERE id = v_user_id;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'User profile not found');
    END IF;

    -- Clean up stale searching entries older than 3 minutes
    UPDATE public.matchmaking_queue
    SET status = 'EXPIRED', updated_at = timezone('utc'::text, now())
    WHERE status = 'SEARCHING' AND queued_at < timezone('utc'::text, now()) - interval '3 minutes';

    -- Check if caller already has a GENUINELY active quick match
    SELECT qm.*, r.code as room_code, g.status as game_status
    INTO v_existing_active_match
    FROM public.quick_matches qm
    JOIN public.rooms r ON r.id = qm.room_id
    JOIN public.games g ON g.id = qm.game_id
    WHERE (qm.player1_id = v_user_id OR qm.player2_id = v_user_id)
      AND qm.status IN ('COUNTDOWN', 'BOARD_PREPARATION', 'IN_PROGRESS')
      AND g.status NOT IN ('completed', 'cancelled')
      AND r.status != 'completed'
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

    -- Cancel any previous SEARCHING queue entry for caller
    UPDATE public.matchmaking_queue
    SET status = 'CANCELLED', updated_at = timezone('utc'::text, now())
    WHERE user_id = v_user_id AND status = 'SEARCHING';

    -- ATOMIC PAIRING: Find available waiting opponent
    SELECT * INTO v_opponent_queue
    FROM public.matchmaking_queue
    WHERE status = 'SEARCHING'
      AND user_id != v_user_id
    ORDER BY queued_at ASC
    LIMIT 1
    FOR UPDATE SKIP LOCKED;

    IF FOUND THEN
        SELECT * INTO v_opponent_profile FROM public.profiles WHERE id = v_opponent_queue.user_id;

        -- Verify opponent does not have conflicting active match
        IF EXISTS (
            SELECT 1 FROM public.quick_matches qm
            JOIN public.games g ON g.id = qm.game_id
            WHERE (qm.player1_id = v_opponent_queue.user_id OR qm.player2_id = v_opponent_queue.user_id)
              AND qm.status IN ('COUNTDOWN', 'BOARD_PREPARATION', 'IN_PROGRESS')
              AND g.status NOT IN ('completed', 'cancelled')
        ) THEN
            UPDATE public.matchmaking_queue
            SET status = 'EXPIRED', updated_at = timezone('utc'::text, now())
            WHERE id = v_opponent_queue.id;

            INSERT INTO public.matchmaking_queue (user_id, status, region, queued_at)
            VALUES (v_user_id, 'SEARCHING', p_region, timezone('utc'::text, now()))
            RETURNING id INTO v_queue_id;

            RETURN jsonb_build_object('success', true, 'status', 'SEARCHING', 'queue_id', v_queue_id);
        END IF;

        -- Create shared room with match_type = 'QUICK_MATCH'
        v_room_code := public.fn_generate_quick_match_room_code();
        v_room_id := gen_random_uuid();
        v_game_id := gen_random_uuid();
        v_quick_match_id := gen_random_uuid();
        v_countdown_deadline := timezone('utc'::text, now()) + interval '10 seconds';

        INSERT INTO public.rooms (
            id, code, name, host_id, max_players, prep_time_seconds, turn_time_seconds, status, match_type, created_at, updated_at
        ) VALUES (
            v_room_id, v_room_code, 'Quick Match 1v1', v_opponent_queue.user_id, 2, 30, 20, 'preparing', 'QUICK_MATCH', timezone('utc'::text, now()), timezone('utc'::text, now())
        );

        INSERT INTO public.room_players (id, room_id, user_id, is_host, is_ready, seat_index, joined_at)
        VALUES
            (gen_random_uuid(), v_room_id, v_opponent_queue.user_id, TRUE, TRUE, 0, timezone('utc'::text, now())),
            (gen_random_uuid(), v_room_id, v_user_id, FALSE, TRUE, 1, timezone('utc'::text, now()));

        INSERT INTO public.games (
            id, room_id, status, prep_deadline, current_turn_user_id, round_number, created_at, updated_at
        ) VALUES (
            v_game_id, v_room_id, 'preparing', v_countdown_deadline + interval '30 seconds', v_opponent_queue.user_id, 1, timezone('utc'::text, now()), timezone('utc'::text, now())
        );

        INSERT INTO public.game_player_states (id, game_id, user_id, lines_claimed, claimed_line_types, is_winner, is_forfeited, created_at, updated_at)
        VALUES
            (gen_random_uuid(), v_game_id, v_opponent_queue.user_id, 0, '{}'::TEXT[], FALSE, FALSE, timezone('utc'::text, now()), timezone('utc'::text, now())),
            (gen_random_uuid(), v_game_id, v_user_id, 0, '{}'::TEXT[], FALSE, FALSE, timezone('utc'::text, now()), timezone('utc'::text, now()));

        INSERT INTO public.quick_matches (
            id, room_id, game_id, player1_id, player2_id, status, countdown_deadline, created_at, updated_at
        ) VALUES (
            v_quick_match_id, v_room_id, v_game_id, v_opponent_queue.user_id, v_user_id, 'COUNTDOWN', v_countdown_deadline, timezone('utc'::text, now()), timezone('utc'::text, now())
        );

        UPDATE public.matchmaking_queue
        SET status = 'MATCHED', match_id = v_quick_match_id, matched_at = timezone('utc'::text, now()), updated_at = timezone('utc'::text, now())
        WHERE id = v_opponent_queue.id;

        INSERT INTO public.matchmaking_queue (user_id, status, region, match_id, queued_at, matched_at)
        VALUES (v_user_id, 'MATCHED', p_region, v_quick_match_id, timezone('utc'::text, now()), timezone('utc'::text, now()));

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
                'display_name', v_opponent_profile.display_name,
                'avatar_color_hex', v_opponent_profile.avatar_color_hex
            )
        );
    ELSE
        INSERT INTO public.matchmaking_queue (user_id, status, region, queued_at)
        VALUES (v_user_id, 'SEARCHING', p_region, timezone('utc'::text, now()))
        RETURNING id INTO v_queue_id;

        RETURN jsonb_build_object('success', true, 'status', 'SEARCHING', 'queue_id', v_queue_id);
    END IF;
END;
$$;

-- ============================================================================
-- 7. RPC: rpc_get_quick_match_details (COMPREHENSIVE RESULT STATS)
-- ============================================================================

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
    v_gps1 public.game_player_states%ROWTYPE;
    v_gps2 public.game_player_states%ROWTYPE;
    v_duration_seconds INT := 0;
    v_total_calls INT := 0;
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
    SELECT * INTO v_gps1 FROM public.game_player_states WHERE game_id = v_qm.game_id AND user_id = v_qm.player1_id;
    SELECT * INTO v_gps2 FROM public.game_player_states WHERE game_id = v_qm.game_id AND user_id = v_qm.player2_id;

    -- Calculate duration
    IF v_game.completed_at IS NOT NULL AND v_game.created_at IS NOT NULL THEN
        v_duration_seconds := EXTRACT(EPOCH FROM (v_game.completed_at - v_game.created_at))::INT;
    ELSE
        v_duration_seconds := EXTRACT(EPOCH FROM (timezone('utc'::text, now()) - v_game.created_at))::INT;
    END IF;
    IF v_duration_seconds < 0 THEN
        v_duration_seconds := 0;
    END IF;

    v_total_calls := COALESCE(array_length(v_game.called_numbers, 1), 0);

    RETURN jsonb_build_object(
        'success', true,
        'match_id', v_qm.id,
        'room_id', v_qm.room_id,
        'room_code', v_room.code,
        'game_id', v_qm.game_id,
        'status', v_qm.status,
        'countdown_deadline', v_qm.countdown_deadline,
        'prep_deadline', v_game.prep_deadline,
        'game_status', v_game.status,
        'winner_user_id', v_game.winner_user_id,
        'total_calls', v_total_calls,
        'duration_seconds', v_duration_seconds,
        'called_numbers', COALESCE(v_game.called_numbers, '{}'::INT[]),
        'player1', jsonb_build_object(
            'id', v_p1.id,
            'display_name', v_p1.display_name,
            'avatar_color_hex', v_p1.avatar_color_hex,
            'lines_claimed', COALESCE(v_gps1.lines_claimed, 0),
            'claimed_line_types', COALESCE(v_gps1.claimed_line_types, '{}'::TEXT[]),
            'is_winner', COALESCE(v_gps1.is_winner, FALSE),
            'is_forfeited', COALESCE(v_gps1.is_forfeited, FALSE)
        ),
        'player2', jsonb_build_object(
            'id', v_p2.id,
            'display_name', v_p2.display_name,
            'avatar_color_hex', v_p2.avatar_color_hex,
            'lines_claimed', COALESCE(v_gps2.lines_claimed, 0),
            'claimed_line_types', COALESCE(v_gps2.claimed_line_types, '{}'::TEXT[]),
            'is_winner', COALESCE(v_gps2.is_winner, FALSE),
            'is_forfeited', COALESCE(v_gps2.is_forfeited, FALSE)
        )
    );
END;
$$;

-- ============================================================================
-- 8. RPC: BILATERAL REMATCH SYSTEM
-- ============================================================================

-- 8a. Request Rematch
CREATE OR REPLACE FUNCTION public.rpc_request_quick_match_rematch(
    p_previous_match_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_prev_qm public.quick_matches%ROWTYPE;
    v_opponent_id UUID;
    v_request_id UUID;
    v_now TIMESTAMPTZ := timezone('utc'::text, now());
    v_expires_at TIMESTAMPTZ := v_now + interval '30 seconds';
    v_existing_request public.quick_match_rematch_requests%ROWTYPE;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
    END IF;

    -- Verify previous match and caller participation
    SELECT * INTO v_prev_qm
    FROM public.quick_matches
    WHERE id = p_previous_match_id AND (player1_id = v_user_id OR player2_id = v_user_id);

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Previous match not found');
    END IF;

    -- Ensure previous match is completed or forfeited
    IF v_prev_qm.status NOT IN ('COMPLETED', 'FORFEITED') THEN
        -- Check if linked game is completed
        IF NOT EXISTS (SELECT 1 FROM public.games WHERE id = v_prev_qm.game_id AND status IN ('completed', 'cancelled')) THEN
            RETURN jsonb_build_object('success', false, 'error', 'Previous match has not concluded yet');
        END IF;
    END IF;

    -- Determine opponent ID
    IF v_prev_qm.player1_id = v_user_id THEN
        v_opponent_id := v_prev_qm.player2_id;
    ELSE
        v_opponent_id := v_prev_qm.player1_id;
    END IF;

    -- Check if there is an active pending rematch request
    SELECT * INTO v_existing_request
    FROM public.quick_match_rematch_requests
    WHERE previous_match_id = p_previous_match_id AND status = 'PENDING';

    IF FOUND THEN
        -- If expired, mark EXPIRED
        IF v_existing_request.expires_at <= v_now THEN
            UPDATE public.quick_match_rematch_requests
            SET status = 'EXPIRED', updated_at = v_now
            WHERE id = v_existing_request.id;
        ELSIF v_existing_request.requester_user_id = v_user_id THEN
            -- Already requested by caller
            RETURN jsonb_build_object(
                'success', true,
                'request_id', v_existing_request.id,
                'status', 'PENDING',
                'expires_at', v_existing_request.expires_at,
                'is_requester', true
            );
        ELSE
            -- Opponent already sent a rematch request! Caller can accept it!
            RETURN jsonb_build_object(
                'success', true,
                'request_id', v_existing_request.id,
                'status', 'PENDING',
                'expires_at', v_existing_request.expires_at,
                'is_requester', false,
                'can_accept', true
            );
        END IF;
    END IF;

    -- Create fresh rematch request
    INSERT INTO public.quick_match_rematch_requests (
        previous_match_id, requester_user_id, opponent_user_id, status, expires_at, created_at, updated_at
    ) VALUES (
        p_previous_match_id, v_user_id, v_opponent_id, 'PENDING', v_expires_at, v_now, v_now
    ) RETURNING id INTO v_request_id;

    RETURN jsonb_build_object(
        'success', true,
        'request_id', v_request_id,
        'status', 'PENDING',
        'expires_at', v_expires_at,
        'is_requester', true
    );
END;
$$;

-- 8b. Respond to Rematch (Accept or Decline)
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

    -- Verify respondent is the opponent
    IF v_req.opponent_user_id != v_user_id THEN
        RETURN jsonb_build_object('success', false, 'error', 'Only the designated opponent can respond');
    END IF;

    -- Verify request is PENDING and not expired
    IF v_req.status != 'PENDING' THEN
        RETURN jsonb_build_object('success', false, 'error', 'Request is no longer pending', 'status', v_req.status);
    END IF;

    IF v_req.expires_at <= v_now THEN
        UPDATE public.quick_match_rematch_requests
        SET status = 'EXPIRED', updated_at = v_now
        WHERE id = v_req.id;
        RETURN jsonb_build_object('success', false, 'error', 'Rematch request has expired', 'status', 'EXPIRED');
    END IF;

    -- If DECLINED
    IF NOT p_accept THEN
        UPDATE public.quick_match_rematch_requests
        SET status = 'DECLINED', responded_at = v_now, updated_at = v_now
        WHERE id = v_req.id;

        RETURN jsonb_build_object('success', true, 'status', 'DECLINED');
    END IF;

    -- If ACCEPTED: Atomically create NEW Quick Match 1v1
    SELECT * INTO v_prev_qm FROM public.quick_matches WHERE id = v_req.previous_match_id;

    v_new_match_id := gen_random_uuid();
    v_room_id := gen_random_uuid();
    v_game_id := gen_random_uuid();
    v_room_code := public.fn_generate_quick_match_room_code();
    v_countdown_deadline := v_now + interval '10 seconds';

    -- Create room
    INSERT INTO public.rooms (
        id, code, name, host_id, max_players, prep_time_seconds, turn_time_seconds, status, match_type, created_at, updated_at
    ) VALUES (
        v_room_id, v_room_code, 'Quick Match 1v1', v_req.requester_user_id, 2, 30, 20, 'preparing', 'QUICK_MATCH', v_now, v_now
    );

    -- Room players
    INSERT INTO public.room_players (id, room_id, user_id, is_host, is_ready, seat_index, joined_at)
    VALUES
        (gen_random_uuid(), v_room_id, v_req.requester_user_id, TRUE, TRUE, 0, v_now),
        (gen_random_uuid(), v_room_id, v_req.opponent_user_id, FALSE, TRUE, 1, v_now);

    -- Game
    INSERT INTO public.games (
        id, room_id, status, prep_deadline, current_turn_user_id, round_number, created_at, updated_at
    ) VALUES (
        v_game_id, v_room_id, 'preparing', v_countdown_deadline + interval '30 seconds', v_req.requester_user_id, 1, v_now, v_now
    );

    -- Game player states
    INSERT INTO public.game_player_states (id, game_id, user_id, lines_claimed, claimed_line_types, is_winner, is_forfeited, created_at, updated_at)
    VALUES
        (gen_random_uuid(), v_game_id, v_req.requester_user_id, 0, '{}'::TEXT[], FALSE, FALSE, v_now, v_now),
        (gen_random_uuid(), v_game_id, v_req.opponent_user_id, 0, '{}'::TEXT[], FALSE, FALSE, v_now, v_now);

    -- New Quick Match
    INSERT INTO public.quick_matches (
        id, room_id, game_id, player1_id, player2_id, status, countdown_deadline, created_at, updated_at
    ) VALUES (
        v_new_match_id, v_room_id, v_game_id, v_req.requester_user_id, v_req.opponent_user_id, 'COUNTDOWN', v_countdown_deadline, v_now, v_now
    );

    -- Update rematch request
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

-- 8c. Cancel Rematch Request
CREATE OR REPLACE FUNCTION public.rpc_cancel_quick_match_rematch(
    p_request_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_req public.quick_match_rematch_requests%ROWTYPE;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
    END IF;

    SELECT * INTO v_req FROM public.quick_match_rematch_requests WHERE id = p_request_id;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Request not found');
    END IF;

    IF v_req.requester_user_id != v_user_id AND v_req.opponent_user_id != v_user_id THEN
        RETURN jsonb_build_object('success', false, 'error', 'Not authorized');
    END IF;

    IF v_req.status = 'PENDING' THEN
        UPDATE public.quick_match_rematch_requests
        SET status = 'CANCELLED', updated_at = timezone('utc'::text, now())
        WHERE id = p_request_id;
    END IF;

    RETURN jsonb_build_object('success', true, 'status', 'CANCELLED');
END;
$$;

-- 8d. Get Pending Rematch Request
CREATE OR REPLACE FUNCTION public.rpc_get_pending_rematch_request(
    p_match_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_req public.quick_match_rematch_requests%ROWTYPE;
    v_other_user_id UUID;
    v_other_profile public.profiles%ROWTYPE;
    v_now TIMESTAMPTZ := timezone('utc'::text, now());
BEGIN
    IF v_user_id IS NULL THEN
        RETURN jsonb_build_object('has_pending_request', false, 'error', 'Not authenticated');
    END IF;

    IF p_match_id IS NOT NULL THEN
        SELECT * INTO v_req
        FROM public.quick_match_rematch_requests
        WHERE previous_match_id = p_match_id AND (requester_user_id = v_user_id OR opponent_user_id = v_user_id)
        ORDER BY created_at DESC
        LIMIT 1;
    ELSE
        SELECT * INTO v_req
        FROM public.quick_match_rematch_requests
        WHERE (requester_user_id = v_user_id OR opponent_user_id = v_user_id)
          AND status IN ('PENDING', 'ACCEPTED')
        ORDER BY created_at DESC
        LIMIT 1;
    END IF;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('has_pending_request', false);
    END IF;

    -- If pending but expired, mark EXPIRED
    IF v_req.status = 'PENDING' AND v_req.expires_at <= v_now THEN
        UPDATE public.quick_match_rematch_requests
        SET status = 'EXPIRED', updated_at = v_now
        WHERE id = v_req.id;
        RETURN jsonb_build_object('has_pending_request', false, 'status', 'EXPIRED');
    END IF;

    -- Determine opponent profile relative to caller
    IF v_req.requester_user_id = v_user_id THEN
        v_other_user_id := v_req.opponent_user_id;
    ELSE
        v_other_user_id := v_req.requester_user_id;
    END IF;

    SELECT * INTO v_other_profile FROM public.profiles WHERE id = v_other_user_id;

    RETURN jsonb_build_object(
        'has_pending_request', true,
        'request_id', v_req.id,
        'previous_match_id', v_req.previous_match_id,
        'status', v_req.status,
        'is_requester', (v_req.requester_user_id = v_user_id),
        'expires_at', v_req.expires_at,
        'seconds_remaining', GREATEST(0, EXTRACT(EPOCH FROM (v_req.expires_at - v_now))::INT),
        'new_match_id', v_req.new_match_id,
        'opponent', jsonb_build_object(
            'id', v_other_profile.id,
            'display_name', v_other_profile.display_name,
            'avatar_color_hex', v_other_profile.avatar_color_hex
        )
    );
END;
$$;
