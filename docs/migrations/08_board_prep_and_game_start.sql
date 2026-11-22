-- ==============================================================================
-- Migration 08: Multiplayer Board Preparation & Atomic Game Start
-- ==============================================================================

-- Drop existing functions if signature or return type changed
DROP FUNCTION IF EXISTS public.rpc_submit_board(UUID, INTEGER[]);
DROP FUNCTION IF EXISTS public.fn_generate_valid_bingo_board();
DROP FUNCTION IF EXISTS public.rpc_start_board_prep(UUID);
DROP FUNCTION IF EXISTS public.rpc_handle_prep_timeout(UUID, BOOLEAN);
DROP FUNCTION IF EXISTS public.rpc_extend_prep_timer(UUID, INTEGER);

-- 1. Helper function: generate a random valid 5x5 BINGO board (1..25 permutation)
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

-- 2. Server-Authoritative RPC: rpc_start_board_prep
-- Called when host starts game from lobby. Transitions room to 'preparing' and creates/resets games row.
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

    -- Verify player count
    SELECT count(*) INTO v_player_count FROM public.room_players WHERE room_id = p_room_id;
    IF v_player_count < 2 THEN
        RAISE EXCEPTION 'At least 2 players required to begin match preparation';
    END IF;

    v_prep_seconds := COALESCE(v_room.prep_time_seconds, 45);
    v_deadline := timezone('utc'::text, now()) + (v_prep_seconds || ' seconds')::interval;

    -- Update room status
    UPDATE public.rooms
    SET status = 'preparing',
        updated_at = timezone('utc'::text, now())
    WHERE id = p_room_id;

    -- Check if game row exists for this room, else create
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
            round_number = 1,
            current_turn_user_id = NULL,
            turn_deadline = NULL,
            called_numbers = '{}',
            winner_user_id = NULL,
            updated_at = timezone('utc'::text, now())
        WHERE id = v_game_id;
    END IF;

    -- Seed / reset player states for all room members
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

-- 3. Server-Authoritative RPC: rpc_submit_board (Atomic Confirmation & Game Start)
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
    -- 1. Validate board bijection: exactly 25 numbers, every number 1..25 exactly once
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

    -- 2. Lock game record FOR UPDATE to prevent race conditions
    SELECT * INTO v_game FROM public.games WHERE id = p_game_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Game not found';
    END IF;

    -- If already started, exit cleanly (idempotent)
    IF v_game.status = 'in_progress' THEN
        RETURN jsonb_build_object('success', true, 'status', 'in_progress', 'already_started', true);
    END IF;

    SELECT * INTO v_room FROM public.rooms WHERE id = v_game.room_id;

    -- 3. Upsert player's confirmed board state
    INSERT INTO public.game_player_states (game_id, user_id, board_numbers, board_confirmed, updated_at)
    VALUES (p_game_id, v_user_id, p_board, TRUE, timezone('utc'::text, now()))
    ON CONFLICT (game_id, user_id)
    DO UPDATE SET
        board_numbers = p_board,
        board_confirmed = TRUE,
        updated_at = timezone('utc'::text, now());

    -- 4. Check if all players in the room are ready
    SELECT
        COALESCE(bool_and(COALESCE(gps.board_confirmed, false)), false),
        count(rp.id)
    INTO v_all_confirmed, v_player_count
    FROM public.room_players rp
    LEFT JOIN public.game_player_states gps
        ON gps.game_id = p_game_id AND gps.user_id = rp.user_id
    WHERE rp.room_id = v_room.id;

    -- 5. Condition A: If all players confirmed and at least 2 players exist, start game immediately!
    IF v_all_confirmed AND v_player_count >= 2 THEN
        v_turn_time_sec := COALESCE(v_room.turn_time_seconds, 20);

        -- Randomly choose starting player among connected room players
        SELECT user_id INTO v_first_turn_user
        FROM public.room_players
        WHERE room_id = v_room.id
        ORDER BY random()
        LIMIT 1;

        -- Fallback to host if random returned null
        IF v_first_turn_user IS NULL THEN
            v_first_turn_user := v_room.host_id;
        END IF;

        -- Atomically update game
        UPDATE public.games
        SET status = 'in_progress',
            current_turn_user_id = v_first_turn_user,
            turn_deadline = timezone('utc'::text, now()) + (v_turn_time_sec || ' seconds')::interval,
            called_numbers = '{}',
            updated_at = timezone('utc'::text, now())
        WHERE id = p_game_id;

        -- Atomically update room
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

-- 4. Server-Authoritative RPC: rpc_handle_prep_timeout
-- Called when countdown expires.
CREATE OR REPLACE FUNCTION public.rpc_handle_prep_timeout(
    p_game_id UUID,
    p_auto_fill BOOLEAN DEFAULT TRUE
) RETURNS JSONB AS $$
DECLARE
    v_game public.games%ROWTYPE;
    v_room public.rooms%ROWTYPE;
    v_rp RECORD;
    v_player_count INTEGER := 0;
    v_confirmed_count INTEGER := 0;
    v_first_turn_user UUID;
    v_turn_time_sec INTEGER;
BEGIN
    SELECT * INTO v_game FROM public.games WHERE id = p_game_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Game not found';
    END IF;

    -- Already started? Idempotent return
    IF v_game.status = 'in_progress' THEN
        RETURN jsonb_build_object('success', true, 'status', 'in_progress', 'already_started', true);
    END IF;

    SELECT * INTO v_room FROM public.rooms WHERE id = v_game.room_id;

    -- If auto-fill is enabled, fill boards for any unconfirmed players
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

    -- Count confirmed players
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
        -- Less than 2 confirmed: revert room to waiting
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

-- 5. Server-Authoritative RPC: rpc_extend_prep_timer
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
