import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';
import '../services/rpc_client.dart';

/// Clean Architecture Repository for Parent operations.
/// Child access remains constrained by RLS and `public.user_relationships`.
class ParentRepository {
  final SupabaseClient _client;
  final RpcClient _rpc;
  final String? Function() _getActiveProfileId;

  ParentRepository({
    required this._client,
    required this._rpc,
    required this._getActiveProfileId,
  });

  Future<List<AuthorizedChild>> fetchAuthorizedChildren() async {
    final parentProfileId = _getActiveProfileId();
    if (parentProfileId == null || parentProfileId.isEmpty) {
      debugPrint('[ParentRepository] No active parent profile found in session');
      return [];
    }

    try {
      final response = await _client
          .from('user_relationships')
          .select(
            'id, relationship_type, student_id, '
            'student:profiles!user_relationships_student_id_fkey('
            'id, first_name, last_name, role, avatar_url, school_id)',
          )
          .eq('parent_id', parentProfileId)
          .isFilter('deleted_at', null);

      final list = (response as List<dynamic>?) ?? [];
      return list.map((raw) {
        final map = Map<String, dynamic>.from(raw as Map);
        final studentRaw = map['student'];
        if (studentRaw is Map) {
          final student = Map<String, dynamic>.from(studentRaw);
          final firstName = student['first_name']?.toString().trim() ?? '';
          final lastName = student['last_name']?.toString().trim() ?? '';
          student['full_name'] = '$firstName $lastName'.trim();
          map['student'] = student;
        }
        return AuthorizedChild.fromRelationshipMap(map);
      }).toList(growable: false);
    } catch (e) {
      debugPrint('[ParentRepository] fetchAuthorizedChildren error: $e');
      return [];
    }
  }

