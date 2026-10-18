-- ==============================================================================
-- FSEGN Study Groups Beta - Supabase Database Schema & Security Policies
-- Target: First-year Business Computing licence students at FSEGN (Université de Carthage)
-- Ongoing Cost: $0 (Supabase Free Tier)
-- Note: Supabase Free projects pause after 7 days of inactivity; resume in dashboard.
-- ==============================================================================

-- 1. EXTENSIONS
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 2. PUBLIC PROFILES TABLE
-- DIRECTIVE #1: Email addresses are NEVER exposed here. Emails stay in auth.users.
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    display_name TEXT NOT NULL CHECK (char_length(trim(display_name)) >= 2 AND char_length(display_name) <= 60),
    bio TEXT CHECK (bio IS NULL OR char_length(bio) <= 250),
    university TEXT NOT NULL DEFAULT 'Université de Carthage',
    faculty TEXT NOT NULL DEFAULT 'FSEGN (Nabeul)',
    licence_year TEXT NOT NULL DEFAULT 'L1 (1ère année)',
    specialty TEXT NOT NULL DEFAULT 'Business Computing',
    reliability_score INTEGER NOT NULL DEFAULT 100 CHECK (reliability_score >= 0 AND reliability_score <= 100),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Index for profile queries
CREATE INDEX IF NOT EXISTS idx_profiles_created_at ON public.profiles(created_at);

-- 3. STUDY GROUPS TABLE
-- Exact 12 timetable subjects for FSEGN L1 Business Computing
CREATE TABLE IF NOT EXISTS public.study_groups (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    creator_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    subject TEXT NOT NULL CHECK (
        subject IN (
            'Statistique et probabilité',
            'Comptabilité générale',
            'Culture de l’IA',
            'Systèmes logiques, architecture et ordinateurs',
            'Algorithmique et structures',
            'Systèmes d’exploitation',
            'Analyse',
            'Principes de gestion 1',
            'Technologie Web et programmation',
            'Study Skills 1',
            'Anglais fondamental',
            'Digital Skills'
        )
    ),
    topic TEXT NOT NULL CHECK (char_length(trim(topic)) >= 2 AND char_length(topic) <= 150),
    description TEXT CHECK (description IS NULL OR char_length(description) <= 800),
    meeting_location TEXT NOT NULL CHECK (char_length(trim(meeting_location)) >= 2 AND char_length(meeting_location) <= 120),
    start_time TIMESTAMPTZ NOT NULL,
    end_time TIMESTAMPTZ NOT NULL,
    capacity INTEGER NOT NULL DEFAULT 5 CHECK (capacity >= 2 AND capacity <= 20),
    status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'cancelled', 'completed')),
    cohort_key TEXT NOT NULL DEFAULT 'fsegn_l1_bc',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chk_time_window CHECK (end_time > start_time)
);

CREATE INDEX IF NOT EXISTS idx_study_groups_status_start ON public.study_groups(status, start_time);
CREATE INDEX IF NOT EXISTS idx_study_groups_subject ON public.study_groups(subject);

-- 4. GROUP MEMBERS & ATTENDANCE TABLE
CREATE TABLE IF NOT EXISTS public.group_members (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id UUID NOT NULL REFERENCES public.study_groups(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    role TEXT NOT NULL DEFAULT 'member' CHECK (role IN ('creator', 'member')),
    -- DIRECTIVE #3: Unconfirmed by default, even for creator
    attendance_confirmed BOOLEAN NOT NULL DEFAULT false,
    attendance_status TEXT NOT NULL DEFAULT 'pending' CHECK (attendance_status IN ('pending', 'attended', 'absent', 'unconfirmed')),
    attendance_recorded_at TIMESTAMPTZ,
    joined_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_group_member UNIQUE (group_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_group_members_group_id ON public.group_members(group_id);
CREATE INDEX IF NOT EXISTS idx_group_members_user_id ON public.group_members(user_id);

-- 5. GROUP CHAT MESSAGES TABLE
CREATE TABLE IF NOT EXISTS public.group_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id UUID NOT NULL REFERENCES public.study_groups(id) ON DELETE CASCADE,
    sender_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    message TEXT NOT NULL CHECK (char_length(trim(message)) >= 1 AND char_length(message) <= 2000),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_group_messages_group_time ON public.group_messages(group_id, created_at ASC);

-- ==============================================================================
-- 6. ROW LEVEL SECURITY (RLS) POLICIES
-- ==============================================================================

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.study_groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.group_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.group_messages ENABLE ROW LEVEL SECURITY;

-- Profiles: readable by authenticated students.
-- Direct UPDATE and INSERT on profiles from client are DENIED to prevent tampering
-- with reliability_score or cohort data.
-- Profile edits are permitted ONLY via the secure function public.update_my_profile() below.
CREATE POLICY "Authenticated users can view profiles"
    ON public.profiles FOR SELECT
    TO authenticated
    USING (true);

-- Explicitly revoke direct table mutations from client roles
REVOKE INSERT, UPDATE, DELETE ON public.profiles FROM authenticated, anon;


-- Study groups: readable by authenticated students, created by self, updated by creator
CREATE POLICY "Authenticated users can view study groups"
    ON public.study_groups FOR SELECT
    TO authenticated
    USING (true);

CREATE POLICY "Authenticated users can create study groups"
    ON public.study_groups FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = creator_id);

CREATE POLICY "Creators can update or cancel their study groups"
    ON public.study_groups FOR UPDATE
    TO authenticated
    USING (auth.uid() = creator_id)
    WITH CHECK (auth.uid() = creator_id);

-- Group members: readable by authenticated students, leaves managed by self
CREATE POLICY "Authenticated users can view group members"
    ON public.group_members FOR SELECT
    TO authenticated
    USING (true);

CREATE POLICY "Members can leave a group"
    ON public.group_members FOR DELETE
    TO authenticated
    USING (auth.uid() = user_id AND role != 'creator');

-- Group messages: STRICT - readable and sendable ONLY by verified group members
CREATE POLICY "Members can view messages in their groups"
    ON public.group_messages FOR SELECT
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.group_members gm
            WHERE gm.group_id = group_messages.group_id
              AND gm.user_id = auth.uid()
        )
    );

