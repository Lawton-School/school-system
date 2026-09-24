-- ZivoConnect live backend reconciliation: Super Admin RPCs.

CREATE OR REPLACE FUNCTION public.get_super_admin_platform_metrics()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE role_name text:=public.get_active_role()::text; result jsonb;
BEGIN
  IF role_name<>'super_admin' THEN RAISE EXCEPTION 'not authorized'; END IF;
  WITH school_rollup AS (
    SELECT s.id,s.name,s.subdomain,s.city,s.country_code,s.plan_code,s.status,s.subscription_status,s.trial_ends_at,s.current_period_ends_at,s.created_at,
           count(p.id) FILTER (WHERE p.deleted_at IS NULL) users_total,
           count(p.id) FILTER (WHERE p.deleted_at IS NULL AND p.role='student'::public.app_role) students,
           count(p.id) FILTER (WHERE p.deleted_at IS NULL AND p.role='teacher'::public.app_role) teachers,
           count(DISTINCT pa.profile_id) FILTER (WHERE pa.deleted_at IS NULL AND pa.last_active_at>=now()-interval '30 days') monthly_active_users,
           max(pa.last_active_at) FILTER (WHERE pa.deleted_at IS NULL) last_activity_at
    FROM public.schools s
    LEFT JOIN public.profiles p ON p.school_id=s.id
    LEFT JOIN public.profile_activity pa ON pa.school_id=s.id
    WHERE s.deleted_at IS NULL GROUP BY s.id
  )
  SELECT jsonb_build_object(
    'schools_total',(SELECT count(*) FROM school_rollup),
    'schools_active',(SELECT count(*) FROM school_rollup WHERE status='active'),
    'schools_trial',(SELECT count(*) FROM school_rollup WHERE subscription_status='trial'),
    'schools_past_due',(SELECT count(*) FROM school_rollup WHERE subscription_status='past_due'),
    'schools_suspended',(SELECT count(*) FROM school_rollup WHERE status='suspended' OR subscription_status='suspended'),
    'users_total',(SELECT COALESCE(sum(users_total),0) FROM school_rollup),
    'students_total',(SELECT COALESCE(sum(students),0) FROM school_rollup),
    'teachers_total',(SELECT COALESCE(sum(teachers),0) FROM school_rollup),
    'monthly_active_users',(SELECT count(DISTINCT profile_id) FROM public.profile_activity WHERE deleted_at IS NULL AND last_active_at>=now()-interval '30 days'),
    'active_last_24h',(SELECT count(DISTINCT profile_id) FROM public.profile_activity WHERE deleted_at IS NULL AND last_active_at>=now()-interval '24 hours'),
    'new_schools_30d',(SELECT count(*) FROM school_rollup WHERE created_at>=now()-interval '30 days'),
    'subscription_mix',jsonb_build_object(
      'trial',(SELECT count(*) FROM school_rollup WHERE subscription_status='trial'),
      'active',(SELECT count(*) FROM school_rollup WHERE subscription_status='active'),
      'past_due',(SELECT count(*) FROM school_rollup WHERE subscription_status='past_due'),
      'suspended',(SELECT count(*) FROM school_rollup WHERE subscription_status='suspended')
    ),
    'plan_mix',COALESCE((SELECT jsonb_agg(jsonb_build_object('plan_code',plan_code,'schools',cnt) ORDER BY cnt DESC)
      FROM (SELECT plan_code,count(*) cnt FROM school_rollup GROUP BY plan_code) x),'[]'::jsonb)
  ) INTO result;
  RETURN result;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_super_admin_schools_directory()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE role_name text:=public.get_active_role()::text; result jsonb;
