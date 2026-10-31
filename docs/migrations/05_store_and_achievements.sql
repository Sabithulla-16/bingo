-- ==============================================================================
-- Migration: 05_store_and_achievements.sql
-- Description: Tables, RPCs, and RLS policies for Store Customizations,
--              Daily Check-ins, Earned Rewards, and Achievement Milestones.
-- ==============================================================================

-- 1. Player Customizations Table (Locker / Inventory)
CREATE TABLE IF NOT EXISTS public.player_customizations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    item_id INT NOT NULL,
    category TEXT NOT NULL CHECK (category IN ('board', 'numbers', 'avatar', 'victory', 'frame', 'sound')),
    is_equipped BOOLEAN NOT NULL DEFAULT false,
    purchased_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL,
    UNIQUE(user_id, item_id)
);

CREATE INDEX IF NOT EXISTS idx_player_customizations_user ON public.player_customizations(user_id);
CREATE INDEX IF NOT EXISTS idx_player_customizations_equipped ON public.player_customizations(user_id, category, is_equipped);

-- 2. Daily Check-ins Table
CREATE TABLE IF NOT EXISTS public.daily_checkins (
    user_id UUID PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
    last_checkin_date DATE NOT NULL,
    streak_count INT NOT NULL DEFAULT 1,
    claimed_days INT[] NOT NULL DEFAULT '{1}',
    updated_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 3. Player Achievements Progress Table
CREATE TABLE IF NOT EXISTS public.player_achievements (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    achievement_id TEXT NOT NULL,
    progress INT NOT NULL DEFAULT 0,
    is_unlocked BOOLEAN NOT NULL DEFAULT false,
    is_claimed BOOLEAN NOT NULL DEFAULT false,
    unlocked_at TIMESTAMPTZ,
    claimed_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL,
    UNIQUE(user_id, achievement_id)
);

CREATE INDEX IF NOT EXISTS idx_player_achievements_user ON public.player_achievements(user_id);

-- 4. Chip Transactions Ledger (Audit Trail)
CREATE TABLE IF NOT EXISTS public.chip_transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    amount INT NOT NULL,
    balance_after INT NOT NULL,
    reason TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_chip_transactions_user ON public.chip_transactions(user_id);

-- 5. Enable Row Level Security (RLS)
ALTER TABLE public.player_customizations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.daily_checkins ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.player_achievements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chip_transactions ENABLE ROW LEVEL SECURITY;

-- Customizations: Users can view and manage their own inventory
CREATE POLICY "Users view own customizations"
    ON public.player_customizations FOR SELECT
    TO authenticated
    USING (auth.uid() = user_id);

CREATE POLICY "Users insert own customizations"
    ON public.player_customizations FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users update own customizations"
    ON public.player_customizations FOR UPDATE
    TO authenticated
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- Daily Checkins: Users view and update their own checkin state
CREATE POLICY "Users view own checkins"
    ON public.daily_checkins FOR SELECT
    TO authenticated
    USING (auth.uid() = user_id);

CREATE POLICY "Users insert own checkins"
    ON public.daily_checkins FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users update own checkins"
    ON public.daily_checkins FOR UPDATE
    TO authenticated
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- Achievements: Users view and update their own progress
CREATE POLICY "Users view own achievements"
    ON public.player_achievements FOR SELECT
    TO authenticated
    USING (auth.uid() = user_id);

CREATE POLICY "Users insert own achievements"
    ON public.player_achievements FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users update own achievements"
    ON public.player_achievements FOR UPDATE
    TO authenticated
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- Transactions: Users view their own transaction history
CREATE POLICY "Users view own transactions"
    ON public.chip_transactions FOR SELECT
    TO authenticated
    USING (auth.uid() = user_id);

-- 6. Server-Authoritative Database RPCs

-- A. Purchase Customization RPC
CREATE OR REPLACE FUNCTION public.rpc_purchase_customization(
    p_item_id INT,
    p_category TEXT,
    p_price INT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_current_chips INT;
    v_new_balance INT;
    v_already_owned BOOLEAN;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    -- Check if already owned
    SELECT EXISTS(
        SELECT 1 FROM public.player_customizations
        WHERE user_id = v_user_id AND item_id = p_item_id
    ) INTO v_already_owned;

    IF v_already_owned THEN
        RAISE EXCEPTION 'Item already owned';
    END IF;

    -- Lock and check user chips balance
    SELECT chips INTO v_current_chips
    FROM public.profiles
    WHERE id = v_user_id
    FOR UPDATE;

    IF v_current_chips IS NULL THEN
        RAISE EXCEPTION 'Profile not found';
    END IF;

    IF v_current_chips < p_price THEN
        RAISE EXCEPTION 'Insufficient chips (have %, need %)', v_current_chips, p_price;
    END IF;

    -- Deduct chips
    v_new_balance := v_current_chips - p_price;
    UPDATE public.profiles
    SET chips = v_new_balance, updated_at = now()
    WHERE id = v_user_id;

    -- Insert into customizations inventory
    INSERT INTO public.player_customizations (user_id, item_id, category, is_equipped)
    VALUES (v_user_id, p_item_id, p_category, false);

    -- Log transaction
    INSERT INTO public.chip_transactions (user_id, amount, balance_after, reason)
    VALUES (v_user_id, -p_price, v_new_balance, 'purchase_item_' || p_item_id);

    RETURN jsonb_build_object(
        'success', true,
        'item_id', p_item_id,
        'new_balance', v_new_balance
    );
END;
$$;

-- B. Equip Customization RPC (Exactly one equipped per category)
CREATE OR REPLACE FUNCTION public.rpc_equip_customization(
    p_item_id INT,
    p_category TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    -- Unequip all items in this category for this user
    UPDATE public.player_customizations
    SET is_equipped = false
    WHERE user_id = v_user_id AND category = p_category;

    -- Equip selected item (or create if free starter item)
    INSERT INTO public.player_customizations (user_id, item_id, category, is_equipped)
    VALUES (v_user_id, p_item_id, p_category, true)
    ON CONFLICT (user_id, item_id)
    DO UPDATE SET is_equipped = true;

    RETURN jsonb_build_object(
        'success', true,
        'item_id', p_item_id,
        'category', p_category
    );
END;
$$;

-- C. Claim Daily Check-in RPC
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
    v_today DATE := CURRENT_DATE;
    v_checkin RECORD;
    v_current_chips INT;
    v_new_balance INT;
    v_new_streak INT := 1;
    v_claimed_days INT[];
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    SELECT * INTO v_checkin
    FROM public.daily_checkins
    WHERE user_id = v_user_id
    FOR UPDATE;

    IF v_checkin IS NOT NULL THEN
        IF v_checkin.last_checkin_date = v_today THEN
            RAISE EXCEPTION 'Daily reward already claimed today';
        ELSIF v_checkin.last_checkin_date = v_today - INTERVAL '1 day' THEN
            v_new_streak := (v_checkin.streak_count % 7) + 1;
            v_claimed_days := array_append(v_checkin.claimed_days, p_day_index);
        ELSE
            -- Streak reset
            v_new_streak := 1;
            v_claimed_days := ARRAY[1];
        END IF;

        UPDATE public.daily_checkins
        SET last_checkin_date = v_today,
            streak_count = v_new_streak,
            claimed_days = v_claimed_days,
            updated_at = now()
        WHERE user_id = v_user_id;
    ELSE
        INSERT INTO public.daily_checkins (user_id, last_checkin_date, streak_count, claimed_days)
        VALUES (v_user_id, v_today, 1, ARRAY[1]);
        v_new_streak := 1;
    END IF;

    -- Credit chips
    SELECT chips INTO v_current_chips
    FROM public.profiles
    WHERE id = v_user_id
    FOR UPDATE;

    v_new_balance := COALESCE(v_current_chips, 500) + p_reward_amount;
    UPDATE public.profiles
    SET chips = v_new_balance, updated_at = now()
    WHERE id = v_user_id;

    -- Record transaction
    INSERT INTO public.chip_transactions (user_id, amount, balance_after, reason)
    VALUES (v_user_id, p_reward_amount, v_new_balance, 'daily_checkin_day_' || p_day_index);

    RETURN jsonb_build_object(
        'success', true,
        'streak', v_new_streak,
        'reward_claimed', p_reward_amount,
        'new_balance', v_new_balance
    );
END;
$$;

-- D. Claim Achievement Reward RPC
CREATE OR REPLACE FUNCTION public.rpc_claim_achievement(
    p_achievement_id TEXT,
    p_reward_amount INT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_ach RECORD;
    v_current_chips INT;
    v_new_balance INT;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    SELECT * INTO v_ach
    FROM public.player_achievements
    WHERE user_id = v_user_id AND achievement_id = p_achievement_id
    FOR UPDATE;

    IF v_ach IS NOT NULL AND v_ach.is_claimed THEN
        RAISE EXCEPTION 'Achievement reward already claimed';
    END IF;

    -- Mark claimed
    INSERT INTO public.player_achievements (user_id, achievement_id, is_unlocked, is_claimed, unlocked_at, claimed_at)
    VALUES (v_user_id, p_achievement_id, true, true, now(), now())
    ON CONFLICT (user_id, achievement_id)
    DO UPDATE SET is_unlocked = true, is_claimed = true, claimed_at = now(), updated_at = now();

    -- Credit chips
    SELECT chips INTO v_current_chips
    FROM public.profiles
    WHERE id = v_user_id
    FOR UPDATE;

    v_new_balance := COALESCE(v_current_chips, 500) + p_reward_amount;
    UPDATE public.profiles
    SET chips = v_new_balance, updated_at = now()
    WHERE id = v_user_id;

    -- Audit trail
    INSERT INTO public.chip_transactions (user_id, amount, balance_after, reason)
    VALUES (v_user_id, p_reward_amount, v_new_balance, 'achievement_' || p_achievement_id);

    RETURN jsonb_build_object(
        'success', true,
        'achievement_id', p_achievement_id,
        'reward_claimed', p_reward_amount,
        'new_balance', v_new_balance
    );
END;
$$;
