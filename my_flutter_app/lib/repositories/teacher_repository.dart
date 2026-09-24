import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/database/app_database.dart';
import '../core/sync_engine.dart';
import '../models/models.dart';
import '../services/rpc_client.dart';

/// Clean Architecture Repository for Teacher operations.
/// All reads flow through authoritative Supabase RPCs, while safe teacher
/// mutations may be queued in Drift when the network write fails.
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

  Future<TeacherDashboardMetrics> fetchDashboardMetrics() async {
    try {
      final res = await _rpc.getTeacherDashboardMetrics();
      if (res.isNotEmpty) return TeacherDashboardMetrics.fromMap(res);
    } catch (e) {
      debugPrint('[TeacherRepository] fetchDashboardMetrics error: $e');
    }
    return const TeacherDashboardMetrics();
  }

  Future<Map<String, dynamic>> fetchAttendanceRollCall({
    required String classSectionId,
    required DateTime date,
  }) {
    return _rpc.getAttendanceRollCall(
      classSectionId: classSectionId,
      date: date,
    );
  }

  Future<void> submitAttendanceRollCall({
    required String schoolId,
    required String classSectionId,
    required DateTime date,
    required List<Map<String, dynamic>> records,
  }) async {
    final dateStr = date.toIso8601String().split('T')[0];
    final rows = records.map((record) {
      // Accept the previous UI key temporarily, but never send it to Supabase.
      final studentProfileId =
          record['student_profile_id'] ?? record['student_id'];
      if (studentProfileId == null || studentProfileId.toString().isEmpty) {
        throw ArgumentError('Attendance record requires student_profile_id.');
      }
      return <String, dynamic>{
        'school_id': schoolId,
        'class_section_id': classSectionId,
        'student_profile_id': studentProfileId,
        'date': dateStr,
        'status': record['status'],
        'remarks': record['remarks'],
      };
    }).toList(growable: false);

    try {
      await _client.from('daily_attendance').upsert(
        rows,
        onConflict: 'student_profile_id,date',
      );
      debugPrint('[TeacherRepository] Attendance submitted live to Supabase');
    } catch (e) {
      debugPrint(
        '[TeacherRepository] Attendance write failed; queueing safe mutation: $e',
      );
      for (final row in rows) {
        await _syncEngine.enqueueAction(
          schoolId: schoolId,
          tableName: 'daily_attendance',
          action: SyncAction.insert,
          payload: row,
        );
      }
    }
  }

  Future<Map<String, dynamic>> fetchGradebook({
    required String classSectionId,
    required String subjectId,
    required String termId,
  }) {
    return _rpc.getTeacherGradebook(
      classSectionId: classSectionId,
      subjectId: subjectId,
      termId: termId,
    );
  }

  Future<void> saveGradeRecord({
    required String schoolId,
    required String assessmentId,
    required String studentProfileId,
    required double score,
    required double maxPoints,
    String? remarks,
  }) async {
    if (score < 0 || score > maxPoints) {
      throw ArgumentError(
        'Score $score must be between 0 and maximum points ($maxPoints)',
      );
    }

    final payload = <String, dynamic>{
      'school_id': schoolId,
      'assessment_id': assessmentId,
      'student_profile_id': studentProfileId,
      'points_obtained': score,
      'teacher_remarks': remarks,
    };

    try {
      await _client.from('grade_records').upsert(
        payload,
        onConflict: 'assessment_id,student_profile_id',
      );
      debugPrint('[TeacherRepository] Grade record saved live');
    } catch (e) {
      debugPrint(
        '[TeacherRepository] Grade write failed; queueing safe mutation: $e',
      );
      await _syncEngine.enqueueAction(
        schoolId: schoolId,
        tableName: 'grade_records',
        action: SyncAction.insert,
        payload: payload,
      );
    }
  }

  Future<Map<String, dynamic>> fetchGradebookSetup({
    required String classSectionId,
    required String subjectId,
    required String termId,
  }) {
    return _rpc.getGradebookSetup(
      classSectionId: classSectionId,
      subjectId: subjectId,
      termId: termId,
    );
  }
}
