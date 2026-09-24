-- ZivoConnect live backend reconciliation: extensions to original baseline tables
-- Captures columns, constraints and important indexes already present in production.

-- -----------------------------------------------------------------------------
-- Gradebook / terms / report-card lifecycle
-- -----------------------------------------------------------------------------
ALTER TABLE public.grading_terms
  ADD COLUMN IF NOT EXISTS sequence integer,
  ADD COLUMN IF NOT EXISTS start_date date,
  ADD COLUMN IF NOT EXISTS end_date date;

ALTER TABLE public.grading_terms DROP CONSTRAINT IF EXISTS grading_terms_sequence_check;
ALTER TABLE public.grading_terms
  ADD CONSTRAINT grading_terms_sequence_check CHECK (sequence IS NULL OR sequence > 0);
ALTER TABLE public.grading_terms DROP CONSTRAINT IF EXISTS grading_terms_dates_check;
ALTER TABLE public.grading_terms
  ADD CONSTRAINT grading_terms_dates_check CHECK (start_date IS NULL OR end_date IS NULL OR start_date <= end_date);

CREATE UNIQUE INDEX IF NOT EXISTS idx_grading_terms_year_sequence
  ON public.grading_terms (school_id, academic_year_id, sequence)
  WHERE sequence IS NOT NULL AND deleted_at IS NULL;

ALTER TABLE public.assessment_categories
  ADD COLUMN IF NOT EXISTS class_section_id uuid REFERENCES public.class_sections(id) ON DELETE CASCADE,
  ADD COLUMN IF NOT EXISTS subject_id uuid REFERENCES public.subjects(id) ON DELETE CASCADE,
  ADD COLUMN IF NOT EXISTS term_id uuid REFERENCES public.grading_terms(id) ON DELETE CASCADE;

ALTER TABLE public.assessment_categories DROP CONSTRAINT IF EXISTS assessment_categories_scope_check;
ALTER TABLE public.assessment_categories
  ADD CONSTRAINT assessment_categories_scope_check CHECK (
    (class_section_id IS NULL AND subject_id IS NULL AND term_id IS NULL)
    OR
    (class_section_id IS NOT NULL AND subject_id IS NOT NULL AND term_id IS NOT NULL)
  );

CREATE INDEX IF NOT EXISTS idx_assessment_categories_scope
  ON public.assessment_categories (school_id, class_section_id, subject_id, term_id)
  WHERE deleted_at IS NULL;
CREATE UNIQUE INDEX IF NOT EXISTS idx_assessment_categories_scoped_name
  ON public.assessment_categories (school_id, class_section_id, subject_id, term_id, lower(name))
  WHERE deleted_at IS NULL AND class_section_id IS NOT NULL AND subject_id IS NOT NULL AND term_id IS NOT NULL;

ALTER TABLE public.assessments
  ADD COLUMN IF NOT EXISTS weight numeric;
ALTER TABLE public.assessments DROP CONSTRAINT IF EXISTS assessments_weight_check;
ALTER TABLE public.assessments
  ADD CONSTRAINT assessments_weight_check CHECK (weight IS NULL OR (weight > 0 AND weight <= 1));

CREATE INDEX IF NOT EXISTS idx_assessments_category
  ON public.assessments (category_id) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_assessments_gradebook_scope
  ON public.assessments (school_id, class_section_id, subject_id, term_id) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_assessments_lookup
  ON public.assessments (class_section_id, subject_id, term_id) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_assessments_subject
  ON public.assessments (subject_id) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_assessments_term
  ON public.assessments (term_id) WHERE deleted_at IS NULL;

ALTER TABLE public.report_cards
  ADD COLUMN IF NOT EXISTS status text NOT NULL DEFAULT 'draft',
  ADD COLUMN IF NOT EXISTS average_percentage numeric,
  ADD COLUMN IF NOT EXISTS overall_grade text,
  ADD COLUMN IF NOT EXISTS attendance_rate numeric,
  ADD COLUMN IF NOT EXISTS approved_by_profile_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS approved_at timestamptz,
  ADD COLUMN IF NOT EXISTS published_at timestamptz,
  ADD COLUMN IF NOT EXISTS summary jsonb NOT NULL DEFAULT '{}'::jsonb;

