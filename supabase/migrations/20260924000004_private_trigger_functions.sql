-- ZivoConnect live backend reconciliation: private trigger helpers

CREATE SCHEMA IF NOT EXISTS private;
REVOKE ALL ON SCHEMA private FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION private.activity_from_attendance()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'private'
AS $$
DECLARE
  actor_id uuid;
  status_label text;
BEGIN
  IF TG_OP = 'DELETE' THEN
    UPDATE public.activity_events
       SET deleted_at = now(), updated_at = now()
     WHERE source_table = 'daily_attendance'
       AND source_id = OLD.id
       AND event_type = 'attendance_marked'
       AND deleted_at IS NULL;
    RETURN OLD;
  END IF;

  IF NEW.deleted_at IS NOT NULL THEN
    UPDATE public.activity_events
       SET deleted_at = now(), updated_at = now()
     WHERE source_table = 'daily_attendance'
       AND source_id = NEW.id
       AND event_type = 'attendance_marked'
       AND deleted_at IS NULL;
    RETURN NEW;
  END IF;

  actor_id := public.get_active_profile_id();
  status_label := initcap(NEW.status);

  INSERT INTO public.activity_events (
    school_id, actor_profile_id, subject_profile_id,
    event_type, title, description,
    source_table, source_id, metadata, occurred_at
  )
  VALUES (
    NEW.school_id,
    actor_id,
    NEW.student_profile_id,
    'attendance_marked',
    format('Attendance marked — %s', status_label),
    NULLIF(NEW.remarks, ''),
    'daily_attendance',
    NEW.id,
    jsonb_build_object(
      'attendance_date', NEW.date,
      'status', NEW.status,
      'class_section_id', NEW.class_section_id,
      'remarks', NEW.remarks
    ),
    COALESCE(NEW.updated_at, now())
  )
  ON CONFLICT (source_table, source_id, event_type)
    WHERE deleted_at IS NULL AND source_table IS NOT NULL AND source_id IS NOT NULL
  DO UPDATE SET
    actor_profile_id = EXCLUDED.actor_profile_id,
    title = EXCLUDED.title,
    description = EXCLUDED.description,
    metadata = EXCLUDED.metadata,
    occurred_at = EXCLUDED.occurred_at,
    updated_at = now();

  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION private.activity_from_behavior()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'private'
AS $$
DECLARE
  actor_id uuid;
BEGIN
  IF TG_OP = 'DELETE' THEN
    UPDATE public.activity_events
       SET deleted_at = now(), updated_at = now()
     WHERE source_table = 'behavioral_logs'
       AND source_id = OLD.id
       AND event_type = 'behavior_recorded'
       AND deleted_at IS NULL;
    RETURN OLD;
  END IF;

  IF NEW.deleted_at IS NOT NULL THEN
    UPDATE public.activity_events
       SET deleted_at = now(), updated_at = now()
     WHERE source_table = 'behavioral_logs'
       AND source_id = NEW.id
       AND event_type = 'behavior_recorded'
       AND deleted_at IS NULL;
    RETURN NEW;
  END IF;

  actor_id := COALESCE(NEW.logged_by_profile_id, public.get_active_profile_id());

  INSERT INTO public.activity_events (
    school_id, actor_profile_id, subject_profile_id,
    event_type, title, description,
    source_table, source_id, metadata, occurred_at
  )
  VALUES (
    NEW.school_id,
    actor_id,
    NEW.student_profile_id,
    'behavior_recorded',
    format('%s recorded — %s', initcap(NEW.type), initcap(NEW.severity)),
    NEW.description,
    'behavioral_logs',
    NEW.id,
    jsonb_build_object(
      'type', NEW.type,
      'severity', NEW.severity,
      'status', NEW.status,
      'points', NEW.points,
      'incident_date', NEW.incident_date
    ),
    COALESCE(NEW.updated_at, now())
  )
  ON CONFLICT (source_table, source_id, event_type)
    WHERE deleted_at IS NULL AND source_table IS NOT NULL AND source_id IS NOT NULL
  DO UPDATE SET
    actor_profile_id = EXCLUDED.actor_profile_id,
    title = EXCLUDED.title,
    description = EXCLUDED.description,
    metadata = EXCLUDED.metadata,
    occurred_at = EXCLUDED.occurred_at,
    updated_at = now();

  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION private.activity_from_grade_record()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'private'
AS $$
DECLARE
  assessment_title text;
  subject_name text;
  max_points numeric;
  pct numeric;
  actor_id uuid;
