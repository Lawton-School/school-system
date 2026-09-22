import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/database/app_database.dart';
import '../core/sync_engine.dart';
import '../models/models.dart';
import '../services/rpc_client.dart';

/// Clean Architecture Repository for Teacher operations.
/// All queries flow through authoritative Supabase RPCs, with
/// optimistic offline mutation queuing backed by Drift AppDatabase.
class TeacherRepository {
  final SupabaseClient _client;
  final RpcClient _rpc;
  final AppDatabase _db;
  final SyncEngine _syncEngine;

  TeacherRepository({
    required this._client,
    required this._rpc,
    required this._db,
    required this._syncEngine,
  });

  AppDatabase get database => _db;

  /// Screen 03: Live Teacher Dashboard Metrics & Schedule
  Future<TeacherDashboardMetrics> fetchDashboardMetrics() async {
    try {
      final res = await _rpc.getTeacherDashboardMetrics();
      if (res.isNotEmpty) {
        return TeacherDashboardMetrics.fromMap(res);
      }
    } catch (e) {
      debugPrint('[TeacherRepository] fetchDashboardMetrics error: $e');
    }
    // Return empty metrics if no data from backend
    return const TeacherDashboardMetrics();
  }

  /// Screen 04: Live Attendance Roll Call roster for date and class section
  Future<Map<String, dynamic>> fetchAttendanceRollCall({
    required String classSectionId,
    required DateTime date,
  }) async {
    return await _rpc.getAttendanceRollCall(
      classSectionId: classSectionId,
      date: date,
    );
  }

  /// Screen 04: Submit or Queue Attendance Roll Call
  /// Enforces offline durability via Drift queue when offline.
  Future<void> submitAttendanceRollCall({
    required String schoolId,
    required String classSectionId,
    required DateTime date,
    required List<Map<String, dynamic>> records,
  }) async {
    final dateStr = date.toIso8601String().split('T')[0];

    try {
      // Try live upsert to Supabase daily_attendance table
      final rows = records.map((r) => {
        'school_id': schoolId,
        'class_section_id': classSectionId,
        'student_id': r['student_id'],
        'date': dateStr,
        'status': r['status'],
        'remarks': r['remarks'],
      }).toList();

      await _client.from('daily_attendance').upsert(
        rows,
        onConflict: 'school_id,class_section_id,student_id,date',
      );
      debugPrint('[TeacherRepository] Attendance submitted live to Supabase');
    } catch (e) {
      debugPrint('[TeacherRepository] Network error, enqueueing attendance in Drift: $e');
      // Queue mutation into Drift OfflineQueueEntries
      for (final r in records) {
        await _syncEngine.enqueueAction(
          schoolId: schoolId,
          tableName: 'daily_attendance',
          action: SyncAction.insert,
          payload: {
            'school_id': schoolId,
            'class_section_id': classSectionId,
            'student_id': r['student_id'],
            'date': dateStr,
            'status': r['status'],
            'remarks': r['remarks'],
          },
        );
      }
    }
  }

  /// Screen 05: Authoritative Teacher Gradebook Matrix
  Future<Map<String, dynamic>> fetchGradebook({
    required String classSectionId,
    required String subjectId,
    required String termId,
  }) async {
    return await _rpc.getTeacherGradebook(
      classSectionId: classSectionId,
      subjectId: subjectId,
      termId: termId,
    );
  }

  /// Screen 05: Update student grade record
  /// Enforces: 0 <= score <= max_points locally, while PostgreSQL remains authoritative.
  Future<void> saveGradeRecord({
    required String schoolId,
    required String assessmentId,
    required String studentProfileId,
    required double score,
    required double maxPoints,
    String? remarks,
  }) async {
    if (score < 0 || score > maxPoints) {
      throw ArgumentError('Score $score must be between 0 and maximum points ($maxPoints)');
    }

    try {
      await _client.from('grade_records').upsert({
        'school_id': schoolId,
        'assessment_id': assessmentId,
        'student_profile_id': studentProfileId,
        'points_obtained': score,
        'feedback': remarks,
      }, onConflict: 'school_id,assessment_id,student_profile_id');
      debugPrint('[TeacherRepository] Grade record saved live');
    } catch (e) {
      debugPrint('[TeacherRepository] Network error, enqueueing grade record: $e');
      await _syncEngine.enqueueAction(
        schoolId: schoolId,
        tableName: 'grade_records',
        action: SyncAction.insert,
        payload: {
          'school_id': schoolId,
          'assessment_id': assessmentId,
          'student_profile_id': studentProfileId,
          'points_obtained': score,
          'feedback': remarks,
        },
      );
    }
  }

  /// Screen 26: Authoritative Gradebook Setup & Weight Validation
  Future<Map<String, dynamic>> fetchGradebookSetup({
    required String classSectionId,
    required String subjectId,
    required String termId,
  }) async {
    return await _rpc.getGradebookSetup(
      classSectionId: classSectionId,
      subjectId: subjectId,
      termId: termId,
    );
  }
}
