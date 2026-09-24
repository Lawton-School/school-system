import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/rpc_client.dart';

class BehaviorRepository {
  final SupabaseClient _client;
  final RpcClient _rpc;

  const BehaviorRepository({required SupabaseClient client, required RpcClient rpc})
      : _client = client,
        _rpc = rpc;

  Future<Map<String, dynamic>> fetchDashboard() {
    return _rpc.getBehaviorDashboard();
  }

  Future<List<Map<String, dynamic>>> fetchStudents(String schoolId) async {
    final response = await _client
        .from('profiles')
        .select('id, first_name, last_name, status')
        .eq('school_id', schoolId)
        .eq('role', 'student')
        .eq('status', 'active')
        .isFilter('deleted_at', null)
        .order('first_name')
        .order('last_name');

    return (response as List)
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList(growable: false);
  }

  Future<void> createCase({
    required String schoolId,
    required String loggedByProfileId,
    required String studentProfileId,
    required String type,
    required String severity,
    required int points,
    required String description,
    required DateTime incidentDate,
  }) async {
    await _client.from('behavioral_logs').insert({
      'school_id': schoolId,
      'student_profile_id': studentProfileId,
      'logged_by_profile_id': loggedByProfileId,
      'type': type,
      'severity': severity,
      'points': points,
      'description': description.trim(),
      'incident_date': incidentDate.toIso8601String().split('T').first,
      'status': 'open',
    });
  }

  Future<void> updateCase({
    required String behaviorId,
    required String status,
    String? followUpNotes,
  }) async {
    await _client.rpc('update_behavior_case', params: {
      'p_behavior_id': behaviorId,
      'p_status': status,
      'p_follow_up_notes': _nullableText(followUpNotes),
    });
  }

  Future<void> markGuardianNotified(String behaviorId) async {
    await _client.rpc('mark_behavior_guardian_notified', params: {
      'p_behavior_id': behaviorId,
    });
  }

  static String? _nullableText(String? value) {
    final trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }
}
