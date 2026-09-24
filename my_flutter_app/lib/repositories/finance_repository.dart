import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/rpc_client.dart';

/// Server-authoritative finance repository for Screens 13 and 14.
///
/// These screens intentionally use normalized maps instead of the historical
/// InvoiceModel/PaymentModel because the live backend now includes currency,
/// invoice numbers, nullable payment invoice links, provider metadata and
/// reconciliation state that those older models do not represent.
class FinanceRepository {
  final SupabaseClient _client;
  final RpcClient _rpc;

  FinanceRepository({
    required SupabaseClient client,
    required RpcClient rpc,
  })  : _client = client,
        _rpc = rpc;

  Future<List<Map<String, dynamic>>> fetchInvoices() async {
    final raw = await _client
        .from('invoices')
        .select(
          'id, school_id, student_profile_id, academic_year_id, '
          'total_amount, paid_amount, due_date, status, invoice_number, '
          'currency, issued_at, fee_structure_id, notes, created_at, updated_at',
        )
        .isFilter('deleted_at', null)
        .order('issued_at', ascending: false);

    final rows = _mapList(raw);
    if (rows.isEmpty) return const [];

    final studentIds = rows
        .map((row) => row['student_profile_id']?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false);
    final structureIds = rows
        .map((row) => row['fee_structure_id']?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false);

    final students = <String, Map<String, dynamic>>{};
    if (studentIds.isNotEmpty) {
      final studentRaw = await _client
          .from('profiles')
          .select('id, first_name, last_name, email')
          .inFilter('id', studentIds)
          .isFilter('deleted_at', null);
      for (final student in _mapList(studentRaw)) {
        final id = student['id']?.toString();
        if (id != null && id.isNotEmpty) students[id] = student;
      }
    }

    final structures = <String, Map<String, dynamic>>{};
    if (structureIds.isNotEmpty) {
      final structureRaw = await _client
          .from('fee_structures')
          .select('id, name, currency, status')
          .inFilter('id', structureIds)
          .isFilter('deleted_at', null);
      for (final structure in _mapList(structureRaw)) {
        final id = structure['id']?.toString();
        if (id != null && id.isNotEmpty) structures[id] = structure;
      }
    }

    return rows.map((row) {
      final student = students[row['student_profile_id']?.toString()];
      final structure = structures[row['fee_structure_id']?.toString()];
      final total = _number(row['total_amount']);
      final paid = _number(row['paid_amount']);

      return <String, dynamic>{
        ...row,
        'student_name': _profileName(student),
        'student_email': student?['email'],
        'fee_structure_name': structure?['name'],
        'balance': (total - paid).clamp(0.0, double.infinity),
      };
    }).toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> fetchPayments() async {
    final raw = await _client
        .from('payments')
        .select(
          'id, school_id, invoice_id, amount, currency, payment_method, '
          'transaction_reference, status, provider, provider_reference, '
          'receipt_url, recorded_by_profile_id, paid_at, metadata, '
          'created_at, updated_at',
        )
        .isFilter('deleted_at', null)
        .order('paid_at', ascending: false);

    final rows = _mapList(raw);
    if (rows.isEmpty) return const [];

    final invoiceIds = rows
        .map((row) => row['invoice_id']?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false);

    final invoices = <String, Map<String, dynamic>>{};
    final studentIds = <String>{};
    if (invoiceIds.isNotEmpty) {
      final invoiceRaw = await _client
          .from('invoices')
          .select(
            'id, invoice_number, student_profile_id, currency, total_amount, '
            'paid_amount, status, due_date',
          )
          .inFilter('id', invoiceIds)
          .isFilter('deleted_at', null);
      for (final invoice in _mapList(invoiceRaw)) {
        final id = invoice['id']?.toString();
        if (id == null || id.isEmpty) continue;
        invoices[id] = invoice;
        final studentId = invoice['student_profile_id']?.toString();
        if (studentId != null && studentId.isNotEmpty) studentIds.add(studentId);
      }
    }

    final students = <String, Map<String, dynamic>>{};
    if (studentIds.isNotEmpty) {
      final studentRaw = await _client
          .from('profiles')
          .select('id, first_name, last_name')
          .inFilter('id', studentIds.toList(growable: false))
          .isFilter('deleted_at', null);
      for (final student in _mapList(studentRaw)) {
        final id = student['id']?.toString();
        if (id != null && id.isNotEmpty) students[id] = student;
      }
    }

    return rows.map((row) {
      final invoice = invoices[row['invoice_id']?.toString()];
      final student = invoice == null
          ? null
          : students[invoice['student_profile_id']?.toString()];
      return <String, dynamic>{
        ...row,
        'invoice_number': invoice?['invoice_number'],
        'invoice_status': invoice?['status'],
        'student_name': _profileName(student),
      };
    }).toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> fetchActiveFeeStructures() async {
    final raw = await _client
        .from('fee_structures')
        .select(
          'id, academic_year_id, term_id, class_id, class_section_id, '
          'name, currency, default_due_date, status',
        )
        .eq('status', 'active')
        .isFilter('deleted_at', null)
        .order('name', ascending: true);
    return _mapList(raw);
  }

  Future<Map<String, dynamic>> generateInvoices({
    required String feeStructureId,
    DateTime? dueDate,
    bool includeOptional = false,
  }) {
    return _rpc.generateInvoicesFromFeeStructure(
      feeStructureId: feeStructureId,
      dueDate: dueDate,
      includeOptional: includeOptional,
    );
  }

  Future<Map<String, dynamic>> reconcilePayment({
    required String paymentId,
    required String invoiceId,
  }) {
    return _rpc.reconcilePaymentToInvoice(
      paymentId: paymentId,
      invoiceId: invoiceId,
    );
  }

  static List<Map<String, dynamic>> _mapList(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList(growable: false);
  }

  static double _number(dynamic value) => value is num ? value.toDouble() : 0.0;

  static String _profileName(Map<String, dynamic>? profile) {
    if (profile == null) return 'Unknown Student';
    final first = profile['first_name']?.toString().trim() ?? '';
    final last = profile['last_name']?.toString().trim() ?? '';
    final name = '$first $last'.trim();
    return name.isEmpty ? 'Unknown Student' : name;
  }
}
