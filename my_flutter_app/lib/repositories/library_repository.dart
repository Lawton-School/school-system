import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/rpc_client.dart';

class LibraryRepository {
  final SupabaseClient _client;
  final RpcClient _rpc;

  const LibraryRepository({required SupabaseClient client, required RpcClient rpc})
      : _client = client,
        _rpc = rpc;

  Future<Map<String, dynamic>> fetchDashboard() {
    return _rpc.getLibraryDashboard();
  }

  Future<List<Map<String, dynamic>>> fetchBorrowers(String schoolId) async {
    final response = await _client
        .from('profiles')
        .select('id, first_name, last_name, role, status')
        .eq('school_id', schoolId)
        .eq('status', 'active')
        .isFilter('deleted_at', null)
        .order('first_name')
        .order('last_name');

    return (response as List)
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> fetchFines(String schoolId) async {
    final response = await _client
        .from('library_fines')
        .select('id, issue_id, amount, status, reason, paid_at, created_at')
        .eq('school_id', schoolId)
        .isFilter('deleted_at', null)
        .order('created_at', ascending: false);

    return (response as List)
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList(growable: false);
  }

  Future<String> fetchSchoolCurrency(String schoolId) async {
    final row = await _client
        .from('schools')
        .select('default_currency')
        .eq('id', schoolId)
        .single();
    return row['default_currency']?.toString().toUpperCase() ?? 'USD';
  }

  Future<void> issueBook({
    required String bookId,
    required String borrowerProfileId,
    required DateTime dueAt,
    String? notes,
  }) async {
    await _client.rpc('issue_library_book', params: {
      'p_book_id': bookId,
      'p_borrower_profile_id': borrowerProfileId,
      'p_due_at': dueAt.toUtc().toIso8601String(),
      'p_notes': _nullableText(notes),
    });
  }

  Future<void> returnBook({
    required String issueId,
    String? notes,
  }) async {
    await _client.rpc('return_library_book', params: {
      'p_issue_id': issueId,
      'p_notes': _nullableText(notes),
    });
  }

  Future<void> createFine({
    required String issueId,
    required double amount,
    String? reason,
  }) async {
    await _client.rpc('create_library_fine', params: {
      'p_issue_id': issueId,
      'p_amount': amount,
      'p_reason': _nullableText(reason),
    });
  }

  Future<void> markFinePaid(String fineId) async {
    await _client.rpc('mark_library_fine_paid', params: {
      'p_fine_id': fineId,
    });
  }

  static String? _nullableText(String? value) {
    final trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }
}