BEGIN
  IF TG_OP = 'DELETE' THEN
    UPDATE public.activity_events
       SET deleted_at = now(), updated_at = now()
     WHERE source_table = 'grade_records'
       AND source_id = OLD.id
       AND event_type = 'grade_recorded'
       AND deleted_at IS NULL;
    RETURN OLD;
  END IF;

  IF NEW.deleted_at IS NOT NULL THEN
    UPDATE public.activity_events
       SET deleted_at = now(), updated_at = now()
     WHERE source_table = 'grade_records'
       AND source_id = NEW.id
       AND event_type = 'grade_recorded'
       AND deleted_at IS NULL;
    RETURN NEW;
  END IF;

  SELECT a.title, a.max_points, s.name
    INTO assessment_title, max_points, subject_name
    FROM public.assessments a
    JOIN public.subjects s ON s.id = a.subject_id
   WHERE a.id = NEW.assessment_id
     AND a.deleted_at IS NULL;

  IF max_points IS NULL OR max_points <= 0 THEN
    RETURN NEW;
  END IF;

  pct := round((NEW.points_obtained / max_points) * 100, 1);
  actor_id := public.get_active_profile_id();

  INSERT INTO public.activity_events (
    school_id, actor_profile_id, subject_profile_id,
    event_type, title, description,
    source_table, source_id, metadata, occurred_at
  )
  VALUES (
    NEW.school_id,
    actor_id,
    NEW.student_profile_id,
    'grade_recorded',
    format('%s score recorded — %s%%', COALESCE(subject_name, 'Assessment'), trim(to_char(pct, 'FM999990.0'))),
    format('%s · %s/%s', COALESCE(assessment_title, 'Assessment'), NEW.points_obtained, max_points),
    'grade_records',
    NEW.id,
    jsonb_build_object(
      'assessment_id', NEW.assessment_id,
      'assessment_title', assessment_title,
      'subject', subject_name,
      'points_obtained', NEW.points_obtained,
      'max_points', max_points,
      'percentage', pct
    ),
    COALESCE(NEW.updated_at, now())
  )
  ON CONFLICT (source_table, source_id, event_type)
    WHERE deleted_at IS NULL AND source_table IS NOT NULL AND source_id IS NOT NULL
  DO UPDATE SET
    actor_profile_id = EXCLUDED.actor_profile_id,
    title = EXCLUDED.title,
    description = EXCLUDED.description,
    metadata = EXCLUDED.metadata,
    occurred_at = EXCLUDED.occurred_at,
    updated_at = now();

  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION private.activity_from_payment()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'private'
AS $$
DECLARE
  student_id uuid;
  actor_id uuid;
  payment_label text;
BEGIN
  IF TG_OP = 'DELETE' THEN
    UPDATE public.activity_events
       SET deleted_at = now(), updated_at = now()
     WHERE source_table = 'payments'
       AND source_id = OLD.id
       AND event_type = 'payment_received'
       AND deleted_at IS NULL;
    RETURN OLD;
  END IF;

  IF NEW.deleted_at IS NOT NULL OR NEW.status <> 'confirmed' THEN
    UPDATE public.activity_events
       SET deleted_at = now(), updated_at = now()
     WHERE source_table = 'payments'
       AND source_id = NEW.id
       AND event_type = 'payment_received'
       AND deleted_at IS NULL;
    RETURN NEW;
  END IF;

  SELECT i.student_profile_id
    INTO student_id
    FROM public.invoices i
   WHERE i.id = NEW.invoice_id
     AND i.deleted_at IS NULL;

  IF student_id IS NULL THEN
    RETURN NEW;
  END IF;

  actor_id := COALESCE(NEW.recorded_by_profile_id, public.get_active_profile_id());
  payment_label := COALESCE(NULLIF(NEW.provider, ''), NULLIF(NEW.payment_method, ''), 'Payment');

  INSERT INTO public.activity_events (
    school_id, actor_profile_id, subject_profile_id,
    event_type, title, description,
    source_table, source_id, metadata, occurred_at
  )
  VALUES (
    NEW.school_id,
    actor_id,
    student_id,
    'payment_received',
    format('Fee payment received — %s %s', NEW.currency, trim(to_char(NEW.amount, 'FM9999999990.00'))),
    concat_ws(' · ', payment_label, COALESCE(NEW.provider_reference, NEW.transaction_reference)),
    'payments',
    NEW.id,
    jsonb_build_object(
      'invoice_id', NEW.invoice_id,
      'amount', NEW.amount,
      'currency', NEW.currency,
      'payment_method', NEW.payment_method,
      'provider', NEW.provider,
      'reference', COALESCE(NEW.provider_reference, NEW.transaction_reference)
    ),
    NEW.paid_at
  )
  ON CONFLICT (source_table, source_id, event_type)
    WHERE deleted_at IS NULL AND source_table IS NOT NULL AND source_id IS NOT NULL
  DO UPDATE SET
    school_id = EXCLUDED.school_id,
    actor_profile_id = EXCLUDED.actor_profile_id,
    subject_profile_id = EXCLUDED.subject_profile_id,
    title = EXCLUDED.title,
    description = EXCLUDED.description,
    metadata = EXCLUDED.metadata,
    occurred_at = EXCLUDED.occurred_at,
    updated_at = now();

  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION private.notify_payment_confirmed()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'private'
