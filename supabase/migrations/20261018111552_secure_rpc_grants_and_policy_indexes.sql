-- Lock down callable SECURITY DEFINER RPC grants and tune RLS predicates.
-- App RPCs are intentionally available to authenticated users only.
REVOKE EXECUTE ON FUNCTION public.handle_new_user() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.handle_new_study_group() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.update_my_profile(text, text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.update_my_profile(text, text) TO authenticated;
REVOKE EXECUTE ON FUNCTION public.join_study_group(uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.join_study_group(uuid) TO authenticated;
REVOKE EXECUTE ON FUNCTION public.set_attendance_confirmation(uuid, boolean) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.set_attendance_confirmation(uuid, boolean) TO authenticated;
REVOKE EXECUTE ON FUNCTION public.record_my_attendance(uuid, boolean) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.record_my_attendance(uuid, boolean) TO authenticated;

CREATE INDEX IF NOT EXISTS idx_group_messages_sender_id ON public.group_messages(sender_id);
CREATE INDEX IF NOT EXISTS idx_study_groups_creator_id ON public.study_groups(creator_id);

DROP POLICY IF EXISTS "Authenticated users can create study groups" ON public.study_groups;
CREATE POLICY "Authenticated users can create study groups"
    ON public.study_groups FOR INSERT TO authenticated
    WITH CHECK ((SELECT auth.uid()) = creator_id);

DROP POLICY IF EXISTS "Creators can update or cancel their study groups" ON public.study_groups;
CREATE POLICY "Creators can update or cancel their study groups"
    ON public.study_groups FOR UPDATE TO authenticated
    USING ((SELECT auth.uid()) = creator_id)
    WITH CHECK ((SELECT auth.uid()) = creator_id);

DROP POLICY IF EXISTS "Members can leave a group" ON public.group_members;
CREATE POLICY "Members can leave a group"
    ON public.group_members FOR DELETE TO authenticated
    USING ((SELECT auth.uid()) = user_id AND role != 'creator');

DROP POLICY IF EXISTS "Members can view messages in their groups" ON public.group_messages;
CREATE POLICY "Members can view messages in their groups"
    ON public.group_messages FOR SELECT TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.group_members gm
            WHERE gm.group_id = group_messages.group_id
              AND gm.user_id = (SELECT auth.uid())
        )
    );

DROP POLICY IF EXISTS "Members can send messages to their groups" ON public.group_messages;
CREATE POLICY "Members can send messages to their groups"
    ON public.group_messages FOR INSERT TO authenticated
    WITH CHECK (
        sender_id = (SELECT auth.uid())
        AND EXISTS (
            SELECT 1 FROM public.group_members gm
            WHERE gm.group_id = group_messages.group_id
              AND gm.user_id = (SELECT auth.uid())
        )
    );
