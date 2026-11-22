-- BINGO Database Migration 07: Realtime Lobby Sync, Ready-Up RLS & Idempotent Rewards
-- Guarantees atomic reward claims, active readiness updates, and Supabase Realtime broadcast

-- 1. Ensure room_players table supports player readiness and connection updates
ALTER TABLE public.room_players ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Players can update their own readiness" ON public.room_players;
CREATE POLICY "Players can update their own readiness"
    ON public.room_players
    FOR UPDATE
    TO authenticated
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- 2. Ensure Realtime Publication includes rooms and room_players with full replica identity
ALTER TABLE public.rooms REPLICA IDENTITY FULL;
ALTER TABLE public.room_players REPLICA IDENTITY FULL;

DO $$ BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.rooms;
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.room_players;
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- 3. Reward Claims Table for Atomic Idempotency
CREATE TABLE IF NOT EXISTS public.reward_claims (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    task_id TEXT NOT NULL,
    category TEXT NOT NULL,
    amount INT NOT NULL CHECK (amount > 0),
    claimed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_user_task_claim UNIQUE (user_id, task_id)
);

ALTER TABLE public.reward_claims ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can read their own reward claims" ON public.reward_claims;
CREATE POLICY "Users can read their own reward claims"
    ON public.reward_claims
    FOR SELECT
    TO authenticated
    USING (auth.uid() = user_id);

-- 4. RPC for Idempotent Daily Check-in Claim
CREATE OR REPLACE FUNCTION public.rpc_claim_daily_checkin(
    p_day_index INT,
    p_reward_amount INT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_task_id TEXT;
    v_new_balance INT;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    -- Generate date-based or day-index task key to enforce once-per-day
    v_task_id := 'daily_' || to_char(now(), 'YYYY-MM-DD');

    -- Check if already claimed today
    IF EXISTS (
        SELECT 1 FROM public.reward_claims 
        WHERE user_id = v_user_id AND task_id = v_task_id
    ) THEN
        RAISE EXCEPTION 'Daily check-in already claimed today';
    END IF;

    -- Record claim atomically
    INSERT INTO public.reward_claims (user_id, task_id, category, amount, claimed_at)
    VALUES (v_user_id, v_task_id, 'daily_checkin', p_reward_amount, now());

    -- Credit profile wallet
    UPDATE public.profiles
    SET chips = chips + p_reward_amount
    WHERE id = v_user_id
    RETURNING chips INTO v_new_balance;

    RETURN jsonb_build_object(
        'success', true,
        'reward_amount', p_reward_amount,
        'new_balance', v_new_balance,
        'task_id', v_task_id
    );
END;
$$;

-- 5. RPC for Idempotent Match / Multiplayer Task Claim
CREATE OR REPLACE FUNCTION public.rpc_claim_reward_task(
    p_task_id TEXT,
    p_reward_amount INT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_new_balance INT;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    -- Validate uniqueness
    IF EXISTS (
        SELECT 1 FROM public.reward_claims 
        WHERE user_id = v_user_id AND task_id = p_task_id
    ) THEN
        RAISE EXCEPTION 'Reward task % already claimed', p_task_id;
    END IF;

    -- Record claim
    INSERT INTO public.reward_claims (user_id, task_id, category, amount, claimed_at)
    VALUES (v_user_id, p_task_id, 'match_task', p_reward_amount, now());

    -- Credit profile wallet
    UPDATE public.profiles
    SET chips = chips + p_reward_amount
    WHERE id = v_user_id
    RETURNING chips INTO v_new_balance;

    RETURN jsonb_build_object(
        'success', true,
        'task_id', p_task_id,
        'reward_amount', p_reward_amount,
        'new_balance', v_new_balance
    );
END;
$$;

-- 6. RPC for Idempotent Achievement Claim
CREATE OR REPLACE FUNCTION public.rpc_claim_achievement_reward(
    p_achievement_id TEXT,
    p_reward_amount INT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_new_balance INT;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    -- Validate uniqueness
    IF EXISTS (
        SELECT 1 FROM public.reward_claims 
        WHERE user_id = v_user_id AND task_id = p_achievement_id
    ) THEN
        RAISE EXCEPTION 'Achievement % already claimed', p_achievement_id;
    END IF;

    -- Record claim
    INSERT INTO public.reward_claims (user_id, task_id, category, amount, claimed_at)
    VALUES (v_user_id, p_achievement_id, 'achievement', p_reward_amount, now());

    -- Record in user_achievements if table exists
    BEGIN
        INSERT INTO public.user_achievements (user_id, achievement_id, status, unlocked_at, claimed_at)
        VALUES (v_user_id, p_achievement_id, 'claimed', now(), now())
        ON CONFLICT (user_id, achievement_id) DO UPDATE
        SET status = 'claimed', claimed_at = now();
    EXCEPTION WHEN undefined_table THEN
        -- Table might be managed client-side in hybrid mode
        null;
    END;

    -- Credit profile wallet
    UPDATE public.profiles
    SET chips = chips + p_reward_amount
    WHERE id = v_user_id
    RETURNING chips INTO v_new_balance;

    RETURN jsonb_build_object(
        'success', true,
        'achievement_id', p_achievement_id,
        'reward_amount', p_reward_amount,
        'new_balance', v_new_balance
    );
END;
$$;
