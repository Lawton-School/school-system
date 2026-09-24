-- ZivoConnect live backend reconciliation: Announcements and School Settings RPCs.

CREATE OR REPLACE FUNCTION public.save_announcement_draft(
  p_announcement_id uuid,
  p_title text,
  p_content text,
  p_target_role text,
  p_priority text,
  p_target_class_section_id uuid,
  p_attachment_urls jsonb
)
RETURNS jsonb LANGUAGE plpgsql SET search_path TO 'public' AS $$
DECLARE
  role_name text:=public.get_active_role()::text;
  sid uuid:=public.get_active_school_id();
  pid uuid:=public.get_active_profile_id();
  existing_author uuid;
  existing_school uuid;
  saved jsonb;
BEGIN
  IF role_name NOT IN ('school_admin','teacher','super_admin') THEN RAISE EXCEPTION 'not authorized'; END IF;
  IF NULLIF(trim(p_title),'') IS NULL OR NULLIF(trim(p_content),'') IS NULL THEN RAISE EXCEPTION 'title and content are required'; END IF;
  IF p_target_role NOT IN ('all','teachers','parents','students','staff','school_admins') THEN RAISE EXCEPTION 'invalid announcement audience'; END IF;
  IF p_priority NOT IN ('normal','high','urgent') THEN RAISE EXCEPTION 'invalid announcement priority'; END IF;
  IF p_target_class_section_id IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM public.class_sections cs
    WHERE cs.id=p_target_class_section_id AND cs.deleted_at IS NULL AND (role_name='super_admin' OR cs.school_id=sid)
  ) THEN RAISE EXCEPTION 'target class section not found or not authorized'; END IF;

  IF p_announcement_id IS NULL THEN
    INSERT INTO public.announcements(school_id,title,content,author_profile_id,target_role,status,priority,target_class_section_id,attachment_urls)
    VALUES(sid,trim(p_title),p_content,pid,p_target_role,'draft',p_priority,p_target_class_section_id,COALESCE(p_attachment_urls,'[]'::jsonb))
    RETURNING to_jsonb(public.announcements.*) INTO saved;
  ELSE
    SELECT author_profile_id,school_id INTO existing_author,existing_school
    FROM public.announcements WHERE id=p_announcement_id AND deleted_at IS NULL;
    IF existing_school IS NULL OR (role_name<>'super_admin' AND existing_school<>sid)
       OR (role_name='teacher' AND existing_author IS DISTINCT FROM pid) THEN
      RAISE EXCEPTION 'announcement not found or not authorized';
    END IF;
    UPDATE public.announcements SET title=trim(p_title),content=p_content,target_role=p_target_role,priority=p_priority,
      target_class_section_id=p_target_class_section_id,attachment_urls=COALESCE(p_attachment_urls,'[]'::jsonb),updated_at=now()
    WHERE id=p_announcement_id RETURNING to_jsonb(public.announcements.*) INTO saved;
  END IF;
  RETURN saved;
END; $$;

CREATE OR REPLACE FUNCTION public.set_announcement_status(
  p_announcement_id uuid,
  p_status text,
  p_scheduled_at timestamptz DEFAULT NULL,
  p_expires_at timestamptz DEFAULT NULL
)
RETURNS jsonb LANGUAGE plpgsql SET search_path TO 'public' AS $$
DECLARE role_name text:=public.get_active_role()::text; sid uuid:=public.get_active_school_id(); pid uuid:=public.get_active_profile_id(); existing_author uuid; existing_school uuid; saved jsonb;
BEGIN
  IF role_name NOT IN ('school_admin','teacher','super_admin') THEN RAISE EXCEPTION 'not authorized'; END IF;
  IF p_status NOT IN ('draft','scheduled','published','archived') THEN RAISE EXCEPTION 'invalid announcement status'; END IF;
  SELECT author_profile_id,school_id INTO existing_author,existing_school FROM public.announcements
  WHERE id=p_announcement_id AND deleted_at IS NULL FOR UPDATE;
  IF existing_school IS NULL OR (role_name<>'super_admin' AND existing_school<>sid)
     OR (role_name='teacher' AND existing_author IS DISTINCT FROM pid) THEN RAISE EXCEPTION 'announcement not found or not authorized'; END IF;
  IF p_status='scheduled' AND (p_scheduled_at IS NULL OR p_scheduled_at<=now()) THEN RAISE EXCEPTION 'scheduled announcements require a future scheduled_at'; END IF;
  IF p_expires_at IS NOT NULL AND p_expires_at<=COALESCE(CASE WHEN p_status='scheduled' THEN p_scheduled_at ELSE now() END,now()) THEN
    RAISE EXCEPTION 'expiry must be after publication/scheduled time';
  END IF;
  UPDATE public.announcements SET status=p_status,
    scheduled_at=CASE WHEN p_status='scheduled' THEN p_scheduled_at ELSE NULL END,
    published_at=CASE WHEN p_status='published' THEN COALESCE(published_at,now()) WHEN p_status IN ('draft','scheduled') THEN NULL ELSE published_at END,
    expires_at=p_expires_at,updated_at=now()
  WHERE id=p_announcement_id RETURNING to_jsonb(public.announcements.*) INTO saved;
  RETURN saved;
END; $$;

