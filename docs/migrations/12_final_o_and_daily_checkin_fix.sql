-- Migration 12: Final O Claim in Multiplayer & Authoritative Daily Check-in System Fix
-- Ensures atomic 5th line claim with O letter award and match finalization
-- Enforces strictly authoritative daily check-in with Asia/Kolkata timezone and streak calculation

-- ============================================================================
-- PART 1: AUTHORITATIVE MULTIPLAYER 5TH LINE CLAIM & VICTORY FINALIZATION
-- ============================================================================

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

    -- 5. Verify the requested winning line exists & normalize it
    v_normalized_line := LOWER(TRIM(p_line_type));
    IF v_normalized_line = 'row_0' OR v_normalized_line = 'row 1' OR v_normalized_line = 'row 0' THEN
        v_normalized_line := 'row_0';
        v_line_indices := ARRAY[0, 1, 2, 3, 4];
    ELSIF v_normalized_line = 'row_1' OR v_normalized_line = 'row 2' THEN
        v_normalized_line := 'row_1';
        v_line_indices := ARRAY[5, 6, 7, 8, 9];
    ELSIF v_normalized_line = 'row_2' OR v_normalized_line = 'row 3' THEN
        v_normalized_line := 'row_2';
        v_line_indices := ARRAY[10, 11, 12, 13, 14];
    ELSIF v_normalized_line = 'row_3' OR v_normalized_line = 'row 4' THEN
        v_normalized_line := 'row_3';
        v_line_indices := ARRAY[15, 16, 17, 18, 19];
    ELSIF v_normalized_line = 'row_4' OR v_normalized_line = 'row 5' THEN
        v_normalized_line := 'row_4';
        v_line_indices := ARRAY[20, 21, 22, 23, 24];
    ELSIF v_normalized_line = 'col_0' OR v_normalized_line = 'column 1' OR v_normalized_line = 'col 1' OR v_normalized_line = 'col 0' THEN
        v_normalized_line := 'col_0';
        v_line_indices := ARRAY[0, 5, 10, 15, 20];
    ELSIF v_normalized_line = 'col_1' OR v_normalized_line = 'column 2' OR v_normalized_line = 'col 2' THEN
        v_normalized_line := 'col_1';
        v_line_indices := ARRAY[1, 6, 11, 16, 21];
    ELSIF v_normalized_line = 'col_2' OR v_normalized_line = 'column 3' OR v_normalized_line = 'col 3' THEN
        v_normalized_line := 'col_2';
        v_line_indices := ARRAY[2, 7, 12, 17, 22];
    ELSIF v_normalized_line = 'col_3' OR v_normalized_line = 'column 4' OR v_normalized_line = 'col 4' THEN
        v_normalized_line := 'col_3';
        v_line_indices := ARRAY[3, 8, 13, 18, 23];
    ELSIF v_normalized_line = 'col_4' OR v_normalized_line = 'column 5' OR v_normalized_line = 'col 5' THEN
        v_normalized_line := 'col_4';
        v_line_indices := ARRAY[4, 9, 14, 19, 24];
    ELSIF v_normalized_line = 'diag_main' OR v_normalized_line = 'main diagonal' OR v_normalized_line LIKE '%main%' THEN
        v_normalized_line := 'diag_main';
        v_line_indices := ARRAY[0, 6, 12, 18, 24];
    ELSIF v_normalized_line = 'diag_anti' OR v_normalized_line = 'anti diagonal' OR v_normalized_line LIKE '%anti%' THEN
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

        -- Finalize match statistics exactly once
        SELECT EXISTS(
            SELECT 1 FROM public.room_match_history 
            WHERE room_id = v_game.room_id AND round_number = v_game.round_number
        ) INTO v_already_completed;

        IF NOT v_already_completed THEN
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
    END IF;

    RETURN v_has_won;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ============================================================================
-- PART 2: AUTHORITATIVE DAILY CHECK-IN SYSTEM & STREAK MANAGEMENT
-- ============================================================================

