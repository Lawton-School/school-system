import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/rpc_client.dart';

/// Server-authoritative repository for Screen 15 — Admissions.
///
/// Reads the admissions pipeline through the verified RPC contract. Status
/// transitions and enrollment linking are performed only by server RPCs so the
/// client cannot bypass tenant, role, status, or school checks.
class AdmissionsRepository {
  final SupabaseClient _client;
  final RpcClient _rpc;

  AdmissionsRepository({
    required SupabaseClient client,
    required RpcClient rpc,
  }) : this._(client, rpc);

  AdmissionsRepository._(this._client, this._rpc);

  Future<Map<String, dynamic>> fetchPipeline() => _rpc.getAdmissionsPipeline();

  Future<List<Map<String, dynamic>>> fetchDocuments(String applicationId) async {
    if (applicationId.trim().isEmpty) return const [];

    final raw = await _client
        .from('admissions_documents')
        .select(
          'id, application_id, document_type, document_url, created_at, updated_at',
        )
        .eq('application_id', applicationId)
        .isFilter('deleted_at', null)
        .order('created_at', ascending: false);

    return _mapList(raw);
  }

  /// Existing student profiles eligible to be selected by staff when linking
  /// an accepted application. The RPC still re-validates role and school.
  Future<List<Map<String, dynamic>>> fetchStudentCandidates() async {
    final raw = await _client
        .from('profiles')
        .select('id, first_name, last_name, email, status')
        .eq('role', 'student')
        .eq('status', 'active')
        .isFilter('deleted_at', null)
        .order('last_name', ascending: true)
        .order('first_name', ascending: true);

    return _mapList(raw).map((profile) {
      final first = profile['first_name']?.toString().trim() ?? '';
      final last = profile['last_name']?.toString().trim() ?? '';
      return <String, dynamic>{
        ...profile,
        'full_name': '$first $last'.trim(),
      };
    }).toList(growable: false);
  }

  Future<Map<String, dynamic>> setStatus({
    required String applicationId,
    required String status,
    String? reviewNotes,
  }) async {
    const allowed = {
      'applied',
      'review',
      'info_requested',
      'accepted',
      'waitlisted',
      'rejected',
    };
    if (!allowed.contains(status)) {
      throw ArgumentError.value(status, 'status', 'Unsupported admission status.');
    }

    final response = await _client.rpc(
      'set_admission_status',
      params: {
        'p_application_id': applicationId,
        'p_status': status,
        'p_review_notes': _nullableTrim(reviewNotes),
      },
    );
    return _asMap(response);
  }

  Future<Map<String, dynamic>> linkEnrolledStudent({
    required String applicationId,
    required String studentProfileId,
  }) async {
    final response = await _client.rpc(
      'link_admission_to_enrolled_student',
      params: {
        'p_application_id': applicationId,
        'p_student_profile_id': studentProfileId,
      },
    );
    return _asMap(response);
  }

  static String? _nullableTrim(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  static Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return const <String, dynamic>{};
  }

  static List<Map<String, dynamic>> _mapList(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }
}