ALTER TABLE public.report_cards DROP CONSTRAINT IF EXISTS report_cards_status_check;
ALTER TABLE public.report_cards
  ADD CONSTRAINT report_cards_status_check CHECK (status IN ('draft','pending_approval','approved','published'));
CREATE UNIQUE INDEX IF NOT EXISTS unique_report_card_per_term
  ON public.report_cards (student_profile_id, academic_year_id, term_id);
CREATE INDEX IF NOT EXISTS idx_report_cards_lookup
  ON public.report_cards (student_profile_id, academic_year_id) WHERE deleted_at IS NULL;

-- -----------------------------------------------------------------------------
-- Finance / payment reconciliation
-- -----------------------------------------------------------------------------
ALTER TABLE public.invoices
  ADD COLUMN IF NOT EXISTS invoice_number text,
  ADD COLUMN IF NOT EXISTS currency text NOT NULL DEFAULT 'USD',
  ADD COLUMN IF NOT EXISTS issued_at timestamptz NOT NULL DEFAULT now(),
  ADD COLUMN IF NOT EXISTS fee_structure_id uuid REFERENCES public.fee_structures(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS notes text;

CREATE UNIQUE INDEX IF NOT EXISTS idx_invoices_school_number
  ON public.invoices (school_id, invoice_number)
  WHERE invoice_number IS NOT NULL AND deleted_at IS NULL;
CREATE UNIQUE INDEX IF NOT EXISTS idx_invoices_student_fee_structure_unique
  ON public.invoices (student_profile_id, fee_structure_id)
  WHERE deleted_at IS NULL AND fee_structure_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_invoices_student_year
  ON public.invoices (student_profile_id, academic_year_id, status) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_invoices_tenant_sync
  ON public.invoices (school_id, updated_at) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_invoices_deleted_sync
  ON public.invoices (updated_at) WHERE deleted_at IS NOT NULL;

ALTER TABLE public.payments ALTER COLUMN invoice_id DROP NOT NULL;
ALTER TABLE public.payments
  ADD COLUMN IF NOT EXISTS status text NOT NULL DEFAULT 'confirmed',
  ADD COLUMN IF NOT EXISTS currency text NOT NULL DEFAULT 'USD',
  ADD COLUMN IF NOT EXISTS provider text,
  ADD COLUMN IF NOT EXISTS provider_reference text,
  ADD COLUMN IF NOT EXISTS receipt_url text,
  ADD COLUMN IF NOT EXISTS recorded_by_profile_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS metadata jsonb NOT NULL DEFAULT '{}'::jsonb;

ALTER TABLE public.payments DROP CONSTRAINT IF EXISTS payments_status_check;
ALTER TABLE public.payments
  ADD CONSTRAINT payments_status_check CHECK (status IN ('pending','confirmed','failed','reversed'));
ALTER TABLE public.payments DROP CONSTRAINT IF EXISTS payments_confirmed_requires_invoice;
ALTER TABLE public.payments
  ADD CONSTRAINT payments_confirmed_requires_invoice CHECK (status <> 'confirmed' OR invoice_id IS NOT NULL);

CREATE INDEX IF NOT EXISTS idx_payments_invoice
  ON public.payments (invoice_id) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_payments_provider_reference
  ON public.payments (provider, provider_reference)
  WHERE provider_reference IS NOT NULL AND deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_payments_reconciliation_queue
  ON public.payments (school_id, status, paid_at DESC)
  WHERE deleted_at IS NULL AND invoice_id IS NULL;
CREATE INDEX IF NOT EXISTS idx_payments_deleted_sync
  ON public.payments (updated_at) WHERE deleted_at IS NOT NULL;

-- -----------------------------------------------------------------------------
-- Announcements / messaging
-- -----------------------------------------------------------------------------
ALTER TABLE public.announcements
  ADD COLUMN IF NOT EXISTS status text NOT NULL DEFAULT 'published',
  ADD COLUMN IF NOT EXISTS priority text NOT NULL DEFAULT 'normal',
  ADD COLUMN IF NOT EXISTS scheduled_at timestamptz,
  ADD COLUMN IF NOT EXISTS published_at timestamptz,
  ADD COLUMN IF NOT EXISTS expires_at timestamptz,
  ADD COLUMN IF NOT EXISTS target_class_section_id uuid REFERENCES public.class_sections(id) ON DELETE CASCADE,
  ADD COLUMN IF NOT EXISTS attachment_urls jsonb NOT NULL DEFAULT '[]'::jsonb;

ALTER TABLE public.announcements DROP CONSTRAINT IF EXISTS announcements_status_check;
ALTER TABLE public.announcements
  ADD CONSTRAINT announcements_status_check CHECK (status IN ('draft','scheduled','published','archived'));
ALTER TABLE public.announcements DROP CONSTRAINT IF EXISTS announcements_priority_check;
ALTER TABLE public.announcements
  ADD CONSTRAINT announcements_priority_check CHECK (priority IN ('normal','high','urgent'));
ALTER TABLE public.announcements DROP CONSTRAINT IF EXISTS announcements_target_role_check;
ALTER TABLE public.announcements
  ADD CONSTRAINT announcements_target_role_check
  CHECK (target_role IN ('all','teachers','parents','students','staff','school_admins'));

CREATE INDEX IF NOT EXISTS idx_announcements_author
  ON public.announcements (author_profile_id)
  WHERE deleted_at IS NULL AND author_profile_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_announcements_schedule
  ON public.announcements (school_id, status, scheduled_at) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_announcements_target
  ON public.announcements (school_id, target_role, created_at DESC) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_announcements_target_section
  ON public.announcements (target_class_section_id)
  WHERE deleted_at IS NULL AND target_class_section_id IS NOT NULL;

ALTER TABLE public.direct_messages
  ADD COLUMN IF NOT EXISTS read_at timestamptz,
  ADD COLUMN IF NOT EXISTS attachment_urls jsonb NOT NULL DEFAULT '[]'::jsonb,
  ADD COLUMN IF NOT EXISTS message_type text NOT NULL DEFAULT 'text',
  ADD COLUMN IF NOT EXISTS reply_to_message_id uuid REFERENCES public.direct_messages(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS edited_at timestamptz;

ALTER TABLE public.direct_messages DROP CONSTRAINT IF EXISTS direct_messages_message_type_check;
ALTER TABLE public.direct_messages
  ADD CONSTRAINT direct_messages_message_type_check CHECK (message_type IN ('text','attachment','system'));

CREATE INDEX IF NOT EXISTS idx_direct_messages_sender_recipient
  ON public.direct_messages (school_id, sender_profile_id, recipient_profile_id, created_at DESC)
  WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_messages_recipient_unread
  ON public.direct_messages (recipient_profile_id, created_at DESC)
  WHERE deleted_at IS NULL AND read_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_direct_messages_deleted_sync
  ON public.direct_messages (updated_at) WHERE deleted_at IS NOT NULL;

-- -----------------------------------------------------------------------------
-- Library / behaviour
-- -----------------------------------------------------------------------------
ALTER TABLE public.library_books
  ADD COLUMN IF NOT EXISTS category text,
  ADD COLUMN IF NOT EXISTS cover_url text,
  ADD COLUMN IF NOT EXISTS shelf_code text,
  ADD COLUMN IF NOT EXISTS publisher text,
  ADD COLUMN IF NOT EXISTS published_year integer;
ALTER TABLE public.library_books DROP CONSTRAINT IF EXISTS library_books_stock_bounds_check;
ALTER TABLE public.library_books
  ADD CONSTRAINT library_books_stock_bounds_check CHECK (
    stock_quantity >= 0 AND available_quantity >= 0 AND available_quantity <= stock_quantity
  );
CREATE INDEX IF NOT EXISTS idx_library_books_category
  ON public.library_books (school_id, category, title) WHERE deleted_at IS NULL;

ALTER TABLE public.library_issues
  ADD COLUMN IF NOT EXISTS issued_by_profile_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS received_by_profile_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS notes text;
CREATE INDEX IF NOT EXISTS idx_library_issues_book
  ON public.library_issues (book_id) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_library_issues_borrower
  ON public.library_issues (borrower_profile_id, status) WHERE deleted_at IS NULL;

ALTER TABLE public.library_fines
  ADD COLUMN IF NOT EXISTS reason text,
  ADD COLUMN IF NOT EXISTS paid_at timestamptz;
CREATE INDEX IF NOT EXISTS idx_library_fines_issue
  ON public.library_fines (issue_id) WHERE deleted_at IS NULL;

ALTER TABLE public.behavioral_logs
  ADD COLUMN IF NOT EXISTS severity text NOT NULL DEFAULT 'low',
  ADD COLUMN IF NOT EXISTS status text NOT NULL DEFAULT 'open',
  ADD COLUMN IF NOT EXISTS follow_up_notes text,
  ADD COLUMN IF NOT EXISTS guardian_notified_at timestamptz,
  ADD COLUMN IF NOT EXISTS resolved_at timestamptz,
  ADD COLUMN IF NOT EXISTS resolved_by_profile_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL;
ALTER TABLE public.behavioral_logs DROP CONSTRAINT IF EXISTS behavioral_logs_severity_check;
ALTER TABLE public.behavioral_logs
  ADD CONSTRAINT behavioral_logs_severity_check CHECK (severity IN ('low','medium','high'));
ALTER TABLE public.behavioral_logs DROP CONSTRAINT IF EXISTS behavioral_logs_status_check;
ALTER TABLE public.behavioral_logs
  ADD CONSTRAINT behavioral_logs_status_check CHECK (status IN ('open','follow_up','resolved'));
CREATE INDEX IF NOT EXISTS idx_behavior_student_status
  ON public.behavioral_logs (student_profile_id, status, incident_date DESC) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_behavioral_student
  ON public.behavioral_logs (student_profile_id, type) WHERE deleted_at IS NULL;

-- -----------------------------------------------------------------------------
-- Marketplace lifecycle
-- -----------------------------------------------------------------------------
ALTER TABLE public.marketplace_items
  ADD COLUMN IF NOT EXISTS category text;
CREATE INDEX IF NOT EXISTS idx_marketplace_category
  ON public.marketplace_items (school_id, category, status) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_marketplace_items_listing
  ON public.marketplace_items (school_id, status) WHERE deleted_at IS NULL;

ALTER TABLE public.marketplace_orders
  ADD COLUMN IF NOT EXISTS currency text NOT NULL DEFAULT 'USD',
  ADD COLUMN IF NOT EXISTS payment_status text NOT NULL DEFAULT 'unpaid',
  ADD COLUMN IF NOT EXISTS fulfillment_status text NOT NULL DEFAULT 'pending';
ALTER TABLE public.marketplace_orders DROP CONSTRAINT IF EXISTS marketplace_orders_payment_status_check;
ALTER TABLE public.marketplace_orders
  ADD CONSTRAINT marketplace_orders_payment_status_check
  CHECK (payment_status IN ('unpaid','pending','paid','failed','refunded'));
ALTER TABLE public.marketplace_orders DROP CONSTRAINT IF EXISTS marketplace_orders_fulfillment_status_check;
ALTER TABLE public.marketplace_orders
  ADD CONSTRAINT marketplace_orders_fulfillment_status_check
  CHECK (fulfillment_status IN ('pending','processing','ready','collected','cancelled'));
CREATE INDEX IF NOT EXISTS idx_marketplace_orders_buyer
  ON public.marketplace_orders (buyer_profile_id) WHERE deleted_at IS NULL;

-- -----------------------------------------------------------------------------
-- Push-token indexes. Note: the live table constraint still permits only
-- android/ios/web while register_push_token() currently accepts additional
-- desktop platforms. Phase 1 captures production exactly; the mismatch is
-- intentionally left for a later explicit fix.
-- -----------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_push_tokens_profile
  ON public.push_tokens (profile_id) WHERE deleted_at IS NULL;
CREATE UNIQUE INDEX IF NOT EXISTS idx_push_tokens_active_token_unique
  ON public.push_tokens (token) WHERE deleted_at IS NULL;
