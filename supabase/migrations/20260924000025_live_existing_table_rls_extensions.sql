-- ZivoConnect live backend reconciliation: later RLS policies added to original baseline tables.

-- Registrar academic read access
DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['academic_years','classes','class_sections','subjects'] LOOP
    EXECUTE format('DROP POLICY IF EXISTS zc_registrar_academic_read ON public.%I',t);
    EXECUTE format(
      'CREATE POLICY zc_registrar_academic_read ON public.%I FOR SELECT USING (school_id=public.get_active_school_id() AND public.get_active_role()::text=''registrar'')',t
    );
  END LOOP;
END $$;

-- Registrar operational write access
DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['admissions_applications','admissions_documents','student_enrollments'] LOOP
    EXECUTE format('DROP POLICY IF EXISTS zc_registrar_all ON public.%I',t);
    EXECUTE format(
      'CREATE POLICY zc_registrar_all ON public.%I FOR ALL USING (school_id=public.get_active_school_id() AND public.get_active_role()=''registrar''::public.app_role) WITH CHECK (school_id=public.get_active_school_id() AND public.get_active_role()=''registrar''::public.app_role)',t
    );
  END LOOP;
END $$;

DROP POLICY IF EXISTS zc_ops_profile_lookup ON public.profiles;
CREATE POLICY zc_ops_profile_lookup ON public.profiles
FOR SELECT
USING (
  school_id=public.get_active_school_id()
  AND public.get_active_role()::text=ANY(ARRAY['finance_manager','registrar']::text[])
);

DROP POLICY IF EXISTS zc_extended_staff_announcements ON public.announcements;
CREATE POLICY zc_extended_staff_announcements ON public.announcements
FOR SELECT
USING (
  school_id=public.get_active_school_id()
  AND public.get_active_role()::text=ANY(ARRAY['finance_manager','registrar']::text[])
  AND target_role=ANY(ARRAY['all','staff']::text[])
  AND deleted_at IS NULL
);

-- Finance Manager access to legacy finance tables
DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['budgets','bursaries','expenses','fee_types','invoice_items','invoices','payments','staff_payroll','student_bursaries'] LOOP
    EXECUTE format('DROP POLICY IF EXISTS zc_finance_manager_all ON public.%I',t);
    EXECUTE format(
      'CREATE POLICY zc_finance_manager_all ON public.%I FOR ALL USING (school_id=public.get_active_school_id() AND public.get_active_role()::text=''finance_manager'') WITH CHECK (school_id=public.get_active_school_id() AND public.get_active_role()::text=''finance_manager'')',t
    );
  END LOOP;
END $$;

-- Behaviour / pastoral access
DROP POLICY IF EXISTS zc_behavior_read ON public.behavioral_logs;
CREATE POLICY zc_behavior_read ON public.behavioral_logs
FOR SELECT
USING (
  public.get_active_role()='super_admin'::public.app_role
  OR (
    school_id=public.get_active_school_id()
    AND (
      public.get_active_role()::text=ANY(ARRAY['school_admin','teacher']::text[])
      OR student_profile_id=public.get_active_profile_id()
      OR public.user_is_parent_of_student(student_profile_id,auth.uid())
    )
  )
);

DROP POLICY IF EXISTS zc_behavior_staff_write ON public.behavioral_logs;
CREATE POLICY zc_behavior_staff_write ON public.behavioral_logs
FOR ALL
USING (
  public.get_active_role()='super_admin'::public.app_role
  OR (school_id=public.get_active_school_id() AND public.get_active_role()::text=ANY(ARRAY['school_admin','teacher']::text[]))
)
WITH CHECK (
  public.get_active_role()='super_admin'::public.app_role
  OR (school_id=public.get_active_school_id() AND public.get_active_role()::text=ANY(ARRAY['school_admin','teacher']::text[]))
);

-- Library access
DROP POLICY IF EXISTS zc_library_books_read ON public.library_books;
CREATE POLICY zc_library_books_read ON public.library_books
FOR SELECT
USING (
  public.get_active_role()='super_admin'::public.app_role
  OR public.user_has_profile_in_school(school_id,auth.uid())
);

DROP POLICY IF EXISTS zc_library_books_manage ON public.library_books;
CREATE POLICY zc_library_books_manage ON public.library_books
FOR ALL
USING (
  public.get_active_role()='super_admin'::public.app_role
  OR (school_id=public.get_active_school_id() AND public.get_active_role()::text='school_admin')
)
WITH CHECK (
  public.get_active_role()='super_admin'::public.app_role
  OR (school_id=public.get_active_school_id() AND public.get_active_role()::text='school_admin')
);

DROP POLICY IF EXISTS zc_library_issues_read ON public.library_issues;
CREATE POLICY zc_library_issues_read ON public.library_issues
FOR SELECT
USING (
  public.get_active_role()='super_admin'::public.app_role
  OR (
    school_id=public.get_active_school_id()
    AND (
      public.get_active_role()::text=ANY(ARRAY['school_admin','teacher']::text[])
      OR borrower_profile_id=public.get_active_profile_id()
      OR public.user_is_parent_of_student(borrower_profile_id,auth.uid())
    )
  )
);

DROP POLICY IF EXISTS zc_library_issues_manage ON public.library_issues;
CREATE POLICY zc_library_issues_manage ON public.library_issues
FOR ALL
USING (
  public.get_active_role()='super_admin'::public.app_role
  OR (school_id=public.get_active_school_id() AND public.get_active_role()::text='school_admin')
)
WITH CHECK (
  public.get_active_role()='super_admin'::public.app_role
  OR (school_id=public.get_active_school_id() AND public.get_active_role()::text='school_admin')
);

DROP POLICY IF EXISTS zc_library_fines_read ON public.library_fines;
CREATE POLICY zc_library_fines_read ON public.library_fines
FOR SELECT
USING (
  public.get_active_role()='super_admin'::public.app_role
  OR EXISTS (
    SELECT 1 FROM public.library_issues li
    WHERE li.id=library_fines.issue_id
      AND li.deleted_at IS NULL
      AND (
        li.borrower_profile_id=public.get_active_profile_id()
        OR public.user_is_parent_of_student(li.borrower_profile_id,auth.uid())
        OR public.get_active_role()::text='school_admin'
      )
  )
);

DROP POLICY IF EXISTS zc_library_fines_manage ON public.library_fines;
CREATE POLICY zc_library_fines_manage ON public.library_fines
FOR ALL
USING (
  public.get_active_role()='super_admin'::public.app_role
  OR (school_id=public.get_active_school_id() AND public.get_active_role()::text='school_admin')
)
WITH CHECK (
  public.get_active_role()='super_admin'::public.app_role
  OR (school_id=public.get_active_school_id() AND public.get_active_role()::text='school_admin')
);
