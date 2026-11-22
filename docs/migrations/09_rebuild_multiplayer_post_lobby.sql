-- ==============================================================================
-- Migration 09: Complete Rebuild & Unification of Post-Lobby Multiplayer Flow
-- ==============================================================================

-- 1. Ensure table schemas and column naming are 100% unified
DO $$
BEGIN
    -- Ensure games columns
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='games' AND column_name='turn_player_id') THEN
        ALTER TABLE public.games RENAME COLUMN turn_player_id TO current_turn_user_id;
    END IF;
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='games' AND column_name='winner_id') THEN
        ALTER TABLE public.games RENAME COLUMN winner_id TO winner_user_id;
    END IF;

    -- Ensure game_player_states columns
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='game_player_states' AND column_name='is_board_confirmed') THEN
        ALTER TABLE public.game_player_states RENAME COLUMN is_board_confirmed TO board_confirmed;
    END IF;
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='game_player_states' AND column_name='lines_claimed_count') THEN
        ALTER TABLE public.game_player_states RENAME COLUMN lines_claimed_count TO lines_claimed;
    END IF;
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='game_player_states' AND column_name='completed_lines') THEN
        ALTER TABLE public.game_player_states RENAME COLUMN completed_lines TO claimed_line_types;
    END IF;
END $$;

-- 2. Clean Drop of Legacy RPCs
DROP FUNCTION IF EXISTS public.rpc_start_board_prep(UUID);
DROP FUNCTION IF EXISTS public.rpc_submit_board(UUID, INTEGER[]);
DROP FUNCTION IF EXISTS public.rpc_handle_prep_timeout(UUID, BOOLEAN);
DROP FUNCTION IF EXISTS public.rpc_extend_prep_timer(UUID, INTEGER);
DROP FUNCTION IF EXISTS public.rpc_remove_unready_players(UUID, UUID);
DROP FUNCTION IF EXISTS public.rpc_call_number(UUID, INTEGER);
DROP FUNCTION IF EXISTS public.rpc_claim_line(UUID, TEXT, INTEGER[]);
DROP FUNCTION IF EXISTS public.rpc_finish_round(UUID, UUID, UUID, TEXT, INT, JSONB);
DROP FUNCTION IF EXISTS public.rpc_start_next_round(UUID, UUID, UUID);
DROP FUNCTION IF EXISTS public.rpc_return_to_lobby(UUID, UUID);
DROP FUNCTION IF EXISTS public.fn_generate_valid_bingo_board();

-- 3. Random Valid 5x5 Permutation Generator (1..25)
CREATE OR REPLACE FUNCTION public.fn_generate_valid_bingo_board()
RETURNS INTEGER[] AS $$
DECLARE
    v_arr INTEGER[] := ARRAY[1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25];
    v_i INTEGER;
    v_j INTEGER;
    v_temp INTEGER;
BEGIN
    FOR v_i IN REVERSE 25..2 LOOP
        v_j := floor(random() * v_i + 1)::INTEGER;
        v_temp := v_arr[v_i];
        v_arr[v_i] := v_arr[v_j];
        v_arr[v_j] := v_temp;
    END LOOP;
    RETURN v_arr;
END;
$$ LANGUAGE plpgsql VOLATILE;

-- 4. RPC: rpc_start_board_prep
CREATE OR REPLACE FUNCTION public.rpc_start_board_prep(
    p_room_id UUID
) RETURNS JSONB AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_room public.rooms%ROWTYPE;
    v_player_count INTEGER;
    v_game_id UUID;
    v_prep_seconds INTEGER;
    v_deadline TIMESTAMPTZ;
