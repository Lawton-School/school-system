import '../services/rpc_client.dart';

/// Repository for student-facing authoritative summary data.
///
/// Student identity, enrollment, attendance, academics, finance and activity
/// come from the server-side Student 360 contract. LMS courses/assignments are
/// deliberately not inferred here because the current schema has no verified
/// student-to-course enrollment relationship.
class StudentRepository {
  final RpcClient _rpc;

  const StudentRepository(this._rpc);

  Future<Map<String, dynamic>> fetchStudent360(String studentProfileId) {
    return _rpc.getStudent360Summary(studentProfileId);
  }
}
