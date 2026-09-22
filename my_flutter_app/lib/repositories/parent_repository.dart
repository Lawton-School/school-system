import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';
import '../services/rpc_client.dart';

/// Clean Architecture Repository for Parent operations.
/// All child access is strictly constrained by authorized relationships in
/// `public.user_relationships`, deriving the parent profile directly from
/// the active authenticated session.
class ParentRepository {
  final SupabaseClient _client;
  final RpcClient _rpc;
  final String? Function() _getActiveProfileId;

  ParentRepository({
    required this._client,
    required this._rpc,
    required this._getActiveProfileId,
  });

  /// Fetches authorized children for the currently active parent profile.
  /// Strictly resolves parent_id from active session, preventing unauthorized student access.
  Future<List<AuthorizedChild>> fetchAuthorizedChildren() async {
    final parentProfileId = _getActiveProfileId();
    if (parentProfileId == null || parentProfileId.isEmpty) {
      debugPrint('[ParentRepository] No active parent profile found in session');
      return [];
    }

    try {
      final response = await _client
          .from('user_relationships')
          .select('id, relationship_type, student_id, student:profiles!user_relationships_student_id_fkey(id, full_name, role, avatar_url, school_id)')
          .eq('parent_id', parentProfileId)
          .isFilter('deleted_at', null);

      final list = (response as List<dynamic>?) ?? [];
      return list.map((m) {
        final map = Map<String, dynamic>.from(m as Map);
        return AuthorizedChild.fromRelationshipMap(map);
      }).toList();
    } catch (e) {
      debugPrint('[ParentRepository] fetchAuthorizedChildren error: $e');
      return [];
    }
  }

  /// Screen 06: Authoritative Parent Dashboard for authorized child
  /// Multi-currency separation is preserved via [FinanceCurrencySummary].
  Future<ParentDashboardData?> fetchParentDashboard({
    required String studentProfileId,
    required String studentName,
    required String className,
  }) async {
    try {
      final res = await _rpc.getParentDashboard(studentProfileId);
      if (res.isNotEmpty) {
        return ParentDashboardData.fromMap(studentProfileId, studentName, className, res);
      }
    } catch (e) {
      debugPrint('[ParentRepository] fetchParentDashboard RPC error: $e');
    }
    return null;
  }

  /// Screen 07: Authoritative 360 summary for parent academics view
  Future<Map<String, dynamic>> fetchStudent360(String studentProfileId) async {
    return await _rpc.getStudent360Summary(studentProfileId);
  }

  /// Screen 08: Live Invoices for student, preserving multi-currency separation
  /// Never introduces fake balance_due; calculates: total_amount - paid_amount.
  Future<List<InvoiceModel>> fetchStudentInvoices(String studentProfileId) async {
    try {
      final response = await _client
          .from('invoices')
          .select('*, fee_type:fee_types(*), items:invoice_items(*)')
          .eq('student_profile_id', studentProfileId)
          .isFilter('deleted_at', null)
          .order('due_date', ascending: false);

      return (response as List<dynamic>)
          .map((m) => InvoiceModel.fromMap(Map<String, dynamic>.from(m as Map)))
          .toList();
    } catch (e) {
      debugPrint('[ParentRepository] fetchStudentInvoices error: $e');
      return [];
    }
  }

  /// Screen 08: Live Payments for student
  Future<List<PaymentModel>> fetchStudentPayments(String studentProfileId) async {
    try {
      final response = await _client
          .from('payments')
          .select('*')
          .eq('student_profile_id', studentProfileId)
          .isFilter('deleted_at', null)
          .order('payment_date', ascending: false);

      return (response as List<dynamic>)
          .map((m) => PaymentModel.fromMap(Map<String, dynamic>.from(m as Map)))
          .toList();
    } catch (e) {
      debugPrint('[ParentRepository] fetchStudentPayments error: $e');
      return [];
    }
  }
}
