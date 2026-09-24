import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';
import 'legacy_services.dart' as legacy;

/// Hardened compatibility facade for Gradebook and Report Card operations.
///
/// Existing read/setup methods remain available through the legacy service,
/// while report-card generation and lifecycle changes are delegated to the
/// authoritative PostgreSQL RPCs. The client no longer calculates or persists
/// report-card results itself.
class AcademicGradebookService extends legacy.AcademicGradebookService {
  final SupabaseClient _client;

  AcademicGradebookService(this._client) : super(_client);

  @override
  Future<ReportCardModel> generateReportCard({
    required String schoolId,
    required String studentProfileId,
    required String academicYearId,
    required String termId,
    double? gpa,
    String? teacherComments,
  }) async {
    final response = await _client.rpc(
      'generate_student_report_card',
      params: {
        'p_student_profile_id': studentProfileId,
        'p_term_id': termId,
      },
    );

    // schoolId, academicYearId and gpa are intentionally not trusted inputs.
    // The server derives the tenant/year and calculates the authoritative
    // academic result. teacherComments are not written here because this RPC
    // does not expose a comments mutation contract.
    return ReportCardModel.fromMap(
      Map<String, dynamic>.from(response as Map),
    );
  }

  @override
  Future<void> setReportCardApproval(String reportCardId, bool approved) async {
    await _client.rpc(
      'set_report_card_status',
      params: {
        'p_report_card_id': reportCardId,
        'p_status': approved ? 'approved' : 'draft',
      },
    );
  }
}