AS $$
DECLARE
  student_id uuid;
  recipient uuid;
  label text;
BEGIN
  IF NEW.deleted_at IS NOT NULL OR NEW.status <> 'confirmed' OR NEW.invoice_id IS NULL THEN
    RETURN NEW;
  END IF;

  IF TG_OP = 'UPDATE' AND OLD.status = 'confirmed'
     AND OLD.invoice_id IS NOT DISTINCT FROM NEW.invoice_id
     AND OLD.amount IS NOT DISTINCT FROM NEW.amount THEN
    RETURN NEW;
  END IF;

  SELECT i.student_profile_id INTO student_id
  FROM public.invoices i
  WHERE i.id = NEW.invoice_id AND i.deleted_at IS NULL;

  IF student_id IS NULL THEN RETURN NEW; END IF;

  label := format('%s %s', NEW.currency, trim(to_char(NEW.amount, 'FM9999999990.00')));

  FOR recipient IN
    SELECT student_id
    UNION
    SELECT ur.parent_id
    FROM public.user_relationships ur
    WHERE ur.student_id = student_id AND ur.deleted_at IS NULL
  LOOP
    INSERT INTO public.notifications(
      school_id, recipient_profile_id, category, title, body, priority,
      data, action_path, source_table, source_id
    )
    VALUES(
      NEW.school_id, recipient, 'finance', 'Invoice payment confirmed',
      format('%s received and confirmed.', label), 'normal',
      jsonb_build_object('payment_id',NEW.id,'invoice_id',NEW.invoice_id,'amount',NEW.amount,'currency',NEW.currency),
      '/fees', 'payments', NEW.id
    )
    ON CONFLICT DO NOTHING;
  END LOOP;

  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION private.notify_report_card_published()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'private'
AS $$
DECLARE
  recipient uuid;
  term_name text;
BEGIN
  IF NEW.deleted_at IS NOT NULL OR NEW.status <> 'published' THEN
    RETURN NEW;
  END IF;

  IF TG_OP = 'UPDATE' AND OLD.status = 'published' THEN
    RETURN NEW;
  END IF;

  SELECT gt.name INTO term_name
  FROM public.grading_terms gt
  WHERE gt.id = NEW.term_id;

  FOR recipient IN
    SELECT NEW.student_profile_id
    UNION
    SELECT ur.parent_id
    FROM public.user_relationships ur
    WHERE ur.student_id = NEW.student_profile_id AND ur.deleted_at IS NULL
  LOOP
    INSERT INTO public.notifications(
      school_id, recipient_profile_id, category, title, body, priority,
      data, action_path, source_table, source_id
    )
    VALUES(
      NEW.school_id, recipient, 'academic', 'Report card published',
      format('%s report card is now available.', COALESCE(term_name,'Term')), 'normal',
      jsonb_build_object('report_card_id',NEW.id,'student_profile_id',NEW.student_profile_id,'term_id',NEW.term_id),
      '/academics/report-cards', 'report_cards', NEW.id
    )
    ON CONFLICT DO NOTHING;
  END LOOP;

  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION private.validate_grade_record_score()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO 'public', 'private'
AS $$
DECLARE
  max_score numeric;
BEGIN
  IF NEW.points_obtained < 0 THEN
    RAISE EXCEPTION 'score cannot be negative';
  END IF;

  SELECT max_points INTO max_score
  FROM public.assessments
  WHERE id = NEW.assessment_id AND deleted_at IS NULL;

  IF max_score IS NULL THEN
    RAISE EXCEPTION 'assessment not found';
  END IF;

  IF NEW.points_obtained > max_score THEN
    RAISE EXCEPTION 'score % exceeds assessment maximum %', NEW.points_obtained, max_score;
  END IF;

  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION private.activity_from_attendance() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION private.activity_from_behavior() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION private.activity_from_grade_record() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION private.activity_from_payment() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION private.notify_payment_confirmed() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION private.notify_report_card_published() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION private.validate_grade_record_score() FROM PUBLIC, anon, authenticated;
