-- ZivoConnect live backend reconciliation: execute permissions for application-facing RPCs.
-- Production grants EXECUTE to authenticated + service_role and revokes anon/PUBLIC.

DO $$
DECLARE
  fn record;
BEGIN
  FOR fn IN
    SELECT p.oid::regprocedure AS signature
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid=p.pronamespace
    WHERE n.nspname='public'
      AND p.proname=ANY(ARRAY[
        'bulk_publish_report_cards','calculate_student_term_report','cancel_marketplace_order',
        'create_library_fine','generate_invoices_from_fee_structure','generate_student_report_card',
        'get_academic_performance_report','get_admissions_pipeline','get_attendance_report',
        'get_attendance_roll_call','get_behavior_dashboard','get_classes_sections_overview',
        'get_fee_collections_report','get_fee_collections_report_by_date','get_fee_collections_report_by_scope',
        'get_finance_dashboard_metrics','get_fleet_dashboard','get_gradebook_setup','get_library_dashboard',
        'get_notification_center','get_notification_preferences','get_parent_academics','get_parent_child_summary',
        'get_parent_dashboard','get_parent_fees','get_report_cards_overview','get_reports_analytics',
        'get_school_admin_dashboard_metrics','get_school_configuration','get_student_360_summary','get_students_directory',
        'get_super_admin_platform_metrics','get_super_admin_schools_directory','get_teacher_dashboard_metrics',
        'get_teacher_gradebook','issue_library_book','link_admission_to_enrolled_student','mark_all_notifications_read',
        'mark_behavior_guardian_notified','mark_library_fine_paid','mark_notification_read','patch_school_configuration',
        'place_marketplace_order','reconcile_payment_to_invoice','register_push_token','return_library_book',
        'save_announcement_draft','set_admission_status','set_announcement_status','set_marketplace_fulfillment_status',
        'set_report_card_status','set_school_operational_status','set_school_subscription_status','unregister_push_token',
        'update_behavior_case','update_notification_preferences'
      ])
  LOOP
    EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC, anon',fn.signature);
    EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO authenticated, service_role',fn.signature);
  END LOOP;
END $$;
