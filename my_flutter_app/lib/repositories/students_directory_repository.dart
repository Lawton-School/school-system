import '../services/rpc_client.dart';

class StudentsDirectoryRepository {
  final RpcClient _rpc;

  const StudentsDirectoryRepository(this._rpc);

  Future<List<Map<String, dynamic>>> fetchStudents(
    String academicYearId,
  ) {
    return _rpc.getStudentsDirectory(academicYearId: academicYearId);
  }
}
