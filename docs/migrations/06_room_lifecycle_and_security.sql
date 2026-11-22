-- BINGO Database Migration 06: Room Lifecycle & Guest Security
-- Authoritative Room Lifecycle: CREATED -> WAITING -> BOARD_PREPARATION -> PLAYING -> ROUND_COMPLETED -> CLOSED

-- 1. Ensure rooms table supports 'closed' and 'expired' status and closed_at column
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'rooms' 
        AND column_name = 'closed_at'
    ) THEN
        ALTER TABLE public.rooms ADD COLUMN closed_at TIMESTAMPTZ NULL;
    END IF;
END $$;

-- 2. Prevent guest / anonymous users from creating or joining multiplayer rooms at the database level
-- Ensure RLS on public.rooms restricts inserts and updates to authenticated non-anonymous users
ALTER TABLE public.rooms ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Authenticated users can create rooms" ON public.rooms;
CREATE POLICY "Authenticated users can create rooms"
    ON public.rooms
    FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = host_id AND auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Hosts can update their rooms" ON public.rooms;
CREATE POLICY "Hosts can update their rooms"
    ON public.rooms
    FOR UPDATE
    TO authenticated
    USING (auth.uid() = host_id)
    WITH CHECK (auth.uid() = host_id);

DROP POLICY IF EXISTS "Authenticated users can read rooms" ON public.rooms;
CREATE POLICY "Authenticated users can read rooms"
    ON public.rooms
    FOR SELECT
    TO authenticated
    USING (true);

-- 3. Room Players RLS
ALTER TABLE public.room_players ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Authenticated users can join rooms" ON public.room_players;
CREATE POLICY "Authenticated users can join rooms"
    ON public.room_players
    FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = user_id AND auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Users can leave rooms" ON public.room_players;
CREATE POLICY "Users can leave rooms"
    ON public.room_players
    FOR DELETE
    TO authenticated
    USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Authenticated users can view players" ON public.room_players;
CREATE POLICY "Authenticated users can view players"
    ON public.room_players
    FOR SELECT
    TO authenticated
    USING (true);

-- 4. RPC for transactional authoritative room closing
CREATE OR REPLACE FUNCTION public.rpc_close_room(p_room_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_room RECORD;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    SELECT * INTO v_room
    FROM public.rooms
    WHERE id = p_room_id
    FOR UPDATE;

    IF v_room IS NULL THEN
        RAISE EXCEPTION 'Room not found';
    END IF;

    IF v_room.host_id <> v_user_id THEN
        RAISE EXCEPTION 'Only the room host can close this room';
    END IF;

    UPDATE public.rooms
    SET status = 'closed',
        closed_at = now()
    WHERE id = p_room_id;

    RETURN jsonb_build_object(
        'success', true,
        'room_id', p_room_id,
        'status', 'closed'
    );
END;
$$;
