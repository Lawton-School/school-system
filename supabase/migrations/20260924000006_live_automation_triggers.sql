-- ZivoConnect live backend reconciliation: production automation triggers.

DROP TRIGGER IF EXISTS trigger_activity_from_behavior ON public.behavioral_logs;
CREATE TRIGGER trigger_activity_from_behavior
AFTER INSERT OR DELETE OR UPDATE ON public.behavioral_logs
FOR EACH ROW EXECUTE FUNCTION private.activity_from_behavior();

DROP TRIGGER IF EXISTS trigger_activity_from_attendance ON public.daily_attendance;
CREATE TRIGGER trigger_activity_from_attendance
AFTER INSERT OR DELETE OR UPDATE ON public.daily_attendance
FOR EACH ROW EXECUTE FUNCTION private.activity_from_attendance();

DROP TRIGGER IF EXISTS trigger_activity_from_grade_record ON public.grade_records;
CREATE TRIGGER trigger_activity_from_grade_record
AFTER INSERT OR DELETE OR UPDATE ON public.grade_records
FOR EACH ROW EXECUTE FUNCTION private.activity_from_grade_record();

DROP TRIGGER IF EXISTS trigger_validate_grade_record_score ON public.grade_records;
CREATE TRIGGER trigger_validate_grade_record_score
BEFORE INSERT OR UPDATE OF assessment_id, points_obtained ON public.grade_records
FOR EACH ROW EXECUTE FUNCTION private.validate_grade_record_score();

DROP TRIGGER IF EXISTS trigger_invoice_item_recalculate_invoice ON public.invoice_items;
CREATE TRIGGER trigger_invoice_item_recalculate_invoice
AFTER INSERT OR DELETE OR UPDATE ON public.invoice_items
FOR EACH ROW EXECUTE FUNCTION public.on_invoice_item_recalculate_invoice();

DROP TRIGGER IF EXISTS trigger_library_issue_recalculate ON public.library_issues;
CREATE TRIGGER trigger_library_issue_recalculate
AFTER INSERT OR DELETE OR UPDATE ON public.library_issues
FOR EACH ROW EXECUTE FUNCTION public.on_library_issue_recalculate();

DROP TRIGGER IF EXISTS trigger_activity_from_payment ON public.payments;
CREATE TRIGGER trigger_activity_from_payment
AFTER INSERT OR DELETE OR UPDATE ON public.payments
FOR EACH ROW EXECUTE FUNCTION private.activity_from_payment();

DROP TRIGGER IF EXISTS trigger_notify_payment_confirmed ON public.payments;
CREATE TRIGGER trigger_notify_payment_confirmed
AFTER INSERT OR UPDATE ON public.payments
FOR EACH ROW EXECUTE FUNCTION private.notify_payment_confirmed();

DROP TRIGGER IF EXISTS trigger_payment_recalculate_invoice ON public.payments;
CREATE TRIGGER trigger_payment_recalculate_invoice
AFTER INSERT OR DELETE OR UPDATE ON public.payments
FOR EACH ROW EXECUTE FUNCTION public.on_payment_recalculate_invoice();

DROP TRIGGER IF EXISTS trigger_notify_report_card_published ON public.report_cards;
CREATE TRIGGER trigger_notify_report_card_published
AFTER INSERT OR UPDATE ON public.report_cards
FOR EACH ROW EXECUTE FUNCTION private.notify_report_card_published();

DROP TRIGGER IF EXISTS trigger_sync_report_card_approval ON public.report_cards;
CREATE TRIGGER trigger_sync_report_card_approval
BEFORE INSERT OR UPDATE ON public.report_cards
FOR EACH ROW EXECUTE FUNCTION public.sync_report_card_approval();

DROP TRIGGER IF EXISTS trigger_notify_direct_message ON public.direct_messages;
CREATE TRIGGER trigger_notify_direct_message
AFTER INSERT ON public.direct_messages
FOR EACH ROW EXECUTE FUNCTION public.notify_direct_message_recipient();
