-- ZivoConnect live backend reconciliation: public functions required by production triggers.

CREATE OR REPLACE FUNCTION public.recalculate_invoice_totals(p_invoice_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  current_total numeric;
  calculated_total numeric;
  active_item_count integer;
  confirmed_paid numeric;
  new_total numeric;
  new_paid numeric;
BEGIN
  SELECT total_amount
  INTO current_total
  FROM public.invoices
  WHERE id = p_invoice_id
    AND deleted_at IS NULL;

  IF current_total IS NULL THEN
    RETURN;
  END IF;

  SELECT count(*), COALESCE(sum(amount), 0)
  INTO active_item_count, calculated_total
  FROM public.invoice_items
  WHERE invoice_id = p_invoice_id
    AND deleted_at IS NULL;

  new_total := CASE
    WHEN active_item_count > 0 THEN calculated_total
    ELSE current_total
  END;

  SELECT COALESCE(sum(amount), 0)
  INTO confirmed_paid
  FROM public.payments
  WHERE invoice_id = p_invoice_id
    AND status = 'confirmed'
    AND deleted_at IS NULL;

  new_paid := LEAST(confirmed_paid, new_total);

  UPDATE public.invoices
  SET total_amount = new_total,
      paid_amount = new_paid,
      status = CASE
        WHEN new_total > 0 AND new_paid >= new_total THEN 'paid'
        WHEN new_paid > 0 THEN 'partial'
        ELSE 'unpaid'
      END
  WHERE id = p_invoice_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.on_invoice_item_recalculate_invoice()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
BEGIN
  IF TG_OP = 'DELETE' THEN
    PERFORM public.recalculate_invoice_totals(OLD.invoice_id);
    RETURN OLD;
  END IF;

  PERFORM public.recalculate_invoice_totals(NEW.invoice_id);

  IF TG_OP = 'UPDATE' AND OLD.invoice_id IS DISTINCT FROM NEW.invoice_id THEN
    PERFORM public.recalculate_invoice_totals(OLD.invoice_id);
  END IF;

  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.on_payment_recalculate_invoice()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO 'public'
AS $$
BEGIN
  IF TG_OP = 'DELETE' THEN
    PERFORM public.recalculate_invoice_totals(OLD.invoice_id);
    RETURN OLD;
  END IF;

  PERFORM public.recalculate_invoice_totals(NEW.invoice_id);

  IF TG_OP = 'UPDATE' AND OLD.invoice_id IS DISTINCT FROM NEW.invoice_id THEN
    PERFORM public.recalculate_invoice_totals(OLD.invoice_id);
  END IF;

  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.recalculate_library_availability(p_book_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  total_stock integer;
  active_issues integer;
BEGIN
  SELECT stock_quantity INTO total_stock
  FROM public.library_books
  WHERE id = p_book_id;

  IF total_stock IS NULL THEN
    RETURN;
  END IF;

  SELECT count(*) INTO active_issues
  FROM public.library_issues
  WHERE book_id = p_book_id
    AND status IN ('issued','overdue')
    AND returned_at IS NULL
    AND deleted_at IS NULL;

  UPDATE public.library_books
  SET available_quantity = GREATEST(total_stock - active_issues, 0)
  WHERE id = p_book_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.on_library_issue_recalculate()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
BEGIN
  IF TG_OP = 'DELETE' THEN
    PERFORM public.recalculate_library_availability(OLD.book_id);
    RETURN OLD;
  END IF;

  PERFORM public.recalculate_library_availability(NEW.book_id);

  IF TG_OP = 'UPDATE' AND OLD.book_id IS DISTINCT FROM NEW.book_id THEN
    PERFORM public.recalculate_library_availability(OLD.book_id);
  END IF;

  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.notify_direct_message_recipient()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
BEGIN
  INSERT INTO public.notifications (
    school_id,
    recipient_profile_id,
    category,
    title,
    body,
    priority,
    data,
    action_path,
    source_table,
    source_id
  )
  VALUES (
    NEW.school_id,
    NEW.recipient_profile_id,
    'message',
    'New message',
    CASE
      WHEN length(NEW.message) > 120 THEN left(NEW.message, 117) || '...'
      ELSE NEW.message
    END,
    'normal',
    jsonb_build_object('sender_profile_id', NEW.sender_profile_id),
    '/messages',
    'direct_messages',
    NEW.id
  )
  ON CONFLICT DO NOTHING;

  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.sync_report_card_approval()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO 'public'
AS $$
DECLARE
  entering_reviewed_state boolean;
  report_complete boolean;
BEGIN
  entering_reviewed_state :=
    TG_OP = 'INSERT'
    OR (
      TG_OP = 'UPDATE'
      AND (
        OLD.status IS DISTINCT FROM NEW.status
        OR OLD.principal_approved IS DISTINCT FROM NEW.principal_approved
      )
    );

  IF entering_reviewed_state
     AND (
       NEW.status IN ('approved','published')
       OR NEW.principal_approved = true
     ) THEN
    report_complete :=
      COALESCE((NEW.summary ->> 'is_complete')::boolean, false);

    IF NOT report_complete OR NEW.average_percentage IS NULL THEN
      RAISE EXCEPTION
        'report card cannot be approved or published while academic calculations are incomplete';
    END IF;
  END IF;

  IF NEW.principal_approved = true
     AND NEW.status IN ('draft','pending_approval') THEN
    NEW.status := 'approved';
    NEW.approved_at := COALESCE(NEW.approved_at, now());
    NEW.approved_by_profile_id :=
      COALESCE(
        NEW.approved_by_profile_id,
        public.get_active_profile_id()
      );
  END IF;

  IF NEW.status = 'published' THEN
    NEW.principal_approved := true;
    NEW.approved_at := COALESCE(NEW.approved_at, now());
    NEW.approved_by_profile_id :=
      COALESCE(
        NEW.approved_by_profile_id,
        public.get_active_profile_id()
      );
    NEW.published_at := COALESCE(NEW.published_at, now());
  END IF;

  RETURN NEW;
END;
$$;
