-- ZivoConnect live backend reconciliation: authoritative Teacher Gradebook RPC.

CREATE OR REPLACE FUNCTION public.get_teacher_gradebook(
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
  role_name text := public.get_active_role()::text;
  academic_year_id_value uuid;
  term_sequence_value integer;
  previous_term_id uuid;
  current_class_average numeric;
  previous_class_average numeric;
  result jsonb;
BEGIN
  IF role_name NOT IN ('teacher','school_admin','super_admin') THEN
    RAISE EXCEPTION 'not authorized';
  END IF;

  SELECT gt.academic_year_id,gt.sequence
  INTO academic_year_id_value,term_sequence_value
  FROM public.grading_terms gt
  WHERE gt.id=p_term_id AND gt.deleted_at IS NULL;

  IF academic_year_id_value IS NULL THEN
    RAISE EXCEPTION 'term not found or not authorized';
  END IF;

  IF term_sequence_value IS NOT NULL THEN
    SELECT gt.id INTO previous_term_id
    FROM public.grading_terms gt
    WHERE gt.academic_year_id=academic_year_id_value
      AND gt.sequence<term_sequence_value
      AND gt.deleted_at IS NULL
    ORDER BY gt.sequence DESC
    LIMIT 1;
  END IF;

  current_class_average:=public.get_gradebook_class_average(p_class_section_id,p_subject_id,p_term_id);
  IF previous_term_id IS NOT NULL THEN
    previous_class_average:=public.get_gradebook_class_average(p_class_section_id,p_subject_id,previous_term_id);
  END IF;

  WITH assessment_base AS (
    SELECT a.id,a.title,a.max_points,a.date_administered,a.category_id,
           ac.name AS category_name,ac.weight AS category_weight,a.weight AS assessment_weight,
           count(*) OVER (PARTITION BY a.category_id) AS category_assessment_count
    FROM public.assessments a
    JOIN public.assessment_categories ac ON ac.id=a.category_id AND ac.deleted_at IS NULL
    WHERE a.class_section_id=p_class_section_id
      AND a.subject_id=p_subject_id
      AND a.term_id=p_term_id
      AND a.deleted_at IS NULL
  ),
  assessment_scope AS (
    SELECT ab.*,
           COALESCE(ab.assessment_weight,ab.category_weight/NULLIF(ab.category_assessment_count,0)) AS effective_weight,
           CASE WHEN ab.assessment_weight IS NOT NULL THEN 'assessment' ELSE 'category_fallback' END AS weight_source
    FROM assessment_base ab
  ),
  config AS (
    SELECT count(*) AS assessment_count,
           count(*) FILTER (WHERE assessment_weight IS NOT NULL) AS explicit_weight_count,
           COALESCE(sum(effective_weight),0) AS total_weight
    FROM assessment_scope
  ),
  enrolled_students AS (
    SELECT DISTINCT p.id AS student_profile_id,p.first_name,p.last_name,p.avatar_url,
           sd.admission_number,COALESCE(NULLIF(sd.curriculum,''),'zimsec') AS curriculum
    FROM public.student_enrollments se
    JOIN public.profiles p ON p.id=se.student_profile_id AND p.deleted_at IS NULL
    LEFT JOIN public.student_details sd ON sd.student_profile_id=p.id AND sd.deleted_at IS NULL
    WHERE se.class_section_id=p_class_section_id
      AND se.academic_year_id=academic_year_id_value
      AND se.status='active'
      AND se.deleted_at IS NULL
  ),
  grade_grid AS (
    SELECT es.student_profile_id,es.first_name,es.last_name,es.avatar_url,es.admission_number,es.curriculum,
           a.id AS assessment_id,a.title AS assessment_title,a.max_points,a.date_administered,a.category_name,
           a.effective_weight,gr.id AS grade_record_id,gr.points_obtained,gr.teacher_remarks,
           CASE WHEN gr.id IS NOT NULL AND a.max_points>0 THEN (gr.points_obtained/a.max_points)*100 ELSE NULL END AS percentage
    FROM enrolled_students es
    CROSS JOIN assessment_scope a
    LEFT JOIN public.grade_records gr
      ON gr.assessment_id=a.id
     AND gr.student_profile_id=es.student_profile_id
     AND gr.deleted_at IS NULL
  ),
  student_rollup AS (
    SELECT gg.student_profile_id,gg.first_name,gg.last_name,gg.avatar_url,gg.admission_number,gg.curriculum,
           count(*) FILTER (WHERE gg.grade_record_id IS NULL) AS missing_scores,
           COALESCE(sum(gg.effective_weight) FILTER (WHERE gg.grade_record_id IS NOT NULL),0) AS scored_weight,
           COALESCE(sum(gg.percentage*gg.effective_weight) FILTER (WHERE gg.grade_record_id IS NOT NULL),0) AS weighted_points,
           COALESCE((
             SELECT jsonb_agg(jsonb_build_object(
               'assessment_id',g2.assessment_id,
               'grade_record_id',g2.grade_record_id,
               'points_obtained',g2.points_obtained,
               'max_points',g2.max_points,
               'percentage',CASE WHEN g2.percentage IS NULL THEN NULL ELSE round(g2.percentage,1) END,
               'teacher_remarks',g2.teacher_remarks
             ) ORDER BY g2.date_administered,g2.assessment_title)
             FROM grade_grid g2
             WHERE g2.student_profile_id=gg.student_profile_id
           ),'[]'::jsonb) AS scores
    FROM grade_grid gg
    GROUP BY gg.student_profile_id,gg.first_name,gg.last_name,gg.avatar_url,gg.admission_number,gg.curriculum
  ),
  student_results AS (
    SELECT sr.*,
           CASE WHEN sr.scored_weight>0 THEN round(sr.weighted_points/sr.scored_weight,1) ELSE NULL END AS running_average,
           CASE
             WHEN cfg.assessment_count>0
              AND cfg.explicit_weight_count IN (0,cfg.assessment_count)
              AND abs(cfg.total_weight-1)<=0.0001
              AND sr.missing_scores=0
             THEN round(sr.weighted_points,1)
             ELSE NULL
           END AS final_average
    FROM student_rollup sr
    CROSS JOIN config cfg
  ),
  assessment_performance AS (
    SELECT a.id AS assessment_id,a.title,a.max_points,a.date_administered,a.category_name,a.weight_source,a.effective_weight,
           count(gg.grade_record_id) AS graded_students,
           round(avg(gg.percentage) FILTER (WHERE gg.grade_record_id IS NOT NULL),1) AS class_average
    FROM assessment_scope a
    LEFT JOIN grade_grid gg ON gg.assessment_id=a.id
    GROUP BY a.id,a.title,a.max_points,a.date_administered,a.category_name,a.weight_source,a.effective_weight
  )
  SELECT jsonb_build_object(
    'scope',jsonb_build_object(
      'class_section_id',p_class_section_id,
      'subject_id',p_subject_id,
      'term_id',p_term_id,
      'academic_year_id',academic_year_id_value,
      'previous_term_id',previous_term_id
    ),
    'configuration',(
      SELECT jsonb_build_object(
        'assessment_count',cfg.assessment_count,
        'weight_mode',CASE
          WHEN cfg.assessment_count=0 THEN 'empty'
          WHEN cfg.explicit_weight_count=0 THEN 'category_fallback'
          WHEN cfg.explicit_weight_count=cfg.assessment_count THEN 'assessment'
          ELSE 'mixed' END,
        'weights_total_percent',round(cfg.total_weight*100,1),
        'weights_valid',(
          cfg.assessment_count>0
          AND cfg.explicit_weight_count IN (0,cfg.assessment_count)
          AND abs(cfg.total_weight-1)<=0.0001
        )
      ) FROM config cfg
    ),
    'metrics',jsonb_build_object(
      'students',(SELECT count(*) FROM enrolled_students),
      'class_average',current_class_average,
      'previous_term_class_average',previous_class_average,
      'change_vs_previous_term',CASE
        WHEN current_class_average IS NOT NULL AND previous_class_average IS NOT NULL
        THEN round(current_class_average-previous_class_average,1)
        ELSE NULL END,
      'assessments',(SELECT assessment_count FROM config),
      'assessments_graded',(
        SELECT count(*) FROM assessment_performance ap
        WHERE ap.graded_students=(SELECT count(*) FROM enrolled_students)
          AND (SELECT count(*) FROM enrolled_students)>0
      ),
      'assessments_open',(
        SELECT count(*) FROM assessment_performance ap
        WHERE ap.graded_students<(SELECT count(*) FROM enrolled_students)
           OR (SELECT count(*) FROM enrolled_students)=0
      ),
      'missing_scores',COALESCE((SELECT sum(missing_scores) FROM student_results),0),
      'students_incomplete',(SELECT count(*) FROM student_results WHERE missing_scores>0)
    ),
    'assessments',COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
        'id',ap.assessment_id,
        'title',ap.title,
        'category',ap.category_name,
        'max_points',ap.max_points,
        'date_administered',ap.date_administered,
        'weight_percent',round(ap.effective_weight*100,1),
        'weight_source',ap.weight_source,
        'graded_students',ap.graded_students,
        'class_average',ap.class_average
      ) ORDER BY ap.date_administered,ap.title)
      FROM assessment_performance ap
    ),'[]'::jsonb),
    'students',COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
        'profile_id',sr.student_profile_id,
        'first_name',sr.first_name,
        'last_name',sr.last_name,
        'avatar_url',sr.avatar_url,
        'admission_number',sr.admission_number,
        'curriculum',sr.curriculum,
        'missing_scores',sr.missing_scores,
        'is_complete',sr.missing_scores=0,
        'running_average',sr.running_average,
        'final_average',sr.final_average,
        'grade',public.grade_letter(COALESCE(sr.final_average,sr.running_average),sr.curriculum),
        'scores',sr.scores
      ) ORDER BY sr.last_name,sr.first_name)
      FROM student_results sr
    ),'[]'::jsonb)
  ) INTO result;

  RETURN result;
END;
$$;
