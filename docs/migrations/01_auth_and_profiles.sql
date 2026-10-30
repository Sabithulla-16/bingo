-- Migration 01: Authentication, Profiles, and Player Statistics
-- Run this migration in the Supabase SQL Editor.

-- 1. Profiles Table
CREATE TABLE IF NOT EXISTS public.profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  display_name TEXT NOT NULL,
  email TEXT NOT NULL,
  avatar_id TEXT DEFAULT 'avatar_coral',
  avatar_color_hex TEXT DEFAULT '#FC695C',
  chips INT DEFAULT 500 NOT NULL,
  created_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 2. Player Lifetime Statistics Table
CREATE TABLE IF NOT EXISTS public.player_statistics (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  total_matches INT DEFAULT 0 NOT NULL,
  wins INT DEFAULT 0 NOT NULL,
  losses INT DEFAULT 0 NOT NULL,
  draws INT DEFAULT 0 NOT NULL,
  current_streak INT DEFAULT 0 NOT NULL,
  best_streak INT DEFAULT 0 NOT NULL,
  highest_lines_claimed INT DEFAULT 0 NOT NULL,
  average_calls_per_match NUMERIC(4, 1) DEFAULT 0.0 NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 3. Row Level Security (RLS)
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.player_statistics ENABLE ROW LEVEL SECURITY;

-- Profiles: Anyone authenticated can read profiles (needed for multiplayer lobbies and opponents)
CREATE POLICY "Profiles are viewable by everyone" 
  ON public.profiles 
  FOR SELECT 
  USING (true);

-- Profiles: Users can update their own profile
CREATE POLICY "Users can update their own profile" 
  ON public.profiles 
  FOR UPDATE 
  USING (auth.uid() = id);

-- Profiles: Users can insert their own profile
CREATE POLICY "Users can insert their own profile" 
  ON public.profiles 
  FOR INSERT 
  WITH CHECK (auth.uid() = id);

-- Player Statistics: Anyone authenticated can view statistics (for room leaderboards and profiles)
CREATE POLICY "Player statistics are viewable by everyone" 
  ON public.player_statistics 
  FOR SELECT 
  USING (true);

-- Player Statistics: Users can update their own stats (or via secure RPC)
CREATE POLICY "Users can update their own stats" 
  ON public.player_statistics 
  FOR UPDATE 
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own stats" 
  ON public.player_statistics 
  FOR INSERT 
  WITH CHECK (auth.uid() = user_id);

-- 4. Automatic User Profile & Statistics Creation Trigger
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  -- Insert into public.profiles
  INSERT INTO public.profiles (
    id,
    display_name,
    email,
    avatar_id,
    avatar_color_hex,
    chips
  ) VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'display_name', 'Player'),
    COALESCE(NEW.email, ''),
    'avatar_coral',
    '#FC695C',
    500
  )
  ON CONFLICT (id) DO NOTHING;

  -- Insert into public.player_statistics
  INSERT INTO public.player_statistics (
    user_id,
    total_matches,
    wins,
    losses,
    draws,
    current_streak,
    best_streak,
    highest_lines_claimed,
    average_calls_per_match
  ) VALUES (
    NEW.id,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0.0
  )
  ON CONFLICT (user_id) DO NOTHING;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger firing immediately after an auth user is created
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
