-- ZivoConnect live backend reconciliation: RLS policies for tables introduced after baseline.
-- Policy expressions mirror production as of 2026-09-24.

-- AI usage is server-only. No authenticated/anon policy exists in production.
REVOKE ALL ON TABLE public.ai_usage_events FROM anon, authenticated;
GRANT ALL ON TABLE public.ai_usage_events TO service_role;

-- Activity events
DROP POLICY IF EXISTS zc_activity_insert ON public.activity_events;
CREATE POLICY zc_activity_insert ON public.activity_events
FOR INSERT
WITH CHECK (
  public.get_active_role() = 'super_admin'::public.app_role
  OR (
    school_id = public.get_active_school_id()
    AND actor_profile_id = public.get_active_profile_id()
  )
);

DROP POLICY IF EXISTS zc_activity_select ON public.activity_events;
CREATE POLICY zc_activity_select ON public.activity_events
FOR SELECT
USING (
  public.get_active_role() = 'super_admin'::public.app_role
  OR (
    school_id = public.get_active_school_id()
    AND (
      public.get_active_role()::text = ANY (ARRAY['school_admin','teacher','registrar']::text[])
      OR subject_profile_id = public.get_active_profile_id()
      OR (
        subject_profile_id IS NOT NULL
        AND public.user_is_parent_of_student(subject_profile_id, auth.uid())
      )
    )
  )
);

-- Finance extension tables
DROP POLICY IF EXISTS zc_finance_ext_access ON public.fee_structures;
CREATE POLICY zc_finance_ext_access ON public.fee_structures
FOR ALL
USING (
  public.get_active_role() = 'super_admin'::public.app_role
  OR (
    school_id = public.get_active_school_id()
    AND public.get_active_role()::text = ANY (ARRAY['school_admin','finance_manager']::text[])
  )
)
WITH CHECK (
  public.get_active_role() = 'super_admin'::public.app_role
  OR (
    school_id = public.get_active_school_id()
    AND public.get_active_role()::text = ANY (ARRAY['school_admin','finance_manager']::text[])
  )
);

DROP POLICY IF EXISTS zc_finance_ext_access ON public.fee_structure_items;
CREATE POLICY zc_finance_ext_access ON public.fee_structure_items
FOR ALL
USING (
  public.get_active_role() = 'super_admin'::public.app_role
  OR (
    school_id = public.get_active_school_id()
    AND public.get_active_role()::text = ANY (ARRAY['school_admin','finance_manager']::text[])
  )
)
WITH CHECK (
  public.get_active_role() = 'super_admin'::public.app_role
  OR (
    school_id = public.get_active_school_id()
    AND public.get_active_role()::text = ANY (ARRAY['school_admin','finance_manager']::text[])
  )
);

DROP POLICY IF EXISTS zc_finance_ext_access ON public.school_payment_methods;
CREATE POLICY zc_finance_ext_access ON public.school_payment_methods
FOR ALL
USING (
  public.get_active_role() = 'super_admin'::public.app_role
  OR (
    school_id = public.get_active_school_id()
    AND public.get_active_role()::text = ANY (ARRAY['school_admin','finance_manager']::text[])
  )
)
WITH CHECK (
  public.get_active_role() = 'super_admin'::public.app_role
  OR (
    school_id = public.get_active_school_id()
    AND public.get_active_role()::text = ANY (ARRAY['school_admin','finance_manager']::text[])
  )
);

DROP POLICY IF EXISTS zc_finance_ext_access ON public.payroll_runs;
CREATE POLICY zc_finance_ext_access ON public.payroll_runs
FOR ALL
USING (
  public.get_active_role() = 'super_admin'::public.app_role
  OR (
    school_id = public.get_active_school_id()
    AND public.get_active_role()::text = ANY (ARRAY['school_admin','finance_manager']::text[])
  )
)
WITH CHECK (
  public.get_active_role() = 'super_admin'::public.app_role
  OR (
    school_id = public.get_active_school_id()
    AND public.get_active_role()::text = ANY (ARRAY['school_admin','finance_manager']::text[])
  )
);

-- Notification center / preferences
DROP POLICY IF EXISTS zc_notifications_own ON public.notifications;
CREATE POLICY zc_notifications_own ON public.notifications
FOR ALL
USING (
  recipient_profile_id = public.get_active_profile_id()
  OR public.get_active_role() = 'super_admin'::public.app_role
)
WITH CHECK (
  recipient_profile_id = public.get_active_profile_id()
  OR public.get_active_role() = 'super_admin'::public.app_role
);

DROP POLICY IF EXISTS zc_notification_prefs_own ON public.notification_preferences;
CREATE POLICY zc_notification_prefs_own ON public.notification_preferences
FOR ALL
USING (
  profile_id = public.get_active_profile_id()
  OR public.get_active_role() = 'super_admin'::public.app_role
)
WITH CHECK (
  profile_id = public.get_active_profile_id()
  OR public.get_active_role() = 'super_admin'::public.app_role
);

DROP POLICY IF EXISTS zc_notification_delivery_select ON public.notification_deliveries;
CREATE POLICY zc_notification_delivery_select ON public.notification_deliveries
FOR SELECT
USING (
  public.get_active_role() = 'super_admin'::public.app_role
  OR EXISTS (
    SELECT 1
    FROM public.notifications n
    WHERE n.id = notification_deliveries.notification_id
      AND n.recipient_profile_id = public.get_active_profile_id()
      AND n.deleted_at IS NULL
  )
);

