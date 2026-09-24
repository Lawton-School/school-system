-- ZivoConnect live backend reconciliation: Parent child summary, academics and fees RPCs.

CREATE OR REPLACE FUNCTION public.get_parent_child_summary(p_student_profile_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SET search_path TO 'public'
AS $$
DECLARE
  child_school uuid;
  allowed boolean;
  result jsonb;
BEGIN
  SELECT school_id INTO child_school
  FROM public.profiles
  WHERE id=p_student_profile_id AND role='student'::public.app_role AND deleted_at IS NULL;

  IF child_school IS NULL THEN RAISE EXCEPTION 'student not found or not authorized'; END IF;

  allowed := public.get_active_role()='super_admin'::public.app_role
    OR p_student_profile_id=public.get_active_profile_id()
    OR public.user_is_parent_of_student(p_student_profile_id,auth.uid());
  IF NOT allowed THEN RAISE EXCEPTION 'not authorized'; END IF;

  SELECT jsonb_build_object(
    'attendance_total',(SELECT count(*) FROM public.daily_attendance WHERE student_profile_id=p_student_profile_id AND deleted_at IS NULL),
    'attendance_present',(SELECT count(*) FROM public.daily_attendance WHERE student_profile_id=p_student_profile_id AND status='present' AND deleted_at IS NULL),
    'outstanding_fees',COALESCE((SELECT sum(total_amount-paid_amount) FROM public.invoices WHERE student_profile_id=p_student_profile_id AND status<>'paid' AND deleted_at IS NULL),0),
    'latest_report',(
      SELECT to_jsonb(r) FROM (
        SELECT id,academic_year_id,term_id,gpa,average_percentage,overall_grade,attendance_rate,status,published_at
        FROM public.report_cards
        WHERE student_profile_id=p_student_profile_id AND deleted_at IS NULL
        ORDER BY created_at DESC LIMIT 1
      ) r
    )
  ) INTO result;

  RETURN result;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_parent_academics(
  p_student_profile_id uuid,
  p_term_id uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SET search_path TO 'public'
AS $$
DECLARE
  role_name text:=public.get_active_role()::text;
  sid uuid;
  ay_id uuid;
  section_id uuid;
  current_term_id uuid:=p_term_id;
  previous_term_id uuid;
  current_report jsonb;
  previous_report jsonb;
  result jsonb;
BEGIN
  SELECT school_id INTO sid FROM public.profiles
  WHERE id=p_student_profile_id AND role='student'::public.app_role AND deleted_at IS NULL;
  IF sid IS NULL THEN RAISE EXCEPTION 'student not found or not authorized'; END IF;

  IF role_name='parent' AND NOT public.user_is_parent_of_student(p_student_profile_id,auth.uid()) THEN
    RAISE EXCEPTION 'not authorized';
  ELSIF role_name='student' AND p_student_profile_id<>public.get_active_profile_id() THEN
    RAISE EXCEPTION 'not authorized';
  ELSIF role_name NOT IN ('parent','student','school_admin','teacher','registrar','super_admin') THEN
    RAISE EXCEPTION 'not authorized';
  END IF;

  SELECT id INTO ay_id FROM public.academic_years
  WHERE school_id=sid AND is_current=true AND deleted_at IS NULL
  ORDER BY start_date DESC LIMIT 1;

  SELECT se.class_section_id INTO section_id
  FROM public.student_enrollments se
  WHERE se.student_profile_id=p_student_profile_id AND se.academic_year_id=ay_id
    AND se.status='active' AND se.deleted_at IS NULL
  ORDER BY se.updated_at DESC LIMIT 1;

  IF current_term_id IS NULL THEN
    SELECT gt.id INTO current_term_id
    FROM public.grading_terms gt
    WHERE gt.school_id=sid AND gt.academic_year_id=ay_id AND gt.deleted_at IS NULL
      AND gt.start_date IS NOT NULL AND gt.end_date IS NOT NULL
      AND current_date BETWEEN gt.start_date AND gt.end_date
    ORDER BY gt.sequence NULLS LAST LIMIT 1;

    IF current_term_id IS NULL THEN
      SELECT gt.id INTO current_term_id FROM public.grading_terms gt
      WHERE gt.school_id=sid AND gt.academic_year_id=ay_id AND gt.deleted_at IS NULL
      ORDER BY gt.sequence DESC NULLS LAST,gt.created_at DESC LIMIT 1;
    END IF;
  END IF;

  SELECT gt2.id INTO previous_term_id
  FROM public.grading_terms gt
  JOIN public.grading_terms gt2
    ON gt2.academic_year_id=gt.academic_year_id AND gt2.school_id=gt.school_id
   AND gt2.deleted_at IS NULL AND gt2.sequence<gt.sequence
  WHERE gt.id=current_term_id AND gt.deleted_at IS NULL
  ORDER BY gt2.sequence DESC LIMIT 1;

  SELECT to_jsonb(rc) INTO current_report FROM public.report_cards rc
  WHERE rc.student_profile_id=p_student_profile_id AND rc.academic_year_id=ay_id
    AND rc.term_id=current_term_id AND rc.status IN ('approved','published') AND rc.deleted_at IS NULL
  ORDER BY CASE WHEN rc.status='published' THEN 0 ELSE 1 END,COALESCE(rc.published_at,rc.updated_at) DESC
  LIMIT 1;

  IF previous_term_id IS NOT NULL THEN
    SELECT to_jsonb(rc) INTO previous_report FROM public.report_cards rc
    WHERE rc.student_profile_id=p_student_profile_id AND rc.academic_year_id=ay_id
      AND rc.term_id=previous_term_id AND rc.status IN ('approved','published') AND rc.deleted_at IS NULL
    ORDER BY CASE WHEN rc.status='published' THEN 0 ELSE 1 END,COALESCE(rc.published_at,rc.updated_at) DESC
    LIMIT 1;
  END IF;

  WITH current_subjects AS (
    SELECT elem FROM jsonb_array_elements(
      CASE WHEN jsonb_typeof(current_report->'summary'->'subjects')='array'
           THEN current_report->'summary'->'subjects' ELSE '[]'::jsonb END
    ) elem
  ), previous_subjects AS (
    SELECT elem FROM jsonb_array_elements(
      CASE WHEN jsonb_typeof(previous_report->'summary'->'subjects')='array'
           THEN previous_report->'summary'->'subjects' ELSE '[]'::jsonb END
    ) elem
  ), subjects AS (
    SELECT cs.elem->>'subject_id' subject_id,cs.elem->>'subject' subject,
           COALESCE(NULLIF(cs.elem->>'final_average','')::numeric,NULLIF(cs.elem->>'running_average','')::numeric) current_average,
           COALESCE(NULLIF(ps.elem->>'final_average','')::numeric,NULLIF(ps.elem->>'running_average','')::numeric) previous_average,
           (
             SELECT trim(concat_ws(' ',tp.first_name,tp.last_name))
             FROM public.class_teachers ct
             JOIN public.profiles tp ON tp.id=ct.teacher_profile_id AND tp.deleted_at IS NULL
             WHERE ct.class_section_id=section_id AND ct.subject_id::text=cs.elem->>'subject_id' AND ct.deleted_at IS NULL
             ORDER BY ct.is_primary_homeroom_teacher DESC,ct.created_at LIMIT 1
           ) teacher_name
    FROM current_subjects cs
    LEFT JOIN previous_subjects ps ON ps.elem->>'subject_id'=cs.elem->>'subject_id'
  ), recent_assessments AS (
    SELECT gr.id grade_record_id,a.id assessment_id,a.title assessment,s.name subject,a.date_administered,
           gr.points_obtained,a.max_points,
           CASE WHEN a.max_points>0 THEN round((gr.points_obtained/a.max_points)*100,1) ELSE NULL END percentage,
           gr.teacher_remarks,gr.updated_at
    FROM public.grade_records gr
    JOIN public.assessments a ON a.id=gr.assessment_id AND a.deleted_at IS NULL
    JOIN public.subjects s ON s.id=a.subject_id AND s.deleted_at IS NULL
    WHERE gr.student_profile_id=p_student_profile_id AND gr.deleted_at IS NULL
      AND (current_term_id IS NULL OR a.term_id=current_term_id)
    ORDER BY a.date_administered DESC,gr.updated_at DESC
  )
  SELECT jsonb_build_object(
    'student_profile_id',p_student_profile_id,'academic_year_id',ay_id,
    'term_id',current_term_id,'previous_term_id',previous_term_id,
    'current_average',NULLIF(current_report->>'average_percentage','')::numeric,
    'overall_grade',current_report->>'overall_grade',
    'attendance_rate',NULLIF(current_report->>'attendance_rate','')::numeric,
    'best_subject',(
      SELECT to_jsonb(x) FROM (
        SELECT subject,round(current_average,1) average FROM subjects
        WHERE current_average IS NOT NULL ORDER BY current_average DESC LIMIT 1
      ) x
    ),
    'assessment_count',(SELECT count(*) FROM recent_assessments),
    'assessments_added_this_month',(SELECT count(*) FROM recent_assessments WHERE date_administered>=date_trunc('month',current_date)::date),
    'report_card_count',(SELECT count(*) FROM public.report_cards rc WHERE rc.student_profile_id=p_student_profile_id AND rc.deleted_at IS NULL AND rc.status='published'),
    'subjects',COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
        'subject_id',s.subject_id,'subject',s.subject,'teacher',s.teacher_name,
        'average',CASE WHEN s.current_average IS NULL THEN NULL ELSE round(s.current_average,1) END,
        'previous_average',CASE WHEN s.previous_average IS NULL THEN NULL ELSE round(s.previous_average,1) END,
        'trend',CASE WHEN s.current_average IS NOT NULL AND s.previous_average IS NOT NULL THEN round(s.current_average-s.previous_average,1) ELSE NULL END
      ) ORDER BY s.current_average DESC NULLS LAST,s.subject) FROM subjects s
    ),'[]'::jsonb),
    'latest_report_card',current_report,
    'recent_assessments',COALESCE((
      SELECT jsonb_agg(to_jsonb(r) ORDER BY r.date_administered DESC,r.updated_at DESC)
      FROM (SELECT * FROM recent_assessments LIMIT 10) r
    ),'[]'::jsonb)
  ) INTO result;

  RETURN result;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_parent_fees(
  p_student_profile_id uuid,
  p_academic_year_id uuid DEFAULT NULL,
  p_term_id uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SET search_path TO 'public'
AS $$
DECLARE
  role_name text:=public.get_active_role()::text;
  sid uuid;
  ay_id uuid:=p_academic_year_id;
  school_settings jsonb;
  result jsonb;
BEGIN
  SELECT school_id INTO sid FROM public.profiles
  WHERE id=p_student_profile_id AND role='student'::public.app_role AND deleted_at IS NULL;
  IF sid IS NULL THEN RAISE EXCEPTION 'student not found or not authorized'; END IF;

  IF role_name='parent' AND NOT public.user_is_parent_of_student(p_student_profile_id,auth.uid()) THEN
    RAISE EXCEPTION 'not authorized';
  ELSIF role_name='student' AND p_student_profile_id<>public.get_active_profile_id() THEN
    RAISE EXCEPTION 'not authorized';
  ELSIF role_name NOT IN ('parent','student','school_admin','finance_manager','registrar','super_admin') THEN
    RAISE EXCEPTION 'not authorized';
  END IF;

  IF ay_id IS NULL THEN
    SELECT id INTO ay_id FROM public.academic_years
    WHERE school_id=sid AND is_current=true AND deleted_at IS NULL
    ORDER BY start_date DESC LIMIT 1;
  END IF;

  SELECT settings INTO school_settings FROM public.schools WHERE id=sid AND deleted_at IS NULL;

  WITH scoped_invoices AS (
    SELECT i.id,i.invoice_number,i.currency,i.issued_at,i.due_date,i.total_amount,i.paid_amount,
           round(i.total_amount-i.paid_amount,2) balance,i.status,i.fee_structure_id,fs.name fee_structure,fs.term_id
    FROM public.invoices i
    LEFT JOIN public.fee_structures fs ON fs.id=i.fee_structure_id AND fs.deleted_at IS NULL
    WHERE i.student_profile_id=p_student_profile_id AND i.academic_year_id=ay_id AND i.deleted_at IS NULL
      AND (p_term_id IS NULL OR fs.term_id=p_term_id)
  ), totals AS (
    SELECT currency,round(sum(total_amount),2) total_invoiced,round(sum(paid_amount),2) paid,
           round(sum(total_amount-paid_amount),2) outstanding,
           round(COALESCE(sum(total_amount-paid_amount) FILTER (WHERE due_date<current_date AND status<>'paid'),0),2) overdue,
           CASE WHEN sum(total_amount)>0 THEN round((sum(paid_amount)/sum(total_amount))*100,1) ELSE 0 END settled_percent,
           min(due_date) FILTER (WHERE due_date>=current_date AND status<>'paid') next_due_date
    FROM scoped_invoices GROUP BY currency
  ), history AS (
    SELECT p.id payment_id,p.invoice_id,p.amount,p.currency,p.payment_method,p.provider,
           COALESCE(p.provider_reference,p.transaction_reference) reference,p.status,p.paid_at,p.receipt_url,i.invoice_number
    FROM public.payments p
    JOIN public.invoices i ON i.id=p.invoice_id AND i.student_profile_id=p_student_profile_id AND i.deleted_at IS NULL
    WHERE p.deleted_at IS NULL ORDER BY p.paid_at DESC LIMIT 50
  )
  SELECT jsonb_build_object(
    'student_profile_id',p_student_profile_id,'academic_year_id',ay_id,'term_id',p_term_id,
    'totals',COALESCE((SELECT jsonb_agg(to_jsonb(t) ORDER BY t.currency) FROM totals t),'[]'::jsonb),
    'invoices',COALESCE((SELECT jsonb_agg(to_jsonb(i) ORDER BY i.due_date DESC,i.issued_at DESC) FROM scoped_invoices i),'[]'::jsonb),
    'payment_history',COALESCE((SELECT jsonb_agg(to_jsonb(h) ORDER BY h.paid_at DESC) FROM history h),'[]'::jsonb),
    'payment_methods',CASE WHEN jsonb_typeof(school_settings->'payment_methods')='array' THEN school_settings->'payment_methods' ELSE '[]'::jsonb END,
    'data_quality',jsonb_build_object(
      'term_filter_excludes_invoices_without_fee_structure',p_term_id IS NOT NULL,
      'unscoped_invoice_count',(
        SELECT count(*) FROM public.invoices i
        WHERE i.student_profile_id=p_student_profile_id AND i.academic_year_id=ay_id
          AND i.deleted_at IS NULL AND i.fee_structure_id IS NULL
      )
    )
  ) INTO result;

  RETURN result;
END;
$$;
