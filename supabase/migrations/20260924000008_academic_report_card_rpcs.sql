-- ZivoConnect live backend reconciliation: academic/report-card RPCs.

CREATE OR REPLACE FUNCTION public.grade_letter(
  p_percentage numeric,
  p_curriculum text DEFAULT 'zimsec'
)
RETURNS text
LANGUAGE plpgsql
IMMUTABLE
SET search_path TO 'public'
AS $$
DECLARE
  c text := lower(COALESCE(NULLIF(trim(p_curriculum), ''), 'zimsec'));
BEGIN
  IF p_percentage IS NULL THEN RETURN NULL; END IF;

  IF c LIKE 'cambridge%' THEN
    RETURN CASE
      WHEN p_percentage >= 90 THEN 'A*'
      WHEN p_percentage >= 80 THEN 'A'
      WHEN p_percentage >= 70 THEN 'B'
      WHEN p_percentage >= 60 THEN 'C'
      WHEN p_percentage >= 50 THEN 'D'
      WHEN p_percentage >= 40 THEN 'E'
      WHEN p_percentage >= 30 THEN 'F'
      WHEN p_percentage >= 20 THEN 'G'
      ELSE 'U'
    END;
  END IF;

  RETURN CASE
    WHEN p_percentage >= 75 THEN 'A'
    WHEN p_percentage >= 65 THEN 'B'
    WHEN p_percentage >= 50 THEN 'C'
    WHEN p_percentage >= 40 THEN 'D'
    WHEN p_percentage >= 30 THEN 'E'
    ELSE 'U'
  END;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_gradebook_class_average(
  p_class_section_id uuid,
  p_subject_id uuid,
  p_term_id uuid
)
RETURNS numeric
LANGUAGE sql
STABLE
SET search_path TO 'public'
AS $$
WITH term_info AS (
  SELECT academic_year_id
  FROM public.grading_terms
  WHERE id = p_term_id AND deleted_at IS NULL
),
assessment_scope AS (
  SELECT a.id,a.max_points,
         COALESCE(
           a.weight,
           ac.weight / NULLIF(count(*) OVER (PARTITION BY a.category_id),0)
         ) AS effective_weight
  FROM public.assessments a
  JOIN public.assessment_categories ac ON ac.id=a.category_id AND ac.deleted_at IS NULL
  WHERE a.class_section_id=p_class_section_id
    AND a.subject_id=p_subject_id
    AND a.term_id=p_term_id
    AND a.deleted_at IS NULL
),
students AS (
  SELECT DISTINCT se.student_profile_id
  FROM public.student_enrollments se
  JOIN term_info ti ON ti.academic_year_id=se.academic_year_id
  WHERE se.class_section_id=p_class_section_id
    AND se.status='active'
    AND se.deleted_at IS NULL
),
student_avg AS (
  SELECT s.student_profile_id,
         CASE
           WHEN COALESCE(sum(a.effective_weight) FILTER (WHERE gr.id IS NOT NULL),0)>0
           THEN sum(((gr.points_obtained/NULLIF(a.max_points,0))*100)*a.effective_weight)
                  FILTER (WHERE gr.id IS NOT NULL)
                / sum(a.effective_weight) FILTER (WHERE gr.id IS NOT NULL)
           ELSE NULL
         END AS running_average
  FROM students s
  CROSS JOIN assessment_scope a
  LEFT JOIN public.grade_records gr
    ON gr.assessment_id=a.id
   AND gr.student_profile_id=s.student_profile_id
   AND gr.deleted_at IS NULL
  GROUP BY s.student_profile_id
)
SELECT round(avg(running_average),1)
FROM student_avg
WHERE running_average IS NOT NULL;
$$;

