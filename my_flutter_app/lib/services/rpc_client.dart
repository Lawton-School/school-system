import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Central typed client for authoritative PostgreSQL RPC functions exposed by
/// the ZivoConnect EMS backend.
///
/// RPC parameter names intentionally mirror the PostgreSQL signatures exactly.
class RpcClient {
  final SupabaseClient _client;

  RpcClient(this._client);

  DateTime? _lastHeartbeatTime;

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
        'p_platform': platform,
        'p_app_version': '1.0.0',
      });
      _lastHeartbeatTime = now;
    } catch (e) {
      debugPrint('[RpcClient] touch_active_profile error: $e');
    }
  }

  Future<Map<String, dynamic>> getSchoolAdminDashboardMetrics() async {
    return _asMap(await _client.rpc('get_school_admin_dashboard_metrics'));
  }

  Future<Map<String, dynamic>> getStudent360Summary(
    String studentProfileId,
  ) async {
    return _asMap(await _client.rpc('get_student_360_summary', params: {
      'p_student_profile_id': studentProfileId,
    }));
  }

  Future<List<Map<String, dynamic>>> getStudentsDirectory({
    String? academicYearId,
  }) async {
    final yearId = _requiredId(academicYearId, 'academicYearId');
    final payload = _asMap(await _client.rpc('get_students_directory', params: {
      'p_academic_year_id': yearId,
    }));
    return _mapList(payload['students']);
  }

  Future<List<Map<String, dynamic>>> getClassesSectionsOverview({
    String? academicYearId,
  }) async {
    final yearId = _requiredId(academicYearId, 'academicYearId');
    final payload =
        _asMap(await _client.rpc('get_classes_sections_overview', params: {
      'p_academic_year_id': yearId,
    }));
    return _mapList(payload['classes']);
  }

  Future<Map<String, dynamic>> getTeacherDashboardMetrics() async {
    return _asMap(await _client.rpc('get_teacher_dashboard_metrics'));
  }

  Future<Map<String, dynamic>> getAttendanceRollCall({
    required String classSectionId,
    required DateTime date,
  }) async {
    return _asMap(await _client.rpc('get_attendance_roll_call', params: {
      'p_class_section_id': classSectionId,
      'p_date': _date(date),
    }));
  }

  Future<Map<String, dynamic>> getTeacherGradebook({
    required String classSectionId,
    required String subjectId,
    required String termId,
  }) async {
    return _asMap(await _client.rpc('get_teacher_gradebook', params: {
      'p_class_section_id': classSectionId,
      'p_subject_id': subjectId,
      'p_term_id': termId,
    }));
  }

  Future<Map<String, dynamic>> getGradebookSetup({
    required String classSectionId,
    required String subjectId,
    required String termId,
  }) async {
    return _asMap(await _client.rpc('get_gradebook_setup', params: {
      'p_class_section_id': classSectionId,
      'p_subject_id': subjectId,
      'p_term_id': termId,
    }));
  }

  Future<Map<String, dynamic>> calculateStudentTermReport({
    required String studentProfileId,
    required String termId,
  }) async {
    return _asMap(await _client.rpc('calculate_student_term_report', params: {
      'p_student_profile_id': studentProfileId,
      'p_term_id': termId,
    }));
  }

  Future<Map<String, dynamic>> generateStudentReportCard({
    required String studentProfileId,
    required String termId,
  }) async {
    return _asMap(await _client.rpc('generate_student_report_card', params: {
      'p_student_profile_id': studentProfileId,
      'p_term_id': termId,
    }));
  }

  Future<List<Map<String, dynamic>>> getReportCardsOverview({
    String? academicYearId,
    String? termId,
    String? classSectionId,
  }) async {
    final yearId = _requiredId(academicYearId, 'academicYearId');
    final resolvedTermId = _requiredId(termId, 'termId');
    final sectionId = _requiredId(classSectionId, 'classSectionId');
    final payload = _asMap(await _client.rpc(
      'get_report_cards_overview',
      params: {
        'p_academic_year_id': yearId,
        'p_term_id': resolvedTermId,
        'p_class_section_id': sectionId,
      },
    ));
    return _mapList(payload['students']);
  }

  Future<void> setReportCardStatus({
    required String reportCardId,
    required String status,
  }) async {
    await _client.rpc('set_report_card_status', params: {
      'p_report_card_id': reportCardId,
      'p_status': status,
    });
  }

  Future<int> bulkPublishReportCards({
    required String academicYearId,
    required String termId,
    String? classSectionId,
  }) async {
    final sectionId = _requiredId(classSectionId, 'classSectionId');
    final res = await _client.rpc('bulk_publish_report_cards', params: {
      'p_academic_year_id': academicYearId,
      'p_term_id': termId,
      'p_class_section_id': sectionId,
    });
    return (res as num?)?.toInt() ?? 0;
  }

  Future<Map<String, dynamic>> getParentDashboard(
    String studentProfileId,
  ) async {
    return _asMap(await _client.rpc('get_parent_dashboard', params: {
      'p_student_profile_id': studentProfileId,
    }));
  }

  Future<Map<String, dynamic>> getParentChildSummary(
    String studentProfileId,
  ) async {
    return _asMap(await _client.rpc('get_parent_child_summary', params: {
      'p_student_profile_id': studentProfileId,
    }));
  }

  Future<Map<String, dynamic>> getParentAcademics({
    required String studentProfileId,
    String? termId,
  }) async {
    return _asMap(await _client.rpc('get_parent_academics', params: {
      'p_student_profile_id': studentProfileId,
      'p_term_id': termId,
    }));
  }

  Future<Map<String, dynamic>> getParentFees({
    required String studentProfileId,
    String? academicYearId,
    String? termId,
  }) async {
    return _asMap(await _client.rpc('get_parent_fees', params: {
      'p_student_profile_id': studentProfileId,
      'p_academic_year_id': academicYearId,
      'p_term_id': termId,
    }));
  }

  Future<Map<String, dynamic>> getFinanceDashboardMetrics() async {
    final payload =
        _asMap(await _client.rpc('get_finance_dashboard_metrics'));

    // Compatibility aliases for the frozen Finance dashboard UI. These map
    // directly to authoritative backend fields; they do not change currency
    // semantics. Multi-currency scalar aggregation remains a backend/UI debt
    // and must not be presented as currency-safe reporting.
    return <String, dynamic>{
      ...payload,
      'total_collected': payload['total_paid'],
      'total_outstanding': payload['outstanding'],
      'total_expenses': payload['expenses_this_month'],
    };
  }

  Future<Map<String, dynamic>> reconcilePaymentToInvoice({
    required String paymentId,
    required String invoiceId,
  }) async {
    return _asMap(await _client.rpc('reconcile_payment_to_invoice', params: {
      'p_payment_id': paymentId,
      'p_invoice_id': invoiceId,
    }));
  }

  Future<Map<String, dynamic>> generateInvoicesFromFeeStructure({
    required String feeStructureId,
    DateTime? dueDate,
    bool includeOptional = false,
  }) async {
    return _asMap(await _client.rpc(
      'generate_invoices_from_fee_structure',
      params: {
        'p_fee_structure_id': feeStructureId,
        'p_due_date': dueDate == null ? null : _date(dueDate),
        'p_include_optional': includeOptional,
      },
    ));
  }

  Future<Map<String, dynamic>> getAttendanceReport({
    required String academicYearId,
    String? termId,
    String? classSectionId,
  }) async {
    return _asMap(await _client.rpc('get_attendance_report', params: {
      'p_academic_year_id': academicYearId,
      'p_term_id': termId,
      'p_class_section_id': classSectionId,
    }));
  }

  Future<Map<String, dynamic>> getAcademicPerformanceReport({
    required String academicYearId,
    String? termId,
    String? classSectionId,
  }) async {
    return _asMap(
        await _client.rpc('get_academic_performance_report', params: {
      'p_academic_year_id': academicYearId,
      'p_term_id': termId,
      'p_class_section_id': classSectionId,
    }));
  }

  /// Date-window fee report. Uses the unambiguous wrapper RPC rather than the
  /// overloaded PostgreSQL function name.
  Future<Map<String, dynamic>> getFeeCollectionsReport({
    required String academicYearId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    return _asMap(await _client.rpc(
      'get_fee_collections_report_by_date',
      params: {
        'p_academic_year_id': academicYearId,
        'p_start_date': startDate == null ? null : _date(startDate),
        'p_end_date': endDate == null ? null : _date(endDate),
      },
    ));
  }

  /// Academic-scope fee report for Reports & Analytics.
  Future<Map<String, dynamic>> getFeeCollectionsReportByScope({
    required String academicYearId,
    String? termId,
    String? classSectionId,
  }) async {
    return _asMap(await _client.rpc(
      'get_fee_collections_report_by_scope',
      params: {
        'p_academic_year_id': academicYearId,
        'p_term_id': termId,
        'p_class_section_id': classSectionId,
      },
    ));
  }

  Future<Map<String, dynamic>> getAdmissionsPipeline() async {
    return _asMap(await _client.rpc('get_admissions_pipeline'));
  }

  Future<Map<String, dynamic>> getFleetDashboard() async {
    return _asMap(await _client.rpc('get_fleet_dashboard'));
  }

  Future<Map<String, dynamic>> getLibraryDashboard() async {
    return _asMap(await _client.rpc('get_library_dashboard'));
  }

  Future<Map<String, dynamic>> getBehaviorDashboard() async {
    return _asMap(await _client.rpc('get_behavior_dashboard'));
  }

  Future<Map<String, dynamic>> getSuperAdminPlatformMetrics() async {
    final payload =
        _asMap(await _client.rpc('get_super_admin_platform_metrics'));

    // Compatibility aliases for the frozen Super Admin dashboard. Keep the
    // backend names as source of truth while preventing old UI keys from
    // rendering valid platform metrics as zero.
    return <String, dynamic>{
      ...payload,
      'total_schools': payload['schools_total'],
      'active_schools': payload['schools_active'],
      'trial_schools': payload['schools_trial'],
      'platform_users': payload['users_total'],
      'total_users': payload['users_total'],
      'needs_attention':
          ((payload['schools_past_due'] as num?)?.toInt() ?? 0) +
              ((payload['schools_suspended'] as num?)?.toInt() ?? 0),
    };
  }

  Future<List<Map<String, dynamic>>> getSuperAdminSchoolsDirectory() async {
    final payload =
        _asMap(await _client.rpc('get_super_admin_schools_directory'));
    return _mapList(payload['schools']);
  }

  Future<void> markAllNotificationsRead() async {
    await _client.rpc('mark_all_notifications_read');
  }

  static Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  static List<Map<String, dynamic>> _mapList(dynamic value) {
    if (value is! List) return <Map<String, dynamic>>[];
    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }

  static String _requiredId(String? value, String name) {
    if (value == null || value.trim().isEmpty) {
      throw ArgumentError('$name is required by the backend RPC contract.');
    }
    return value;
  }

  static String _date(DateTime value) => value.toIso8601String().split('T')[0];
}