-- 1. Ensure daily_checkin_history table exists for immutable once-per-day claim audit
CREATE TABLE IF NOT EXISTS public.daily_checkin_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    claim_date DATE NOT NULL,
    streak_day INT NOT NULL,
    reward_amount INT NOT NULL,
    claimed_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL,
    UNIQUE(user_id, claim_date)
);

CREATE INDEX IF NOT EXISTS idx_daily_checkin_history_user_date 
    ON public.daily_checkin_history(user_id, claim_date);

ALTER TABLE public.daily_checkin_history ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users view own checkin history" ON public.daily_checkin_history;
CREATE POLICY "Users view own checkin history"
    ON public.daily_checkin_history FOR SELECT
    TO authenticated
    USING (auth.uid() = user_id);

-- 2. Ensure daily_checkins table exists
CREATE TABLE IF NOT EXISTS public.daily_checkins (
    user_id UUID PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
    last_checkin_date DATE NOT NULL,
    streak_count INT NOT NULL DEFAULT 1,
    claimed_days INT[] NOT NULL DEFAULT '{1}',
    updated_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL
);

ALTER TABLE public.daily_checkins ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users view own checkins" ON public.daily_checkins;
CREATE POLICY "Users view own checkins"
    ON public.daily_checkins FOR SELECT
    TO authenticated
    USING (auth.uid() = user_id);

-- 3. RPC: rpc_get_daily_checkin_status
CREATE OR REPLACE FUNCTION public.rpc_get_daily_checkin_status()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_today DATE := (timezone('Asia/Kolkata', now()))::DATE;
    v_checkin public.daily_checkins%ROWTYPE;
    v_is_claimed_today BOOLEAN := FALSE;
    v_streak INT := 1;
    v_day_index INT := 1;
    v_claimed_days INT[] := '{}';
    v_today_reward INT;
    v_rewards INT[] := ARRAY[25, 30, 35, 40, 50, 60, 100];
    v_next_midnight TIMESTAMPTZ;
    v_seconds_until_reset INT;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    SELECT * INTO v_checkin
    FROM public.daily_checkins
    WHERE user_id = v_user_id;

    IF v_checkin.user_id IS NOT NULL THEN
        IF v_checkin.last_checkin_date = v_today THEN
            -- Already claimed today
            v_is_claimed_today := TRUE;
            v_streak := v_checkin.streak_count;
            v_claimed_days := v_checkin.claimed_days;
        ELSIF v_checkin.last_checkin_date = v_today - 1 THEN
            -- Consecutive day check-in: available today with incremented streak
            v_is_claimed_today := FALSE;
            v_streak := (v_checkin.streak_count % 7) + 1;
            v_claimed_days := v_checkin.claimed_days;
        ELSE
            -- Missed day: streak resets to Day 1
            v_is_claimed_today := FALSE;
            v_streak := 1;
            v_claimed_days := '{}';
        END IF;
    ELSE
        -- Brand new user
        v_is_claimed_today := FALSE;
        v_streak := 1;
        v_claimed_days := '{}';
    END IF;

    v_day_index := ((v_streak - 1) % 7) + 1;
    v_today_reward := v_rewards[v_day_index];

    -- Seconds until midnight in Asia/Kolkata
    v_next_midnight := timezone('Asia/Kolkata', (v_today + 1)::timestamp);
    v_seconds_until_reset := GREATEST(0, EXTRACT(EPOCH FROM (v_next_midnight - now()))::INT);

    RETURN jsonb_build_object(
        'is_claimed_today', v_is_claimed_today,
        'streak', v_streak,
        'day_index', v_day_index,
        'today_reward', v_today_reward,
        'claimed_days', v_claimed_days,
        'seconds_until_reset', v_seconds_until_reset,
        'server_date', to_char(v_today, 'YYYY-MM-DD')
    );
END;
$$;

