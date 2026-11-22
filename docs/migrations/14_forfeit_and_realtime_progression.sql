-- ==============================================================================
-- Migration 14: Multiplayer Forfeit Handling, Idempotent Match Completion,
--               Realtime Subscriptions, and Genuine Recent Rooms
-- ==============================================================================

-- 1. Add is_forfeited to game_player_states
ALTER TABLE public.game_player_states
    ADD COLUMN IF NOT EXISTS is_forfeited BOOLEAN NOT NULL DEFAULT FALSE;

-- 2. Ensure room_match_history has finish_reason and is_forfeit
ALTER TABLE public.room_match_history
    ADD COLUMN IF NOT EXISTS game_id UUID,
    ADD COLUMN IF NOT EXISTS winner_id UUID,
    ADD COLUMN IF NOT EXISTS winner_name TEXT,
    ADD COLUMN IF NOT EXISTS player_outcomes JSONB DEFAULT '[]'::jsonb,
    ADD COLUMN IF NOT EXISTS finished_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()),
    ADD COLUMN IF NOT EXISTS is_forfeit BOOLEAN DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS finish_reason TEXT DEFAULT 'victory';

-- Create index on game_id to guarantee match completion idempotency
CREATE INDEX IF NOT EXISTS idx_room_match_history_game_id ON public.room_match_history(game_id);
CREATE INDEX IF NOT EXISTS idx_room_match_history_room_round ON public.room_match_history(room_id, round_number);

-- 3. Ensure player_statistics, player_achievements, profiles and room_match_history are in realtime publication
ALTER TABLE public.player_statistics REPLICA IDENTITY FULL;
ALTER TABLE public.player_achievements REPLICA IDENTITY FULL;
ALTER TABLE public.profiles REPLICA IDENTITY FULL;
ALTER TABLE public.room_match_history REPLICA IDENTITY FULL;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'player_statistics'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.player_statistics;
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'player_achievements'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.player_achievements;
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'profiles'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.profiles;
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'room_match_history'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.room_match_history;
    END IF;
END $$;