CREATE POLICY "Members can send messages to their groups"
    ON public.group_messages FOR INSERT
    TO authenticated
    WITH CHECK (
        auth.uid() = sender_id
        AND EXISTS (
            SELECT 1 FROM public.group_members gm
            WHERE gm.group_id = group_messages.group_id
              AND gm.user_id = auth.uid()
        )
    );

-- ==============================================================================
-- 7. SECURE DATABASE FUNCTIONS & TRIGGERS
-- ==============================================================================

-- A. Auto-create profile on auth.users sign-up (No email copied!)
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    INSERT INTO public.profiles (id, display_name, bio)
    VALUES (
        new.id,
        COALESCE(NULLIF(TRIM(new.raw_user_meta_data->>'display_name'), ''), 'Étudiant FSEGN'),
        NULLIF(TRIM(new.raw_user_meta_data->>'bio'), '')
    );
    RETURN new;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_new_user();

-- B. Auto-join creator when group is created (attendance_confirmed = false as per Directive #3)
CREATE OR REPLACE FUNCTION public.handle_new_study_group()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    INSERT INTO public.group_members (
        group_id,
        user_id,
        role,
        attendance_confirmed,
        attendance_status
    ) VALUES (
        new.id,
        new.creator_id,
        'creator',
        false, -- Unconfirmed by default; creator must confirm explicitly
        'pending'
    );
    RETURN new;
END;
$$;

DROP TRIGGER IF EXISTS on_study_group_created ON public.study_groups;
CREATE TRIGGER on_study_group_created
    AFTER INSERT ON public.study_groups
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_new_study_group();

-- C. SECURE PROFILE UPDATE FUNCTION
-- Ensures students can update ONLY display_name and bio.
-- Direct table updates on profiles are blocked by RLS so reliability_score
-- and cohort metadata CANNOT be modified or bypassed.
CREATE OR REPLACE FUNCTION public.update_my_profile(
    p_display_name TEXT,
    p_bio TEXT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id UUID;
    v_trimmed_name TEXT;
    v_trimmed_bio TEXT;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    v_trimmed_name := TRIM(p_display_name);
    IF char_length(v_trimmed_name) < 2 OR char_length(v_trimmed_name) > 60 THEN
        RAISE EXCEPTION 'Le nom d’affichage doit comporter entre 2 et 60 caractères.';
    END IF;

    v_trimmed_bio := NULLIF(TRIM(p_bio), '');
    IF v_trimmed_bio IS NOT NULL AND char_length(v_trimmed_bio) > 250 THEN
        RAISE EXCEPTION 'La bio ne peut pas dépasser 250 caractères.';
    END IF;

    -- Only updates display_name and bio (and updated_at)
    -- reliability_score remains untouched and can only be altered by record_my_attendance
    UPDATE public.profiles
    SET display_name = v_trimmed_name,
        bio = v_trimmed_bio,
        updated_at = now()
    WHERE id = v_user_id;

    RETURN json_build_object(
        'success', true,
        'message', 'Profil mis à jour avec succès'
    );
END;
$$;

-- D. DIRECTIVE #2: Transactional Capacity Enforcement for Joining Groups
-- Uses FOR UPDATE locking to completely prevent concurrent over-capacity joins
CREATE OR REPLACE FUNCTION public.join_study_group(p_group_id UUID)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id UUID;
    v_group RECORD;
    v_current_count INT;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    -- Lock the group record to eliminate race conditions
    SELECT id, status, start_time, end_time, capacity
    INTO v_group
    FROM public.study_groups
    WHERE id = p_group_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Study group not found';
    END IF;

    IF v_group.status != 'active' THEN
        RAISE EXCEPTION 'This study group is no longer active (%s)', v_group.status;
    END IF;

    IF v_group.end_time <= now() THEN
        RAISE EXCEPTION 'This study session has already ended';
    END IF;

    -- Prevent duplicate membership
    IF EXISTS (
        SELECT 1 FROM public.group_members
        WHERE group_id = p_group_id AND user_id = v_user_id
    ) THEN
        RAISE EXCEPTION 'You are already a member of this study group';
    END IF;

    -- Concurrently safe member count
    SELECT COUNT(*) INTO v_current_count
    FROM public.group_members
    WHERE group_id = p_group_id;

    IF v_current_count >= v_group.capacity THEN
        RAISE EXCEPTION 'Group is full (capacity % reached)', v_group.capacity;
    END IF;

    -- Insert membership (attendance unconfirmed by default)
    INSERT INTO public.group_members (
        group_id,
        user_id,
        role,
        attendance_confirmed,
        attendance_status
    ) VALUES (
        p_group_id,
        v_user_id,
        'member',
        false,
        'pending'
    );

    RETURN json_build_object(
        'success', true,
        'message', 'Joined study group successfully'
    );
END;
$$;

-- D. Attendance Confirmation Toggle (Allowed only before session start)
CREATE OR REPLACE FUNCTION public.set_attendance_confirmation(p_group_id UUID, p_confirmed BOOLEAN)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id UUID;
    v_group RECORD;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    SELECT id, start_time, end_time, status
    INTO v_group
    FROM public.study_groups
    WHERE id = p_group_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Study group not found';
    END IF;

    IF now() >= v_group.start_time THEN
        RAISE EXCEPTION 'Attendance confirmation cannot be changed once the session has started';
    END IF;

    UPDATE public.group_members
    SET attendance_confirmed = p_confirmed
    WHERE group_id = p_group_id AND user_id = v_user_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'You are not a member of this study group';
    END IF;

    RETURN json_build_object(
        'success', true,
        'confirmed', p_confirmed
    );
END;
$$;

-- E. DIRECTIVE #4: Idempotent Post-Session Attendance Recording & Capped Reliability Score
-- Honest Student Beta MVP: Attendance self-reported, not independently verified.
-- +5 points for confirmed & attended, -15 points for confirmed & missed, capped 0 to 100.
CREATE OR REPLACE FUNCTION public.record_my_attendance(p_group_id UUID, p_attended BOOLEAN)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id UUID;
    v_group RECORD;
    v_member RECORD;
    v_current_score INT;
    v_new_score INT;
    v_score_delta INT := 0;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    SELECT id, end_time, status
    INTO v_group
    FROM public.study_groups
    WHERE id = p_group_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Study group not found';
    END IF;

    -- Must be after the session ends
    IF now() < v_group.end_time THEN
        RAISE EXCEPTION 'You can only record attendance after the session has ended';
    END IF;

    -- Lock member row to prevent concurrent or duplicate recording
    SELECT id, attendance_confirmed, attendance_status, attendance_recorded_at
    INTO v_member
    FROM public.group_members
    WHERE group_id = p_group_id AND user_id = v_user_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'You are not a member of this study group';
    END IF;

    -- Enforce idempotency: only record once per student per group
    IF v_member.attendance_recorded_at IS NOT NULL OR v_member.attendance_status != 'pending' THEN
        RAISE EXCEPTION 'Attendance for this session has already been recorded';
    END IF;

    -- Calculate score adjustment
    IF v_member.attendance_confirmed THEN
        IF p_attended THEN
            v_score_delta := 5; -- Reward for showing up when committed
        ELSE
            v_score_delta := -15; -- Penalty for no-show after confirming
        END IF;
    ELSE
        -- If member never confirmed attendance beforehand, neutral delta
        v_score_delta := 0;
    END IF;

    -- Lock and clamp profile score between 0 and 100
    SELECT reliability_score INTO v_current_score
    FROM public.profiles
    WHERE id = v_user_id
    FOR UPDATE;

    v_new_score := GREATEST(0, LEAST(100, v_current_score + v_score_delta));

    UPDATE public.profiles
    SET reliability_score = v_new_score,
        updated_at = now()
    WHERE id = v_user_id;

    -- Update member attendance record
    UPDATE public.group_members
    SET attendance_status = CASE WHEN p_attended THEN 'attended' ELSE 'absent' END,
        attendance_recorded_at = now()
    WHERE id = v_member.id;

    RETURN json_build_object(
        'success', true,
        'attended', p_attended,
        'score_delta', v_score_delta,
        'new_score', v_new_score
    );
END;
$$;

-- 8. REALTIME PUBLICATION
-- Enable Realtime events on group_messages for live chat
DO $$
BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.group_messages;
EXCEPTION
    WHEN duplicate_object THEN
        NULL;
END;
$$;
