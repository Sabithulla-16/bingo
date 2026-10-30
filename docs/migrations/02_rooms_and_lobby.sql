-- ==============================================================================
-- Migration: 02_rooms_and_lobby.sql
-- Description: Schema, RLS policies, and triggers for multiplayer rooms & lobby.
-- ==============================================================================

-- 1. Create room_status enum if not exists
DO $$ BEGIN
    CREATE TYPE room_status AS ENUM ('waiting', 'preparing', 'in_progress', 'completed');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- 2. Rooms table
CREATE TABLE IF NOT EXISTS public.rooms (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(6) UNIQUE NOT NULL,
    name TEXT NOT NULL,
    host_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    max_players INT NOT NULL DEFAULT 4 CHECK (max_players >= 2 AND max_players <= 4),
    prep_time_seconds INT NOT NULL DEFAULT 45 CHECK (prep_time_seconds IN (30, 45, 60)),
    turn_time_seconds INT NOT NULL DEFAULT 20 CHECK (turn_time_seconds IN (15, 20, 30)),
    status room_status NOT NULL DEFAULT 'waiting',
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- Index for instant room lookup by code
CREATE INDEX IF NOT EXISTS idx_rooms_code ON public.rooms(code);
CREATE INDEX IF NOT EXISTS idx_rooms_status ON public.rooms(status);

-- 3. Room Players table
CREATE TABLE IF NOT EXISTS public.room_players (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    room_id UUID NOT NULL REFERENCES public.rooms(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    is_host BOOLEAN NOT NULL DEFAULT false,
    is_ready BOOLEAN NOT NULL DEFAULT false,
    seat_index INT NOT NULL CHECK (seat_index >= 0 AND seat_index < 4),
    joined_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    UNIQUE(room_id, user_id),
    UNIQUE(room_id, seat_index)
);

CREATE INDEX IF NOT EXISTS idx_room_players_room ON public.room_players(room_id);

-- 4. Enable Row Level Security
ALTER TABLE public.rooms ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.room_players ENABLE ROW LEVEL SECURITY;

-- 5. Rooms Policies
-- Anyone authenticated can view active rooms
CREATE POLICY "Allow authenticated read on rooms"
    ON public.rooms FOR SELECT
    TO authenticated
    USING (true);

-- Anyone authenticated can create a room
CREATE POLICY "Allow authenticated create on rooms"
    ON public.rooms FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = host_id);

-- Only host can update room properties (e.g. status)
CREATE POLICY "Allow host update on rooms"
    ON public.rooms FOR UPDATE
    TO authenticated
    USING (auth.uid() = host_id)
    WITH CHECK (auth.uid() = host_id);

-- 6. Room Players Policies
-- Anyone authenticated can view room participants
CREATE POLICY "Allow authenticated read on room_players"
    ON public.room_players FOR SELECT
    TO authenticated
    USING (true);

-- Authenticated players can insert their own participation record
CREATE POLICY "Allow authenticated join room_players"
    ON public.room_players FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = user_id);

-- Players can update their own ready status; Hosts can update or kick
CREATE POLICY "Allow player self update on room_players"
    ON public.room_players FOR UPDATE
    TO authenticated
    USING (
        auth.uid() = user_id OR
        EXISTS (
            SELECT 1 FROM public.rooms
            WHERE rooms.id = room_players.room_id AND rooms.host_id = auth.uid()
        )
    );

-- Players can leave or hosts can kick
CREATE POLICY "Allow player leave or host kick on room_players"
    ON public.room_players FOR DELETE
    TO authenticated
    USING (
        auth.uid() = user_id OR
        EXISTS (
            SELECT 1 FROM public.rooms
            WHERE rooms.id = room_players.room_id AND rooms.host_id = auth.uid()
        )
    );

-- 7. Realtime Replication Publication
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