  Future<ParentDashboardData?> fetchParentDashboard({
    required String studentProfileId,
    required String studentName,
    required String className,
  }) async {
    try {
      final res = await _rpc.getParentDashboard(studentProfileId);
      if (res.isEmpty) return null;

      // The current backend returns Student 360 data plus a nested `dashboard`
      // object. The frozen Parent dashboard model predates that shape, so keep
      // the database contract authoritative and normalize it here.
      final dashboard = _map(res['dashboard']);
      final attendance = _map(res['attendance']);
      final academics = _map(res['academics']);
      final finance = _map(res['finance']);
      final enrollment = _map(res['enrollment']);

      final currentAverage = dashboard['current_average'] as num?;
      final previousAverage = dashboard['previous_average'] as num?;
      final attendanceRate = attendance['attendance_rate'] as num?;
      final assignmentsDue = (dashboard['assignments_due'] as num?)?.toInt() ?? 0;
      final assignmentsOverdue =
          (dashboard['assignments_overdue'] as num?)?.toInt() ?? 0;

      final effectiveClassName = _classLabel(enrollment, fallback: className);
      final normalized = <String, dynamic>{
        ...res,
        'kpis': <String, dynamic>{
          'attendance': attendanceRate,
          'attendance_hint': _attendanceHint(attendance),
          'academic_average': currentAverage,
          'academic_hint': _academicHint(currentAverage, previousAverage),
          'assignments_due': assignmentsDue,
          'assignments_hint': '$assignmentsOverdue overdue',
        },
        'finance': finance,
        'next_lesson': _nextLessonLabel(_map(dashboard['next_lesson'])),
        'latest_result': _latestResultLabel(_map(dashboard['latest_result'])),
        'next_fee_date': _nextFeeLabel(_map(dashboard['next_fee'])),
        'recent_academic_activity': _recentAcademicActivity(academics),
        'announcements': _announcementList(dashboard['latest_announcement']),
      };

      return ParentDashboardData.fromMap(
        studentProfileId,
        studentName,
        effectiveClassName,
        normalized,
      );
    } catch (e) {
      debugPrint('[ParentRepository] fetchParentDashboard RPC error: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>> fetchStudent360(String studentProfileId) {
    return _rpc.getStudent360Summary(studentProfileId);
  }

  Future<Map<String, dynamic>> fetchParentAcademics(
    String studentProfileId, {
    String? termId,
  }) {
    return _rpc.getParentAcademics(
      studentProfileId: studentProfileId,
      termId: termId,
    );
  }

  Future<List<InvoiceModel>> fetchStudentInvoices(
    String studentProfileId,
  ) async {
    try {
      final response = await _client
          .from('invoices')
          .select('*, invoice_items(*, fee_types(*))')
          .eq('student_profile_id', studentProfileId)
          .isFilter('deleted_at', null)
          .order('due_date', ascending: false);

      return (response as List<dynamic>)
          .map((m) => InvoiceModel.fromMap(
                Map<String, dynamic>.from(m as Map),
              ))
          .toList(growable: false);
    } catch (e) {
      debugPrint('[ParentRepository] fetchStudentInvoices error: $e');
      return [];
    }
  }

  /// Payments do not carry a student_profile_id. Student ownership is derived
  /// through the linked invoice, matching the production schema.
  Future<List<PaymentModel>> fetchStudentPayments(
    String studentProfileId,
  ) async {
    try {
      final response = await _client
          .from('payments')
          .select('*, invoices!inner(student_profile_id)')
          .eq('invoices.student_profile_id', studentProfileId)
          .isFilter('deleted_at', null)
          .order('paid_at', ascending: false);

      return (response as List<dynamic>)
          .map((m) => PaymentModel.fromMap(
                Map<String, dynamic>.from(m as Map),
              ))
          .toList(growable: false);
    } catch (e) {
      debugPrint('[ParentRepository] fetchStudentPayments error: $e');
      return [];
    }
  }

  static Map<String, dynamic> _map(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return const <String, dynamic>{};
  }

  static String _classLabel(
    Map<String, dynamic> enrollment, {
    required String fallback,
  }) {
    final className = enrollment['class_name']?.toString().trim() ?? '';
    final sectionName = enrollment['section_name']?.toString().trim() ?? '';
    final label = [className, sectionName]
        .where((part) => part.isNotEmpty)
        .join(' · ');
    return label.isEmpty ? fallback : label;
  }

  static String _attendanceHint(Map<String, dynamic> attendance) {
    final recorded = (attendance['recorded_days'] as num?)?.toInt() ?? 0;
    if (recorded == 0) return 'No attendance recorded';
    final absent = (attendance['absent'] as num?)?.toInt() ?? 0;
    final late = (attendance['late'] as num?)?.toInt() ?? 0;
    return '$recorded recorded · $absent absent · $late late';
  }

  static String _academicHint(num? currentAverage, num? previousAverage) {
    if (currentAverage == null) return 'No approved or published result yet';
    if (previousAverage == null) return 'Latest approved/published term result';
    final change = currentAverage.toDouble() - previousAverage.toDouble();
    final sign = change > 0 ? '+' : '';
    return '$sign${change.toStringAsFixed(1)} pts vs previous term';
  }

  static String? _nextLessonLabel(Map<String, dynamic> lesson) {
    if (lesson.isEmpty) return null;
    final subject = lesson['subject']?.toString().trim() ?? '';
    final start = lesson['start_time']?.toString().trim() ?? '';
    final room = lesson['room']?.toString().trim() ?? '';
    final teacher = lesson['teacher_name']?.toString().trim() ?? '';
    final details = [
      if (start.isNotEmpty) start.length >= 5 ? start.substring(0, 5) : start,
      if (room.isNotEmpty) room,
      if (teacher.isNotEmpty) teacher,
    ].join(' · ');
    if (subject.isEmpty) return details.isEmpty ? null : details;
    return details.isEmpty ? subject : '$subject · $details';
  }

  static String? _latestResultLabel(Map<String, dynamic> result) {
    if (result.isEmpty) return null;
    final subject = result['subject']?.toString().trim() ?? '';
    final assessment = result['assessment_title']?.toString().trim() ?? '';
    final percentage = result['percentage'] as num?;
    final title = [subject, assessment]
        .where((part) => part.isNotEmpty)
        .join(' · ');
    final score = percentage == null ? '' : '${percentage.toStringAsFixed(1)}%';
    if (title.isEmpty) return score.isEmpty ? null : score;
    return score.isEmpty ? title : '$title · $score';
  }

  static String? _nextFeeLabel(Map<String, dynamic> fee) {
    if (fee.isEmpty) return null;
    final currency = fee['currency']?.toString().trim() ?? '';
    final balance = fee['balance'] as num?;
    final dueDate = fee['due_date']?.toString().trim() ?? '';
    final amount = balance == null
        ? ''
        : '${currency.isEmpty ? '' : '$currency '}${balance.toStringAsFixed(2)}';
    if (dueDate.isEmpty) return amount.isEmpty ? null : amount;
    return amount.isEmpty ? 'Due $dueDate' : '$amount · Due $dueDate';
  }

  static List<Map<String, dynamic>> _recentAcademicActivity(
    Map<String, dynamic> academics,
  ) {
    final raw = academics['recent_grades'];
    if (raw is! List) return const <Map<String, dynamic>>[];

    return raw.whereType<Map>().take(6).map((entry) {
      final grade = Map<String, dynamic>.from(entry);
      final subject = grade['subject']?.toString() ?? 'Academic';
      final assessment =
          grade['assessment_title']?.toString() ?? 'Assessment result';
      final percentage = grade['percentage'] as num?;
      final score = percentage == null
          ? ''
          : '${percentage.toStringAsFixed(1)}%';
      return <String, dynamic>{
        'title': assessment,
        'meta': score.isEmpty ? subject : '$subject · $score',
        'badge': 'Result',
        'variant': percentage != null && percentage.toDouble() >= 50
            ? 'success'
            : 'primary',
      };
    }).toList(growable: false);
  }

  static List<Map<String, dynamic>> _announcementList(dynamic value) {
    final announcement = _map(value);
    if (announcement.isEmpty) return const <Map<String, dynamic>>[];
    return <Map<String, dynamic>>[announcement];
  }
}
