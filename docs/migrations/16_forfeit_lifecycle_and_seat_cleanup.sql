-- ==============================================================================
-- Migration 16: Complete Forfeit Player Lifecycle, Atomic Seat Cleanup,
--               Preserved Historical Participation, and Multi-Player Continuation
-- ==============================================================================

-- 1. Updated Server-Authoritative RPC: rpc_forfeit_match
CREATE OR REPLACE FUNCTION public.rpc_forfeit_match(
    p_game_id UUID,
    p_room_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_game public.games%ROWTYPE;
    v_room public.rooms%ROWTYPE;
    v_gps public.game_player_states%ROWTYPE;
    v_remaining_count INT := 0;
    v_remaining_winner_id UUID;
    v_winner_name TEXT;
    v_current_seat INT;
    v_next_turn_user UUID;
    v_new_host_id UUID;
    v_outcomes JSONB := '[]'::jsonb;
    v_player_outcome JSONB;
    v_p RECORD;
BEGIN
    -- Step 1: Authentication Check
    IF v_user_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
    END IF;

    -- Step 2: Lock and inspect game row
    SELECT * INTO v_game
    FROM public.games
    WHERE id = p_game_id AND room_id = p_room_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Game not found');
    END IF;

    -- Fetch room row
    SELECT * INTO v_room FROM public.rooms WHERE id = p_room_id FOR UPDATE;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Room not found');
    END IF;

    -- Step 3: Inspect caller's player state
    SELECT * INTO v_gps
    FROM public.game_player_states
    WHERE game_id = p_game_id AND user_id = v_user_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Player state not found');
    END IF;

    -- Idempotent check: If already forfeited, ensure room membership removed and return success
    IF v_gps.is_forfeited THEN
        DELETE FROM public.room_players
        WHERE room_id = p_room_id AND user_id = v_user_id;

        RETURN jsonb_build_object(
            'success', true,
            'already_forfeited', true,
            'match_completed', (v_game.status::TEXT = 'completed'),
            'forfeited_user_id', v_user_id
        );
    END IF;

    -- If match is already completed by another action, caller cannot forfeit an already concluded match
    IF v_game.status::TEXT = 'completed' OR v_game.winner_user_id IS NOT NULL THEN
        DELETE FROM public.room_players
        WHERE room_id = p_room_id AND user_id = v_user_id;

        RETURN jsonb_build_object(
            'success', true,
            'match_completed', true,
            'reason', 'MATCH_ALREADY_COMPLETED'
        );
    END IF;

    -- Step 4: Mark caller as forfeited in game_player_states (Preserves historical game records!)
    UPDATE public.game_player_states
    SET is_forfeited = TRUE,
        updated_at = timezone('utc'::text, now())
    WHERE id = v_gps.id;

    -- Record loss for forfeiting player in career statistics
    BEGIN
        INSERT INTO public.player_statistics (
            user_id, total_matches, wins, losses, draws, current_streak, best_streak, highest_lines_claimed, updated_at
        ) VALUES (
            v_user_id, 1, 0, 1, 0, 0, 0, COALESCE(v_gps.lines_claimed, 0), timezone('utc'::text, now())
        )
        ON CONFLICT (user_id) DO UPDATE SET
            total_matches = public.player_statistics.total_matches + 1,
            losses = public.player_statistics.losses + 1,
            current_streak = 0,
            updated_at = timezone('utc'::text, now());
    EXCEPTION WHEN OTHERS THEN
        NULL;
    END;

    -- Step 5: Host transfer if the forfeiting player was the room host
    IF v_room.host_id = v_user_id THEN
        SELECT rp.user_id INTO v_new_host_id
        FROM public.room_players rp
        JOIN public.game_player_states gps ON gps.game_id = p_game_id AND gps.user_id = rp.user_id
        WHERE rp.room_id = p_room_id 
          AND rp.user_id <> v_user_id
          AND gps.is_forfeited = FALSE
        ORDER BY rp.seat_index ASC
        LIMIT 1;

        IF v_new_host_id IS NOT NULL THEN
            UPDATE public.rooms
            SET host_id = v_new_host_id,
                updated_at = timezone('utc'::text, now())
            WHERE id = p_room_id;

            UPDATE public.room_players
            SET is_host = (user_id = v_new_host_id)
            WHERE room_id = p_room_id;
        END IF;
    END IF;

    -- Step 6: Count remaining active participants
    SELECT COUNT(*), (ARRAY_AGG(user_id))[1]
    INTO v_remaining_count, v_remaining_winner_id
    FROM public.game_player_states
    WHERE game_id = p_game_id AND is_forfeited = FALSE;

    -- =========================================================================
    -- SCENARIO A: 1 or 0 players remain active (2-player match forfeit or last standing)
    -- =========================================================================
    IF v_remaining_count <= 1 THEN
        IF v_remaining_winner_id IS NULL THEN
            v_remaining_winner_id := v_user_id;
        END IF;

        SELECT COALESCE(pr.display_name, 'Winner') INTO v_winner_name
        FROM public.profiles pr
        WHERE pr.id = v_remaining_winner_id;
        IF v_winner_name IS NULL THEN
            v_winner_name := 'Winner';
        END IF;

        -- Atomically finalize game and room status
        UPDATE public.games
        SET status = 'completed',
            winner_user_id = v_remaining_winner_id,
            completed_at = timezone('utc'::text, now()),
            updated_at = timezone('utc'::text, now())
        WHERE id = p_game_id;

        UPDATE public.rooms
        SET status = 'completed',
            updated_at = timezone('utc'::text, now())
        WHERE id = p_room_id;

        -- Update winner state
        UPDATE public.game_player_states
        SET is_winner = TRUE,
            updated_at = timezone('utc'::text, now())
        WHERE game_id = p_game_id AND user_id = v_remaining_winner_id;

        -- Build outcomes JSONB for ALL historical participants from game_player_states
        FOR v_p IN
            SELECT
                gps.user_id,
                COALESCE(pr.display_name, 'Player') AS display_name,
                COALESCE(pr.avatar_color_hex, '#FC695C') AS avatar_color_hex,
                COALESCE(rp.is_host, (v_room.host_id = gps.user_id)) AS is_host,
                (gps.user_id = v_remaining_winner_id) AS is_winner,
                CASE WHEN gps.user_id = v_remaining_winner_id THEN 5 ELSE COALESCE(gps.lines_claimed, 0) END AS lines_claimed_count,
                COALESCE(gps.claimed_line_types, '{}'::TEXT[]) AS claimed_line_types,
                gps.is_forfeited AS is_forfeited
            FROM public.game_player_states gps
            LEFT JOIN public.profiles pr ON pr.id = gps.user_id
            LEFT JOIN public.room_players rp ON rp.room_id = p_room_id AND rp.user_id = gps.user_id
            WHERE gps.game_id = p_game_id
            ORDER BY gps.created_at ASC
        LOOP
            v_player_outcome := jsonb_build_object(
                'user_id', v_p.user_id,
                'display_name', v_p.display_name,
                'avatar_color_hex', v_p.avatar_color_hex,
                'is_host', v_p.is_host,
                'is_winner', v_p.is_winner,
                'lines_claimed', v_p.lines_claimed_count,
                'lines_claimed_count', v_p.lines_claimed_count,
                'claimed_line_types', v_p.claimed_line_types,
                'is_forfeited', v_p.is_forfeited
            );
            v_outcomes := v_outcomes || jsonb_build_array(v_player_outcome);
        END LOOP;

        -- Update career statistics for remaining winner
        BEGIN
            INSERT INTO public.player_statistics (
                user_id, total_matches, wins, losses, draws, current_streak, best_streak, highest_lines_claimed, updated_at
            ) VALUES (
                v_remaining_winner_id, 1, 1, 0, 0, 1, 1, 5, timezone('utc'::text, now())
            )
            ON CONFLICT (user_id) DO UPDATE SET
                total_matches = public.player_statistics.total_matches + 1,
                wins = public.player_statistics.wins + 1,
                current_streak = public.player_statistics.current_streak + 1,
                best_streak = GREATEST(public.player_statistics.best_streak, public.player_statistics.current_streak + 1),
                highest_lines_claimed = GREATEST(public.player_statistics.highest_lines_claimed, 5),
                updated_at = timezone('utc'::text, now());
        EXCEPTION WHEN OTHERS THEN
            NULL;
        END;

        -- Insert history record if not already recorded
        IF NOT EXISTS (SELECT 1 FROM public.room_match_history WHERE game_id = p_game_id) THEN
            INSERT INTO public.room_match_history (
                room_id,
                game_id,
                round_number,
                winner_user_id,
                winner_id,
                winner_name,
                winner_display_name,
                total_calls,
                outcomes,
                player_outcomes,
                player_count,
                is_forfeit,
                finish_reason,
                completed_at,
                finished_at
            ) VALUES (
                p_room_id,
                p_game_id,
                COALESCE(v_game.round_number, 1),
                v_remaining_winner_id,
                v_remaining_winner_id,
                v_winner_name,
                v_winner_name,
                COALESCE(array_length(v_game.called_numbers, 1), 0),
                v_outcomes,
                v_outcomes,
                jsonb_array_length(v_outcomes),
                TRUE,
                'forfeit',
                timezone('utc'::text, now()),
                timezone('utc'::text, now())
            );
        END IF;

        -- Step 7: Atomically remove forfeiting player from active room membership so seat becomes available!
        DELETE FROM public.room_players
        WHERE room_id = p_room_id AND user_id = v_user_id;

        RETURN jsonb_build_object(
            'success', true,
            'match_completed', true,
            'winner_id', v_remaining_winner_id,
            'winner_name', v_winner_name,
            'is_forfeit', true,
            'forfeited_user_id', v_user_id
        );
    ELSE
        -- =========================================================================
        -- SCENARIO B: More than 1 player remains active (3-player or 4-player continuation)
        -- =========================================================================
        -- If it was currently the forfeiter's turn, advance turn immediately to next active player
        IF v_game.current_turn_user_id = v_user_id THEN
            SELECT rp.seat_index INTO v_current_seat
            FROM public.room_players rp
            WHERE rp.room_id = p_room_id AND rp.user_id = v_user_id;

            -- Find next active non-forfeited player strictly
            SELECT rp.user_id INTO v_next_turn_user
            FROM public.room_players rp
            JOIN public.game_player_states gps ON gps.game_id = p_game_id AND gps.user_id = rp.user_id
            WHERE rp.room_id = p_room_id
              AND rp.seat_index > v_current_seat
              AND rp.user_id <> v_user_id
              AND gps.is_forfeited = FALSE
            ORDER BY rp.seat_index ASC
            LIMIT 1;

            IF v_next_turn_user IS NULL THEN
                SELECT rp.user_id INTO v_next_turn_user
                FROM public.room_players rp
                JOIN public.game_player_states gps ON gps.game_id = p_game_id AND gps.user_id = rp.user_id
                WHERE rp.room_id = p_room_id
                  AND rp.user_id <> v_user_id
                  AND gps.is_forfeited = FALSE
                ORDER BY rp.seat_index ASC
                LIMIT 1;
            END IF;

            UPDATE public.games
            SET current_turn_user_id = v_next_turn_user,
                turn_deadline = timezone('utc'::text, now()) + (COALESCE(v_room.turn_time_seconds, 20) || ' seconds')::interval,
                updated_at = timezone('utc'::text, now())
            WHERE id = p_game_id;
        END IF;

        -- Atomically remove forfeiting player from active room membership so seat is released
        DELETE FROM public.room_players
        WHERE room_id = p_room_id AND user_id = v_user_id;

        RETURN jsonb_build_object(
            'success', true,
            'match_completed', false,
            'active_players_count', v_remaining_count,
            'is_forfeit', true,
            'forfeited_user_id', v_user_id
        );
    END IF;
END;
$$;

-- 2. Updated rpc_claim_line: Builds outcomes from all historical game participants
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
    v_p RECORD;
    v_outcomes JSONB := '[]'::jsonb;
    v_player_outcome JSONB;
    v_normalized_line TEXT;
    v_line_indices INTEGER[];
    v_board INTEGER[];
    v_cell_num INTEGER;
    v_i INTEGER;
    v_already_completed BOOLEAN;
    v_room public.rooms%ROWTYPE;
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

    SELECT * INTO v_room FROM public.rooms WHERE id = v_game.room_id;

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

        -- Build outcomes JSONB for ALL historical participants (including any earlier forfeiter)
        FOR v_p IN
            SELECT
                gps.user_id,
                COALESCE(pr.display_name, 'Player') AS display_name,
                COALESCE(pr.avatar_color_hex, '#FF6B6B') AS avatar_color_hex,
                COALESCE(rp.is_host, (v_room.host_id = gps.user_id)) AS is_host,
                (gps.user_id = v_user_id) AS is_winner,
                CASE WHEN gps.user_id = v_user_id THEN 5 ELSE COALESCE(gps.lines_claimed, 0) END AS lines_claimed_count,
                COALESCE(gps.claimed_line_types, '{}'::TEXT[]) AS claimed_line_types,
                COALESCE(gps.is_forfeited, FALSE) AS is_forfeited
            FROM public.game_player_states gps
            LEFT JOIN public.profiles pr ON pr.id = gps.user_id
            LEFT JOIN public.room_players rp ON rp.room_id = v_game.room_id AND rp.user_id = gps.user_id
            WHERE gps.game_id = p_game_id
            ORDER BY gps.created_at ASC
        LOOP
            v_player_outcome := jsonb_build_object(
                'user_id', v_p.user_id,
                'display_name', v_p.display_name,
                'avatar_color_hex', v_p.avatar_color_hex,
                'is_host', v_p.is_host,
                'is_winner', v_p.is_winner,
                'lines_claimed', v_p.lines_claimed_count,
                'lines_claimed_count', v_p.lines_claimed_count,
                'claimed_line_types', v_p.claimed_line_types,
                'is_forfeited', v_p.is_forfeited
            );
            v_outcomes := v_outcomes || jsonb_build_array(v_player_outcome);

            -- Update career player_statistics for each participant
            BEGIN
                INSERT INTO public.player_statistics (
                    user_id, total_matches, wins, losses, draws, current_streak, best_streak, highest_lines_claimed, updated_at
                ) VALUES (
                    v_p.user_id,
                    1,
                    CASE WHEN v_p.is_winner THEN 1 ELSE 0 END,
                    CASE WHEN v_p.is_winner THEN 0 ELSE 1 END,
                    0,
                    CASE WHEN v_p.is_winner THEN 1 ELSE 0 END,
                    CASE WHEN v_p.is_winner THEN 1 ELSE 0 END,
                    COALESCE(v_p.lines_claimed_count, 0),
                    timezone('utc'::text, now())
                )
                ON CONFLICT (user_id) DO UPDATE SET
                    total_matches = public.player_statistics.total_matches + 1,
                    wins = public.player_statistics.wins + CASE WHEN v_p.is_winner THEN 1 ELSE 0 END,
                    losses = public.player_statistics.losses + CASE WHEN v_p.is_winner THEN 0 ELSE 1 END,
                    current_streak = CASE WHEN v_p.is_winner THEN public.player_statistics.current_streak + 1 ELSE 0 END,
                    best_streak = GREATEST(
                        public.player_statistics.best_streak,
                        CASE WHEN v_p.is_winner THEN public.player_statistics.current_streak + 1 ELSE public.player_statistics.best_streak END
                    ),
                    highest_lines_claimed = GREATEST(
                        public.player_statistics.highest_lines_claimed,
                        COALESCE(v_p.lines_claimed_count, 0)
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