BEGIN
  IF role_name<>'super_admin' THEN RAISE EXCEPTION 'not authorized'; END IF;
  WITH ay AS (
    SELECT DISTINCT ON (school_id) school_id,id academic_year_id,name academic_year
    FROM public.academic_years WHERE deleted_at IS NULL ORDER BY school_id,is_current DESC,start_date DESC
  ), rows AS (
    SELECT s.id school_id,s.name,s.subdomain,s.city,s.province,s.country_code,s.logo_url,s.contact_email,s.contact_phone,s.plan_code,
           s.status,s.subscription_status,s.trial_ends_at,s.current_period_ends_at,s.created_at,ay.academic_year_id,ay.academic_year,
           (SELECT count(*) FROM public.profiles p WHERE p.school_id=s.id AND p.deleted_at IS NULL) users_total,
           (SELECT count(*) FROM public.profiles p WHERE p.school_id=s.id AND p.role='student'::public.app_role AND p.deleted_at IS NULL) students,
           (SELECT count(*) FROM public.profiles p WHERE p.school_id=s.id AND p.role='teacher'::public.app_role AND p.deleted_at IS NULL) teachers,
           (SELECT count(*) FROM public.class_sections cs JOIN public.classes c ON c.id=cs.class_id AND c.deleted_at IS NULL
            WHERE cs.school_id=s.id AND cs.deleted_at IS NULL AND (ay.academic_year_id IS NULL OR c.academic_year_id=ay.academic_year_id)) class_sections,
           (SELECT count(DISTINCT pa.profile_id) FROM public.profile_activity pa WHERE pa.school_id=s.id AND pa.deleted_at IS NULL AND pa.last_active_at>=now()-interval '30 days') monthly_active_users,
           (SELECT max(pa.last_active_at) FROM public.profile_activity pa WHERE pa.school_id=s.id AND pa.deleted_at IS NULL) last_activity_at,
           (SELECT count(*) FROM public.invoices i WHERE i.school_id=s.id AND i.deleted_at IS NULL AND (ay.academic_year_id IS NULL OR i.academic_year_id=ay.academic_year_id)) invoices_current_year,
           (SELECT count(*) FROM public.payments p WHERE p.school_id=s.id AND p.deleted_at IS NULL AND p.paid_at>=now()-interval '30 days') payments_30d,
           (SELECT count(*) FROM public.activity_events ae WHERE ae.school_id=s.id AND ae.deleted_at IS NULL AND ae.occurred_at>=now()-interval '7 days') activity_events_7d
    FROM public.schools s LEFT JOIN ay ON ay.school_id=s.id WHERE s.deleted_at IS NULL
  )
  SELECT jsonb_build_object('schools',COALESCE((SELECT jsonb_agg(to_jsonb(r) ORDER BY r.name) FROM rows r),'[]'::jsonb)) INTO result;
  RETURN result;
END;
$$;

CREATE OR REPLACE FUNCTION public.set_school_operational_status(p_school_id uuid,p_status text)
RETURNS jsonb LANGUAGE plpgsql SET search_path TO 'public' AS $$
DECLARE saved jsonb;
BEGIN
  IF public.get_active_role()::text<>'super_admin' THEN RAISE EXCEPTION 'not authorized'; END IF;
  IF p_status NOT IN ('active','suspended') THEN RAISE EXCEPTION 'invalid school status'; END IF;
  UPDATE public.schools SET status=p_status,updated_at=now()
  WHERE id=p_school_id AND deleted_at IS NULL RETURNING to_jsonb(public.schools.*) INTO saved;
  IF saved IS NULL THEN RAISE EXCEPTION 'school not found'; END IF;
  RETURN saved;
END; $$;

CREATE OR REPLACE FUNCTION public.set_school_subscription_status(
  p_school_id uuid,
  p_subscription_status text,
  p_plan_code text DEFAULT NULL,
  p_period_end timestamptz DEFAULT NULL
)
RETURNS jsonb LANGUAGE plpgsql SET search_path TO 'public' AS $$
DECLARE saved jsonb;
BEGIN
  IF public.get_active_role()::text<>'super_admin' THEN RAISE EXCEPTION 'not authorized'; END IF;
  IF p_subscription_status NOT IN ('trial','active','past_due','suspended','cancelled') THEN RAISE EXCEPTION 'invalid subscription status'; END IF;
  IF p_plan_code IS NOT NULL AND NULLIF(trim(p_plan_code),'') IS NULL THEN RAISE EXCEPTION 'plan code cannot be empty'; END IF;
  UPDATE public.schools SET subscription_status=p_subscription_status,
    plan_code=COALESCE(NULLIF(trim(p_plan_code),''),plan_code),
    current_period_ends_at=CASE WHEN p_period_end IS NOT NULL THEN p_period_end ELSE current_period_ends_at END,
    updated_at=now()
  WHERE id=p_school_id AND deleted_at IS NULL RETURNING to_jsonb(public.schools.*) INTO saved;
  IF saved IS NULL THEN RAISE EXCEPTION 'school not found'; END IF;
  RETURN saved;
END; $$;
