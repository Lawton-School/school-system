-- Family & Guardians management + module-level parent permission enforcement.
CREATE UNIQUE INDEX IF NOT EXISTS uq_user_relationships_one_primary_guardian
ON public.user_relationships(student_id)
WHERE is_primary_guardian AND deleted_at IS NULL AND status IN ('verified','active');

CREATE OR REPLACE FUNCTION public.get_student_guardians(p_student_profile_id uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SET search_path='public' AS $$
DECLARE sid uuid; role_name text:=public.get_active_role()::text; result jsonb;
BEGIN
 SELECT school_id INTO sid FROM public.profiles WHERE id=p_student_profile_id AND role='student'::public.app_role AND deleted_at IS NULL;
 IF sid IS NULL OR sid<>public.get_active_school_id() THEN RAISE EXCEPTION 'student not found or not authorized'; END IF;
 IF role_name NOT IN ('school_admin','registrar','super_admin') AND NOT EXISTS(
   SELECT 1 FROM public.user_relationships ur WHERE ur.student_id=p_student_profile_id
   AND ur.parent_id=public.get_active_profile_id() AND ur.is_primary_guardian AND ur.deleted_at IS NULL
   AND ur.status IN ('verified','active')
 ) THEN RAISE EXCEPTION 'not authorized'; END IF;
 SELECT coalesce(jsonb_agg(jsonb_build_object(
   'relationship_id',ur.id,'parent_id',ur.parent_id,'parent_name',trim(concat_ws(' ',p.first_name,p.last_name)),
   'relationship_type',ur.relationship_type,'status',ur.status,'is_primary_guardian',ur.is_primary_guardian,
   'is_legal_guardian',ur.is_legal_guardian,'lives_with_student',ur.lives_with_student,
   'valid_from',ur.valid_from,'valid_until',ur.valid_until,
   'permissions',jsonb_build_object('academics',gp.can_view_academics,'attendance',gp.can_view_attendance,
   'behaviour',gp.can_view_behaviour,'documents',gp.can_view_documents,'message_teachers',gp.can_message_teachers,
   'school_messages',gp.receives_school_messages,'attendance_alerts',gp.receives_attendance_alerts,
   'financially_responsible',gp.is_financially_responsible,'invoices',gp.receives_invoices,'payments',gp.can_make_payments,
   'emergency_contact',gp.is_emergency_contact,'pickup_authorized',gp.is_pickup_authorized,'portal',gp.portal_access)
 ) ORDER BY ur.is_primary_guardian DESC,p.first_name,p.last_name),'[]'::jsonb) INTO result
 FROM public.user_relationships ur JOIN public.profiles p ON p.id=ur.parent_id AND p.deleted_at IS NULL
 LEFT JOIN public.student_guardian_permissions gp ON gp.relationship_id=ur.id AND gp.deleted_at IS NULL
 WHERE ur.student_id=p_student_profile_id AND ur.school_id=sid AND ur.deleted_at IS NULL;
 RETURN result;
END $$;

CREATE OR REPLACE FUNCTION public.set_primary_guardian(p_relationship_id uuid)
RETURNS void LANGUAGE plpgsql SET search_path='public' AS $$
DECLARE rel public.user_relationships%rowtype; role_name text:=public.get_active_role()::text;
BEGIN
 IF role_name NOT IN ('school_admin','registrar','super_admin') THEN RAISE EXCEPTION 'not authorized'; END IF;
 SELECT * INTO rel FROM public.user_relationships WHERE id=p_relationship_id AND deleted_at IS NULL;
 IF rel.id IS NULL OR rel.school_id<>public.get_active_school_id() THEN RAISE EXCEPTION 'relationship not found'; END IF;
 UPDATE public.user_relationships SET is_primary_guardian=false,updated_at=now()
 WHERE student_id=rel.student_id AND school_id=rel.school_id AND deleted_at IS NULL AND id<>rel.id AND is_primary_guardian;
 UPDATE public.user_relationships SET is_primary_guardian=true,status='active',updated_at=now() WHERE id=rel.id;
END $$;

CREATE OR REPLACE FUNCTION public.update_guardian_permissions(p_relationship_id uuid,p_permissions jsonb)
RETURNS jsonb LANGUAGE plpgsql SET search_path='public' AS $$
DECLARE rel public.user_relationships%rowtype; role_name text:=public.get_active_role()::text; actor_primary boolean:=false; result jsonb;
BEGIN
 SELECT * INTO rel FROM public.user_relationships WHERE id=p_relationship_id AND deleted_at IS NULL;
 IF rel.id IS NULL OR rel.school_id<>public.get_active_school_id() THEN RAISE EXCEPTION 'relationship not found'; END IF;
 actor_primary:=EXISTS(SELECT 1 FROM public.user_relationships ur WHERE ur.student_id=rel.student_id
   AND ur.parent_id=public.get_active_profile_id() AND ur.school_id=rel.school_id AND ur.is_primary_guardian
   AND ur.deleted_at IS NULL AND ur.status IN ('verified','active'));
 IF role_name NOT IN ('school_admin','registrar','super_admin') AND NOT actor_primary THEN RAISE EXCEPTION 'not authorized'; END IF;
 IF actor_primary AND rel.is_primary_guardian THEN RAISE EXCEPTION 'primary guardian cannot change own permissions'; END IF;
 INSERT INTO public.student_guardian_permissions(school_id,relationship_id) VALUES(rel.school_id,rel.id)
 ON CONFLICT (relationship_id) WHERE deleted_at IS NULL DO NOTHING;
 UPDATE public.student_guardian_permissions gp SET
  can_view_academics=coalesce((p_permissions->>'academics')::boolean,gp.can_view_academics),
  can_view_attendance=coalesce((p_permissions->>'attendance')::boolean,gp.can_view_attendance),
  can_view_behaviour=coalesce((p_permissions->>'behaviour')::boolean,gp.can_view_behaviour),
  can_view_documents=coalesce((p_permissions->>'documents')::boolean,gp.can_view_documents),
  can_message_teachers=coalesce((p_permissions->>'message_teachers')::boolean,gp.can_message_teachers),
  receives_school_messages=coalesce((p_permissions->>'school_messages')::boolean,gp.receives_school_messages),
  receives_attendance_alerts=coalesce((p_permissions->>'attendance_alerts')::boolean,gp.receives_attendance_alerts),
  is_financially_responsible=coalesce((p_permissions->>'financially_responsible')::boolean,gp.is_financially_responsible),
  receives_invoices=coalesce((p_permissions->>'invoices')::boolean,gp.receives_invoices),
  can_make_payments=coalesce((p_permissions->>'payments')::boolean,gp.can_make_payments),
  is_emergency_contact=coalesce((p_permissions->>'emergency_contact')::boolean,gp.is_emergency_contact),
  is_pickup_authorized=coalesce((p_permissions->>'pickup_authorized')::boolean,gp.is_pickup_authorized),
  portal_access=coalesce((p_permissions->>'portal')::boolean,gp.portal_access),updated_at=now()
 WHERE gp.relationship_id=rel.id AND gp.deleted_at IS NULL
 RETURNING jsonb_build_object('relationship_id',gp.relationship_id,'academics',gp.can_view_academics,
 'attendance',gp.can_view_attendance,'behaviour',gp.can_view_behaviour,'documents',gp.can_view_documents,
 'message_teachers',gp.can_message_teachers,'school_messages',gp.receives_school_messages,
 'attendance_alerts',gp.receives_attendance_alerts,'financially_responsible',gp.is_financially_responsible,
 'invoices',gp.receives_invoices,'payments',gp.can_make_payments,'emergency_contact',gp.is_emergency_contact,
 'pickup_authorized',gp.is_pickup_authorized,'portal',gp.portal_access) INTO result;
 RETURN result;
END $$;

CREATE OR REPLACE FUNCTION public.parent_can_access_module(p_student_profile_id uuid,p_module text)
RETURNS boolean LANGUAGE sql STABLE SET search_path='public' AS $$
 SELECT CASE WHEN public.get_active_role()::text='parent'
 THEN public.parent_has_student_permission(public.get_active_profile_id(),p_student_profile_id,p_module) ELSE true END;
$$;

REVOKE ALL ON FUNCTION public.get_student_guardians(uuid) FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.set_primary_guardian(uuid) FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.update_guardian_permissions(uuid,jsonb) FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.parent_can_access_module(uuid,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.get_student_guardians(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.set_primary_guardian(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.update_guardian_permissions(uuid,jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.parent_can_access_module(uuid,text) TO authenticated;
