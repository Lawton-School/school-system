import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';
import 'legacy_services.dart' as legacy;

/// Hardened compatibility facade for the existing Finance UI/providers.
///
/// It preserves the existing public API while replacing the two unsafe
/// client-authoritative paths:
/// - batch invoice generation now delegates to the authoritative
///   `generate_invoices_from_fee_structure` RPC;
/// - payment recording no longer mutates invoice totals/status in Flutter;
///   the database reconciliation trigger remains authoritative.
class SchoolFinanceService extends legacy.SchoolFinanceService {
  final SupabaseClient _client;

  SchoolFinanceService(this._client) : super(_client);

  @override
  Future<int> generateBatchInvoices({
    required String schoolId,
    required String classSectionId,
    required String academicYearId,
    required List<Map<String, dynamic>> feeItems,
    required DateTime dueDate,
  }) async {
    final selectedFeeTypeIds = feeItems
        .map((item) => item['fee_type_id']?.toString())
        .whereType<String>()
        .toSet();

    if (selectedFeeTypeIds.isEmpty) {
      throw ArgumentError('Select at least one configured fee type.');
    }

    final structures = await _client
        .from('fee_structures')
        .select('id, class_section_id, academic_year_id, status')
        .eq('school_id', schoolId)
        .eq('academic_year_id', academicYearId)
        .eq('class_section_id', classSectionId)
        .eq('status', 'active')
        .isFilter('deleted_at', null);

    for (final raw in structures as List) {
      final structure = Map<String, dynamic>.from(raw as Map);
      final structureId = structure['id']?.toString();
      if (structureId == null || structureId.isEmpty) continue;

      final rows = await _client
          .from('fee_structure_items')
          .select('fee_type_id, is_required')
          .eq('fee_structure_id', structureId)
          .isFilter('deleted_at', null);

      final allIds = <String>{};
      final requiredIds = <String>{};
      for (final itemRaw in rows as List) {
        final item = Map<String, dynamic>.from(itemRaw as Map);
        final id = item['fee_type_id']?.toString();
        if (id == null || id.isEmpty) continue;
        allIds.add(id);
        if (item['is_required'] == true) requiredIds.add(id);
      }

      final matchesRequired = _sameSet(selectedFeeTypeIds, requiredIds);
      final matchesAll = _sameSet(selectedFeeTypeIds, allIds);
      if (!matchesRequired && !matchesAll) continue;

      final result = await _client.rpc(
        'generate_invoices_from_fee_structure',
        params: {
          'p_fee_structure_id': structureId,
          'p_due_date': dueDate.toIso8601String().split('T')[0],
          'p_include_optional': matchesAll && !_sameSet(allIds, requiredIds),
        },
      );

      final map = Map<String, dynamic>.from(result as Map);
      return (map['created_count'] as num?)?.toInt() ?? 0;
    }

    throw StateError(
      'No active fee structure matches the selected class, academic year and fee types. '
      'Configure the fee structure first so invoices can be generated atomically on the server.',
    );
  }

  @override
  Future<PaymentModel> recordPayment({
    required String schoolId,
    required String invoiceId,
    required double amount,
    required String paymentMethod,
    required double currentPaidAmount,
    required double totalAmount,
  }) async {
    if (amount <= 0) {
      throw ArgumentError.value(amount, 'amount', 'Payment amount must be greater than zero.');
    }

    final invoice = await _client
        .from('invoices')
        .select('id, school_id, currency')
        .eq('id', invoiceId)
        .eq('school_id', schoolId)
        .isFilter('deleted_at', null)
        .single();

    final currency = invoice['currency']?.toString();
    final txRef = 'TXN-${DateTime.now().millisecondsSinceEpoch}';

    final payment = await _client.from('payments').insert({
      'school_id': schoolId,
      'invoice_id': invoiceId,
      'amount': amount,
      'currency': currency,
      'payment_method': paymentMethod,
      'transaction_reference': txRef,
      'status': 'confirmed',
      'paid_at': DateTime.now().toIso8601String(),
    }).select().single();

    // Do not update invoices here. Production triggers recalculate paid_amount
    // and status from confirmed payments, preventing client-side race conditions.
    return PaymentModel.fromMap(payment);
  }

  bool _sameSet(Set<String> a, Set<String> b) {
    return a.length == b.length && a.containsAll(b);
  }
}