-- 4. Server-Authoritative RPC: rpc_forfeit_match
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
    v_rp RECORD;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
    END IF;

    -- 1. Lock and inspect game row
    SELECT * INTO v_game
    FROM public.games
    WHERE id = p_game_id AND room_id = p_room_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Game not found');
    END IF;

    IF v_game.status::TEXT = 'completed' OR v_game.winner_user_id IS NOT NULL THEN
        RETURN jsonb_build_object('success', true, 'reason', 'MATCH_ALREADY_COMPLETED', 'match_completed', true);
    END IF;

    -- 2. Lock and inspect player state
    SELECT * INTO v_gps
    FROM public.game_player_states
    WHERE game_id = p_game_id AND user_id = v_user_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Player state not found');
    END IF;

    IF v_gps.is_forfeited THEN
        RETURN jsonb_build_object('success', true, 'already_forfeited', true);
    END IF;

    -- 3. Mark caller as forfeited
    UPDATE public.game_player_states
    SET is_forfeited = TRUE,
        updated_at = timezone('utc'::text, now())
    WHERE id = v_gps.id;

    -- Update forfeiter player_statistics: count as played match and loss
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

    SELECT * INTO v_room FROM public.rooms WHERE id = p_room_id;

    -- 4. Count remaining active participants
    SELECT COUNT(*), (ARRAY_AGG(user_id))[1]
    INTO v_remaining_count, v_remaining_winner_id
    FROM public.game_player_states
    WHERE game_id = p_game_id AND is_forfeited = FALSE;

    -- SCENARIO A (or last player standing after multiple forfeits):
    -- If 1 or fewer players remain active, end the game immediately!
    IF v_remaining_count <= 1 THEN
        IF v_remaining_winner_id IS NULL THEN
            -- In case everyone somehow forfeited, default to room host or caller
            v_remaining_winner_id := v_user_id;
        END IF;

        SELECT COALESCE(pr.display_name, 'Winner') INTO v_winner_name
        FROM public.profiles pr
        WHERE pr.id = v_remaining_winner_id;
        IF v_winner_name IS NULL THEN
            v_winner_name := 'Winner';
        END IF;

        -- Atomically update game & room status to completed
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

        -- Build outcomes JSONB
        FOR v_rp IN
            SELECT
                rp.user_id,
                COALESCE(pr.display_name, 'Player') AS display_name,
                COALESCE(pr.avatar_color_hex, '#FC695C') AS avatar_color_hex,
                rp.is_host,
                (rp.user_id = v_remaining_winner_id) AS is_winner,
                CASE WHEN rp.user_id = v_remaining_winner_id THEN 5 ELSE COALESCE(s.lines_claimed, 0) END AS lines_claimed_count,
                COALESCE(s.claimed_line_types, '{}'::TEXT[]) AS claimed_line_types,
                COALESCE(s.is_forfeited, FALSE) AS is_forfeited
            FROM public.room_players rp
            LEFT JOIN public.profiles pr ON pr.id = rp.user_id
            LEFT JOIN public.game_player_states s ON s.game_id = p_game_id AND s.user_id = rp.user_id
            WHERE rp.room_id = p_room_id
            ORDER BY rp.seat_index
        LOOP
            v_player_outcome := jsonb_build_object(
                'user_id', v_rp.user_id,
                'display_name', v_rp.display_name,
                'avatar_color_hex', v_rp.avatar_color_hex,
                'is_host', v_rp.is_host,
                'is_winner', v_rp.is_winner,
                'lines_claimed', v_rp.lines_claimed_count,
                'claimed_line_types', v_rp.claimed_line_types,
                'is_forfeited', v_rp.is_forfeited
            );
            v_outcomes := v_outcomes || jsonb_build_array(v_player_outcome);
        END LOOP;

        -- Update career statistics for the winner
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
                TRUE,
                'forfeit',
                timezone('utc'::text, now()),
                timezone('utc'::text, now())
            );
        END IF;

        RETURN jsonb_build_object(
            'success', true,
            'match_completed', true,
            'winner_id', v_remaining_winner_id,
            'winner_name', v_winner_name,
            'is_forfeit', true
        );
    ELSE
        -- SCENARIO B: More than 1 player remains active (e.g. 3 or 4 players)
        -- Continue match with remaining active players.

        -- If it was currently the forfeiter's turn, advance turn immediately!
        IF v_game.current_turn_user_id = v_user_id THEN
            SELECT rp.seat_index INTO v_current_seat
            FROM public.room_players rp
            WHERE rp.room_id = p_room_id AND rp.user_id = v_user_id;

            -- Find next active non-forfeited player
            SELECT rp.user_id INTO v_next_turn_user
            FROM public.room_players rp
            JOIN public.game_player_states gps ON gps.game_id = p_game_id AND gps.user_id = rp.user_id
            WHERE rp.room_id = p_room_id
              AND rp.seat_index > v_current_seat
              AND gps.is_forfeited = FALSE
            ORDER BY rp.seat_index ASC
            LIMIT 1;

            IF v_next_turn_user IS NULL THEN
                SELECT rp.user_id INTO v_next_turn_user
                FROM public.room_players rp
                JOIN public.game_player_states gps ON gps.game_id = p_game_id AND gps.user_id = rp.user_id
                WHERE rp.room_id = p_room_id
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

        -- Host edge case: if host forfeited, transfer host role to next active player
        IF v_room.host_id = v_user_id THEN
            SELECT rp.user_id INTO v_new_host_id
            FROM public.room_players rp
            JOIN public.game_player_states gps ON gps.game_id = p_game_id AND gps.user_id = rp.user_id
            WHERE rp.room_id = p_room_id AND gps.is_forfeited = FALSE
            ORDER BY rp.seat_index ASC
            LIMIT 1;

            IF v_new_host_id IS NOT NULL THEN
                UPDATE public.rooms SET host_id = v_new_host_id, updated_at = now() WHERE id = p_room_id;
                UPDATE public.room_players SET is_host = (user_id = v_new_host_id) WHERE room_id = p_room_id;
            END IF;
        END IF;

        RETURN jsonb_build_object(
            'success', true,
            'match_completed', false,
            'active_players_count', v_remaining_count
        );
    END IF;
END;
$$;

