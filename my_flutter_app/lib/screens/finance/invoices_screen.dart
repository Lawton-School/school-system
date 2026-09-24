import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../controllers/finance_controllers.dart';
import '../../core/theme.dart';
import '../../providers/providers.dart';
import '../../widgets/stitch_widgets.dart';

/// Screen 13 — Invoices Management.
///
/// Uses the live invoice schema and the authoritative
/// `generate_invoices_from_fee_structure` RPC. Currency is always displayed
/// per invoice and is never assumed to be USD.
class InvoicesScreen extends ConsumerStatefulWidget {
  const InvoicesScreen({super.key});

  @override
  ConsumerState<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends ConsumerState<InvoicesScreen> {
  final _searchController = TextEditingController();
  String _statusFilter = 'all';
  String _currencyFilter = 'all';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final invoicesAsync = ref.watch(invoiceManagementProvider);

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
              'Invoices Management',
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
            tooltip: 'Refresh invoices',
            onPressed: () => ref.invalidate(invoiceManagementProvider),
            icon: const Icon(Icons.refresh_rounded),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.icon(
              onPressed: () => _showGenerateDialog(context),
              icon: const Icon(Icons.add_rounded, size: 17),
              label: const Text('Generate'),
            ),
          ),
        ],
      ),
      body: invoicesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorState(
          message: 'Unable to load invoices: $error',
          onRetry: () => ref.invalidate(invoiceManagementProvider),
        ),
        data: (invoices) {
          final currencies = invoices
              .map((row) => row['currency']?.toString())
              .whereType<String>()
              .where((value) => value.isNotEmpty)
              .toSet()
              .toList()
            ..sort();
          final filtered = _filter(invoices);

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(invoiceManagementProvider);
              await ref.read(invoiceManagementProvider.future);
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              children: [
                _buildFilters(currencies),
                const SizedBox(height: 16),
                _InvoiceSummary(invoices: invoices),
                const SizedBox(height: 20),
                StitchSectionHeader(
                  title: 'Invoices',
                  subtitle: '${filtered.length} of ${invoices.length} records',
                ),
                const SizedBox(height: 12),
                if (filtered.isEmpty)
                  const StitchCard(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 30),
                      child: Center(
                        child: Text(
                          'No invoices match the current filters.',
                          style: TextStyle(color: AppTheme.stitchMuted),
                        ),
                      ),
                    ),
                  )
                else
                  ...filtered.map(_buildInvoiceCard),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFilters(List<String> currencies) {
    return StitchCard(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final search = TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Search invoice or student',
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
          final status = DropdownButtonFormField<String>(
            initialValue: _statusFilter,
            decoration: const InputDecoration(labelText: 'Status'),
            items: const [
              DropdownMenuItem(value: 'all', child: Text('All statuses')),
              DropdownMenuItem(value: 'unpaid', child: Text('Unpaid')),
              DropdownMenuItem(value: 'partial', child: Text('Partial')),
              DropdownMenuItem(value: 'paid', child: Text('Paid')),
            ],
            onChanged: (value) => setState(() => _statusFilter = value ?? 'all'),
          );
          final currencyValue = currencies.contains(_currencyFilter)
              ? _currencyFilter
              : 'all';
          final currency = DropdownButtonFormField<String>(
            initialValue: currencyValue,
            decoration: const InputDecoration(labelText: 'Currency'),
            items: [
              const DropdownMenuItem(value: 'all', child: Text('All currencies')),
              ...currencies.map(
                (value) => DropdownMenuItem(value: value, child: Text(value)),
              ),
            ],
            onChanged: (value) => setState(() => _currencyFilter = value ?? 'all'),
          );

          if (constraints.maxWidth < 700) {
            return Column(
              children: [
                search,
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: status),
                    const SizedBox(width: 10),
                    Expanded(child: currency),
                  ],
                ),
              ],
            );
          }

          return Row(
            children: [
              Expanded(flex: 2, child: search),
              const SizedBox(width: 12),
              Expanded(child: status),
              const SizedBox(width: 12),
              Expanded(child: currency),
            ],
          );
        },
      ),
    );
  }

  List<Map<String, dynamic>> _filter(List<Map<String, dynamic>> invoices) {
    final query = _searchController.text.trim().toLowerCase();
    return invoices.where((invoice) {
      final status = invoice['status']?.toString() ?? '';
      final currency = invoice['currency']?.toString() ?? '';
      final invoiceNumber = invoice['invoice_number']?.toString().toLowerCase() ?? '';
      final student = invoice['student_name']?.toString().toLowerCase() ?? '';
      return (query.isEmpty || invoiceNumber.contains(query) || student.contains(query)) &&
          (_statusFilter == 'all' || status == _statusFilter) &&
          (_currencyFilter == 'all' || currency == _currencyFilter);
    }).toList(growable: false);
  }

  Widget _buildInvoiceCard(Map<String, dynamic> invoice) {
    final total = _number(invoice['total_amount']);
    final paid = _number(invoice['paid_amount']);
    final balance = _number(invoice['balance']);
    final currency = invoice['currency']?.toString() ?? 'UNSPECIFIED';
    final status = invoice['status']?.toString() ?? 'unpaid';
    final dueDate = _date(invoice['due_date']);
    final today = DateTime.now();
    final overdue = dueDate != null &&
        dueDate.isBefore(DateTime(today.year, today.month, today.day)) &&
        status != 'paid';

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
                        invoice['invoice_number']?.toString().isNotEmpty == true
                            ? invoice['invoice_number'].toString()
                            : 'Invoice ${_shortId(invoice['id'])}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: AppTheme.stitchHeading,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        invoice['student_name']?.toString() ?? 'Unknown Student',
                        style: const TextStyle(color: AppTheme.stitchMuted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                StitchChip(
                  label: overdue ? 'OVERDUE' : status.toUpperCase(),
                  variant: overdue
                      ? StitchChipVariant.danger
                      : status == 'paid'
                          ? StitchChipVariant.success
                          : status == 'partial'
                              ? StitchChipVariant.warn
                              : StitchChipVariant.neutral,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 18,
              runSpacing: 10,
              children: [
                _Metric(label: 'Total', value: '$currency ${total.toStringAsFixed(2)}'),
                _Metric(label: 'Paid', value: '$currency ${paid.toStringAsFixed(2)}'),
                _Metric(label: 'Balance', value: '$currency ${balance.toStringAsFixed(2)}'),
                _Metric(
                  label: 'Due',
                  value: dueDate == null ? '—' : '${dueDate.day}/${dueDate.month}/${dueDate.year}',
                ),
              ],
            ),
            if ((invoice['fee_structure_name']?.toString() ?? '').isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                invoice['fee_structure_name'].toString(),
                style: const TextStyle(color: AppTheme.stitchMuted, fontSize: 11),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _showGenerateDialog(BuildContext context) async {
    final cached = ref.read(activeFeeStructuresProvider).asData?.value;
    final List<Map<String, dynamic>> structures =
        cached ?? await ref.read(activeFeeStructuresProvider.future);

    if (!context.mounted) return;
    if (structures.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No active fee structures are available for invoice generation.')),
      );
      return;
    }

    var selectedId = structures.first['id']?.toString() ?? '';
    var dueDate = _date(structures.first['default_due_date']) ??
        DateTime.now().add(const Duration(days: 30));
    var includeOptional = false;
    var submitting = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final selected = structures.firstWhere(
            (row) => row['id']?.toString() == selectedId,
            orElse: () => structures.first,
          );
          final currency = selected['currency']?.toString() ?? 'UNSPECIFIED';

          return AlertDialog(
            title: const Text('Generate Invoices'),
            content: SizedBox(
              width: 520,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: selectedId,
                    decoration: const InputDecoration(labelText: 'Fee Structure'),
                    items: structures.map((structure) {
                      final id = structure['id']?.toString() ?? '';
                      final name = structure['name']?.toString() ?? 'Fee Structure';
                      final code = structure['currency']?.toString() ?? '—';
                      return DropdownMenuItem(value: id, child: Text('$name · $code'));
                    }).toList(),
                    onChanged: submitting
                        ? null
                        : (value) {
                            if (value == null) return;
                            final next = structures.firstWhere(
                              (row) => row['id']?.toString() == value,
                            );
                            setDialogState(() {
                              selectedId = value;
                              dueDate = _date(next['default_due_date']) ?? dueDate;
                            });
                          },
                  ),
                  const SizedBox(height: 14),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Due Date'),
                    subtitle: Text('${dueDate.day}/${dueDate.month}/${dueDate.year}'),
                    trailing: TextButton(
                      onPressed: submitting
                          ? null
                          : () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: dueDate,
                                firstDate: DateTime.now(),
                                lastDate: DateTime.now().add(const Duration(days: 730)),
                              );
                              if (picked != null) setDialogState(() => dueDate = picked);
                            },
                      child: const Text('Change'),
                    ),
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Include optional fee items'),
                    subtitle: Text('Invoices will be generated in $currency.'),
                    value: includeOptional,
                    onChanged: submitting
                        ? null
                        : (value) => setDialogState(() => includeOptional = value),
                  ),
                  const Text(
                    'Generation runs on the server and skips existing active invoices for the same student and fee structure.',
                    style: TextStyle(color: AppTheme.stitchMuted, fontSize: 11.5),
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
                        setDialogState(() => submitting = true);
                        try {
                          final result = await ref.read(financeRepositoryProvider).generateInvoices(
                                feeStructureId: selectedId,
                                dueDate: dueDate,
                                includeOptional: includeOptional,
                              );
                          ref.invalidate(invoiceManagementProvider);
                          ref.invalidate(financeDashboardMetricsProvider);
                          if (dialogContext.mounted) Navigator.pop(dialogContext);
                          if (mounted) {
                            final created = (result['created_count'] as num?)?.toInt() ?? 0;
                            final skipped = (result['skipped_existing_count'] as num?)?.toInt() ?? 0;
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Generated $created invoice${created == 1 ? '' : 's'}; $skipped existing skipped.',
                                ),
                              ),
                            );
                          }
                        } catch (error) {
                          if (dialogContext.mounted) {
                            ScaffoldMessenger.of(dialogContext).showSnackBar(
                              SnackBar(content: Text('Generation failed: $error')),
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
                    : const Icon(Icons.auto_awesome_rounded, size: 16),
                label: const Text('Generate'),
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

  static String _shortId(dynamic value) {
    final text = value?.toString() ?? '';
    return text.length <= 8 ? text : text.substring(0, 8).toUpperCase();
  }
}

class _InvoiceSummary extends StatelessWidget {
  final List<Map<String, dynamic>> invoices;

  const _InvoiceSummary({required this.invoices});

  @override
  Widget build(BuildContext context) {
    final byCurrency = <String, Map<String, double>>{};
    for (final invoice in invoices) {
      final currency = invoice['currency']?.toString() ?? 'UNSPECIFIED';
      final bucket = byCurrency.putIfAbsent(
        currency,
        () => {'total': 0, 'paid': 0, 'outstanding': 0},
      );
      final total = _number(invoice['total_amount']);
      final paid = _number(invoice['paid_amount']);
      bucket['total'] = bucket['total']! + total;
      bucket['paid'] = bucket['paid']! + paid;
      bucket['outstanding'] = bucket['outstanding']! + (total - paid);
    }

    if (byCurrency.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: byCurrency.entries.map((entry) {
        final values = entry.value;
        return SizedBox(
          width: 260,
          child: StitchCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.key, style: const TextStyle(color: AppTheme.primaryDark, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text(
                  '${entry.key} ${values['outstanding']!.toStringAsFixed(2)} outstanding',
                  style: const TextStyle(color: AppTheme.stitchHeading, fontWeight: FontWeight.w700, fontSize: 15),
                ),
                const SizedBox(height: 3),
                Text(
                  'Invoiced ${entry.key} ${values['total']!.toStringAsFixed(2)} · Paid ${entry.key} ${values['paid']!.toStringAsFixed(2)}',
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

class _Metric extends StatelessWidget {
  final String label;
  final String value;

  const _Metric({required this.label, required this.value});

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
          style: const TextStyle(color: AppTheme.stitchHeading, fontWeight: FontWeight.w700, fontSize: 12.5),
        ),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

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
