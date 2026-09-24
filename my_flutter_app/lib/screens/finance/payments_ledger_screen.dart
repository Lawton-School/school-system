import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../controllers/finance_controllers.dart';
import '../../core/theme.dart';
import '../../providers/providers.dart';
import '../../widgets/stitch_widgets.dart';

/// Screen 14 — Payments Ledger & Reconciliation.
///
/// Unmatched payments (`invoice_id IS NULL`) are first-class records. Linking a
/// payment to an invoice is performed only through the server-authoritative
/// `reconcile_payment_to_invoice` RPC; the client never changes invoice totals.
class PaymentsLedgerScreen extends ConsumerStatefulWidget {
  const PaymentsLedgerScreen({super.key});

  @override
  ConsumerState<PaymentsLedgerScreen> createState() => _PaymentsLedgerScreenState();
}

class _PaymentsLedgerScreenState extends ConsumerState<PaymentsLedgerScreen> {
  final _searchController = TextEditingController();
  String _filter = 'all';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ledgerAsync = ref.watch(paymentsLedgerProvider);

    return Scaffold(
      backgroundColor: AppTheme.stitchBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'FINANCE',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
                color: AppTheme.primaryDark,
              ),
            ),
            Text(
              'Payments Ledger & Reconciliation',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.stitchHeading,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh payments',
            onPressed: () => ref.invalidate(paymentsLedgerProvider),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: ledgerAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _LedgerError(
          message: 'Unable to load payment ledger: $error',
          onRetry: () => ref.invalidate(paymentsLedgerProvider),
        ),
        data: (payments) {
          final visible = _filterRows(payments);
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(paymentsLedgerProvider);
              await ref.read(paymentsLedgerProvider.future);
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              children: [
                _PaymentCurrencySummary(payments: payments),
                const SizedBox(height: 18),
                _buildFilters(),
                const SizedBox(height: 18),
                StitchSectionHeader(
                  title: 'Transactions',
                  subtitle: '${visible.length} of ${payments.length} payments',
                ),
                const SizedBox(height: 12),
                if (visible.isEmpty)
                  const StitchCard(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 30),
                      child: Center(
                        child: Text(
                          'No payments match the current filter.',
                          style: TextStyle(color: AppTheme.stitchMuted),
                        ),
                      ),
                    ),
                  )
                else
                  ...visible.map(_buildPaymentCard),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFilters() {
    return StitchCard(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final search = TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Search reference, invoice or student',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        _searchController.clear();
                        setState(() {});
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
            ),
          );
          final tabs = Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              _filterChip('all', 'All'),
              _filterChip('unmatched', 'Unmatched'),
              _filterChip('pending', 'Pending'),
              _filterChip('confirmed', 'Confirmed'),
              _filterChip('reversed', 'Reversed'),
            ],
          );

          if (constraints.maxWidth < 720) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                search,
                const SizedBox(height: 12),
                tabs,
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: search),
              const SizedBox(width: 16),
              tabs,
            ],
          );
        },
      ),
    );
  }

  Widget _filterChip(String value, String label) {
    return ChoiceChip(
      label: Text(label),
      selected: _filter == value,
      onSelected: (_) => setState(() => _filter = value),
    );
  }

  List<Map<String, dynamic>> _filterRows(List<Map<String, dynamic>> payments) {
    final query = _searchController.text.trim().toLowerCase();
    return payments.where((payment) {
      final status = payment['status']?.toString() ?? '';
      final unmatched = payment['invoice_id'] == null;
      final matchesType = switch (_filter) {
        'unmatched' => unmatched,
        'pending' => status == 'pending',
        'confirmed' => status == 'confirmed',
        'reversed' => status == 'reversed',
        _ => true,
      };
      if (!matchesType) return false;
      if (query.isEmpty) return true;

      final haystack = [
        payment['transaction_reference'],
        payment['provider_reference'],
        payment['invoice_number'],
        payment['student_name'],
        payment['provider'],
        payment['payment_method'],
      ].whereType<Object>().map((value) => value.toString().toLowerCase()).join(' ');
      return haystack.contains(query);
    }).toList(growable: false);
  }

  Widget _buildPaymentCard(Map<String, dynamic> payment) {
    final status = payment['status']?.toString() ?? 'pending';
    final invoiceId = payment['invoice_id']?.toString();
    final unmatched = invoiceId == null || invoiceId.isEmpty;
    final currency = payment['currency']?.toString() ?? 'UNSPECIFIED';
    final amount = _number(payment['amount']);
    final paidAt = _date(payment['paid_at']);
    final reference = _reference(payment);
    final canReconcile = unmatched && status != 'reversed';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: StitchCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$currency ${amount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: AppTheme.stitchHeading,
                          fontWeight: FontWeight.w800,
                          fontSize: 17,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        reference.isEmpty ? 'No transaction reference' : reference,
                        style: const TextStyle(color: AppTheme.stitchMuted, fontSize: 11.5),
                      ),
                    ],
                  ),
                ),
                StitchChip(
                  label: unmatched ? 'UNMATCHED' : status.toUpperCase(),
                  variant: unmatched
                      ? StitchChipVariant.warn
                      : status == 'confirmed'
                          ? StitchChipVariant.success
                          : status == 'reversed'
                              ? StitchChipVariant.danger
                              : StitchChipVariant.neutral,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 20,
              runSpacing: 10,
              children: [
                _LedgerMetric(label: 'Method', value: payment['payment_method']?.toString() ?? '—'),
                _LedgerMetric(label: 'Provider', value: payment['provider']?.toString() ?? '—'),
                _LedgerMetric(
                  label: 'Paid',
                  value: paidAt == null ? '—' : '${paidAt.day}/${paidAt.month}/${paidAt.year}',
                ),
                _LedgerMetric(
                  label: 'Invoice',
                  value: unmatched
                      ? 'Not linked'
                      : payment['invoice_number']?.toString() ?? _shortId(invoiceId),
                ),
              ],
            ),
            if (!unmatched && (payment['student_name']?.toString() ?? '').isNotEmpty) ...[
              const SizedBox(height: 9),
              Text(
                payment['student_name'].toString(),
                style: const TextStyle(color: AppTheme.stitchMuted, fontSize: 11.5),
              ),
            ],
            if (canReconcile) ...[
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _showReconcileDialog(payment),
                  icon: const Icon(Icons.link_rounded, size: 17),
                  label: const Text('Reconcile to Invoice'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _showReconcileDialog(Map<String, dynamic> payment) async {
    final cached = ref.read(invoiceManagementProvider).asData?.value;
    final List<Map<String, dynamic>> invoices =
        cached ?? await ref.read(invoiceManagementProvider.future);
    if (!mounted) return;

    final paymentCurrency = payment['currency']?.toString() ?? '';
    final candidates = invoices.where((invoice) {
      final invoiceCurrency = invoice['currency']?.toString() ?? '';
      final balance = _number(invoice['balance']);
      return invoiceCurrency == paymentCurrency &&
          balance > 0 &&
          invoice['status']?.toString() != 'paid';
    }).toList(growable: false);

    if (candidates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No outstanding $paymentCurrency invoice is available for this payment.'),
        ),
      );
      return;
    }

    var selectedId = candidates.first['id']?.toString() ?? '';
    var submitting = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Reconcile Payment'),
            content: SizedBox(
              width: 540,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '${paymentCurrency.isEmpty ? 'UNSPECIFIED' : paymentCurrency} ${_number(payment['amount']).toStringAsFixed(2)} · ${_reference(payment)}',
                    style: const TextStyle(color: AppTheme.stitchMuted, fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: selectedId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Outstanding Invoice'),
                    items: candidates.map((invoice) {
                      final id = invoice['id']?.toString() ?? '';
                      final number = invoice['invoice_number']?.toString() ?? _shortId(id);
                      final student = invoice['student_name']?.toString() ?? 'Unknown Student';
                      final balance = _number(invoice['balance']);
                      return DropdownMenuItem(
                        value: id,
                        child: Text(
                          '$number · $student · $paymentCurrency ${balance.toStringAsFixed(2)} due',
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: submitting
                        ? null
                        : (value) {
                            if (value != null) setDialogState(() => selectedId = value);
                          },
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'The server will re-check school ownership and currency before linking the payment and recalculating the invoice.',
                    style: TextStyle(color: AppTheme.stitchMuted, fontSize: 11.5, height: 1.4),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: submitting ? null : () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton.icon(
                onPressed: submitting
                    ? null
                    : () async {
                        final paymentId = payment['id']?.toString() ?? '';
                        if (paymentId.isEmpty || selectedId.isEmpty) return;
                        setDialogState(() => submitting = true);
                        try {
                          await ref.read(financeRepositoryProvider).reconcilePayment(
                                paymentId: paymentId,
                                invoiceId: selectedId,
                              );
                          ref.invalidate(paymentsLedgerProvider);
                          ref.invalidate(invoiceManagementProvider);
                          ref.invalidate(financeDashboardMetricsProvider);
                          if (dialogContext.mounted) Navigator.pop(dialogContext);
                          if (mounted) {
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              const SnackBar(content: Text('Payment reconciled successfully.')),
                            );
                          }
                        } catch (error) {
                          if (dialogContext.mounted) {
                            ScaffoldMessenger.of(dialogContext).showSnackBar(
                              SnackBar(content: Text('Reconciliation failed: $error')),
                            );
                            setDialogState(() => submitting = false);
                          }
                        }
                      },
                icon: submitting
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.link_rounded, size: 17),
                label: const Text('Reconcile'),
              ),
            ],
          );
        },
      ),
    );
  }

  static double _number(dynamic value) => value is num ? value.toDouble() : 0.0;

  static DateTime? _date(dynamic value) =>
      value == null ? null : DateTime.tryParse(value.toString());

  static String _reference(Map<String, dynamic> payment) {
    return payment['provider_reference']?.toString().trim().isNotEmpty == true
        ? payment['provider_reference'].toString()
        : payment['transaction_reference']?.toString() ?? '';
  }

  static String _shortId(dynamic value) {
    final text = value?.toString() ?? '';
    return text.length <= 8 ? text : text.substring(0, 8).toUpperCase();
  }
}

