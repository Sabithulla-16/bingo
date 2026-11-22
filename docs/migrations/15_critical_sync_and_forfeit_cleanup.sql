-- ==============================================================================
-- Migration 15: Critical Synchronization, Realtime Enforcement,
--               Host Waiting-Room Controls, and Authoritative Forfeit Cleanup
-- ==============================================================================

-- 0. Ensure room_status enum includes 'closed' and 'expired'
ALTER TYPE public.room_status ADD VALUE IF NOT EXISTS 'closed';
ALTER TYPE public.room_status ADD VALUE IF NOT EXISTS 'expired';

-- 1. Ensure room_match_history has all canonical columns
ALTER TABLE public.room_match_history
    ADD COLUMN IF NOT EXISTS game_id UUID,
    ADD COLUMN IF NOT EXISTS winner_id UUID,
    ADD COLUMN IF NOT EXISTS winner_user_id UUID,
    ADD COLUMN IF NOT EXISTS winner_name TEXT,
    ADD COLUMN IF NOT EXISTS winner_display_name TEXT,
    ADD COLUMN IF NOT EXISTS player_count INT DEFAULT 0,
    ADD COLUMN IF NOT EXISTS player_outcomes JSONB DEFAULT '[]'::jsonb,
    ADD COLUMN IF NOT EXISTS outcomes JSONB DEFAULT '[]'::jsonb,
    ADD COLUMN IF NOT EXISTS total_calls INT DEFAULT 0,
    ADD COLUMN IF NOT EXISTS is_forfeit BOOLEAN DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS finish_reason TEXT DEFAULT 'victory',
    ADD COLUMN IF NOT EXISTS finished_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()),
    ADD COLUMN IF NOT EXISTS completed_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now());

-- Reconcile existing data across both column sets
UPDATE public.room_match_history
SET winner_id = COALESCE(winner_id, winner_user_id),
    winner_user_id = COALESCE(winner_user_id, winner_id),
    winner_name = COALESCE(winner_name, winner_display_name, 'Winner'),
    winner_display_name = COALESCE(winner_display_name, winner_name, 'Winner'),
    player_outcomes = CASE 
        WHEN player_outcomes IS NOT NULL AND jsonb_array_length(player_outcomes) > 0 THEN player_outcomes 
        ELSE COALESCE(outcomes, '[]'::jsonb) 
    END,
    outcomes = CASE 
        WHEN outcomes IS NOT NULL AND jsonb_array_length(outcomes) > 0 THEN outcomes 
        ELSE COALESCE(player_outcomes, '[]'::jsonb) 
    END,
    player_count = CASE 
        WHEN player_count > 0 THEN player_count 
        ELSE GREATEST(jsonb_array_length(COALESCE(player_outcomes, outcomes, '[]'::jsonb)), 1) 
    END,
    finished_at = COALESCE(finished_at, completed_at, timezone('utc'::text, now())),
    completed_at = COALESCE(completed_at, finished_at, timezone('utc'::text, now()));

-- 2. Secure RLS policies on room_match_history
-- Drop overly permissive WITH CHECK(true) policy if present
DROP POLICY IF EXISTS "Allow insert access to room match history" ON public.room_match_history;
DROP POLICY IF EXISTS "Room match history is insertable by anyone" ON public.room_match_history;

-- Restrict direct client INSERT: regular users cannot forge match history directly.
-- Insertion is handled exclusively through SECURITY DEFINER RPC functions.
CREATE POLICY "Only authorized operations can insert match history"
    ON public.room_match_history
    FOR INSERT
    TO authenticated
    WITH CHECK (false);

-- Read policy allows authenticated users
DROP POLICY IF EXISTS "Room match history is viewable by authenticated users" ON public.room_match_history;
DROP POLICY IF EXISTS "Allow read access to room match history" ON public.room_match_history;
CREATE POLICY "Room match history is viewable by authenticated users"
    ON public.room_match_history
    FOR SELECT
    TO authenticated
    USING (true);

