-- ZivoConnect live backend reconciliation: private document buckets, storage RLS, and Realtime publication.

INSERT INTO storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
VALUES
  ('student-documents','student-documents',false,20971520,ARRAY[
    'application/pdf','image/jpeg','image/png','image/webp','application/msword',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
  ]),
  ('admissions-documents','admissions-documents',false,20971520,ARRAY[
    'application/pdf','image/jpeg','image/png','image/webp','application/msword',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
  ])
ON CONFLICT (id) DO UPDATE SET
  public=EXCLUDED.public,
  file_size_limit=EXCLUDED.file_size_limit,
  allowed_mime_types=EXCLUDED.allowed_mime_types;

DROP POLICY IF EXISTS zc_student_docs_select ON storage.objects;
CREATE POLICY zc_student_docs_select ON storage.objects
FOR SELECT TO authenticated
USING (
  bucket_id='student-documents'
  AND (storage.foldername(name))[1]=public.get_active_school_id()::text
  AND (
    public.get_active_role()::text=ANY(ARRAY['school_admin','registrar','super_admin']::text[])
    OR (storage.foldername(name))[2]=public.get_active_profile_id()::text
    OR (
      public.get_active_role()::text='parent'
      AND (storage.foldername(name))[2] ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
      AND public.user_is_parent_of_student(((storage.foldername(name))[2])::uuid,auth.uid())
    )
  )
);

DROP POLICY IF EXISTS zc_student_docs_insert ON storage.objects;
CREATE POLICY zc_student_docs_insert ON storage.objects
FOR INSERT TO authenticated
WITH CHECK (
  bucket_id='student-documents'
  AND (storage.foldername(name))[1]=public.get_active_school_id()::text
  AND (
    public.get_active_role()::text=ANY(ARRAY['school_admin','registrar','super_admin']::text[])
    OR (storage.foldername(name))[2]=public.get_active_profile_id()::text
    OR (
      public.get_active_role()::text='parent'
      AND (storage.foldername(name))[2] ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
      AND public.user_is_parent_of_student(((storage.foldername(name))[2])::uuid,auth.uid())
    )
  )
);

DROP POLICY IF EXISTS zc_student_docs_update ON storage.objects;
CREATE POLICY zc_student_docs_update ON storage.objects
FOR UPDATE TO authenticated
USING (
  bucket_id='student-documents'
  AND (storage.foldername(name))[1]=public.get_active_school_id()::text
  AND (public.get_active_role()::text=ANY(ARRAY['school_admin','registrar','super_admin']::text[]) OR owner_id=auth.uid()::text)
)
WITH CHECK (bucket_id='student-documents' AND (storage.foldername(name))[1]=public.get_active_school_id()::text);

DROP POLICY IF EXISTS zc_student_docs_delete ON storage.objects;
CREATE POLICY zc_student_docs_delete ON storage.objects
FOR DELETE TO authenticated
USING (
  bucket_id='student-documents'
  AND (storage.foldername(name))[1]=public.get_active_school_id()::text
  AND (public.get_active_role()::text=ANY(ARRAY['school_admin','registrar','super_admin']::text[]) OR owner_id=auth.uid()::text)
);

DROP POLICY IF EXISTS zc_admissions_docs_select ON storage.objects;
CREATE POLICY zc_admissions_docs_select ON storage.objects
FOR SELECT TO authenticated
USING (
  bucket_id='admissions-documents'
  AND (storage.foldername(name))[1]=public.get_active_school_id()::text
  AND (
    public.get_active_role()::text=ANY(ARRAY['school_admin','registrar','super_admin']::text[])
    OR EXISTS (
      SELECT 1 FROM public.admissions_applications a
      WHERE a.id::text=(storage.foldername(storage.objects.name))[2]
        AND a.school_id=public.get_active_school_id()
        AND a.deleted_at IS NULL
        AND lower(a.email)=lower(COALESCE(auth.jwt()->>'email',''))
    )
  )
);

DROP POLICY IF EXISTS zc_admissions_docs_insert ON storage.objects;
CREATE POLICY zc_admissions_docs_insert ON storage.objects
FOR INSERT TO authenticated
WITH CHECK (
  bucket_id='admissions-documents'
  AND (storage.foldername(name))[1]=public.get_active_school_id()::text
  AND (
    public.get_active_role()::text=ANY(ARRAY['school_admin','registrar','super_admin']::text[])
    OR EXISTS (
      SELECT 1 FROM public.admissions_applications a
      WHERE a.id::text=(storage.foldername(storage.objects.name))[2]
        AND a.school_id=public.get_active_school_id()
        AND a.deleted_at IS NULL
        AND lower(a.email)=lower(COALESCE(auth.jwt()->>'email',''))
    )
  )
);

DROP POLICY IF EXISTS zc_admissions_docs_update ON storage.objects;
CREATE POLICY zc_admissions_docs_update ON storage.objects
FOR UPDATE TO authenticated
USING (
  bucket_id='admissions-documents'
  AND (storage.foldername(name))[1]=public.get_active_school_id()::text
  AND (public.get_active_role()::text=ANY(ARRAY['school_admin','registrar','super_admin']::text[]) OR owner_id=auth.uid()::text)
)
WITH CHECK (bucket_id='admissions-documents' AND (storage.foldername(name))[1]=public.get_active_school_id()::text);

DROP POLICY IF EXISTS zc_admissions_docs_delete ON storage.objects;
CREATE POLICY zc_admissions_docs_delete ON storage.objects
FOR DELETE TO authenticated
USING (
  bucket_id='admissions-documents'
  AND (storage.foldername(name))[1]=public.get_active_school_id()::text
  AND (public.get_active_role()::text=ANY(ARRAY['school_admin','registrar','super_admin']::text[]) OR owner_id=auth.uid()::text)
);

-- Reproduce the exact live Supabase Realtime membership without adding payments or other tables.
DO $$
DECLARE
  t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['announcements','bus_telemetry','direct_messages','notifications']
  LOOP
    IF NOT EXISTS (
      SELECT 1 FROM pg_publication_tables
      WHERE pubname='supabase_realtime' AND schemaname='public' AND tablename=t
    ) THEN
      EXECUTE format('ALTER PUBLICATION supabase_realtime ADD TABLE public.%I',t);
    END IF;
  END LOOP;
END $$;