CREATE OR REPLACE FUNCTION public.get_gradebook_setup(
  p_class_section_id uuid,
  p_subject_id uuid,
  p_term_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SET search_path TO 'public'
AS $$
DECLARE
  role_name text:=public.get_active_role()::text;
  sid uuid:=public.get_active_school_id();
  result jsonb;
BEGIN
  IF role_name NOT IN ('school_admin','teacher','super_admin') THEN RAISE EXCEPTION 'not authorized'; END IF;

  WITH relevant_categories AS (
    SELECT DISTINCT ac.id,ac.name,ac.weight,ac.class_section_id,ac.subject_id,ac.term_id,
           CASE WHEN ac.class_section_id IS NULL THEN 'legacy_global' ELSE 'scoped' END scope_type
    FROM public.assessment_categories ac
    WHERE ac.school_id=sid AND ac.deleted_at IS NULL
      AND (
        (ac.class_section_id=p_class_section_id AND ac.subject_id=p_subject_id AND ac.term_id=p_term_id)
        OR EXISTS (
          SELECT 1 FROM public.assessments a
          WHERE a.category_id=ac.id
            AND a.class_section_id=p_class_section_id
            AND a.subject_id=p_subject_id
            AND a.term_id=p_term_id
            AND a.deleted_at IS NULL
        )
      )
  ), category_rows AS (
    SELECT rc.*,
           (SELECT count(*) FROM public.assessments a
            WHERE a.category_id=rc.id
              AND a.class_section_id=p_class_section_id
              AND a.subject_id=p_subject_id
              AND a.term_id=p_term_id
              AND a.deleted_at IS NULL) assessment_count
    FROM relevant_categories rc
  ), validation AS (
    SELECT count(*) category_count,COALESCE(sum(weight),0) total_weight FROM category_rows
  )
  SELECT jsonb_build_object(
    'class_section_id',p_class_section_id,
    'subject_id',p_subject_id,
    'term_id',p_term_id,
    'categories',COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
        'id',c.id,'name',c.name,'weight',c.weight,
        'weight_percent',round(c.weight*100,1),
        'assessment_count',c.assessment_count,'scope_type',c.scope_type
      ) ORDER BY c.name) FROM category_rows c
    ),'[]'::jsonb),
    'weight_validation',(
      SELECT jsonb_build_object(
        'category_count',category_count,
        'total_percent',round(total_weight*100,1),
        'is_valid',category_count>0 AND abs(total_weight-1)<=0.0001
      ) FROM validation
    ),
    'assessments',COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
        'id',a.id,'title',a.title,'category_id',a.category_id,
        'max_points',a.max_points,'weight',a.weight,
        'weight_percent',CASE WHEN a.weight IS NULL THEN NULL ELSE round(a.weight*100,1) END,
        'date_administered',a.date_administered
      ) ORDER BY a.date_administered,a.title)
      FROM public.assessments a
      WHERE a.class_section_id=p_class_section_id
        AND a.subject_id=p_subject_id
        AND a.term_id=p_term_id
        AND a.deleted_at IS NULL
    ),'[]'::jsonb)
  ) INTO result;

  RETURN result;
END;
$$;