CREATE OR REPLACE FUNCTION public.get_school_configuration()
RETURNS jsonb LANGUAGE plpgsql STABLE SET search_path TO 'public' AS $$
DECLARE sid uuid:=public.get_active_school_id(); result jsonb;
BEGIN
  SELECT jsonb_build_object(
    'id',s.id,'name',s.name,'subdomain',s.subdomain,'status',s.status,'legal_name',s.legal_name,
    'registration_number',s.registration_number,'contact_email',s.contact_email,'contact_phone',s.contact_phone,
    'address_line1',s.address_line1,'address_line2',s.address_line2,'city',s.city,'province',s.province,
    'country_code',s.country_code,'timezone',s.timezone,'default_currency',s.default_currency,'logo_url',s.logo_url,
    'website_url',s.website_url,'plan_code',s.plan_code,'subscription_status',s.subscription_status,
    'trial_ends_at',s.trial_ends_at,'current_period_ends_at',s.current_period_ends_at,'settings',s.settings
  ) INTO result FROM public.schools s WHERE s.id=sid AND s.deleted_at IS NULL;
  IF result IS NULL THEN RAISE EXCEPTION 'school not found or not authorized'; END IF;
  RETURN result;
END; $$;

CREATE OR REPLACE FUNCTION public.patch_school_configuration(
  p_profile_patch jsonb DEFAULT '{}'::jsonb,
  p_settings_patch jsonb DEFAULT '{}'::jsonb
)
RETURNS jsonb LANGUAGE plpgsql SET search_path TO 'public' AS $$
DECLARE
  role_name text:=public.get_active_role()::text;
  sid uuid:=public.get_active_school_id();
  allowed_profile_keys text[]:=ARRAY['name','legal_name','registration_number','contact_email','contact_phone','address_line1','address_line2','city','province','country_code','timezone','default_currency','logo_url','website_url'];
  invalid_key text;
  saved jsonb;
BEGIN
  IF role_name NOT IN ('school_admin','super_admin') THEN RAISE EXCEPTION 'not authorized'; END IF;
  SELECT key INTO invalid_key FROM jsonb_object_keys(COALESCE(p_profile_patch,'{}'::jsonb)) key WHERE NOT (key=ANY(allowed_profile_keys)) LIMIT 1;
  IF invalid_key IS NOT NULL THEN RAISE EXCEPTION 'profile field % cannot be changed through school settings',invalid_key; END IF;
  IF COALESCE(p_settings_patch,'{}'::jsonb)::text ~* '\"[^\"]*(secret|password|service_role|private_key|client_secret|api_key|access_token|refresh_token)[^\"]*\"\s*:' THEN
    RAISE EXCEPTION 'secret credentials cannot be stored in client-readable school settings';
  END IF;
  IF p_profile_patch ? 'name' AND NULLIF(trim(p_profile_patch->>'name'),'') IS NULL THEN RAISE EXCEPTION 'school name cannot be empty'; END IF;
  IF p_profile_patch ? 'country_code' AND NULLIF(trim(p_profile_patch->>'country_code'),'') IS NULL THEN RAISE EXCEPTION 'country_code cannot be empty'; END IF;
  IF p_profile_patch ? 'timezone' AND NULLIF(trim(p_profile_patch->>'timezone'),'') IS NULL THEN RAISE EXCEPTION 'timezone cannot be empty'; END IF;
  IF p_profile_patch ? 'default_currency' AND NULLIF(trim(p_profile_patch->>'default_currency'),'') IS NULL THEN RAISE EXCEPTION 'default_currency cannot be empty'; END IF;
  UPDATE public.schools SET
    name=CASE WHEN p_profile_patch ? 'name' THEN trim(p_profile_patch->>'name') ELSE name END,
    legal_name=CASE WHEN p_profile_patch ? 'legal_name' THEN NULLIF(trim(p_profile_patch->>'legal_name'),'') ELSE legal_name END,
    registration_number=CASE WHEN p_profile_patch ? 'registration_number' THEN NULLIF(trim(p_profile_patch->>'registration_number'),'') ELSE registration_number END,
    contact_email=CASE WHEN p_profile_patch ? 'contact_email' THEN NULLIF(trim(p_profile_patch->>'contact_email'),'') ELSE contact_email END,
    contact_phone=CASE WHEN p_profile_patch ? 'contact_phone' THEN NULLIF(trim(p_profile_patch->>'contact_phone'),'') ELSE contact_phone END,
    address_line1=CASE WHEN p_profile_patch ? 'address_line1' THEN NULLIF(trim(p_profile_patch->>'address_line1'),'') ELSE address_line1 END,
    address_line2=CASE WHEN p_profile_patch ? 'address_line2' THEN NULLIF(trim(p_profile_patch->>'address_line2'),'') ELSE address_line2 END,
    city=CASE WHEN p_profile_patch ? 'city' THEN NULLIF(trim(p_profile_patch->>'city'),'') ELSE city END,
    province=CASE WHEN p_profile_patch ? 'province' THEN NULLIF(trim(p_profile_patch->>'province'),'') ELSE province END,
    country_code=CASE WHEN p_profile_patch ? 'country_code' THEN upper(trim(p_profile_patch->>'country_code')) ELSE country_code END,
    timezone=CASE WHEN p_profile_patch ? 'timezone' THEN trim(p_profile_patch->>'timezone') ELSE timezone END,
    default_currency=CASE WHEN p_profile_patch ? 'default_currency' THEN upper(trim(p_profile_patch->>'default_currency')) ELSE default_currency END,
    logo_url=CASE WHEN p_profile_patch ? 'logo_url' THEN NULLIF(trim(p_profile_patch->>'logo_url'),'') ELSE logo_url END,
    website_url=CASE WHEN p_profile_patch ? 'website_url' THEN NULLIF(trim(p_profile_patch->>'website_url'),'') ELSE website_url END,
    settings=COALESCE(settings,'{}'::jsonb)||COALESCE(p_settings_patch,'{}'::jsonb),updated_at=now()
  WHERE id=sid AND deleted_at IS NULL RETURNING to_jsonb(public.schools.*) INTO saved;
  IF saved IS NULL THEN RAISE EXCEPTION 'school not found or not authorized'; END IF;
  RETURN saved;
END; $$;
