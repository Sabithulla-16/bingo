-- ==============================================================================
-- Migration 11: Authoritative Multiplayer Match Completion & Concurrent Enforcement
-- ==============================================================================

-- 1. Ensure Full Replica Identity on games and game_player_states
-- This is critical so Supabase Realtime can evaluate RLS for non-key column updates
-- and broadcast status = 'completed' / winner_user_id updates to ALL room participants.
ALTER TABLE public.games REPLICA IDENTITY FULL;
ALTER TABLE public.game_player_states REPLICA IDENTITY FULL;

-- Ensure tables are published to realtime
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'games'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.games;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'game_player_states'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.game_player_states;
    END IF;
END $$;

-- 2. Authoritative rpc_call_number: Enforces MATCH_ALREADY_COMPLETED and atomic state locking
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
    -- Acquire exclusive row lock on game
    SELECT * INTO v_game FROM public.games WHERE id = p_game_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Game not found';
    END IF;

    -- Strict match completion check
    IF v_game.status = 'completed' OR v_game.winner_user_id IS NOT NULL THEN
        RAISE EXCEPTION 'MATCH_ALREADY_COMPLETED';
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

    -- Find current seat index
    SELECT rp.seat_index INTO v_current_seat
    FROM public.room_players rp
    WHERE rp.room_id = v_room.id AND rp.user_id = v_user_id;

    -- Turn progression by seat_index
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
        turn_deadline = timezone('utc'::text, now()) + (COALESCE(v_room.turn_time_seconds, 20) || ' seconds')::interval,
        updated_at = timezone('utc'::text, now())
    WHERE id = p_game_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Authoritative rpc_claim_line: Enforces MATCH_ALREADY_COMPLETED, atomic victory check and statistics finalization
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
    -- 1. Row-level lock on the active game to serialize concurrent claim and number-call actions
    SELECT * INTO v_game FROM public.games WHERE id = p_game_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Game not found';
    END IF;

    -- Strict match completion check: reject late or concurrent claims if a winner was already finalized
    IF v_game.status = 'completed' OR v_game.winner_user_id IS NOT NULL THEN
        RAISE EXCEPTION 'MATCH_ALREADY_COMPLETED';
    END IF;

    IF v_game.status != 'in_progress' THEN
        RAISE EXCEPTION 'Game is not in progress';
    END IF;

    -- 2. Lock player state row
    SELECT * INTO v_gps FROM public.game_player_states
    WHERE game_id = p_game_id AND user_id = v_user_id FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Player state not found';
    END IF;

    IF p_line_type = ANY(v_gps.claimed_line_types) THEN
        RAISE EXCEPTION 'Line already claimed';
    END IF;

    -- 3. Verify all numbers in claimed line have authoritatively been called
    FOREACH v_num IN ARRAY p_numbers LOOP
        IF NOT (v_num = ANY(v_game.called_numbers)) THEN
            RAISE EXCEPTION 'Number % in claimed line has not been called yet', v_num;
        END IF;
    END LOOP;

    v_new_lines := v_gps.lines_claimed + 1;
    IF v_new_lines >= 5 THEN
        v_has_won := TRUE;
    END IF;

    -- 4. Update player state
    UPDATE public.game_player_states
    SET lines_claimed = v_new_lines,
        claimed_line_types = array_append(claimed_line_types, p_line_type),
        is_winner = v_has_won,
        updated_at = timezone('utc'::text, now())
    WHERE id = v_gps.id;

    -- 5. If this claim completes BINGO (5 lines), atomically finalize the match!
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

        -- Build outcomes JSONB for all participants in the match
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

        -- Record match in room_match_history
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
            COALESCE(array_length(v_game.called_numbers, 1), 0),
            jsonb_array_length(v_outcomes),
            v_outcomes,
            timezone('utc'::text, now())
        );

        -- Update career player_statistics for each participant
        FOR v_rp IN SELECT * FROM jsonb_array_elements(v_outcomes)
        LOOP
            INSERT INTO public.player_statistics (
                user_id, total_matches, wins, losses, draws, current_streak, best_streak, highest_lines_claimed, updated_at
            ) VALUES (
                (v_rp->>'user_id')::UUID,
                1,
                CASE WHEN (v_rp->>'is_winner')::BOOLEAN THEN 1 ELSE 0 END,
                CASE WHEN (v_rp->>'is_winner')::BOOLEAN THEN 0 ELSE 1 END,
                0,
                CASE WHEN (v_rp->>'is_winner')::BOOLEAN THEN 1 ELSE 0 END,
                CASE WHEN (v_rp->>'is_winner')::BOOLEAN THEN 1 ELSE 0 END,
                COALESCE((v_rp->>'lines_claimed_count')::INTEGER, 0),
                timezone('utc'::text, now())
            )
            ON CONFLICT (user_id) DO UPDATE SET
                total_matches = public.player_statistics.total_matches + 1,
                wins = public.player_statistics.wins + CASE WHEN (v_rp->>'is_winner')::BOOLEAN THEN 1 ELSE 0 END,
                losses = public.player_statistics.losses + CASE WHEN (v_rp->>'is_winner')::BOOLEAN THEN 0 ELSE 1 END,
                current_streak = CASE WHEN (v_rp->>'is_winner')::BOOLEAN THEN public.player_statistics.current_streak + 1 ELSE 0 END,
                best_streak = GREATEST(
                    public.player_statistics.best_streak,
                    CASE WHEN (v_rp->>'is_winner')::BOOLEAN THEN public.player_statistics.current_streak + 1 ELSE public.player_statistics.best_streak END
                ),
                highest_lines_claimed = GREATEST(
                    public.player_statistics.highest_lines_claimed,
                    COALESCE((v_rp->>'lines_claimed_count')::INTEGER, 0)
                ),
                updated_at = timezone('utc'::text, now());
        END LOOP;
    END IF;

    RETURN v_has_won;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. Authoritative rpc_handle_turn_timeout: Rejects if round is completed
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
        RETURN jsonb_build_object('success', false, 'reason', 'game_not_found', 'error', 'game_not_found');
    END IF;

    -- Strict match completion check
    IF v_game.status = 'completed' OR v_game.winner_user_id IS NOT NULL THEN
        RETURN jsonb_build_object('success', false, 'reason', 'MATCH_ALREADY_COMPLETED', 'error', 'MATCH_ALREADY_COMPLETED');
    END IF;

    IF v_game.status != 'in_progress' THEN
        RETURN jsonb_build_object('success', false, 'reason', 'game_not_in_progress', 'error', 'game_not_in_progress');
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
        'next_turn_user_id', v_next_turn_user
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