-- 4. RPC: rpc_claim_daily_checkin
CREATE OR REPLACE FUNCTION public.rpc_claim_daily_checkin(
    p_day_index INT DEFAULT NULL,
    p_reward_amount INT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_today DATE := (timezone('Asia/Kolkata', now()))::DATE;
    v_checkin public.daily_checkins%ROWTYPE;
    v_new_streak INT := 1;
    v_day_index INT := 1;
    v_claimed_days INT[] := '{}';
    v_rewards INT[] := ARRAY[25, 30, 35, 40, 50, 60, 100];
    v_reward_amount INT;
    v_new_balance INT;
    v_task_id TEXT;
BEGIN
    -- 1. Verify user is authenticated
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    -- 2. Lock checkin record for update
    SELECT * INTO v_checkin
    FROM public.daily_checkins
    WHERE user_id = v_user_id
    FOR UPDATE;

    -- 3. Enforce once-per-calendar-day restriction
    IF v_checkin.user_id IS NOT NULL AND v_checkin.last_checkin_date = v_today THEN
        RAISE EXCEPTION 'Daily check-in already claimed today';
    END IF;

    IF EXISTS (
        SELECT 1 FROM public.daily_checkin_history 
        WHERE user_id = v_user_id AND claim_date = v_today
    ) THEN
        RAISE EXCEPTION 'Daily check-in already claimed today';
    END IF;

    -- 4. Calculate authoritative consecutive-day streak
    IF v_checkin.user_id IS NOT NULL THEN
        IF v_checkin.last_checkin_date = v_today - 1 THEN
            v_new_streak := (v_checkin.streak_count % 7) + 1;
            v_claimed_days := v_checkin.claimed_days;
            IF v_new_streak = 1 THEN
                v_claimed_days := ARRAY[1];
            ELSE
                IF NOT (v_new_streak = ANY(v_claimed_days)) THEN
                    v_claimed_days := array_append(v_claimed_days, v_new_streak);
                END IF;
            END IF;
        ELSE
            -- Missed one or more calendar days: reset streak to 1
            v_new_streak := 1;
            v_claimed_days := ARRAY[1];
        END IF;
    ELSE
        -- First check-in
        v_new_streak := 1;
        v_claimed_days := ARRAY[1];
    END IF;

    -- 5. Trusted reward configuration
    v_day_index := ((v_new_streak - 1) % 7) + 1;
    v_reward_amount := v_rewards[v_day_index];

    -- 6. Atomically record claim in daily_checkin_history (guaranteed unique by (user_id, claim_date))
    INSERT INTO public.daily_checkin_history (
        user_id, claim_date, streak_day, reward_amount, claimed_at
    ) VALUES (
        v_user_id, v_today, v_new_streak, v_reward_amount, timezone('utc'::text, now())
    );

    -- 7. Update daily_checkins state
    INSERT INTO public.daily_checkins (
        user_id, last_checkin_date, streak_count, claimed_days, updated_at
    ) VALUES (
        v_user_id, v_today, v_new_streak, v_claimed_days, timezone('utc'::text, now())
    )
    ON CONFLICT (user_id) DO UPDATE SET
        last_checkin_date = v_today,
        streak_count = v_new_streak,
        claimed_days = v_claimed_days,
        updated_at = timezone('utc'::text, now());

    -- Record in reward_claims for cross-feature idempotency
    v_task_id := 'daily_' || to_char(v_today, 'YYYY-MM-DD');
    INSERT INTO public.reward_claims (user_id, task_id, category, amount, claimed_at)
    VALUES (v_user_id, v_task_id, 'daily_checkin', v_reward_amount, timezone('utc'::text, now()))
    ON CONFLICT (user_id, task_id) DO NOTHING;

    -- 8. Credit wallet balance atomically
    UPDATE public.profiles
    SET chips = chips + v_reward_amount,
        updated_at = timezone('utc'::text, now())
    WHERE id = v_user_id
    RETURNING chips INTO v_new_balance;

    -- Record chip transaction
    INSERT INTO public.chip_transactions (
        user_id, amount, balance_after, reason, created_at
    ) VALUES (
        v_user_id, v_reward_amount, v_new_balance, 'daily_checkin_day_' || v_day_index, timezone('utc'::text, now())
    );

    RETURN jsonb_build_object(
        'success', true,
        'streak', v_new_streak,
        'day_index', v_day_index,
        'reward_amount', v_reward_amount,
        'new_balance', v_new_balance,
        'claimed_days', v_claimed_days,
        'claim_date', to_char(v_today, 'YYYY-MM-DD')
    );
END;
$$;