-- 3. Host Removes a Player RPC: rpc_kick_player
CREATE OR REPLACE FUNCTION public.rpc_kick_player(
    p_room_id UUID,
    p_user_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_caller_id UUID := auth.uid();
    v_room public.rooms%ROWTYPE;
BEGIN
    IF v_caller_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
    END IF;

    SELECT * INTO v_room FROM public.rooms WHERE id = p_room_id FOR UPDATE;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Room not found');
    END IF;

    IF v_room.host_id <> v_caller_id THEN
        RETURN jsonb_build_object('success', false, 'error', 'Only the room host can remove players');
    END IF;

    IF v_room.status::TEXT NOT IN ('created', 'waiting') THEN
        RETURN jsonb_build_object('success', false, 'error', 'Cannot remove players once game has started');
    END IF;

    IF p_user_id = v_caller_id THEN
        RETURN jsonb_build_object('success', false, 'error', 'Host cannot kick themselves');
    END IF;

    DELETE FROM public.room_players
    WHERE room_id = p_room_id AND user_id = p_user_id;

    RETURN jsonb_build_object('success', true, 'kicked_user_id', p_user_id);
END;
$$;

-- 4. Host Leaves Waiting Room RPC: rpc_close_waiting_room
CREATE OR REPLACE FUNCTION public.rpc_close_waiting_room(
    p_room_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_caller_id UUID := auth.uid();
    v_room public.rooms%ROWTYPE;
BEGIN
    IF v_caller_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
    END IF;

    SELECT * INTO v_room FROM public.rooms WHERE id = p_room_id FOR UPDATE;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Room not found');
    END IF;

    IF v_room.host_id <> v_caller_id THEN
        RETURN jsonb_build_object('success', false, 'error', 'Only the room host can close this room');
    END IF;

    -- Only close atomically if the room is in waiting or created status
    IF v_room.status::TEXT IN ('created', 'waiting') THEN
        UPDATE public.rooms
        SET status = 'closed',
            closed_at = timezone('utc'::text, now()),
            updated_at = timezone('utc'::text, now())
        WHERE id = p_room_id;

        -- Remove all participants from room_players
        DELETE FROM public.room_players WHERE room_id = p_room_id;

        RETURN jsonb_build_object('success', true, 'status', 'closed');
    ELSE
        RETURN jsonb_build_object('success', false, 'error', 'Room is not in waiting status');
    END IF;
END;
$$;

-- Also update rpc_close_room to ensure room_players are cleaned up
CREATE OR REPLACE FUNCTION public.rpc_close_room(p_room_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_room RECORD;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    SELECT * INTO v_room
    FROM public.rooms
    WHERE id = p_room_id
    FOR UPDATE;

    IF v_room IS NULL THEN
        RAISE EXCEPTION 'Room not found';
    END IF;

    IF v_room.host_id <> v_user_id THEN
        RAISE EXCEPTION 'Only the room host can close this room';
    END IF;

    UPDATE public.rooms
    SET status = 'closed',
        closed_at = timezone('utc'::text, now()),
        updated_at = timezone('utc'::text, now())
    WHERE id = p_room_id;

    DELETE FROM public.room_players WHERE room_id = p_room_id;

    RETURN jsonb_build_object(
        'success', true,
        'room_id', p_room_id,
        'status', 'closed'
    );
END;
$$;

-- 5. Updated rpc_call_number: Enforces forfeited player exclusion from turn rotation and number calling
CREATE OR REPLACE FUNCTION public.rpc_call_number(
    p_game_id UUID,
    p_number INTEGER
) RETURNS VOID AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_game public.games%ROWTYPE;
    v_room public.rooms%ROWTYPE;
    v_next_turn_user UUID;
    v_current_seat INTEGER;
    v_is_caller_forfeited BOOLEAN;
BEGIN
    SELECT * INTO v_game FROM public.games WHERE id = p_game_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Game not found';
    END IF;

    IF v_game.status::TEXT = 'completed' OR v_game.winner_user_id IS NOT NULL THEN
        RAISE EXCEPTION 'MATCH_ALREADY_COMPLETED';
    END IF;

    IF v_game.status::TEXT != 'in_progress' THEN
        RAISE EXCEPTION 'Game is not in progress';
    END IF;

    -- Verify caller is not forfeited
    SELECT is_forfeited INTO v_is_caller_forfeited
    FROM public.game_player_states
    WHERE game_id = p_game_id AND user_id = v_user_id;

    IF v_is_caller_forfeited THEN
        RAISE EXCEPTION 'Forfeited players cannot call numbers';
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

    -- Find current seat index
    SELECT rp.seat_index INTO v_current_seat
    FROM public.room_players rp
    WHERE rp.room_id = v_room.id AND rp.user_id = v_user_id;

    -- Turn progression by seat_index, strictly excluding forfeited players!
    SELECT rp.user_id INTO v_next_turn_user
    FROM public.room_players rp
    JOIN public.game_player_states gps ON gps.game_id = p_game_id AND gps.user_id = rp.user_id
    WHERE rp.room_id = v_room.id 
      AND rp.seat_index > v_current_seat
      AND gps.is_forfeited = FALSE
    ORDER BY rp.seat_index ASC
    LIMIT 1;

    IF v_next_turn_user IS NULL THEN
        SELECT rp.user_id INTO v_next_turn_user
        FROM public.room_players rp
        JOIN public.game_player_states gps ON gps.game_id = p_game_id AND gps.user_id = rp.user_id
        WHERE rp.room_id = v_room.id
          AND gps.is_forfeited = FALSE
        ORDER BY rp.seat_index ASC
        LIMIT 1;
    END IF;

    UPDATE public.games
    SET called_numbers = array_append(called_numbers, p_number),
        current_turn_user_id = v_next_turn_user,
        turn_deadline = timezone('utc'::text, now()) + (COALESCE(v_room.turn_time_seconds, 20) || ' seconds')::interval,
        updated_at = timezone('utc'::text, now())
    WHERE id = p_game_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 6. Updated rpc_handle_turn_timeout: Excludes forfeited players from turn rotation
CREATE OR REPLACE FUNCTION public.rpc_handle_turn_timeout(
    p_game_id UUID,
    p_turn_user_id UUID DEFAULT NULL
) RETURNS JSONB AS $$
DECLARE
    v_game public.games%ROWTYPE;
    v_room public.rooms%ROWTYPE;
    v_player_board INTEGER[];
    v_uncalled_numbers INTEGER[] := '{}';
    v_num INTEGER;
    v_auto_number INTEGER;
    v_current_seat INTEGER;
    v_next_turn_user UUID;
    v_turn_time_sec INTEGER;
    v_i INTEGER;
    v_is_turn_user_forfeited BOOLEAN;
BEGIN
    SELECT * INTO v_game FROM public.games WHERE id = p_game_id FOR UPDATE;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'reason', 'game_not_found', 'error', 'game_not_found');
    END IF;

    IF v_game.status::TEXT = 'completed' OR v_game.winner_user_id IS NOT NULL THEN
        RETURN jsonb_build_object('success', false, 'reason', 'MATCH_ALREADY_COMPLETED', 'error', 'MATCH_ALREADY_COMPLETED');
    END IF;

    IF v_game.status::TEXT != 'in_progress' THEN
        RETURN jsonb_build_object('success', false, 'reason', 'game_not_in_progress', 'error', 'game_not_in_progress');
    END IF;

    IF p_turn_user_id IS NOT NULL AND v_game.current_turn_user_id != p_turn_user_id THEN
        RETURN jsonb_build_object(
            'success', true,
            'reason', 'turn_already_advanced',
            'current_turn_user_id', v_game.current_turn_user_id
        );
    END IF;

    SELECT * INTO v_room FROM public.rooms WHERE id = v_game.room_id;

    -- Check if current turn player is forfeited
    SELECT is_forfeited INTO v_is_turn_user_forfeited
    FROM public.game_player_states
    WHERE game_id = p_game_id AND user_id = v_game.current_turn_user_id;

    -- Fetch current player's private confirmed board
    SELECT board_numbers INTO v_player_board
    FROM public.game_player_states
    WHERE game_id = p_game_id AND user_id = v_game.current_turn_user_id;

    IF v_player_board IS NOT NULL AND array_length(v_player_board, 1) = 25 THEN
        FOREACH v_num IN ARRAY v_player_board LOOP
            IF NOT (v_num = ANY(v_game.called_numbers)) THEN
                v_uncalled_numbers := array_append(v_uncalled_numbers, v_num);
            END IF;
        END LOOP;
    END IF;

    IF array_length(v_uncalled_numbers, 1) IS NULL OR array_length(v_uncalled_numbers, 1) = 0 THEN
        FOR v_i IN 1..25 LOOP
            IF NOT (v_i = ANY(v_game.called_numbers)) THEN
                v_uncalled_numbers := array_append(v_uncalled_numbers, v_i);
            END IF;
        END LOOP;
    END IF;

    IF array_length(v_uncalled_numbers, 1) IS NULL OR array_length(v_uncalled_numbers, 1) = 0 THEN
        RETURN jsonb_build_object('success', false, 'reason', 'all_numbers_called');
    END IF;

    v_auto_number := v_uncalled_numbers[floor(random() * array_length(v_uncalled_numbers, 1) + 1)::INTEGER];

    -- Find current seat
    SELECT rp.seat_index INTO v_current_seat
    FROM public.room_players rp
    WHERE rp.room_id = v_room.id AND rp.user_id = v_game.current_turn_user_id;

    -- Next turn user: strictly active non-forfeited players only!
    SELECT rp.user_id INTO v_next_turn_user
    FROM public.room_players rp
    JOIN public.game_player_states gps ON gps.game_id = p_game_id AND gps.user_id = rp.user_id
    WHERE rp.room_id = v_room.id 
      AND rp.seat_index > v_current_seat
      AND gps.is_forfeited = FALSE
    ORDER BY rp.seat_index ASC
    LIMIT 1;

    IF v_next_turn_user IS NULL THEN
        SELECT rp.user_id INTO v_next_turn_user
        FROM public.room_players rp
        JOIN public.game_player_states gps ON gps.game_id = p_game_id AND gps.user_id = rp.user_id
        WHERE rp.room_id = v_room.id
          AND gps.is_forfeited = FALSE
        ORDER BY rp.seat_index ASC
        LIMIT 1;
    END IF;

    v_turn_time_sec := COALESCE(v_room.turn_time_seconds, 20);

    UPDATE public.games
    SET called_numbers = array_append(called_numbers, v_auto_number),
        current_turn_user_id = v_next_turn_user,
        turn_deadline = timezone('utc'::text, now()) + (v_turn_time_sec || ' seconds')::interval,
        updated_at = timezone('utc'::text, now())
    WHERE id = p_game_id;

    RETURN jsonb_build_object(
        'success', true,
        'auto_number', v_auto_number,
        'next_turn_user_id', v_next_turn_user
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 7. Updated rpc_claim_line: Excludes forfeited players, populates all history columns, and updates player_statistics
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
    v_winner_name TEXT;
    v_rp RECORD;
    v_outcomes JSONB := '[]'::jsonb;
    v_player_outcome JSONB;
    v_normalized_line TEXT;
    v_line_indices INTEGER[];
    v_board INTEGER[];
    v_cell_num INTEGER;
    v_i INTEGER;
    v_already_completed BOOLEAN;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    SELECT * INTO v_game FROM public.games WHERE id = p_game_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Game not found';
    END IF;

    IF v_game.status::TEXT = 'completed' OR v_game.winner_user_id IS NOT NULL THEN
        RAISE EXCEPTION 'MATCH_ALREADY_COMPLETED';
    END IF;

    IF v_game.status::TEXT != 'in_progress' THEN
        RAISE EXCEPTION 'Game is not in progress';
    END IF;

    SELECT * INTO v_gps FROM public.game_player_states
    WHERE game_id = p_game_id AND user_id = v_user_id FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Player state not found';
    END IF;

    -- Disallow forfeited players from claiming lines
    IF v_gps.is_forfeited THEN
        RAISE EXCEPTION 'Forfeited players cannot claim winning lines';
    END IF;

    IF COALESCE(v_gps.lines_claimed, 0) >= 5 THEN
        RAISE EXCEPTION 'Player already has 5 claimed lines';
    END IF;

    v_normalized_line := LOWER(TRIM(p_line_type));
    IF v_normalized_line = 'row_0' OR v_normalized_line = 'row 1' OR v_normalized_line = 'row 0' OR v_normalized_line = 'row1' OR v_normalized_line = 'row0' THEN
        v_normalized_line := 'row_0';
        v_line_indices := ARRAY[0, 1, 2, 3, 4];
    ELSIF v_normalized_line = 'row_1' OR v_normalized_line = 'row 2' OR v_normalized_line = 'row2' THEN
        v_normalized_line := 'row_1';
        v_line_indices := ARRAY[5, 6, 7, 8, 9];
    ELSIF v_normalized_line = 'row_2' OR v_normalized_line = 'row 3' OR v_normalized_line = 'row3' THEN
        v_normalized_line := 'row_2';
        v_line_indices := ARRAY[10, 11, 12, 13, 14];
    ELSIF v_normalized_line = 'row_3' OR v_normalized_line = 'row 4' OR v_normalized_line = 'row4' THEN
        v_normalized_line := 'row_3';
        v_line_indices := ARRAY[15, 16, 17, 18, 19];
    ELSIF v_normalized_line = 'row_4' OR v_normalized_line = 'row 5' OR v_normalized_line = 'row5' THEN
        v_normalized_line := 'row_4';
        v_line_indices := ARRAY[20, 21, 22, 23, 24];
    ELSIF v_normalized_line = 'col_0' OR v_normalized_line = 'column 1' OR v_normalized_line = 'col 1' OR v_normalized_line = 'col 0' OR v_normalized_line = 'col1' OR v_normalized_line = 'col0' THEN
        v_normalized_line := 'col_0';
        v_line_indices := ARRAY[0, 5, 10, 15, 20];
    ELSIF v_normalized_line = 'col_1' OR v_normalized_line = 'column 2' OR v_normalized_line = 'col 2' OR v_normalized_line = 'col2' THEN
        v_normalized_line := 'col_1';
        v_line_indices := ARRAY[1, 6, 11, 16, 21];
    ELSIF v_normalized_line = 'col_2' OR v_normalized_line = 'column 3' OR v_normalized_line = 'col 3' OR v_normalized_line = 'col2' THEN
        v_normalized_line := 'col_2';
        v_line_indices := ARRAY[2, 7, 12, 17, 22];
    ELSIF v_normalized_line = 'col_3' OR v_normalized_line = 'column 4' OR v_normalized_line = 'col 4' OR v_normalized_line = 'col4' THEN
        v_normalized_line := 'col_3';
        v_line_indices := ARRAY[3, 8, 13, 18, 23];
    ELSIF v_normalized_line = 'col_4' OR v_normalized_line = 'column 5' OR v_normalized_line = 'col 5' OR v_normalized_line = 'col5' THEN
        v_normalized_line := 'col_4';
        v_line_indices := ARRAY[4, 9, 14, 19, 24];
    ELSIF v_normalized_line = 'diag_main' OR v_normalized_line = 'main diagonal' OR v_normalized_line LIKE '%main%' OR v_normalized_line = 'diag1' OR v_normalized_line = 'd1' THEN
        v_normalized_line := 'diag_main';
        v_line_indices := ARRAY[0, 6, 12, 18, 24];
    ELSIF v_normalized_line = 'diag_anti' OR v_normalized_line = 'anti diagonal' OR v_normalized_line LIKE '%anti%' OR v_normalized_line = 'diag2' OR v_normalized_line = 'd2' THEN
        v_normalized_line := 'diag_anti';
        v_line_indices := ARRAY[4, 8, 12, 16, 20];
    ELSE
        RAISE EXCEPTION 'Invalid winning line: %', p_line_type;
    END IF;

    IF v_normalized_line = ANY(v_gps.claimed_line_types) 
       OR p_line_type = ANY(v_gps.claimed_line_types) 
       OR LOWER(p_line_type) = ANY(v_gps.claimed_line_types) THEN
        RAISE EXCEPTION 'Line already claimed';
    END IF;

    v_board := v_gps.board_numbers;
    IF v_board IS NOT NULL AND array_length(v_board, 1) = 25 THEN
        FOR v_i IN 1..5 LOOP
            v_cell_num := v_board[v_line_indices[v_i] + 1];
            IF NOT (v_cell_num = ANY(v_game.called_numbers)) THEN
                RAISE EXCEPTION 'Number % in claimed line has not been called yet', v_cell_num;
            END IF;
        END LOOP;
    ELSE
        IF p_numbers IS NULL OR array_length(p_numbers, 1) != 5 THEN
            RAISE EXCEPTION 'Claimed line must contain exactly 5 numbers';
        END IF;
        FOREACH v_num IN ARRAY p_numbers LOOP
            IF NOT (v_num = ANY(v_game.called_numbers)) THEN
                RAISE EXCEPTION 'Number % in claimed line has not been called yet', v_num;
            END IF;
        END LOOP;
    END IF;

    v_new_lines := COALESCE(v_gps.lines_claimed, 0) + 1;
    IF v_new_lines >= 5 THEN
        v_has_won := TRUE;
    END IF;

    UPDATE public.game_player_states
    SET lines_claimed = v_new_lines,
        claimed_line_types = array_append(claimed_line_types, v_normalized_line),
        is_winner = v_has_won,
        updated_at = timezone('utc'::text, now())
    WHERE id = v_gps.id;

    IF v_has_won THEN
        UPDATE public.games
        SET status = 'completed',
            winner_user_id = v_user_id,
            completed_at = timezone('utc'::text, now()),
            updated_at = timezone('utc'::text, now())
        WHERE id = p_game_id;

        UPDATE public.rooms
        SET status = 'completed',
            updated_at = timezone('utc'::text, now())
        WHERE id = v_game.room_id;

        SELECT COALESCE(pr.display_name, 'Winner') INTO v_winner_name
        FROM public.profiles pr
        WHERE pr.id = v_user_id;
        IF v_winner_name IS NULL THEN
            v_winner_name := 'Winner';
        END IF;

        -- Build outcomes JSONB for ALL participants
        FOR v_rp IN
            SELECT
                rp.user_id,
                COALESCE(pr.display_name, 'Player') AS display_name,
                COALESCE(pr.avatar_color_hex, '#FF6B6B') AS avatar_color_hex,
                rp.is_host,
                (rp.user_id = v_user_id) AS is_winner,
                CASE WHEN rp.user_id = v_user_id THEN 5 ELSE COALESCE(s.lines_claimed, 0) END AS lines_claimed_count,
                COALESCE(s.claimed_line_types, '{}'::TEXT[]) AS claimed_line_types,
                COALESCE(s.is_forfeited, FALSE) AS is_forfeited
            FROM public.room_players rp
            LEFT JOIN public.profiles pr ON pr.id = rp.user_id
            LEFT JOIN public.game_player_states s ON s.game_id = p_game_id AND s.user_id = rp.user_id
            WHERE rp.room_id = v_game.room_id
            ORDER BY rp.seat_index
        LOOP
            v_player_outcome := jsonb_build_object(
                'user_id', v_rp.user_id,
                'display_name', v_rp.display_name,
                'avatar_color_hex', v_rp.avatar_color_hex,
                'is_host', v_rp.is_host,
                'is_winner', v_rp.is_winner,
                'lines_claimed', v_rp.lines_claimed_count,
                'lines_claimed_count', v_rp.lines_claimed_count,
                'claimed_line_types', v_rp.claimed_line_types,
                'is_forfeited', v_rp.is_forfeited
            );
            v_outcomes := v_outcomes || jsonb_build_array(v_player_outcome);

            -- Update career player_statistics for each participant
            BEGIN
                INSERT INTO public.player_statistics (
                    user_id, total_matches, wins, losses, draws, current_streak, best_streak, highest_lines_claimed, updated_at
                ) VALUES (
                    v_rp.user_id,
                    1,
                    CASE WHEN v_rp.is_winner THEN 1 ELSE 0 END,
                    CASE WHEN v_rp.is_winner THEN 0 ELSE 1 END,
                    0,
                    CASE WHEN v_rp.is_winner THEN 1 ELSE 0 END,
                    CASE WHEN v_rp.is_winner THEN 1 ELSE 0 END,
                    COALESCE(v_rp.lines_claimed_count, 0),
                    timezone('utc'::text, now())
                )
                ON CONFLICT (user_id) DO UPDATE SET
                    total_matches = public.player_statistics.total_matches + 1,
                    wins = public.player_statistics.wins + CASE WHEN v_rp.is_winner THEN 1 ELSE 0 END,
                    losses = public.player_statistics.losses + CASE WHEN v_rp.is_winner THEN 0 ELSE 1 END,
                    current_streak = CASE WHEN v_rp.is_winner THEN public.player_statistics.current_streak + 1 ELSE 0 END,
                    best_streak = GREATEST(
                        public.player_statistics.best_streak,
                        CASE WHEN v_rp.is_winner THEN public.player_statistics.current_streak + 1 ELSE public.player_statistics.best_streak END
                    ),
                    highest_lines_claimed = GREATEST(
                        public.player_statistics.highest_lines_claimed,
                        COALESCE(v_rp.lines_claimed_count, 0)
                    ),
                    updated_at = timezone('utc'::text, now());
            EXCEPTION WHEN OTHERS THEN
                NULL;
            END;
        END LOOP;

        -- Record match history with BOTH column sets
        BEGIN
            SELECT EXISTS(
                SELECT 1 FROM public.room_match_history WHERE game_id = p_game_id
            ) INTO v_already_completed;

            IF NOT v_already_completed THEN
                INSERT INTO public.room_match_history (
                    room_id,
                    game_id,
                    round_number,
                    winner_id,
                    winner_user_id,
                    winner_name,
                    winner_display_name,
                    total_calls,
                    player_count,
                    player_outcomes,
                    outcomes,
                    is_forfeit,
                    finish_reason,
                    finished_at,
                    completed_at
                ) VALUES (
                    v_game.room_id,
                    p_game_id,
                    COALESCE(v_game.round_number, 1),
                    v_user_id,
                    v_user_id,
                    v_winner_name,
                    v_winner_name,
                    COALESCE(array_length(v_game.called_numbers, 1), 0),
                    jsonb_array_length(v_outcomes),
                    v_outcomes,
                    v_outcomes,
                    FALSE,
                    'victory',
                    timezone('utc'::text, now()),
                    timezone('utc'::text, now())
                );
            END IF;
        EXCEPTION WHEN OTHERS THEN
            NULL;
        END;
    END IF;

    RETURN v_has_won;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