CREATE OR REPLACE FUNCTION public.generate_student_report_card(
  p_student_profile_id uuid,
  p_term_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SET search_path TO 'public'
AS $$
DECLARE
  role_name text := public.get_active_role()::text;
  calc jsonb;
  saved_row jsonb;
  sid uuid;
  academic_year_id_value uuid;
  display_average numeric;
  display_grade text;
  attendance_rate_value numeric;
BEGIN
  IF role_name NOT IN ('school_admin','super_admin') THEN RAISE EXCEPTION 'not authorized'; END IF;

  calc := public.calculate_student_term_report(p_student_profile_id,p_term_id);
  sid := (calc ->> 'school_id')::uuid;
  academic_year_id_value := (calc ->> 'academic_year_id')::uuid;
  display_average := COALESCE(
    NULLIF(calc ->> 'final_average','')::numeric,
    NULLIF(calc ->> 'running_average','')::numeric
  );
  display_grade := calc ->> 'overall_grade';
  attendance_rate_value := NULLIF(calc #>> '{attendance,attendance_rate}','')::numeric;

  INSERT INTO public.report_cards(
    school_id,student_profile_id,academic_year_id,term_id,
    average_percentage,overall_grade,attendance_rate,status,summary
  )
  VALUES(
    sid,p_student_profile_id,academic_year_id_value,p_term_id,
    display_average,display_grade,attendance_rate_value,'draft',calc
  )
  ON CONFLICT (student_profile_id,academic_year_id,term_id)
  DO UPDATE SET
    average_percentage=EXCLUDED.average_percentage,
    overall_grade=EXCLUDED.overall_grade,
    attendance_rate=EXCLUDED.attendance_rate,
    summary=EXCLUDED.summary,
    status=CASE WHEN public.report_cards.status IN ('approved','published')
                THEN public.report_cards.status ELSE 'draft' END,
    updated_at=now()
  RETURNING to_jsonb(public.report_cards.*) INTO saved_row;

  RETURN saved_row;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_report_cards_overview(
  p_academic_year_id uuid,
  p_term_id uuid,
  p_class_section_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SET search_path TO 'public'
AS $$
DECLARE
  role_name text:=public.get_active_role()::text;
  sid uuid:=public.get_active_school_id();
  result jsonb;
BEGIN
  IF role_name NOT IN ('school_admin','teacher','registrar','super_admin') THEN RAISE EXCEPTION 'not authorized'; END IF;

  WITH students AS (
    SELECT p.id profile_id,p.first_name,p.last_name,p.avatar_url,sd.admission_number
    FROM public.student_enrollments se
    JOIN public.profiles p ON p.id=se.student_profile_id AND p.deleted_at IS NULL
    LEFT JOIN public.student_details sd ON sd.student_profile_id=p.id AND sd.deleted_at IS NULL
    WHERE se.school_id=sid
      AND se.academic_year_id=p_academic_year_id
      AND se.class_section_id=p_class_section_id
      AND se.status='active'
      AND se.deleted_at IS NULL
  ), rows AS (
    SELECT s.*,rc.id report_card_id,rc.average_percentage,rc.overall_grade,
           rc.attendance_rate,rc.teacher_comments,rc.status,
           rc.principal_approved,rc.approved_at,rc.published_at,rc.summary,
           CASE
             WHEN rc.id IS NULL THEN 'not_generated'
             WHEN COALESCE(NULLIF(trim(rc.teacher_comments),''),'')<>'' THEN 'ready'
             ELSE 'missing'
           END teacher_comment_status
    FROM students s
    LEFT JOIN public.report_cards rc
      ON rc.student_profile_id=s.profile_id
     AND rc.academic_year_id=p_academic_year_id
     AND rc.term_id=p_term_id
     AND rc.deleted_at IS NULL
  )
  SELECT jsonb_build_object(
    'academic_year_id',p_academic_year_id,
    'term_id',p_term_id,
    'class_section_id',p_class_section_id,
    'counts',jsonb_build_object(
      'students',(SELECT count(*) FROM rows),
      'not_generated',(SELECT count(*) FROM rows WHERE report_card_id IS NULL),
      'draft',(SELECT count(*) FROM rows WHERE status='draft'),
      'pending_approval',(SELECT count(*) FROM rows WHERE status='pending_approval'),
      'approved',(SELECT count(*) FROM rows WHERE status='approved'),
      'published',(SELECT count(*) FROM rows WHERE status='published')
    ),
    'students',COALESCE((SELECT jsonb_agg(to_jsonb(r) ORDER BY r.last_name,r.first_name) FROM rows r),'[]'::jsonb)
  ) INTO result;

  RETURN result;
END;
$$;

CREATE OR REPLACE FUNCTION public.set_report_card_status(p_report_card_id uuid,p_status text)
RETURNS jsonb
LANGUAGE plpgsql
SET search_path TO 'public'
AS $$
DECLARE
  role_name text:=public.get_active_role()::text;
  saved jsonb;
BEGIN
  IF role_name NOT IN ('school_admin','super_admin') THEN RAISE EXCEPTION 'not authorized'; END IF;
  IF p_status NOT IN ('draft','pending_approval','approved','published') THEN RAISE EXCEPTION 'invalid report card status'; END IF;

  UPDATE public.report_cards
  SET status=p_status,
      principal_approved=CASE WHEN p_status IN ('approved','published') THEN true ELSE false END,
      approved_at=CASE WHEN p_status IN ('draft','pending_approval') THEN NULL ELSE approved_at END,
      approved_by_profile_id=CASE WHEN p_status IN ('draft','pending_approval') THEN NULL ELSE approved_by_profile_id END,
      published_at=CASE WHEN p_status='published' THEN COALESCE(published_at,now()) ELSE NULL END,
      updated_at=now()
  WHERE id=p_report_card_id AND deleted_at IS NULL
  RETURNING to_jsonb(public.report_cards.*) INTO saved;

  IF saved IS NULL THEN RAISE EXCEPTION 'report card not found or not authorized'; END IF;
  RETURN saved;
END;
$$;

CREATE OR REPLACE FUNCTION public.bulk_publish_report_cards(
  p_academic_year_id uuid,
  p_term_id uuid,
  p_class_section_id uuid
)
RETURNS integer
LANGUAGE plpgsql
SET search_path TO 'public'
AS $$
DECLARE
  role_name text:=public.get_active_role()::text;
  n integer;
BEGIN
  IF role_name NOT IN ('school_admin','super_admin') THEN RAISE EXCEPTION 'not authorized'; END IF;

  UPDATE public.report_cards rc
     SET status='published',principal_approved=true,
         published_at=COALESCE(rc.published_at,now()),updated_at=now()
  WHERE rc.academic_year_id=p_academic_year_id
    AND rc.term_id=p_term_id
    AND rc.status='approved'
    AND rc.deleted_at IS NULL
    AND EXISTS (
      SELECT 1 FROM public.student_enrollments se
      WHERE se.student_profile_id=rc.student_profile_id
        AND se.academic_year_id=p_academic_year_id
        AND se.class_section_id=p_class_section_id
        AND se.status='active'
        AND se.deleted_at IS NULL
    );

  GET DIAGNOSTICS n=ROW_COUNT;
  RETURN n;
END;
$$;