class _PaymentCurrencySummary extends StatelessWidget {
  final List<Map<String, dynamic>> payments;

  const _PaymentCurrencySummary({required this.payments});

  @override
  Widget build(BuildContext context) {
    final byCurrency = <String, Map<String, double>>{};
    for (final payment in payments) {
      final currency = payment['currency']?.toString() ?? 'UNSPECIFIED';
      final amount = _number(payment['amount']);
      final bucket = byCurrency.putIfAbsent(
        currency,
        () => {'confirmed': 0, 'pending': 0, 'unmatched': 0},
      );
      final status = payment['status']?.toString() ?? '';
      if (status == 'confirmed') {
        bucket['confirmed'] = bucket['confirmed']! + amount;
      } else if (status == 'pending') {
        bucket['pending'] = bucket['pending']! + amount;
      }
      if (payment['invoice_id'] == null) {
        bucket['unmatched'] = bucket['unmatched']! + amount;
      }
    }

    if (byCurrency.isEmpty) {
      return const StitchCard(
        child: Text('No payment transactions recorded yet.', style: TextStyle(color: AppTheme.stitchMuted)),
      );
    }

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: byCurrency.entries.map((entry) {
        final totals = entry.value;
        return SizedBox(
          width: 280,
          child: StitchCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.key, style: const TextStyle(color: AppTheme.primaryDark, fontWeight: FontWeight.w800)),
                const SizedBox(height: 9),
                Text(
                  '${entry.key} ${totals['confirmed']!.toStringAsFixed(2)} confirmed',
                  style: const TextStyle(color: AppTheme.stitchHeading, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                Text(
                  'Pending ${entry.key} ${totals['pending']!.toStringAsFixed(2)} · Unmatched ${entry.key} ${totals['unmatched']!.toStringAsFixed(2)}',
                  style: const TextStyle(color: AppTheme.stitchMuted, fontSize: 11),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  static double _number(dynamic value) => value is num ? value.toDouble() : 0.0;
}

class _LedgerMetric extends StatelessWidget {
  final String label;
  final String value;

  const _LedgerMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(color: AppTheme.stitchMuted, fontSize: 9.5, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(color: AppTheme.stitchHeading, fontSize: 12.5, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _LedgerError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _LedgerError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 42, color: AppTheme.danger),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
