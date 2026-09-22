import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Central typed client for all authoritative PostgreSQL RPC functions
/// exposed by the ZivoConnect EMS backend.
class RpcClient {
  final SupabaseClient _client;

  RpcClient(this._client);

  // ─────────────────────────────────────────────────────────────────
  // 1. ACTIVITY HEARTBEAT & PLATFORM ENGAGEMENT
  // ─────────────────────────────────────────────────────────────────

  DateTime? _lastHeartbeatTime;

  /// Throttled heartbeat to update `last_active_at` on the active profile.
  /// Enforces a 30-minute throttle to prevent redundant writes.
  Future<void> touchActiveProfile({bool force = false}) async {
    final now = DateTime.now();
    if (!force &&
        _lastHeartbeatTime != null &&
        now.difference(_lastHeartbeatTime!).inMinutes < 30) {
      return;
    }

    try {
      final platform = kIsWeb
          ? 'web'
          : defaultTargetPlatform == TargetPlatform.android
              ? 'android'
              : defaultTargetPlatform == TargetPlatform.iOS
                  ? 'ios'
                  : defaultTargetPlatform == TargetPlatform.windows
                      ? 'windows'
                      : defaultTargetPlatform == TargetPlatform.macOS
                          ? 'macos'
                          : 'other';

      await _client.rpc('touch_active_profile', params: {
        'platform': platform,
        'app_version': '1.0.0',
      });
      _lastHeartbeatTime = now;
      debugPrint('[RpcClient] touch_active_profile succeeded');
    } catch (e) {
      debugPrint('[RpcClient] touch_active_profile error: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // 2. SCHOOL ADMIN & STUDENTS DIRECTORY
  // ─────────────────────────────────────────────────────────────────

  /// Screen 01: School Admin Command Center KPIs
  Future<Map<String, dynamic>> getSchoolAdminDashboardMetrics() async {
    final res = await _client.rpc('get_school_admin_dashboard_metrics');
    if (res is Map) return Map<String, dynamic>.from(res);
    return {};
  }

  /// Screen 02: Full 360 summary for a student profile
  Future<Map<String, dynamic>> getStudent360Summary(String studentProfileId) async {
    final res = await _client.rpc('get_student_360_summary', params: {
      'student_profile_id': studentProfileId,
    });
    if (res is Map) return Map<String, dynamic>.from(res);
    return {};
  }

  /// Screen 24: Students directory with academic, attendance, and fee state
  Future<List<Map<String, dynamic>>> getStudentsDirectory({String? academicYearId}) async {
    final params = <String, dynamic>{};
    if (academicYearId != null) params['academic_year_id'] = academicYearId;
    final res = await _client.rpc('get_students_directory', params: params);
    if (res is List) {
      return res.map((item) => Map<String, dynamic>.from(item as Map)).toList();
    }
    return [];
  }

  /// Screen 25: Classes and sections overview with enrolled count & teachers
  Future<List<Map<String, dynamic>>> getClassesSectionsOverview({String? academicYearId}) async {
    final params = <String, dynamic>{};
    if (academicYearId != null) params['academic_year_id'] = academicYearId;
    final res = await _client.rpc('get_classes_sections_overview', params: params);
    if (res is List) {
      return res.map((item) => Map<String, dynamic>.from(item as Map)).toList();
    }
    return [];
  }

  // ─────────────────────────────────────────────────────────────────
  // 3. TEACHER DASHBOARD, ATTENDANCE & GRADEBOOK
  // ─────────────────────────────────────────────────────────────────

  /// Screen 03: Teacher Dashboard Metrics & Schedule
  Future<Map<String, dynamic>> getTeacherDashboardMetrics() async {
    final res = await _client.rpc('get_teacher_dashboard_metrics');
    if (res is Map) return Map<String, dynamic>.from(res);
    return {};
  }

  /// Screen 04: Attendance roll call roster for a class section & date
  Future<Map<String, dynamic>> getAttendanceRollCall({
    required String classSectionId,
    required DateTime date,
  }) async {
    final res = await _client.rpc('get_attendance_roll_call', params: {
      'class_section_id': classSectionId,
      'date': date.toIso8601String().split('T')[0],
    });
    if (res is Map) return Map<String, dynamic>.from(res);
    return {};
  }

  /// Screen 05: Authoritative teacher gradebook matrix
  Future<Map<String, dynamic>> getTeacherGradebook({
    required String classSectionId,
    required String subjectId,
    required String termId,
  }) async {
    final res = await _client.rpc('get_teacher_gradebook', params: {
      'class_section_id': classSectionId,
      'subject_id': subjectId,
      'term_id': termId,
    });
    if (res is Map) return Map<String, dynamic>.from(res);
    return {};
  }

  /// Screen 26: Gradebook setup and weight validation
  Future<Map<String, dynamic>> getGradebookSetup({
    required String classSectionId,
    required String subjectId,
    required String termId,
  }) async {
    final res = await _client.rpc('get_gradebook_setup', params: {
      'class_section_id': classSectionId,
      'subject_id': subjectId,
      'term_id': termId,
    });
    if (res is Map) return Map<String, dynamic>.from(res);
    return {};
  }

  // ─────────────────────────────────────────────────────────────────
  // 4. REPORT CARDS LIFECYCLE
  // ─────────────────────────────────────────────────────────────────

  /// Calculate preview report card for student
  Future<Map<String, dynamic>> calculateStudentTermReport({
    required String studentProfileId,
    required String termId,
  }) async {
    final res = await _client.rpc('calculate_student_term_report', params: {
      'student_profile_id': studentProfileId,
      'term_id': termId,
    });
    if (res is Map) return Map<String, dynamic>.from(res);
    return {};
  }

  /// Persist generated student report card
  Future<Map<String, dynamic>> generateStudentReportCard({
    required String studentProfileId,
    required String termId,
  }) async {
    final res = await _client.rpc('generate_student_report_card', params: {
      'student_profile_id': studentProfileId,
      'term_id': termId,
    });
    if (res is Map) return Map<String, dynamic>.from(res);
    return {};
  }

  /// Screen 27: Report cards overview for review/publishing
  Future<List<Map<String, dynamic>>> getReportCardsOverview({
    String? academicYearId,
    String? termId,
    String? classSectionId,
  }) async {
    final params = <String, dynamic>{};
    if (academicYearId != null) params['academic_year_id'] = academicYearId;
    if (termId != null) params['term_id'] = termId;
    if (classSectionId != null) params['class_section_id'] = classSectionId;

    final res = await _client.rpc('get_report_cards_overview', params: params);
    if (res is List) {
      return res.map((item) => Map<String, dynamic>.from(item as Map)).toList();
    }
    return [];
  }

  /// Set status: draft, pending_approval, approved, published
  Future<void> setReportCardStatus({
    required String reportCardId,
    required String status,
  }) async {
    await _client.rpc('set_report_card_status', params: {
      'report_card_id': reportCardId,
      'status': status,
    });
  }

  /// Bulk publish report cards for a section/term
  Future<int> bulkPublishReportCards({
    required String academicYearId,
    required String termId,
    String? classSectionId,
  }) async {
    final params = <String, dynamic>{
      'academic_year_id': academicYearId,
      'term_id': termId,
    };
    if (classSectionId != null) params['class_section_id'] = classSectionId;
    final res = await _client.rpc('bulk_publish_report_cards', params: params);
    return (res as num?)?.toInt() ?? 0;
  }

  // ─────────────────────────────────────────────────────────────────
  // 5. PARENT EXPERIENCE
  // ─────────────────────────────────────────────────────────────────

  /// Screen 06: Comprehensive dashboard for a selected child
  Future<Map<String, dynamic>> getParentDashboard(String studentProfileId) async {
    final res = await _client.rpc('get_parent_dashboard', params: {
      'student_profile_id': studentProfileId,
    });
    if (res is Map) return Map<String, dynamic>.from(res);
    return {};
  }

  /// Lightweight child summary
  Future<Map<String, dynamic>> getParentChildSummary(String studentProfileId) async {
    final res = await _client.rpc('get_parent_child_summary', params: {
      'student_profile_id': studentProfileId,
    });
    if (res is Map) return Map<String, dynamic>.from(res);
    return {};
  }

  // ─────────────────────────────────────────────────────────────────
  // 6. FINANCE DASHBOARD & RECONCILIATION
  // ─────────────────────────────────────────────────────────────────

  /// Screen 12: School Finance Dashboard Metrics
  Future<Map<String, dynamic>> getFinanceDashboardMetrics() async {
    final res = await _client.rpc('get_finance_dashboard_metrics');
    if (res is Map) return Map<String, dynamic>.from(res);
    return {};
  }

  /// Screen 14: Unmatched payment reconciliation against invoice
  Future<Map<String, dynamic>> reconcilePaymentToInvoice({
    required String paymentId,
    required String invoiceId,
  }) async {
    final res = await _client.rpc('reconcile_payment_to_invoice', params: {
      'payment_id': paymentId,
      'invoice_id': invoiceId,
    });
    if (res is Map) return Map<String, dynamic>.from(res);
    return {};
  }

  // ─────────────────────────────────────────────────────────────────
  // 7. REPORTS & ANALYTICS
  // ─────────────────────────────────────────────────────────────────

  /// Screen 22 Tab 1: Attendance Report
  Future<Map<String, dynamic>> getAttendanceReport({
    required String academicYearId,
    String? termId,
    String? classSectionId,
  }) async {
    final params = <String, dynamic>{'academic_year_id': academicYearId};
    if (termId != null) params['term_id'] = termId;
    if (classSectionId != null) params['class_section_id'] = classSectionId;

    final res = await _client.rpc('get_attendance_report', params: params);
    if (res is Map) return Map<String, dynamic>.from(res);
    return {};
  }

  /// Screen 22 Tab 2: Academic Performance Report
  Future<Map<String, dynamic>> getAcademicPerformanceReport({
    required String academicYearId,
    String? termId,
    String? classSectionId,
  }) async {
    final params = <String, dynamic>{'academic_year_id': academicYearId};
    if (termId != null) params['term_id'] = termId;
    if (classSectionId != null) params['class_section_id'] = classSectionId;

    final res = await _client.rpc('get_academic_performance_report', params: params);
    if (res is Map) return Map<String, dynamic>.from(res);
    return {};
  }

  /// Screen 22 Tab 3: Fee Collections Report
  Future<Map<String, dynamic>> getFeeCollectionsReport({
    required String academicYearId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final params = <String, dynamic>{'academic_year_id': academicYearId};
    if (startDate != null) params['start_date'] = startDate.toIso8601String().split('T')[0];
    if (endDate != null) params['end_date'] = endDate.toIso8601String().split('T')[0];

    final res = await _client.rpc('get_fee_collections_report', params: params);
    if (res is Map) return Map<String, dynamic>.from(res);
    return {};
  }

  // ─────────────────────────────────────────────────────────────────
  // 8. OPERATIONS DASHBOARDS
  // ─────────────────────────────────────────────────────────────────

  /// Screen 15: Admissions pipeline
  Future<Map<String, dynamic>> getAdmissionsPipeline() async {
    final res = await _client.rpc('get_admissions_pipeline');
    if (res is Map) return Map<String, dynamic>.from(res);
    return {};
  }

  /// Screen 18: Fleet & bus tracking dashboard
  Future<Map<String, dynamic>> getFleetDashboard() async {
    final res = await _client.rpc('get_fleet_dashboard');
    if (res is Map) return Map<String, dynamic>.from(res);
    return {};
  }

  /// Screen 20: Library management dashboard
  Future<Map<String, dynamic>> getLibraryDashboard() async {
    final res = await _client.rpc('get_library_dashboard');
    if (res is Map) return Map<String, dynamic>.from(res);
    return {};
  }

  /// Screen 21: Behaviour & pastoral support dashboard
  Future<Map<String, dynamic>> getBehaviorDashboard() async {
    final res = await _client.rpc('get_behavior_dashboard');
    if (res is Map) return Map<String, dynamic>.from(res);
    return {};
  }

  // ─────────────────────────────────────────────────────────────────
  // 9. SUPER ADMIN & NOTIFICATIONS
  // ─────────────────────────────────────────────────────────────────

  /// Screen 10: Super admin platform metrics (active schools, MAU, etc.)
  Future<Map<String, dynamic>> getSuperAdminPlatformMetrics() async {
    final res = await _client.rpc('get_super_admin_platform_metrics');
    if (res is Map) return Map<String, dynamic>.from(res);
    return {};
  }

  /// Screen 11: Super admin schools directory
  Future<List<Map<String, dynamic>>> getSuperAdminSchoolsDirectory() async {
    final res = await _client.rpc('get_super_admin_schools_directory');
    if (res is List) {
      return res.map((item) => Map<String, dynamic>.from(item as Map)).toList();
    }
    return [];
  }

  /// Screen 17: Mark all notifications as read for current profile
  Future<void> markAllNotificationsRead() async {
    await _client.rpc('mark_all_notifications_read');
  }
}
