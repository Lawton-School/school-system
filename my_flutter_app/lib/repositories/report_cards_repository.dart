import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/rpc_client.dart';

class ReportCardsRepository {
  final SupabaseClient _client;
  final RpcClient _rpc;

  const ReportCardsRepository({required SupabaseClient client, required RpcClient rpc})
      : _client = client,
        _rpc = rpc;

  Future<Map<String, dynamic>> fetchOverview({
    required String academicYearId,
    required String termId,
    required String classSectionId,
  }) async {
    final response = await _client.rpc('get_report_cards_overview', params: {
      'p_academic_year_id': academicYearId,
      'p_term_id': termId,
      'p_class_section_id': classSectionId,
    });
    return Map<String, dynamic>.from(response as Map);
  }

  Future<void> generateStudent({
    required String studentProfileId,
    required String termId,
  }) async {
    await _rpc.generateStudentReportCard(
      studentProfileId: studentProfileId,
      termId: termId,
    );
  }

  Future<void> setStatus({
    required String reportCardId,
    required String status,
  }) {
    return _rpc.setReportCardStatus(
      reportCardId: reportCardId,
      status: status,
    );
  }

  Future<int> bulkPublish({
    required String academicYearId,
    required String termId,
    required String classSectionId,
  }) {
    return _rpc.bulkPublishReportCards(
      academicYearId: academicYearId,
      termId: termId,
      classSectionId: classSectionId,
    );
  }
}