-- 5. Idempotent rpc_finish_round: prevents duplicate records and double-stats
CREATE OR REPLACE FUNCTION public.rpc_finish_round(
    p_game_id UUID,
    p_room_id UUID,
    p_winner_id UUID,
    p_winner_name TEXT,
    p_total_calls INT,
    p_player_outcomes JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_game RECORD;
    v_outcome JSONB;
    v_player_id UUID;
    v_lines INT;
    v_is_winner BOOLEAN;
    v_already_recorded BOOLEAN := FALSE;
BEGIN
    -- 1. Fetch and lock active game
    SELECT * INTO v_game
    FROM public.games
    WHERE id = p_game_id AND room_id = p_room_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Game not found');
    END IF;

    -- Check if history was already recorded
    SELECT EXISTS(
        SELECT 1 FROM public.room_match_history
        WHERE game_id = p_game_id OR (room_id = p_room_id AND round_number = v_game.round_number)
    ) INTO v_already_recorded;

    IF v_already_recorded THEN
        RETURN jsonb_build_object(
            'success', true,
            'already_recorded', true,
            'round_number', v_game.round_number,
            'winner_id', p_winner_id
        );
    END IF;

    -- Update game status to completed
    UPDATE public.games
    SET status = 'completed',
        winner_user_id = p_winner_id,
        completed_at = COALESCE(completed_at, timezone('utc'::text, now())),
        updated_at = timezone('utc'::text, now())
    WHERE id = p_game_id;

    UPDATE public.rooms
    SET status = 'completed',
        updated_at = timezone('utc'::text, now())
    WHERE id = p_room_id;

    -- Insert history record exactly once
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
        finished_at,
        completed_at
    ) VALUES (
        p_room_id,
        p_game_id,
        COALESCE(v_game.round_number, 1),
        p_winner_id,
        p_winner_id,
        p_winner_name,
        p_winner_name,
        p_total_calls,
        jsonb_array_length(p_player_outcomes),
        p_player_outcomes,
        p_player_outcomes,
        timezone('utc'::text, now()),
        timezone('utc'::text, now())
    );

    -- Update career player_statistics for each player
    FOR v_outcome IN SELECT * FROM jsonb_array_elements(p_player_outcomes)
    LOOP
        v_player_id := (v_outcome->>'user_id')::UUID;
        v_lines := COALESCE((v_outcome->>'lines_claimed_count')::INT, (v_outcome->>'lines_claimed')::INT, 0);
        v_is_winner := COALESCE((v_outcome->>'is_winner')::BOOLEAN, false);

        INSERT INTO public.player_statistics (
            user_id, total_matches, wins, losses, draws, current_streak, best_streak, highest_lines_claimed, updated_at
        ) VALUES (
            v_player_id,
            1,
            CASE WHEN v_is_winner THEN 1 ELSE 0 END,
            CASE WHEN v_is_winner THEN 0 ELSE 1 END,
            0,
            CASE WHEN v_is_winner THEN 1 ELSE 0 END,
            CASE WHEN v_is_winner THEN 1 ELSE 0 END,
            v_lines,
            timezone('utc'::text, now())
        )
        ON CONFLICT (user_id) DO UPDATE SET
            total_matches = public.player_statistics.total_matches + 1,
            wins = public.player_statistics.wins + CASE WHEN v_is_winner THEN 1 ELSE 0 END,
            losses = public.player_statistics.losses + CASE WHEN v_is_winner THEN 0 ELSE 1 END,
            current_streak = CASE WHEN v_is_winner THEN public.player_statistics.current_streak + 1 ELSE 0 END,
            best_streak = GREATEST(
                public.player_statistics.best_streak,
                CASE WHEN v_is_winner THEN public.player_statistics.current_streak + 1 ELSE public.player_statistics.best_streak END
            ),
            highest_lines_claimed = GREATEST(public.player_statistics.highest_lines_claimed, v_lines),
            updated_at = timezone('utc'::text, now());
    END LOOP;

    RETURN jsonb_build_object(
        'success', true,
        'round_number', v_game.round_number,
        'winner_id', p_winner_id
    );
END;
$$;

-- 6. RPC: rpc_get_user_recent_rooms
CREATE OR REPLACE FUNCTION public.rpc_get_user_recent_rooms(
    p_limit INT DEFAULT 5
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_res JSONB;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN '[]'::jsonb;
    END IF;

    SELECT COALESCE(jsonb_agg(r_data), '[]'::jsonb) INTO v_res
    FROM (
        SELECT
            r.id,
            r.code,
            r.name,
            r.status::TEXT as status,
            r.max_players,
            (SELECT COUNT(*) FROM public.room_players rp2 WHERE rp2.room_id = r.id) as participant_count,
            rp.joined_at,
            r.updated_at
        FROM public.room_players rp
        JOIN public.rooms r ON r.id = rp.room_id
        WHERE rp.user_id = v_user_id
        ORDER BY rp.joined_at DESC
        LIMIT p_limit
    ) r_data;

    RETURN v_res;
END;
$$;
