import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';
import '../services/rpc_client.dart';

/// Clean Architecture Repository for Parent operations.
/// Child access remains constrained by RLS and `public.user_relationships`.
class ParentRepository {
  final SupabaseClient _client;
  final RpcClient _rpc;
  final String? Function() _getActiveProfileId;

  ParentRepository({
    required this._client,
    required this._rpc,
    required this._getActiveProfileId,
  });

  Future<List<AuthorizedChild>> fetchAuthorizedChildren() async {
    final parentProfileId = _getActiveProfileId();
    if (parentProfileId == null || parentProfileId.isEmpty) {
      debugPrint('[ParentRepository] No active parent profile found in session');
      return [];
    }

    try {
      final response = await _client
          .from('user_relationships')
          .select(
            'id, relationship_type, student_id, '
            'student:profiles!user_relationships_student_id_fkey('
            'id, first_name, last_name, role, avatar_url, school_id)',
          )
          .eq('parent_id', parentProfileId)
          .isFilter('deleted_at', null);

      final list = (response as List<dynamic>?) ?? [];
      return list.map((raw) {
        final map = Map<String, dynamic>.from(raw as Map);
        final studentRaw = map['student'];
        if (studentRaw is Map) {
          final student = Map<String, dynamic>.from(studentRaw);
          final firstName = student['first_name']?.toString().trim() ?? '';
          final lastName = student['last_name']?.toString().trim() ?? '';
          student['full_name'] = '$firstName $lastName'.trim();
          map['student'] = student;
        }
        return AuthorizedChild.fromRelationshipMap(map);
      }).toList(growable: false);
    } catch (e) {
      debugPrint('[ParentRepository] fetchAuthorizedChildren error: $e');
      return [];
    }
  }

  Future<ParentDashboardData?> fetchParentDashboard({
    required String studentProfileId,
    required String studentName,
    required String className,
  }) async {
    try {
      final res = await _rpc.getParentDashboard(studentProfileId);
      if (res.isNotEmpty) {
        return ParentDashboardData.fromMap(
          studentProfileId,
          studentName,
          className,
          res,
        );
      }
    } catch (e) {
      debugPrint('[ParentRepository] fetchParentDashboard RPC error: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>> fetchStudent360(String studentProfileId) {
    return _rpc.getStudent360Summary(studentProfileId);
  }

  Future<List<InvoiceModel>> fetchStudentInvoices(
    String studentProfileId,
  ) async {
    try {
      final response = await _client
          .from('invoices')
          .select('*, invoice_items(*, fee_types(*))')
          .eq('student_profile_id', studentProfileId)
          .isFilter('deleted_at', null)
          .order('due_date', ascending: false);

      return (response as List<dynamic>)
          .map((m) => InvoiceModel.fromMap(
                Map<String, dynamic>.from(m as Map),
              ))
          .toList(growable: false);
    } catch (e) {
      debugPrint('[ParentRepository] fetchStudentInvoices error: $e');
      return [];
    }
  }

  /// Payments do not carry a student_profile_id. Student ownership is derived
  /// through the linked invoice, matching the production schema.
  Future<List<PaymentModel>> fetchStudentPayments(
    String studentProfileId,
  ) async {
    try {
      final response = await _client
          .from('payments')
          .select('*, invoices!inner(student_profile_id)')
          .eq('invoices.student_profile_id', studentProfileId)
          .isFilter('deleted_at', null)
          .order('paid_at', ascending: false);

      return (response as List<dynamic>)
          .map((m) => PaymentModel.fromMap(
                Map<String, dynamic>.from(m as Map),
              ))
          .toList(growable: false);
    } catch (e) {
      debugPrint('[ParentRepository] fetchStudentPayments error: $e');
      return [];
    }
  }
}
