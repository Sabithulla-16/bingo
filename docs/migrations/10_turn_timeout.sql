-- ==============================================================================
-- Migration 10: Server-Authoritative Automatic Turn Timeout & Participant Unification
-- ==============================================================================

-- 1. Create or replace the server-authoritative turn timeout RPC
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
BEGIN
    -- 1. Row-level lock on the active game to serialize concurrent timeout calls
    SELECT * INTO v_game FROM public.games WHERE id = p_game_id FOR UPDATE;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'reason', 'game_not_found');
    END IF;

    IF v_game.status != 'in_progress' OR v_game.winner_user_id IS NOT NULL THEN
        RETURN jsonb_build_object('success', false, 'reason', 'game_not_in_progress');
    END IF;

    -- 2. Idempotent turn check: verify turn has not already advanced
    IF p_turn_user_id IS NOT NULL AND v_game.current_turn_user_id != p_turn_user_id THEN
        RETURN jsonb_build_object(
            'success', true,
            'reason', 'turn_already_advanced',
            'current_turn_user_id', v_game.current_turn_user_id
        );
    END IF;

    -- 3. Authoritative time check: ensure turn deadline has actually passed (with 500ms network tolerance)
    IF v_game.turn_deadline IS NOT NULL AND timezone('utc'::text, now()) < (v_game.turn_deadline - interval '500 milliseconds') THEN
        RETURN jsonb_build_object('success', false, 'reason', 'turn_not_expired');
    END IF;

    SELECT * INTO v_room FROM public.rooms WHERE id = v_game.room_id;

    -- 4. Fetch the current player's private confirmed board
    SELECT board_numbers INTO v_player_board
    FROM public.game_player_states
    WHERE game_id = p_game_id AND user_id = v_game.current_turn_user_id;

    -- 5. Filter for remaining uncalled numbers on the current player's board
    IF v_player_board IS NOT NULL AND array_length(v_player_board, 1) = 25 THEN
        FOREACH v_num IN ARRAY v_player_board LOOP
            IF NOT (v_num = ANY(v_game.called_numbers)) THEN
                v_uncalled_numbers := array_append(v_uncalled_numbers, v_num);
            END IF;
        END LOOP;
    END IF;

    -- Fallback: if somehow player's board is missing or exhausted, find any uncalled 1..25
    IF array_length(v_uncalled_numbers, 1) IS NULL OR array_length(v_uncalled_numbers, 1) = 0 THEN
        FOR v_i IN 1..25 LOOP
            IF NOT (v_i = ANY(v_game.called_numbers)) THEN
                v_uncalled_numbers := array_append(v_uncalled_numbers, v_i);
            END IF;
        END LOOP;
    END IF;

    -- If all 25 numbers are called, round is exhausted
    IF array_length(v_uncalled_numbers, 1) IS NULL OR array_length(v_uncalled_numbers, 1) = 0 THEN
        RETURN jsonb_build_object('success', false, 'reason', 'all_numbers_called');
    END IF;

    -- 6. Random selection from remaining uncalled numbers
    v_auto_number := v_uncalled_numbers[floor(random() * array_length(v_uncalled_numbers, 1) + 1)::INTEGER];

    -- 7. Turn progression: find next player by seat_index
    SELECT rp.seat_index INTO v_current_seat
    FROM public.room_players rp
    WHERE rp.room_id = v_room.id AND rp.user_id = v_game.current_turn_user_id;

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

    v_turn_time_sec := COALESCE(v_room.turn_time_seconds, 20);

    -- 8. Atomically update games: append number, advance turn, reset deadline
    UPDATE public.games
    SET called_numbers = array_append(called_numbers, v_auto_number),
        current_turn_user_id = v_next_turn_user,
        turn_deadline = timezone('utc'::text, now()) + (v_turn_time_sec || ' seconds')::interval,
        updated_at = timezone('utc'::text, now())
    WHERE id = p_game_id;

    RETURN jsonb_build_object(
        'success', true,
        'auto_number', v_auto_number,
        'timed_out_user_id', v_game.current_turn_user_id,
        'next_turn_user_id', v_next_turn_user
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
