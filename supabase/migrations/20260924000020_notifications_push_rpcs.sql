-- ZivoConnect live backend reconciliation: Notification Center, preferences and push-token RPCs.

CREATE OR REPLACE FUNCTION public.get_notification_center(p_limit integer DEFAULT 50,p_offset integer DEFAULT 0)
RETURNS jsonb LANGUAGE plpgsql STABLE SET search_path TO 'public' AS $$
DECLARE pid uuid:=public.get_active_profile_id(); safe_limit integer:=LEAST(GREATEST(COALESCE(p_limit,50),1),100); safe_offset integer:=GREATEST(COALESCE(p_offset,0),0); result jsonb;
BEGIN
  SELECT jsonb_build_object(
    'unread_count',(SELECT count(*) FROM public.notifications n WHERE n.recipient_profile_id=pid AND n.deleted_at IS NULL AND n.read_at IS NULL),
    'items',COALESCE((SELECT jsonb_agg(to_jsonb(x) ORDER BY x.created_at DESC) FROM (
      SELECT n.id,n.category,n.title,n.body,n.priority,n.data,n.action_path,n.source_table,n.source_id,n.read_at,n.created_at
      FROM public.notifications n WHERE n.recipient_profile_id=pid AND n.deleted_at IS NULL
      ORDER BY n.created_at DESC LIMIT safe_limit OFFSET safe_offset
    ) x),'[]'::jsonb),'limit',safe_limit,'offset',safe_offset
  ) INTO result;
  RETURN result;
END; $$;

CREATE OR REPLACE FUNCTION public.mark_notification_read(p_notification_id uuid)
RETURNS jsonb LANGUAGE plpgsql SET search_path TO 'public' AS $$
DECLARE saved jsonb;
BEGIN
  UPDATE public.notifications SET read_at=COALESCE(read_at,now()),updated_at=now()
  WHERE id=p_notification_id AND recipient_profile_id=public.get_active_profile_id() AND deleted_at IS NULL
  RETURNING to_jsonb(public.notifications.*) INTO saved;
  IF saved IS NULL THEN RAISE EXCEPTION 'notification not found or not authorized'; END IF;
  RETURN saved;
END; $$;

CREATE OR REPLACE FUNCTION public.mark_all_notifications_read()
RETURNS integer LANGUAGE plpgsql SET search_path TO 'public' AS $$
DECLARE n integer;
BEGIN
  UPDATE public.notifications SET read_at=COALESCE(read_at,now()),updated_at=now()
  WHERE recipient_profile_id=public.get_active_profile_id() AND deleted_at IS NULL AND read_at IS NULL;
  GET DIAGNOSTICS n=ROW_COUNT;
  RETURN n;
END; $$;

CREATE OR REPLACE FUNCTION public.get_notification_preferences()
RETURNS jsonb LANGUAGE plpgsql SET search_path TO 'public' AS $$
DECLARE sid uuid:=public.get_active_school_id(); pid uuid:=public.get_active_profile_id(); prefs jsonb;
BEGIN
  SELECT preferences INTO prefs FROM public.notification_preferences WHERE profile_id=pid AND deleted_at IS NULL LIMIT 1;
  IF prefs IS NULL THEN
    prefs:='{"push":true,"finance":true,"messages":true,"academics":true,"transport":true,"attendance":true,"announcements":true}'::jsonb;
  END IF;
  RETURN jsonb_build_object('school_id',sid,'profile_id',pid,'preferences',prefs);
END; $$;

CREATE OR REPLACE FUNCTION public.update_notification_preferences(p_patch jsonb)
RETURNS jsonb LANGUAGE plpgsql SET search_path TO 'public' AS $$
DECLARE sid uuid:=public.get_active_school_id(); pid uuid:=public.get_active_profile_id(); allowed_keys text[]:=ARRAY['push','finance','messages','academics','transport','attendance','announcements']; bad_key text; saved jsonb;
BEGIN
  IF auth.uid() IS NULL OR sid IS NULL OR pid IS NULL THEN RAISE EXCEPTION 'authenticated active profile is required'; END IF;
  IF p_patch IS NULL OR jsonb_typeof(p_patch)<>'object' THEN RAISE EXCEPTION 'preferences patch must be a JSON object'; END IF;
  SELECT key INTO bad_key FROM jsonb_object_keys(p_patch) key WHERE NOT (key=ANY(allowed_keys)) LIMIT 1;
  IF bad_key IS NOT NULL THEN RAISE EXCEPTION 'unsupported notification preference: %',bad_key; END IF;
  IF EXISTS (SELECT 1 FROM jsonb_each(p_patch) WHERE jsonb_typeof(value)<>'boolean') THEN RAISE EXCEPTION 'notification preference values must be boolean'; END IF;
  INSERT INTO public.notification_preferences(school_id,profile_id,preferences,deleted_at)
  VALUES(sid,pid,'{"push":true,"finance":true,"messages":true,"academics":true,"transport":true,"attendance":true,"announcements":true}'::jsonb||p_patch,NULL)
  ON CONFLICT (profile_id) WHERE deleted_at IS NULL
  DO UPDATE SET school_id=excluded.school_id,preferences=public.notification_preferences.preferences||p_patch,updated_at=now(),deleted_at=NULL
  RETURNING jsonb_build_object('school_id',school_id,'profile_id',profile_id,'preferences',preferences) INTO saved;
  RETURN saved;
END; $$;

CREATE OR REPLACE FUNCTION public.register_push_token(p_token text,p_platform text)
RETURNS jsonb LANGUAGE plpgsql SET search_path TO 'public' AS $$
DECLARE sid uuid:=public.get_active_school_id(); pid uuid:=public.get_active_profile_id(); normalized_platform text:=lower(trim(p_platform)); saved jsonb;
BEGIN
  IF auth.uid() IS NULL OR sid IS NULL OR pid IS NULL THEN RAISE EXCEPTION 'authenticated active profile is required'; END IF;
  IF NULLIF(trim(p_token),'') IS NULL THEN RAISE EXCEPTION 'push token is required'; END IF;
  IF normalized_platform NOT IN ('android','ios','web','windows','macos','linux') THEN RAISE EXCEPTION 'unsupported push platform'; END IF;
  INSERT INTO public.push_tokens(school_id,profile_id,token,platform,deleted_at)
  VALUES(sid,pid,trim(p_token),normalized_platform,NULL)
  ON CONFLICT (token) WHERE deleted_at IS NULL
  DO UPDATE SET school_id=excluded.school_id,profile_id=excluded.profile_id,platform=excluded.platform,updated_at=now(),deleted_at=NULL
  RETURNING to_jsonb(public.push_tokens.*) INTO saved;
  RETURN saved;
END; $$;

CREATE OR REPLACE FUNCTION public.unregister_push_token(p_token text)
RETURNS boolean LANGUAGE plpgsql SET search_path TO 'public' AS $$
DECLARE pid uuid:=public.get_active_profile_id(); affected integer;
BEGIN
  UPDATE public.push_tokens SET deleted_at=now(),updated_at=now()
  WHERE token=trim(p_token) AND profile_id=pid AND deleted_at IS NULL;
  GET DIAGNOSTICS affected=ROW_COUNT;
  RETURN affected>0;
END; $$;
