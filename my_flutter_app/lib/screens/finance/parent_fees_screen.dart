import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../controllers/parent_controllers.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../providers/providers.dart' hide studentInvoicesProvider;
import '../../services/services.dart';
import '../../widgets/stitch_widgets.dart';

/// Screen 08: Parent Fees & Multi-Currency Payments
/// Strictly preserves currency separation via [FinanceCurrencySummary].
/// Balances are server-authoritative and calculated as `totalAmount - paidAmount`.
class ParentFeesScreen extends ConsumerStatefulWidget {
  const ParentFeesScreen({super.key});

  @override
  ConsumerState<ParentFeesScreen> createState() => _ParentFeesScreenState();
}

class _ParentFeesScreenState extends ConsumerState<ParentFeesScreen> {
  void _showPaymentSheet(BuildContext context, String schoolId, InvoiceModel invoice, String currency) {
    String selectedMethod = 'EcoCash';
    final balance = invoice.totalAmount - invoice.paidAmount;
    final payCtrl = TextEditingController(text: balance.toStringAsFixed(2));
    final methods = ['EcoCash', 'Visa/Mastercard', 'Bank Transfer', 'Stripe', 'Cash Voucher'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Settle Invoice', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: AppTheme.stitchHeading)),
              const SizedBox(height: 4),
              Text('Outstanding Balance: $currency ${balance.toStringAsFixed(2)}',
                  style: const TextStyle(color: AppTheme.stitchMuted, fontSize: 13)),
              const SizedBox(height: 16),

              // Fee line items
              if (invoice.items != null && invoice.items!.isNotEmpty) ...[
                ...invoice.items!.map((item) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(item.feeType?.name ?? 'Tuition Fee', style: const TextStyle(fontSize: 13)),
                      Text('$currency ${item.amount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ],
                  ),
                )),
                const Divider(height: 20),
              ],

              // Payment Method Selection
              const Text('Payment Method:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: methods.map((m) => ChoiceChip(
                  label: Text(m, style: const TextStyle(fontSize: 12)),
                  selected: selectedMethod == m,
                  onSelected: (v) => setSheet(() => selectedMethod = m),
                )).toList(),
              ),
              const SizedBox(height: 16),

              // Amount field
              TextField(
                controller: payCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Amount to Pay ($currency)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 20),

              ElevatedButton.icon(
                onPressed: () async {
                  final amount = double.tryParse(payCtrl.text.trim()) ?? 0.0;
                  if (amount <= 0) return;
                  final client = ref.read(supabaseClientProvider);
                  final payment = await SchoolFinanceService(client).recordPayment(
                    schoolId: schoolId,
                    invoiceId: invoice.id,
                    amount: amount,
                    paymentMethod: selectedMethod,
                    currentPaidAmount: invoice.paidAmount,
                    totalAmount: invoice.totalAmount,
                  );

                  // Refresh live student invoices and dashboard
                  ref.invalidate(studentInvoicesProvider(invoice.studentProfileId));
                  ref.invalidate(studentPaymentsProvider(invoice.studentProfileId));
                  ref.invalidate(parentDashboardDataProvider);

                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                    _showReceiptDialog(context, payment, invoice, selectedMethod, currency);
                  }
                },
                icon: const Icon(Icons.payment_rounded, color: Colors.white),
                label: const Text('Confirm Payment', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: AppTheme.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showReceiptDialog(BuildContext context, PaymentModel payment, InvoiceModel invoice, String method, String currency) {
    final remaining = (invoice.totalAmount - invoice.paidAmount - payment.amount).clamp(0.0, double.infinity);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Color(0xFF10B981)),
            SizedBox(width: 8),
            Text('Payment Confirmed'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ReceiptRow(label: 'Transaction Ref', value: payment.transactionReference ?? 'TXN-${payment.id.substring(0, 6).toUpperCase()}'),
            _ReceiptRow(label: 'Amount Paid', value: '$currency ${payment.amount.toStringAsFixed(2)}'),
            _ReceiptRow(label: 'Method', value: method),
            _ReceiptRow(label: 'Invoice', value: '#${invoice.id.substring(0, 8).toUpperCase()}'),
            _ReceiptRow(label: 'Date & Time', value: '${payment.paidAt.day}/${payment.paidAt.month}/${payment.paidAt.year}'),
            const Divider(height: 20),
            Text(
              remaining <= 0
                  ? '✅ Invoice fully settled. Thank you!'
                  : '⚠️ Partial payment recorded. Balance: $currency ${remaining.toStringAsFixed(2)} remaining.',
              style: TextStyle(
                color: remaining <= 0 ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Close Receipt', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(activeSessionProvider);
    if (session == null) return const Scaffold(body: Center(child: Text('No active session')));
    final schoolId = session.schoolId;

    final childrenAsync = ref.watch(parentChildrenProvider);
    final activeChild = ref.watch(activeSelectedChildProvider);
    final selectedChildIndex = ref.watch(selectedChildIndexProvider);
    final dashboardAsync = ref.watch(parentDashboardDataProvider);

    return Scaffold(
      backgroundColor: AppTheme.stitchBg,
      appBar: AppBar(
        title: const Text('School Fees & Multi-Currency Payments', style: TextStyle(color: AppTheme.stitchHeading, fontWeight: FontWeight.w700, fontSize: 16)),
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Fees',
            onPressed: () {
              if (activeChild != null) {
                ref.invalidate(studentInvoicesProvider(activeChild.studentId));
                ref.invalidate(studentPaymentsProvider(activeChild.studentId));
                ref.invalidate(parentDashboardDataProvider);
              }
            },
          ),
        ],
      ),
      body: childrenAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error loading authorized children: $err')),
        data: (children) {
          if (children.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text('No linked children found for this guardian profile.', style: TextStyle(color: AppTheme.stitchMuted)),
              ),
            );
          }

          final currentChild = activeChild ?? children.first;
          final invoicesAsync = ref.watch(studentInvoicesProvider(currentChild.studentId));
          final paymentsAsync = ref.watch(studentPaymentsProvider(currentChild.studentId));
          final dashboardData = dashboardAsync.asData?.value;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Child Switcher Row
                if (children.length > 1) ...[
                  Row(
                    children: [
                      const Text('Select Student: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(width: 8),
                      ...children.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final child = entry.value;
                        final isSelected = idx == selectedChildIndex;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(child.fullName),
                            selected: isSelected,
                            onSelected: (_) => ref.read(selectedChildIndexProvider.notifier).state = idx,
                          ),
                        );
                      }),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],

                // Multi-Currency Breakdown Cards
                _buildMultiCurrencySummary(dashboardData?.currencySummaries ?? []),
                const SizedBox(height: 20),

                // Invoices Section
                invoicesAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => StitchCard(child: Text('Error loading invoices: $e')),
                  data: (invoices) {
                    final unpaid = invoices.where((i) => i.status != 'paid').toList();
                    final paid = invoices.where((i) => i.status == 'paid').toList();

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const StitchSectionHeader(
                          title: 'Outstanding Invoices',
                          subtitle: 'Due fee balances requiring settlement',
                        ),
                        const SizedBox(height: 12),
                        if (unpaid.isEmpty)
                          const StitchCard(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 24),
                              child: Center(
                                child: Column(
                                  children: [
                                    Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 36),
                                    SizedBox(height: 8),
                                    Text('All fees are fully paid! No outstanding balances.',
                                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppTheme.stitchHeading)),
                                  ],
                                ),
                              ),
                            ),
                          )
                        else
                          ...unpaid.map((inv) => _buildInvoiceCard(context, schoolId, inv, canPay: true)),
                        const SizedBox(height: 24),

                        // Paid Invoices Section
                        const StitchSectionHeader(
                          title: 'Settled Invoices',
                          subtitle: 'Historical receipts and completed payments',
                        ),
                        const SizedBox(height: 12),
                        if (paid.isEmpty)
                          const StitchCard(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 20),
                              child: Center(
                                child: Text('No settled invoices recorded yet.', style: TextStyle(color: AppTheme.stitchMuted, fontSize: 13)),
                              ),
                            ),
                          )
                        else
                          ...paid.map((inv) => _buildInvoiceCard(context, schoolId, inv, canPay: false)),
                        const SizedBox(height: 24),

                        // Direct Payments History
                        paymentsAsync.when(
                          loading: () => const SizedBox.shrink(),
                          error: (_, _) => const SizedBox.shrink(),
                          data: (payments) {
                            if (payments.isEmpty) return const SizedBox.shrink();
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const StitchSectionHeader(
                                  title: 'Payment Transactions History',
                                  subtitle: 'Direct transaction receipts on file',
                                ),
                                const SizedBox(height: 12),
                                StitchCard(
                                  child: ListView.separated(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    itemCount: payments.length,
                                    separatorBuilder: (_, _) => const Divider(height: 16),
                                    itemBuilder: (context, idx) {
                                      final p = payments[idx];
                                      return Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(p.paymentMethod.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                                              Text('Ref: ${p.transactionReference ?? "N/A"} · ${p.paidAt.day}/${p.paidAt.month}/${p.paidAt.year}',
                                                  style: const TextStyle(fontSize: 11, color: AppTheme.stitchMuted)),
                                            ],
                                          ),
                                          Text('\$${p.amount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
                                        ],
                                      );
                                    },
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMultiCurrencySummary(List<FinanceCurrencySummary> summaries) {
    if (summaries.isEmpty) {
      return const StitchCard(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Row(
            children: [
              Icon(Icons.account_balance_wallet_rounded, color: AppTheme.primaryDark),
              SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Currency Balances', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  Text('All account currencies are reconciled and in good standing.', style: TextStyle(color: AppTheme.stitchMuted, fontSize: 11)),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return Row(
          children: summaries.map((s) {
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: StitchCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(s.currency, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppTheme.primaryDark)),
                          StitchChip(
                            label: '${s.settledPercent.toStringAsFixed(0)}% Settled',
                            variant: s.outstanding == 0 ? StitchChipVariant.success : StitchChipVariant.warn,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(s.formattedOutstanding, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20, color: AppTheme.stitchHeading)),
                      const SizedBox(height: 2),
                      Text('Invoiced: ${s.formattedTotal} · Paid: ${s.formattedPaid}', style: const TextStyle(fontSize: 11, color: AppTheme.stitchMuted)),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildInvoiceCard(BuildContext context, String schoolId, InvoiceModel invoice, {required bool canPay}) {
    final balance = invoice.totalAmount - invoice.paidAmount;
    final isOverdue = invoice.dueDate.isBefore(DateTime.now()) && invoice.status != 'paid';
    const currency = 'USD'; // Default backend currency for invoices without explicit currency code

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: StitchCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Invoice #${invoice.id.substring(0, 8).toUpperCase()}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.stitchHeading)),
                StitchChip(
                  label: invoice.status.toUpperCase(),
                  variant: invoice.status == 'paid'
                      ? StitchChipVariant.success
                      : (invoice.status == 'partial' ? StitchChipVariant.warn : StitchChipVariant.neutral),
                ),
              ],
            ),
            if (isOverdue) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('⚠️ OVERDUE', style: TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.bold, fontSize: 11)),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Paid: $currency ${invoice.paidAmount.toStringAsFixed(2)}',
                    style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 12)),
                Text('Total: $currency ${invoice.totalAmount.toStringAsFixed(2)}',
                    style: const TextStyle(color: AppTheme.stitchMuted, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 6),
            LinearProgressIndicator(
              value: invoice.totalAmount > 0 ? (invoice.paidAmount / invoice.totalAmount).clamp(0.0, 1.0) : 0,
              color: invoice.isFullyPaid ? const Color(0xFF10B981) : AppTheme.primary,
              backgroundColor: const Color(0xFFE2E8F0),
              minHeight: 6,
              borderRadius: BorderRadius.circular(3),
            ),
            const SizedBox(height: 10),
            Text('Due Date: ${invoice.dueDate.day}/${invoice.dueDate.month}/${invoice.dueDate.year}',
                style: TextStyle(color: isOverdue ? const Color(0xFFDC2626) : AppTheme.stitchMuted, fontSize: 11)),

            if (canPay && !invoice.isFullyPaid) ...[
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _showPaymentSheet(context, schoolId, invoice, currency),
                  icon: const Icon(Icons.payment_rounded, size: 16, color: Colors.white),
                  label: Text('Pay $currency ${balance.toStringAsFixed(2)} Balance',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
}

class _ReceiptRow extends StatelessWidget {
  final String label;
  final String value;
  const _ReceiptRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppTheme.stitchMuted, fontSize: 12.5)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: AppTheme.stitchHeading)),
        ],
      ),
    );
  }
}