-- Profile heartbeat/activity
DROP POLICY IF EXISTS profile_activity_own ON public.profile_activity;
CREATE POLICY profile_activity_own ON public.profile_activity
FOR ALL TO authenticated
USING (
  profile_id = public.get_active_profile_id()
  OR public.get_active_role() = 'super_admin'::public.app_role
)
WITH CHECK (
  (
    profile_id = public.get_active_profile_id()
    AND school_id = public.get_active_school_id()
  )
  OR public.get_active_role() = 'super_admin'::public.app_role
);

-- School calendar
DROP POLICY IF EXISTS zc_school_events_select ON public.school_events;
CREATE POLICY zc_school_events_select ON public.school_events
FOR SELECT
USING (
  public.get_active_role() = 'super_admin'::public.app_role
  OR public.user_has_profile_in_school(school_id, auth.uid())
);

DROP POLICY IF EXISTS zc_school_events_write ON public.school_events;
CREATE POLICY zc_school_events_write ON public.school_events
FOR ALL
USING (
  public.get_active_role() = 'super_admin'::public.app_role
  OR (
    school_id = public.get_active_school_id()
    AND public.get_active_role()::text = 'school_admin'
  )
)
WITH CHECK (
  public.get_active_role() = 'super_admin'::public.app_role
  OR (
    school_id = public.get_active_school_id()
    AND public.get_active_role()::text = 'school_admin'
  )
);

-- Student details
DROP POLICY IF EXISTS zc_student_details_select ON public.student_details;
CREATE POLICY zc_student_details_select ON public.student_details
FOR SELECT
USING (
  public.get_active_role() = 'super_admin'::public.app_role
  OR (
    school_id = public.get_active_school_id()
    AND (
      public.get_active_role()::text = ANY (ARRAY['school_admin','teacher','registrar']::text[])
      OR student_profile_id = public.get_active_profile_id()
      OR public.user_is_parent_of_student(student_profile_id, auth.uid())
    )
  )
);

DROP POLICY IF EXISTS zc_student_details_write ON public.student_details;
CREATE POLICY zc_student_details_write ON public.student_details
FOR ALL
USING (
  public.get_active_role() = 'super_admin'::public.app_role
  OR (
    school_id = public.get_active_school_id()
    AND public.get_active_role()::text = ANY (ARRAY['school_admin','registrar']::text[])
  )
)
WITH CHECK (
  public.get_active_role() = 'super_admin'::public.app_role
  OR (
    school_id = public.get_active_school_id()
    AND public.get_active_role()::text = ANY (ARRAY['school_admin','registrar']::text[])
  )
);

-- Student documents
DROP POLICY IF EXISTS zc_student_documents_select ON public.student_documents;
CREATE POLICY zc_student_documents_select ON public.student_documents
FOR SELECT
USING (
  public.get_active_role() = 'super_admin'::public.app_role
  OR (
    school_id = public.get_active_school_id()
    AND (
      public.get_active_role()::text = ANY (ARRAY['school_admin','registrar']::text[])
      OR student_profile_id = public.get_active_profile_id()
      OR public.user_is_parent_of_student(student_profile_id, auth.uid())
    )
  )
);

DROP POLICY IF EXISTS zc_student_documents_write ON public.student_documents;
CREATE POLICY zc_student_documents_write ON public.student_documents
FOR ALL
USING (
  public.get_active_role() = 'super_admin'::public.app_role
  OR (
    school_id = public.get_active_school_id()
    AND public.get_active_role()::text = ANY (ARRAY['school_admin','registrar']::text[])
  )
)
WITH CHECK (
  public.get_active_role() = 'super_admin'::public.app_role
  OR (
    school_id = public.get_active_school_id()
    AND public.get_active_role()::text = ANY (ARRAY['school_admin','registrar']::text[])
  )
);

-- Staff details
DROP POLICY IF EXISTS zc_staff_details_select ON public.staff_details;
CREATE POLICY zc_staff_details_select ON public.staff_details
FOR SELECT
USING (
  public.get_active_role() = 'super_admin'::public.app_role
  OR (
    school_id = public.get_active_school_id()
    AND (
      public.get_active_role()::text = ANY (ARRAY['school_admin','registrar']::text[])
      OR staff_profile_id = public.get_active_profile_id()
    )
  )
);

DROP POLICY IF EXISTS zc_staff_details_write ON public.staff_details;
CREATE POLICY zc_staff_details_write ON public.staff_details
FOR ALL
USING (
  public.get_active_role() = 'super_admin'::public.app_role
  OR (
    school_id = public.get_active_school_id()
    AND public.get_active_role()::text = 'school_admin'
  )
)
WITH CHECK (
  public.get_active_role() = 'super_admin'::public.app_role
  OR (
    school_id = public.get_active_school_id()
    AND public.get_active_role()::text = 'school_admin'
  )
);

-- Timetable
DROP POLICY IF EXISTS zc_timetable_select ON public.timetable_entries;
CREATE POLICY zc_timetable_select ON public.timetable_entries
FOR SELECT
USING (
  public.get_active_role() = 'super_admin'::public.app_role
  OR public.user_has_profile_in_school(school_id, auth.uid())
);

DROP POLICY IF EXISTS zc_timetable_write ON public.timetable_entries;
CREATE POLICY zc_timetable_write ON public.timetable_entries
FOR ALL
USING (
  public.get_active_role() = 'super_admin'::public.app_role
  OR (
    school_id = public.get_active_school_id()
    AND public.get_active_role()::text = 'school_admin'
  )
)
WITH CHECK (
  public.get_active_role() = 'super_admin'::public.app_role
  OR (
    school_id = public.get_active_school_id()
    AND public.get_active_role()::text = 'school_admin'
  )
);