BEGIN
    SELECT * INTO v_room FROM public.rooms WHERE id = p_room_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Room not found';
    END IF;

    IF v_room.host_id != v_user_id THEN
        RAISE EXCEPTION 'Only the room host can start board preparation';
    END IF;

    SELECT count(*) INTO v_player_count FROM public.room_players WHERE room_id = p_room_id;
    IF v_player_count < 2 THEN
        RAISE EXCEPTION 'At least 2 players required to begin match preparation';
    END IF;

    v_prep_seconds := COALESCE(v_room.prep_time_seconds, 45);
    v_deadline := timezone('utc'::text, now()) + (v_prep_seconds || ' seconds')::interval;

    UPDATE public.rooms
    SET status = 'preparing',
        updated_at = timezone('utc'::text, now())
    WHERE id = p_room_id;

    SELECT id INTO v_game_id
    FROM public.games
    WHERE room_id = p_room_id
    ORDER BY created_at DESC
    LIMIT 1;

    IF v_game_id IS NULL THEN
        INSERT INTO public.games (
            room_id,
            status,
            prep_deadline,
            round_number,
            called_numbers,
            created_at,
            updated_at
        ) VALUES (
            p_room_id,
            'preparing',
            v_deadline,
            1,
            '{}',
            timezone('utc'::text, now()),
            timezone('utc'::text, now())
        ) RETURNING id INTO v_game_id;
    ELSE
        UPDATE public.games
        SET status = 'preparing',
            prep_deadline = v_deadline,
            current_turn_user_id = NULL,
            turn_deadline = NULL,
            called_numbers = '{}',
            winner_user_id = NULL,
            updated_at = timezone('utc'::text, now())
        WHERE id = v_game_id;
    END IF;

    -- Seed player states
    INSERT INTO public.game_player_states (game_id, user_id, board_numbers, board_confirmed, lines_claimed, claimed_line_types, is_winner)
    SELECT
        v_game_id,
        rp.user_id,
        '{}'::INTEGER[],
        false,
        0,
        '{}'::TEXT[],
        false
    FROM public.room_players rp
    WHERE rp.room_id = p_room_id
    ON CONFLICT (game_id, user_id)
    DO UPDATE SET
        board_numbers = '{}'::INTEGER[],
        board_confirmed = false,
        lines_claimed = 0,
        claimed_line_types = '{}'::TEXT[],
        is_winner = false,
        updated_at = timezone('utc'::text, now());

    RETURN jsonb_build_object(
        'success', true,
        'game_id', v_game_id,
        'prep_deadline', v_deadline,
        'prep_seconds', v_prep_seconds
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5. RPC: rpc_submit_board
CREATE OR REPLACE FUNCTION public.rpc_submit_board(
    p_game_id UUID,
    p_board INTEGER[]
) RETURNS JSONB AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_game public.games%ROWTYPE;
    v_room public.rooms%ROWTYPE;
    v_num INTEGER;
    v_seen_numbers INTEGER[] := '{}';
    v_all_confirmed BOOLEAN := false;
    v_player_count INTEGER := 0;
    v_first_turn_user UUID;
    v_turn_time_sec INTEGER;
BEGIN
    IF p_board IS NULL OR array_length(p_board, 1) != 25 THEN
        RAISE EXCEPTION 'Board must contain exactly 25 numbers';
    END IF;

    FOREACH v_num IN ARRAY p_board LOOP
        IF v_num < 1 OR v_num > 25 THEN
            RAISE EXCEPTION 'Board numbers must be between 1 and 25';
        END IF;
        IF v_num = ANY(v_seen_numbers) THEN
            RAISE EXCEPTION 'Board contains duplicate numbers: %', v_num;
        END IF;
        v_seen_numbers := array_append(v_seen_numbers, v_num);
    END LOOP;

    SELECT * INTO v_game FROM public.games WHERE id = p_game_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Game not found';
    END IF;

    IF v_game.status = 'in_progress' THEN
        RETURN jsonb_build_object('success', true, 'status', 'in_progress', 'already_started', true);
    END IF;

    SELECT * INTO v_room FROM public.rooms WHERE id = v_game.room_id;

    INSERT INTO public.game_player_states (game_id, user_id, board_numbers, board_confirmed, updated_at)
    VALUES (p_game_id, v_user_id, p_board, TRUE, timezone('utc'::text, now()))
    ON CONFLICT (game_id, user_id)
    DO UPDATE SET
        board_numbers = p_board,
        board_confirmed = TRUE,
        updated_at = timezone('utc'::text, now());

    SELECT
        COALESCE(bool_and(COALESCE(gps.board_confirmed, false)), false),
        count(rp.id)
    INTO v_all_confirmed, v_player_count
    FROM public.room_players rp
    LEFT JOIN public.game_player_states gps
        ON gps.game_id = p_game_id AND gps.user_id = rp.user_id
    WHERE rp.room_id = v_room.id;

    IF v_all_confirmed AND v_player_count >= 2 THEN
        v_turn_time_sec := COALESCE(v_room.turn_time_seconds, 20);

        SELECT user_id INTO v_first_turn_user
        FROM public.room_players
        WHERE room_id = v_room.id
        ORDER BY random()
        LIMIT 1;

        IF v_first_turn_user IS NULL THEN
            v_first_turn_user := v_room.host_id;
        END IF;

        UPDATE public.games
        SET status = 'in_progress',
            current_turn_user_id = v_first_turn_user,
            turn_deadline = timezone('utc'::text, now()) + (v_turn_time_sec || ' seconds')::interval,
            called_numbers = '{}',
            updated_at = timezone('utc'::text, now())
        WHERE id = p_game_id;

        UPDATE public.rooms
        SET status = 'in_progress',
            updated_at = timezone('utc'::text, now())
        WHERE id = v_room.id;

        RETURN jsonb_build_object(
            'success', true,
            'status', 'in_progress',
            'started', true,
            'first_turn_user_id', v_first_turn_user
        );
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'status', 'preparing',
        'started', false,
        'all_confirmed', v_all_confirmed
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 6. RPC: rpc_handle_prep_timeout
CREATE OR REPLACE FUNCTION public.rpc_handle_prep_timeout(
    p_game_id UUID,
    p_auto_fill BOOLEAN DEFAULT TRUE
) RETURNS JSONB AS $$
DECLARE
    v_game public.games%ROWTYPE;
    v_room public.rooms%ROWTYPE;
    v_rp RECORD;
    v_confirmed_count INTEGER := 0;
    v_first_turn_user UUID;
    v_turn_time_sec INTEGER;
BEGIN
    SELECT * INTO v_game FROM public.games WHERE id = p_game_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Game not found';
    END IF;

    IF v_game.status = 'in_progress' THEN
        RETURN jsonb_build_object('success', true, 'status', 'in_progress', 'already_started', true);
    END IF;

    SELECT * INTO v_room FROM public.rooms WHERE id = v_game.room_id;

    IF p_auto_fill THEN
        FOR v_rp IN
            SELECT rp.user_id, COALESCE(gps.board_confirmed, false) as is_conf
            FROM public.room_players rp
            LEFT JOIN public.game_player_states gps ON gps.game_id = p_game_id AND gps.user_id = rp.user_id
            WHERE rp.room_id = v_room.id
        LOOP
            IF NOT v_rp.is_conf THEN
                INSERT INTO public.game_player_states (game_id, user_id, board_numbers, board_confirmed, updated_at)
                VALUES (p_game_id, v_rp.user_id, public.fn_generate_valid_bingo_board(), TRUE, timezone('utc'::text, now()))
                ON CONFLICT (game_id, user_id)
                DO UPDATE SET
                    board_numbers = public.fn_generate_valid_bingo_board(),
                    board_confirmed = TRUE,
                    updated_at = timezone('utc'::text, now());
            END IF;
        END LOOP;
    END IF;

    SELECT count(*) INTO v_confirmed_count
    FROM public.room_players rp
    JOIN public.game_player_states gps ON gps.game_id = p_game_id AND gps.user_id = rp.user_id
    WHERE rp.room_id = v_room.id AND gps.board_confirmed = TRUE;

    IF v_confirmed_count >= 2 THEN
        v_turn_time_sec := COALESCE(v_room.turn_time_seconds, 20);

        SELECT rp.user_id INTO v_first_turn_user
        FROM public.room_players rp
        JOIN public.game_player_states gps ON gps.game_id = p_game_id AND gps.user_id = rp.user_id
        WHERE rp.room_id = v_room.id AND gps.board_confirmed = TRUE
        ORDER BY random()
        LIMIT 1;

        UPDATE public.games
        SET status = 'in_progress',
            current_turn_user_id = v_first_turn_user,
            turn_deadline = timezone('utc'::text, now()) + (v_turn_time_sec || ' seconds')::interval,
            called_numbers = '{}',
            updated_at = timezone('utc'::text, now())
        WHERE id = p_game_id;

        UPDATE public.rooms
        SET status = 'in_progress',
            updated_at = timezone('utc'::text, now())
        WHERE id = v_room.id;

        RETURN jsonb_build_object('success', true, 'status', 'in_progress', 'started', true);
    ELSE
        UPDATE public.rooms
        SET status = 'waiting',
            updated_at = timezone('utc'::text, now())
        WHERE id = v_room.id;

        UPDATE public.games
        SET status = 'cancelled',
            updated_at = timezone('utc'::text, now())
        WHERE id = p_game_id;

        RETURN jsonb_build_object('success', false, 'status', 'waiting', 'started', false, 'message', 'Not enough players confirmed');
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 7. RPC: rpc_extend_prep_timer
CREATE OR REPLACE FUNCTION public.rpc_extend_prep_timer(
    p_game_id UUID,
    p_seconds INTEGER DEFAULT 30
) RETURNS JSONB AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_game public.games%ROWTYPE;
    v_room public.rooms%ROWTYPE;
    v_new_deadline TIMESTAMPTZ;
BEGIN
    SELECT * INTO v_game FROM public.games WHERE id = p_game_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Game not found';
    END IF;

    SELECT * INTO v_room FROM public.rooms WHERE id = v_game.room_id;
    IF v_room.host_id != v_user_id THEN
        RAISE EXCEPTION 'Only the room host can extend match preparation time';
    END IF;

    v_new_deadline := GREATEST(v_game.prep_deadline, timezone('utc'::text, now())) + (p_seconds || ' seconds')::interval;

    UPDATE public.games
    SET prep_deadline = v_new_deadline,
        updated_at = timezone('utc'::text, now())
    WHERE id = p_game_id;

    RETURN jsonb_build_object('success', true, 'prep_deadline', v_new_deadline);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 8. RPC: rpc_remove_unready_players
CREATE OR REPLACE FUNCTION public.rpc_remove_unready_players(
    p_room_id UUID,
    p_game_id UUID
) RETURNS JSONB AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_room public.rooms%ROWTYPE;
    v_ready_count INTEGER;
BEGIN
    SELECT * INTO v_room FROM public.rooms WHERE id = p_room_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Room not found';
    END IF;
    IF v_room.host_id != v_user_id THEN
        RAISE EXCEPTION 'Only the room host can remove unready players';
    END IF;

    SELECT count(*) INTO v_ready_count
    FROM public.room_players rp
    JOIN public.game_player_states gps ON gps.game_id = p_game_id AND gps.user_id = rp.user_id
    WHERE rp.room_id = p_room_id AND gps.board_confirmed = TRUE;

    IF v_ready_count < 2 THEN
        RAISE EXCEPTION 'Cannot remove unready players. At least 2 ready players required.';
    END IF;

    -- Delete unconfirmed players from room_players
    DELETE FROM public.room_players rp
    WHERE rp.room_id = p_room_id
      AND NOT EXISTS (
          SELECT 1 FROM public.game_player_states gps
          WHERE gps.game_id = p_game_id AND gps.user_id = rp.user_id AND gps.board_confirmed = TRUE
      );

    -- Delete corresponding states
    DELETE FROM public.game_player_states gps
    WHERE gps.game_id = p_game_id AND gps.board_confirmed = FALSE;

    RETURN jsonb_build_object('success', true, 'ready_count', v_ready_count);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 9. RPC: rpc_call_number
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
BEGIN
    SELECT * INTO v_game FROM public.games WHERE id = p_game_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Game not found';
    END IF;

    IF v_game.status != 'in_progress' OR v_game.winner_user_id IS NOT NULL THEN
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

    SELECT rp.seat_index INTO v_current_seat
    FROM public.room_players rp
    WHERE rp.room_id = v_room.id AND rp.user_id = v_user_id;

    SELECT rp.user_id INTO v_next_turn_user
    FROM public.room_players rp
    WHERE rp.room_id = v_room.id AND rp.seat_index > v_current_seat
    ORDER BY rp.seat_index ASC
    LIMIT 1;

    IF v_next_turn_user IS NULL THEN
        SELECT rp.user_id INTO v_next_turn_user
        FROM public.room_players rp
        WHERE rp.room_id = v_room.id
        ORDER BY rp.seat_index ASC
        LIMIT 1;
    END IF;

    UPDATE public.games
    SET called_numbers = array_append(called_numbers, p_number),
        current_turn_user_id = v_next_turn_user,
        turn_deadline = timezone('utc'::text, now()) + (v_room.turn_time_seconds || ' seconds')::interval,
        updated_at = timezone('utc'::text, now())
    WHERE id = p_game_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 10. RPC: rpc_claim_line (Atomic Winner Check & Round Completion)
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

    -- If this claim triggered BINGO victory, finalize the round atomically!
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

        -- Fetch winner display name
        SELECT display_name INTO v_winner_name
        FROM public.room_players
        WHERE room_id = v_game.room_id AND user_id = v_user_id;
        IF v_winner_name IS NULL THEN
            v_winner_name := 'Winner';
        END IF;

        -- Build outcomes JSONB
        FOR v_rp IN
            SELECT
                rp.user_id,
                rp.display_name,
                rp.avatar_color_hex,
                rp.is_host,
                CASE WHEN rp.user_id = v_user_id THEN TRUE ELSE FALSE END as is_winner,
                CASE WHEN rp.user_id = v_user_id THEN 5 ELSE COALESCE(s.lines_claimed, 0) END as lines_claimed_count,
                COALESCE(s.claimed_line_types, '{}'::TEXT[]) as claimed_line_types
            FROM public.room_players rp
            LEFT JOIN public.game_player_states s ON s.game_id = p_game_id AND s.user_id = rp.user_id
            WHERE rp.room_id = v_game.room_id
        LOOP
            v_player_outcome := jsonb_build_object(
                'user_id', v_rp.user_id,
                'display_name', v_rp.display_name,
                'avatar_color_hex', v_rp.avatar_color_hex,
                'is_host', v_rp.is_host,
                'is_winner', v_rp.is_winner,
                'lines_claimed_count', v_rp.lines_claimed_count,
                'claimed_letters', CASE
                    WHEN v_rp.lines_claimed_count >= 5 THEN jsonb_build_array('B','I','N','G','O')
                    WHEN v_rp.lines_claimed_count = 4 THEN jsonb_build_array('B','I','N','G')
                    WHEN v_rp.lines_claimed_count = 3 THEN jsonb_build_array('B','I','N')
                    WHEN v_rp.lines_claimed_count = 2 THEN jsonb_build_array('B','I')
                    WHEN v_rp.lines_claimed_count = 1 THEN jsonb_build_array('B')
                    ELSE '[]'::jsonb
                END
            );
            v_outcomes := v_outcomes || jsonb_build_array(v_player_outcome);
        END LOOP;

        -- Record match in room_match_history if not already present
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
            v_game.room_id,
            v_game.round_number,
            v_user_id,
            v_winner_name,
            array_length(v_game.called_numbers, 1),
            jsonb_array_length(v_outcomes),
            v_outcomes,
            timezone('utc'::text, now())
        );
    END IF;

    RETURN v_has_won;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 11. RPC: rpc_start_next_round (Authoritative Rematch)
