-- ZivoConnect live backend reconciliation: active tenant/profile context helpers
-- Exact behavior mirrors production as of 2026-09-24.

CREATE OR REPLACE FUNCTION public.get_active_school_id()
RETURNS uuid
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  _school_id uuid;
BEGIN
  _school_id := (auth.jwt() -> 'app_metadata' ->> 'school_id')::uuid;

  IF _school_id IS NULL AND auth.uid() IS NOT NULL THEN
    SELECT school_id INTO _school_id
    FROM public.profiles
    WHERE user_id = auth.uid() AND deleted_at IS NULL
    LIMIT 1;
  END IF;

  RETURN _school_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_active_role()
RETURNS public.app_role
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  _role public.app_role;
  _school_id uuid;
BEGIN
  _role := (auth.jwt() -> 'app_metadata' ->> 'role')::public.app_role;

  IF _role IS NULL AND auth.uid() IS NOT NULL THEN
    _school_id := public.get_active_school_id();
    SELECT role INTO _role
    FROM public.profiles
    WHERE user_id = auth.uid()
      AND school_id = _school_id
      AND deleted_at IS NULL
    LIMIT 1;
  END IF;

  RETURN _role;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_active_profile_id()
RETURNS uuid
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  _profile_id uuid;
BEGIN
  _profile_id := (auth.jwt() -> 'app_metadata' ->> 'profile_id')::uuid;

  IF _profile_id IS NULL AND auth.uid() IS NOT NULL THEN
    SELECT id INTO _profile_id
    FROM public.profiles
    WHERE user_id = auth.uid()
      AND school_id = public.get_active_school_id()
      AND deleted_at IS NULL
      AND status = 'active'
    ORDER BY created_at ASC
    LIMIT 1;
  END IF;

  RETURN _profile_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.user_has_profile_in_school(school_id uuid, user_id uuid)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $$
BEGIN
  IF auth.uid() IS NULL OR user_id IS DISTINCT FROM auth.uid() THEN
    RETURN false;
  END IF;

  RETURN EXISTS (
    SELECT 1
    FROM public.profiles p
    WHERE p.school_id = user_has_profile_in_school.school_id
      AND p.user_id = auth.uid()
      AND p.deleted_at IS NULL
      AND p.status = 'active'
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.user_is_parent_of_student(student_id uuid, user_id uuid)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $$
BEGIN
  IF auth.uid() IS NULL OR user_id IS DISTINCT FROM auth.uid() THEN
    RETURN false;
  END IF;

  RETURN EXISTS (
    SELECT 1
    FROM public.user_relationships r
    JOIN public.profiles p ON p.id = r.parent_id
    WHERE r.student_id = user_is_parent_of_student.student_id
      AND p.user_id = auth.uid()
      AND r.deleted_at IS NULL
      AND p.deleted_at IS NULL
      AND p.status = 'active'
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.touch_active_profile(
  p_platform text DEFAULT NULL,
  p_app_version text DEFAULT NULL
)
RETURNS timestamptz
LANGUAGE plpgsql
SET search_path TO 'public'
AS $$
DECLARE
  pid uuid := public.get_active_profile_id();
  sid uuid := public.get_active_school_id();
  touched timestamptz;
BEGIN
  IF pid IS NULL OR sid IS NULL THEN
    RAISE EXCEPTION 'active profile is required';
  END IF;

  INSERT INTO public.profile_activity(
    school_id, profile_id, last_active_at, platform, app_version
  )
  VALUES(
    sid, pid, now(), p_platform, p_app_version
  )
  ON CONFLICT(profile_id)
  DO UPDATE SET
    school_id = EXCLUDED.school_id,
    last_active_at = EXCLUDED.last_active_at,
    platform = COALESCE(EXCLUDED.platform, public.profile_activity.platform),
    app_version = COALESCE(EXCLUDED.app_version, public.profile_activity.app_version),
    deleted_at = NULL,
    updated_at = now()
  RETURNING last_active_at INTO touched;

  RETURN touched;
END;
$$;

REVOKE ALL ON FUNCTION public.get_active_school_id() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.get_active_role() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.get_active_profile_id() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.user_has_profile_in_school(uuid, uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.user_is_parent_of_student(uuid, uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.touch_active_profile(text, text) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.get_active_school_id() TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_active_role() TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_active_profile_id() TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.user_has_profile_in_school(uuid, uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.user_is_parent_of_student(uuid, uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.touch_active_profile(text, text) TO authenticated, service_role;
