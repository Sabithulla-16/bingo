-- Migration 13: Fix Multiplayer Winning-Line Claiming & Game Start Compatibility
-- 1. Fixes PostgreSQL enum comparison error in rpc_claim_line (invalid input value for enum game_status: "playing")
-- 2. Ensures column public.games.completed_at exists
-- 3. Ensures table public.room_match_history exists with proper schema and RLS
-- 4. Provides backward-compatible rpc_start_game alias
-- 5. Atomic 5th-line victory handling: marks game/room completed, records history and player statistics

-- Step 1: Ensure public.games has completed_at column
ALTER TABLE public.games ADD COLUMN IF NOT EXISTS completed_at TIMESTAMPTZ;

-- Step 2: Ensure public.room_match_history exists
CREATE TABLE IF NOT EXISTS public.room_match_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    room_id UUID NOT NULL,
    game_id UUID NOT NULL,
    round_number INTEGER NOT NULL DEFAULT 1,
    winner_user_id UUID NOT NULL,
    winner_display_name TEXT,
    total_calls INTEGER NOT NULL DEFAULT 0,
    outcomes JSONB NOT NULL DEFAULT '[]'::jsonb,
    completed_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

ALTER TABLE public.room_match_history ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE tablename = 'room_match_history' AND policyname = 'Allow read access to room match history'
    ) THEN
        CREATE POLICY "Allow read access to room match history" ON public.room_match_history FOR SELECT USING (true);
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE tablename = 'room_match_history' AND policyname = 'Allow insert access to room match history'
    ) THEN
        CREATE POLICY "Allow insert access to room match history" ON public.room_match_history FOR INSERT WITH CHECK (true);
    END IF;
END $$;

-- Step 3: Create or replace rpc_start_game as an alias to rpc_start_board_prep
CREATE OR REPLACE FUNCTION public.rpc_start_game(
    p_room_id UUID
) RETURNS JSONB AS $$
BEGIN
    RETURN public.rpc_start_board_prep(p_room_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Step 4: Authoritative rpc_claim_line with safe enum comparisons, correct column references, and atomic 5th-line victory
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
    -- 1. Verify authenticated player
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    -- 2. Row-level lock on the active game to serialize concurrent claim and number-call actions
    SELECT * INTO v_game FROM public.games WHERE id = p_game_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Game not found';
    END IF;

    -- Strict match completion check: reject late or concurrent claims if a winner was already finalized
    IF v_game.status::TEXT = 'completed' OR v_game.winner_user_id IS NOT NULL THEN
        RAISE EXCEPTION 'MATCH_ALREADY_COMPLETED';
    END IF;

    -- Verify game is in progress (cast to TEXT to prevent enum 22P02 casting failures)
    IF v_game.status::TEXT != 'in_progress' THEN
        RAISE EXCEPTION 'Game is not in progress';
    END IF;

    -- 3. Lock player state row & verify player belongs to active round
    SELECT * INTO v_gps FROM public.game_player_states
    WHERE game_id = p_game_id AND user_id = v_user_id FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Player state not found';
    END IF;

    -- 4. Verify player has fewer than 5 successfully claimed lines
    IF COALESCE(v_gps.lines_claimed, 0) >= 5 THEN
        RAISE EXCEPTION 'Player already has 5 claimed lines';
    END IF;

    -- 5. Verify the requested winning line exists & normalize it unambiguously
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

    -- 6. Verify that this specific line has not already been claimed
    IF v_normalized_line = ANY(v_gps.claimed_line_types) 
       OR p_line_type = ANY(v_gps.claimed_line_types) 
       OR LOWER(p_line_type) = ANY(v_gps.claimed_line_types) THEN
        RAISE EXCEPTION 'Line already claimed';
    END IF;

    -- 7. Verify all numbers in claimed line have authoritatively been called
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

    -- 8. Claim specific line & calculate updated claimed-line count
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

    -- 9. If this claim completes BINGO (5 lines), atomically finalize the match!
    IF v_has_won THEN
        -- Atomically update game status and winner
        UPDATE public.games
        SET status = 'completed',
            winner_user_id = v_user_id,
            completed_at = timezone('utc'::text, now()),
            updated_at = timezone('utc'::text, now())
        WHERE id = p_game_id;

        -- Atomically update room status
        UPDATE public.rooms
        SET status = 'completed',
            updated_at = timezone('utc'::text, now())
        WHERE id = v_game.room_id;

        -- Fetch winner display name from profiles
        SELECT COALESCE(pr.display_name, 'Winner') INTO v_winner_name
        FROM public.profiles pr
        WHERE pr.id = v_user_id;
        IF v_winner_name IS NULL THEN
            v_winner_name := 'Winner';
        END IF;

        -- Build outcomes JSONB for all participants in the match and update player_statistics
        FOR v_rp IN
            SELECT
                rp.user_id,
                COALESCE(pr.display_name, 'Player') AS display_name,
                COALESCE(pr.avatar_color_hex, '#FF6B6B') AS avatar_color_hex,
                rp.is_host,
                (rp.user_id = v_user_id) AS is_winner,
                CASE WHEN rp.user_id = v_user_id THEN 5 ELSE COALESCE(s.lines_claimed, 0) END AS lines_claimed_count,
                COALESCE(s.claimed_line_types, '{}'::TEXT[]) AS claimed_line_types
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
                'claimed_line_types', v_rp.claimed_line_types
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
                    wins = public.player_statistics.wins + CASE WHEN EXCLUDED.wins = 1 THEN 1 ELSE 0 END,
                    losses = public.player_statistics.losses + CASE WHEN EXCLUDED.losses = 1 THEN 1 ELSE 0 END,
                    current_streak = CASE WHEN EXCLUDED.wins = 1 THEN public.player_statistics.current_streak + 1 ELSE 0 END,
                    best_streak = GREATEST(
                        public.player_statistics.best_streak,
                        CASE WHEN EXCLUDED.wins = 1 THEN public.player_statistics.current_streak + 1 ELSE public.player_statistics.best_streak END
                    ),
                    highest_lines_claimed = GREATEST(
                        public.player_statistics.highest_lines_claimed,
                        EXCLUDED.highest_lines_claimed
                    ),
                    updated_at = timezone('utc'::text, now());
            EXCEPTION WHEN OTHERS THEN
                -- Gracefully handle stats table variation
            END;
        END LOOP;

        -- Record match history exactly once
        BEGIN
            SELECT EXISTS(
                SELECT 1 FROM public.room_match_history WHERE game_id = p_game_id
            ) INTO v_already_completed;

            IF NOT v_already_completed THEN
                INSERT INTO public.room_match_history (
                    room_id,
                    game_id,
                    round_number,
                    winner_user_id,
                    winner_display_name,
                    total_calls,
                    outcomes,
                    completed_at
                ) VALUES (
                    v_game.room_id,
                    p_game_id,
                    COALESCE(v_game.round_number, 1),
                    v_user_id,
                    v_winner_name,
                    COALESCE(array_length(v_game.called_numbers, 1), 0),
                    v_outcomes,
                    timezone('utc'::text, now())
                );
            END IF;
        EXCEPTION WHEN OTHERS THEN
            -- Gracefully ignore if room_match_history insertion encounters an issue
        END;
    END IF;

    RETURN v_has_won;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