CREATE OR REPLACE FUNCTION public.rpc_start_next_round(
    p_game_id UUID,
    p_room_id UUID,
    p_host_id UUID
) RETURNS JSONB AS $$
DECLARE
    v_room public.rooms%ROWTYPE;
    v_game public.games%ROWTYPE;
    v_prep_seconds INTEGER;
    v_deadline TIMESTAMPTZ;
    v_new_round INTEGER;
BEGIN
    SELECT * INTO v_room FROM public.rooms WHERE id = p_room_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Room not found';
    END IF;
    IF v_room.host_id != p_host_id THEN
        RAISE EXCEPTION 'Only the room host can initiate a rematch';
    END IF;

    SELECT * INTO v_game FROM public.games WHERE id = p_game_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Game not found';
    END IF;

    v_new_round := v_game.round_number + 1;
    v_prep_seconds := COALESCE(v_room.prep_time_seconds, 45);
    v_deadline := timezone('utc'::text, now()) + (v_prep_seconds || ' seconds')::interval;

    -- Update game
    UPDATE public.games
    SET round_number = v_new_round,
        status = 'preparing',
        prep_deadline = v_deadline,
        current_turn_user_id = NULL,
        turn_deadline = NULL,
        called_numbers = '{}',
        winner_user_id = NULL,
        updated_at = timezone('utc'::text, now())
    WHERE id = p_game_id;

    -- Crucial: Update room status so clients listening to room or game navigate back to board preparation
    UPDATE public.rooms
    SET status = 'preparing',
        updated_at = timezone('utc'::text, now())
    WHERE id = p_room_id;

    -- Reset player states
    UPDATE public.game_player_states
    SET board_confirmed = FALSE,
        lines_claimed = 0,
        claimed_line_types = '{}'::TEXT[],
        is_winner = FALSE,
        board_numbers = '{}'::INTEGER[],
        updated_at = timezone('utc'::text, now())
    WHERE game_id = p_game_id;

    RETURN jsonb_build_object(
        'success', true,
        'round_number', v_new_round,
        'prep_deadline', v_deadline
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 12. RPC: rpc_return_to_lobby
CREATE OR REPLACE FUNCTION public.rpc_return_to_lobby(
    p_room_id UUID,
    p_host_id UUID
) RETURNS JSONB AS $$
DECLARE
    v_room public.rooms%ROWTYPE;
BEGIN
    SELECT * INTO v_room FROM public.rooms WHERE id = p_room_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Room not found';
    END IF;
    IF v_room.host_id != p_host_id THEN
        RAISE EXCEPTION 'Only the room host can return players to lobby';
    END IF;

    UPDATE public.rooms
    SET status = 'waiting',
        updated_at = timezone('utc'::text, now())
    WHERE id = p_room_id;

    UPDATE public.games
    SET status = 'preparing',
        updated_at = timezone('utc'::text, now())
    WHERE room_id = p_room_id;

    RETURN jsonb_build_object('success', true, 'status', 'waiting');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
