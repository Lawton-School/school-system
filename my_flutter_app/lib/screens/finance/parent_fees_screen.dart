import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../controllers/parent_controllers.dart';
import '../../core/theme.dart';
import '../../widgets/stitch_widgets.dart';

/// Screen 08: Parent Fees & Multi-Currency Payments.
///
/// Account data is sourced from `get_parent_fees()`. Checkout remains an
/// external dependency until a real payment provider + verified webhook is
/// connected; this screen never fabricates a confirmed payment in Flutter.
class ParentFeesScreen extends ConsumerWidget {
  const ParentFeesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final childrenAsync = ref.watch(parentChildrenProvider);
    final activeChild = ref.watch(activeSelectedChildProvider);
    final selectedChildIndex = ref.watch(selectedChildIndexProvider);

    return Scaffold(
      backgroundColor: AppTheme.stitchBg,
      appBar: AppBar(
        title: const Text(
          'School Fees & Multi-Currency Payments',
          style: TextStyle(
            color: AppTheme.stitchHeading,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Fees',
            onPressed: () {
              final child = ref.read(activeSelectedChildProvider);
              if (child != null) {
                ref.invalidate(parentFeesDataProvider(child.studentId));
                ref.invalidate(parentDashboardDataProvider);
              }
            },
          ),
        ],
      ),
      body: childrenAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Text('Error loading authorized children: $err'),
        ),
        data: (children) {
          if (children.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'No linked children found for this guardian profile.',
                  style: TextStyle(color: AppTheme.stitchMuted),
                ),
              ),
            );
          }

          final currentChild = activeChild ?? children.first;
          final feesAsync = ref.watch(parentFeesDataProvider(currentChild.studentId));

          return feesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(child: Text('Error loading fees: $err')),
            data: (payload) {
              final totals = _listOfMaps(payload['totals']);
              final invoices = _listOfMaps(payload['invoices']);
              final payments = _listOfMaps(payload['payment_history']);
              final paymentMethods = _paymentMethodLabels(payload['payment_methods']);
              final quality = _map(payload['data_quality']);

              final outstanding = invoices
                  .where((invoice) => invoice['status']?.toString() != 'paid')
                  .toList(growable: false);
              final settled = invoices
                  .where((invoice) => invoice['status']?.toString() == 'paid')
                  .toList(growable: false);

              return SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (children.length > 1) ...[
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          const Text(
                            'Select Student:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          ...children.asMap().entries.map((entry) {
                            final index = entry.key;
                            final child = entry.value;
                            return ChoiceChip(
                              label: Text(child.fullName),
                              selected: index == selectedChildIndex,
                              onSelected: (_) {
                                ref.read(selectedChildIndexProvider.notifier).state = index;
                              },
                            );
                          }),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                    _buildMultiCurrencySummary(totals),
                    const SizedBox(height: 20),
                    _buildPaymentMethodsCard(context, paymentMethods),
                    const SizedBox(height: 20),
                    const StitchSectionHeader(
                      title: 'Outstanding Invoices',
                      subtitle: 'Due fee balances requiring settlement',
                    ),
                    const SizedBox(height: 12),
                    if (outstanding.isEmpty)
                      const StitchCard(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(
                            child: Column(
                              children: [
                                Icon(
                                  Icons.check_circle_rounded,
                                  color: Color(0xFF10B981),
                                  size: 36,
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'No outstanding invoices.',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                    color: AppTheme.stitchHeading,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    else
                      ...outstanding.map(
                        (invoice) => _buildInvoiceCard(
                          context,
                          invoice,
                          canPay: true,
                          paymentMethods: paymentMethods,
                        ),
                      ),
                    const SizedBox(height: 24),
                    const StitchSectionHeader(
                      title: 'Settled Invoices',
                      subtitle: 'Historical completed fee accounts',
                    ),
                    const SizedBox(height: 12),
                    if (settled.isEmpty)
                      const StitchCard(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: Center(
                            child: Text(
                              'No settled invoices recorded yet.',
                              style: TextStyle(
                                color: AppTheme.stitchMuted,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      )
                    else
                      ...settled.map(
                        (invoice) => _buildInvoiceCard(
                          context,
                          invoice,
                          canPay: false,
                          paymentMethods: paymentMethods,
                        ),
                      ),
                    const SizedBox(height: 24),
                    _buildPaymentHistory(payments),
                    if (quality['unscoped_invoice_count'] is num &&
                        (quality['unscoped_invoice_count'] as num) > 0) ...[
                      const SizedBox(height: 16),
                      StitchCard(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.info_outline_rounded,
                              color: AppTheme.stitchMuted,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                '${quality['unscoped_invoice_count']} invoice(s) are not linked to a fee structure. They remain visible in the account but cannot be reliably filtered by term.',
                                style: const TextStyle(
                                  color: AppTheme.stitchMuted,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildMultiCurrencySummary(List<Map<String, dynamic>> totals) {
    if (totals.isEmpty) {
      return const StitchCard(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Row(
            children: [
              Icon(
                Icons.account_balance_wallet_rounded,
                color: AppTheme.primaryDark,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Currency Balances',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      'No fee account balances are available for the selected academic year.',
                      style: TextStyle(
                        color: AppTheme.stitchMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = constraints.maxWidth >= 700
            ? (constraints.maxWidth - 12) / 2
            : constraints.maxWidth;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: totals.map((summary) {
            final currency = summary['currency']?.toString() ?? '—';
            final total = _number(summary['total_invoiced']);
            final paid = _number(summary['paid']);
            final outstanding = _number(summary['outstanding']);
            final overdue = _number(summary['overdue']);
            final settledPercent = _number(summary['settled_percent']);

            return SizedBox(
              width: cardWidth,
              child: StitchCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          currency,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            color: AppTheme.primaryDark,
                          ),
                        ),
                        StitchChip(
                          label: '${settledPercent.toStringAsFixed(0)}% Settled',
                          variant: outstanding == 0
                              ? StitchChipVariant.success
                              : StitchChipVariant.warn,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '$currency ${outstanding.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                        color: AppTheme.stitchHeading,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Invoiced: $currency ${total.toStringAsFixed(2)} · Paid: $currency ${paid.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.stitchMuted,
                      ),
                    ),
                    if (overdue > 0) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Overdue: $currency ${overdue.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFDC2626),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildPaymentMethodsCard(
    BuildContext context,
    List<String> paymentMethods,
  ) {
    return StitchCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const StitchSectionHeader(
            title: 'Payment Options',
            subtitle: 'Methods configured by the school',
          ),
          const SizedBox(height: 12),
          if (paymentMethods.isEmpty)
            const Text(
              'No payment methods are configured yet.',
              style: TextStyle(color: AppTheme.stitchMuted, fontSize: 12),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: paymentMethods
                  .map(
                    (method) => StitchChip(
                      label: method,
                      variant: StitchChipVariant.neutral,
                    ),
                  )
                  .toList(),
            ),
          const SizedBox(height: 12),
          const Text(
            'Online checkout will become available after a real payment provider and verified webhook are connected. No client-side payment is recorded as confirmed.',
            style: TextStyle(
              color: AppTheme.stitchMuted,
              fontSize: 11.5,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceCard(
    BuildContext context,
    Map<String, dynamic> invoice, {
    required bool canPay,
    required List<String> paymentMethods,
  }) {
    final invoiceId = invoice['id']?.toString() ?? '';
    final invoiceNumber = invoice['invoice_number']?.toString();
    final currency = invoice['currency']?.toString() ?? '—';
    final total = _number(invoice['total_amount']);
    final paid = _number(invoice['paid_amount']);
    final balance = _number(invoice['balance']);
    final status = invoice['status']?.toString() ?? 'unpaid';
    final dueDate = _date(invoice['due_date']);
    final isOverdue = dueDate != null &&
        dueDate.isBefore(_today()) &&
        status != 'paid';
    final progress = total > 0 ? (paid / total).clamp(0.0, 1.0) : 0.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: StitchCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    invoiceNumber?.isNotEmpty == true
                        ? 'Invoice $invoiceNumber'
                        : 'Invoice ${_shortId(invoiceId)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: AppTheme.stitchHeading,
                    ),
                  ),
                ),
                StitchChip(
                  label: status.toUpperCase(),
                  variant: status == 'paid'
                      ? StitchChipVariant.success
                      : status == 'partial'
                          ? StitchChipVariant.warn
                          : StitchChipVariant.neutral,
                ),
              ],
            ),
            if (isOverdue) ...[
              const SizedBox(height: 6),
              const StitchChip(
                label: 'OVERDUE',
                variant: StitchChipVariant.error,
              ),
            ],
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Paid: $currency ${paid.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: Color(0xFF10B981),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                Text(
                  'Total: $currency ${total.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: AppTheme.stitchMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            LinearProgressIndicator(
              value: progress,
              color: status == 'paid' ? const Color(0xFF10B981) : AppTheme.primary,
              backgroundColor: const Color(0xFFE2E8F0),
              minHeight: 6,
              borderRadius: BorderRadius.circular(3),
            ),
            const SizedBox(height: 10),
            Text(
              dueDate == null
                  ? 'Due date unavailable'
                  : 'Due Date: ${dueDate.day}/${dueDate.month}/${dueDate.year}',
              style: TextStyle(
                color: isOverdue
                    ? const Color(0xFFDC2626)
                    : AppTheme.stitchMuted,
                fontSize: 11,
              ),
            ),
            if ((invoice['fee_structure']?.toString() ?? '').isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                invoice['fee_structure'].toString(),
                style: const TextStyle(
                  color: AppTheme.stitchMuted,
                  fontSize: 11,
                ),
              ),
            ],
            if (canPay && balance > 0) ...[
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _showCheckoutDependency(
                    context,
                    currency: currency,
                    balance: balance,
                    paymentMethods: paymentMethods,
                  ),
                  icon: const Icon(
                    Icons.payment_rounded,
                    size: 16,
                    color: Colors.white,
                  ),
                  label: Text(
                    'Pay $currency ${balance.toStringAsFixed(2)} Balance',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentHistory(List<Map<String, dynamic>> payments) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const StitchSectionHeader(
          title: 'Payment Transactions History',
          subtitle: 'Confirmed and recorded payment transactions',
        ),
        const SizedBox(height: 12),
        if (payments.isEmpty)
          const StitchCard(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  'No payment transactions recorded yet.',
                  style: TextStyle(
                    color: AppTheme.stitchMuted,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          )
        else
          StitchCard(
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: payments.length,
              separatorBuilder: (_, _) => const Divider(height: 16),
              itemBuilder: (context, index) {
                final payment = payments[index];
                final currency = payment['currency']?.toString() ?? '—';
                final amount = _number(payment['amount']);
                final method = payment['payment_method']?.toString() ?? 'Payment';
                final reference = payment['reference']?.toString() ?? 'N/A';
                final status = payment['status']?.toString() ?? 'recorded';
                final paidAt = _dateTime(payment['paid_at']);

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            method.toUpperCase(),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12.5,
                            ),
                          ),
                          Text(
                            'Ref: $reference${paidAt == null ? '' : ' · ${paidAt.day}/${paidAt.month}/${paidAt.year}'}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.stitchMuted,
                            ),
                          ),
                          const SizedBox(height: 4),
                          StitchChip(
                            label: status,
                            variant: status == 'confirmed'
                                ? StitchChipVariant.success
                                : StitchChipVariant.neutral,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '$currency ${amount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF10B981),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
      ],
    );
  }

  void _showCheckoutDependency(
    BuildContext context, {
    required String currency,
    required double balance,
    required List<String> paymentMethods,
  }) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.shield_outlined, color: AppTheme.primaryDark),
            SizedBox(width: 8),
            Expanded(child: Text('Online Checkout Not Connected Yet')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'The live outstanding balance is $currency ${balance.toStringAsFixed(2)}.',
            ),
            const SizedBox(height: 10),
            const Text(
              'ZivoConnect will not mark a parent payment as confirmed until a real payment provider and verified server webhook are connected.',
            ),
            if (paymentMethods.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'School-configured methods: ${paymentMethods.join(', ')}',
                style: const TextStyle(color: AppTheme.stitchMuted),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  static Map<String, dynamic> _map(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return const <String, dynamic>{};
  }

  static List<Map<String, dynamic>> _listOfMaps(dynamic value) {
    if (value is! List) return const <Map<String, dynamic>>[];
    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }

  static List<String> _paymentMethodLabels(dynamic value) {
    if (value is! List) return const <String>[];
    return value.map((item) {
      if (item is String) return item;
      if (item is Map) {
        final map = Map<String, dynamic>.from(item);
        return map['label']?.toString() ??
            map['name']?.toString() ??
            map['provider']?.toString() ??
            '';
      }
      return item.toString();
    }).where((label) => label.trim().isNotEmpty).toList(growable: false);
  }

  static double _number(dynamic value) => (value as num?)?.toDouble() ?? 0.0;

  static DateTime? _date(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }

  static DateTime? _dateTime(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }

  static DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  static String _shortId(String id) {
    if (id.isEmpty) return '—';
    return '#${id.substring(0, id.length < 8 ? id.length : 8).toUpperCase()}';
  }
}
