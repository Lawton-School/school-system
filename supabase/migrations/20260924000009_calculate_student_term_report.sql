-- ZivoConnect live backend reconciliation: authoritative student term report calculation.

CREATE OR REPLACE FUNCTION public.calculate_student_term_report(
  p_student_profile_id uuid,
  p_term_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SET search_path TO 'public'
AS $$
DECLARE
  role_name text := public.get_active_role()::text;
  term_school_id uuid;
  academic_year_id_value uuid;
  term_name_value text;
  term_start date;
  term_end date;
  academic_start date;
  academic_end date;
  attendance_start date;
  attendance_end date;
  attendance_scope text;
  class_section_id_value uuid;
  curriculum_value text;
  result jsonb;
BEGIN
  IF role_name NOT IN ('teacher','school_admin','super_admin') THEN
    RAISE EXCEPTION 'not authorized';
  END IF;

  SELECT gt.school_id,gt.academic_year_id,gt.name,gt.start_date,gt.end_date,ay.start_date,ay.end_date
  INTO term_school_id,academic_year_id_value,term_name_value,term_start,term_end,academic_start,academic_end
  FROM public.grading_terms gt
  JOIN public.academic_years ay ON ay.id=gt.academic_year_id AND ay.deleted_at IS NULL
  WHERE gt.id=p_term_id AND gt.deleted_at IS NULL;

  IF academic_year_id_value IS NULL THEN
    RAISE EXCEPTION 'term not found or not authorized';
  END IF;

  SELECT se.class_section_id INTO class_section_id_value
  FROM public.student_enrollments se
  WHERE se.student_profile_id=p_student_profile_id
    AND se.academic_year_id=academic_year_id_value
    AND se.status='active'
    AND se.deleted_at IS NULL
  ORDER BY se.updated_at DESC
  LIMIT 1;

  IF class_section_id_value IS NULL THEN
    RAISE EXCEPTION 'active enrollment not found or not authorized';
  END IF;

  SELECT COALESCE(NULLIF(sd.curriculum,''),'zimsec') INTO curriculum_value
  FROM public.student_details sd
  WHERE sd.student_profile_id=p_student_profile_id AND sd.deleted_at IS NULL
  LIMIT 1;
  curriculum_value:=COALESCE(curriculum_value,'zimsec');

  IF term_start IS NOT NULL AND term_end IS NOT NULL THEN
    attendance_start:=term_start;
    attendance_end:=term_end;
    attendance_scope:='term';
  ELSE
    attendance_start:=academic_start;
    attendance_end:=academic_end;
    attendance_scope:='academic_year_fallback';
  END IF;

  WITH assessment_base AS (
    SELECT a.id,a.subject_id,s.name AS subject_name,a.title,a.max_points,a.category_id,
           ac.name AS category_name,ac.weight AS category_weight,a.weight AS assessment_weight,
           count(*) OVER (PARTITION BY a.subject_id,a.category_id) AS category_assessment_count
    FROM public.assessments a
    JOIN public.subjects s ON s.id=a.subject_id AND s.deleted_at IS NULL
    JOIN public.assessment_categories ac ON ac.id=a.category_id AND ac.deleted_at IS NULL
    WHERE a.class_section_id=class_section_id_value
      AND a.term_id=p_term_id
      AND a.deleted_at IS NULL
  ),
  assessment_scope AS (
    SELECT ab.*,
           COALESCE(ab.assessment_weight,ab.category_weight/NULLIF(ab.category_assessment_count,0)) AS effective_weight
    FROM assessment_base ab
  ),
  subject_config AS (
    SELECT subject_id,max(subject_name) AS subject_name,count(*) AS assessment_count,
           count(*) FILTER (WHERE assessment_weight IS NOT NULL) AS explicit_weight_count,
           COALESCE(sum(effective_weight),0) AS total_weight
    FROM assessment_scope
    GROUP BY subject_id
  ),
  score_rows AS (
    SELECT a.subject_id,a.subject_name,a.id AS assessment_id,a.title AS assessment_title,
           a.max_points,a.effective_weight,gr.id AS grade_record_id,gr.points_obtained,
           CASE WHEN gr.id IS NOT NULL AND a.max_points>0
                THEN (gr.points_obtained/a.max_points)*100 ELSE NULL END AS percentage
    FROM assessment_scope a
    LEFT JOIN public.grade_records gr
      ON gr.assessment_id=a.id
     AND gr.student_profile_id=p_student_profile_id
     AND gr.deleted_at IS NULL
  ),
  subject_rollup AS (
    SELECT sr.subject_id,max(sr.subject_name) AS subject_name,
           cfg.assessment_count,cfg.explicit_weight_count,cfg.total_weight,
           count(*) FILTER (WHERE sr.grade_record_id IS NULL) AS missing_scores,
           COALESCE(sum(sr.effective_weight) FILTER (WHERE sr.grade_record_id IS NOT NULL),0) AS scored_weight,
           COALESCE(sum(sr.percentage*sr.effective_weight) FILTER (WHERE sr.grade_record_id IS NOT NULL),0) AS weighted_points
    FROM score_rows sr
    JOIN subject_config cfg ON cfg.subject_id=sr.subject_id
    GROUP BY sr.subject_id,cfg.assessment_count,cfg.explicit_weight_count,cfg.total_weight
  ),
  subject_results AS (
    SELECT r.subject_id,r.subject_name,r.assessment_count,r.missing_scores,
           CASE
             WHEN r.assessment_count=0 THEN false
             WHEN r.explicit_weight_count NOT IN (0,r.assessment_count) THEN false
             WHEN abs(r.total_weight-1)>0.0001 THEN false
             ELSE true
           END AS weights_valid,
           round(r.total_weight*100,1) AS weights_total_percent,
           CASE WHEN r.scored_weight>0 THEN round(r.weighted_points/r.scored_weight,1) ELSE NULL END AS running_average,
           CASE
             WHEN r.assessment_count>0
              AND r.explicit_weight_count IN (0,r.assessment_count)
              AND abs(r.total_weight-1)<=0.0001
              AND r.missing_scores=0
             THEN round(r.weighted_points,1)
             ELSE NULL
           END AS final_average
    FROM subject_rollup r
  ),
  overall AS (
    SELECT count(*) AS subject_count,
           count(*) FILTER (WHERE weights_valid=false OR missing_scores>0) AS incomplete_subjects,
           COALESCE(sum(missing_scores),0) AS missing_scores,
           round(avg(running_average) FILTER (WHERE running_average IS NOT NULL),1) AS running_average,
           CASE
             WHEN count(*)>0
              AND count(*) FILTER (WHERE weights_valid=false OR missing_scores>0 OR final_average IS NULL)=0
             THEN round(avg(final_average),1)
             ELSE NULL
           END AS final_average
    FROM subject_results
  ),
  attendance AS (
    SELECT count(*) AS recorded_days,
           count(*) FILTER (WHERE da.status='present') AS present,
           count(*) FILTER (WHERE da.status='late') AS late,
           count(*) FILTER (WHERE da.status='absent') AS absent,
           count(*) FILTER (WHERE da.status='excused') AS excused,
           CASE WHEN count(*)=0 THEN 0
                ELSE round((count(*) FILTER (WHERE da.status IN ('present','late'))::numeric/count(*)::numeric)*100,1)
           END AS attendance_rate
    FROM public.daily_attendance da
    WHERE da.student_profile_id=p_student_profile_id
      AND da.deleted_at IS NULL
      AND da.date BETWEEN attendance_start AND attendance_end
  )
  SELECT jsonb_build_object(
    'student_profile_id',p_student_profile_id,
    'school_id',term_school_id,
    'academic_year_id',academic_year_id_value,
    'term_id',p_term_id,
    'term_name',term_name_value,
    'class_section_id',class_section_id_value,
    'curriculum',curriculum_value,
    'is_complete',(SELECT subject_count>0 AND incomplete_subjects=0 FROM overall),
    'running_average',(SELECT running_average FROM overall),
    'final_average',(SELECT final_average FROM overall),
    'overall_grade',public.grade_letter(COALESCE((SELECT final_average FROM overall),(SELECT running_average FROM overall)),curriculum_value),
    'missing_scores',(SELECT missing_scores FROM overall),
    'subjects',COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
        'subject_id',sr.subject_id,
        'subject',sr.subject_name,
        'assessment_count',sr.assessment_count,
        'missing_scores',sr.missing_scores,
        'weights_valid',sr.weights_valid,
        'weights_total_percent',sr.weights_total_percent,
        'running_average',sr.running_average,
        'final_average',sr.final_average,
        'grade',public.grade_letter(COALESCE(sr.final_average,sr.running_average),curriculum_value)
      ) ORDER BY sr.subject_name)
      FROM subject_results sr
    ),'[]'::jsonb),
    'attendance',(
      SELECT jsonb_build_object(
        'scope',attendance_scope,
        'start_date',attendance_start,
        'end_date',attendance_end,
        'recorded_days',recorded_days,
        'present',present,
        'late',late,
        'absent',absent,
        'excused',excused,
        'attendance_rate',attendance_rate
      ) FROM attendance
    )
  ) INTO result;

  RETURN result;
END;
$$;
