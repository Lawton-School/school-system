import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../widgets/stitch_widgets.dart';

/// Currency-safe KPI header for Screen 12.
///
/// Reads only `currency_totals` from `get_finance_dashboard_metrics()` so
/// invoice values from different currencies are never combined for display.
/// The legacy scalar totals remain in the RPC for backwards compatibility but
/// are deliberately ignored here.
class FinanceCurrencyKpiHeader extends StatelessWidget {
  final Map<String, dynamic> metrics;

  const FinanceCurrencyKpiHeader({
    super.key,
    required this.metrics,
  });

  @override
  Widget build(BuildContext context) {
    final totals = _mapList(metrics['currency_totals']);

    if (totals.isEmpty) {
      return Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: const StitchCard(
          child: Row(
            children: [
              Icon(Icons.account_balance_wallet_outlined, color: AppTheme.primary),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Finance Overview',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppTheme.stitchHeading,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'No invoice balances are available for the current academic year.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.stitchMuted,
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

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var index = 0; index < totals.length; index++) ...[
            _CurrencySection(summary: totals[index]),
            if (index != totals.length - 1) const SizedBox(height: 12),
          ],
          if (metrics['expenses_currency_scoped'] != true) ...[
            const SizedBox(height: 10),
            const Text(
              'Expense totals are excluded from these currency KPIs because existing expense records do not store a currency.',
              style: TextStyle(
                color: AppTheme.stitchMuted,
                fontSize: 11,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }

  static List<Map<String, dynamic>> _mapList(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList(growable: false);
  }
}

class _CurrencySection extends StatelessWidget {
  final Map<String, dynamic> summary;

  const _CurrencySection({required this.summary});

  @override
  Widget build(BuildContext context) {
    final currency = summary['currency']?.toString().trim().isNotEmpty == true
        ? summary['currency'].toString()
        : 'UNSPECIFIED';
    final invoiced = _number(summary['total_invoiced']);
    final paid = _number(summary['total_paid']);
    final outstanding = _number(summary['outstanding']);
    final overdue = _number(summary['overdue']);
    final rate = _number(summary['collection_rate']);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              currency,
              style: const TextStyle(
                color: AppTheme.primaryDark,
                fontWeight: FontWeight.w800,
                fontSize: 12,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(width: 8),
            const Expanded(child: Divider(color: AppTheme.stitchBorder)),
          ],
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 900 ? 4 : 2;
            final spacing = 10.0;
            final width = (constraints.maxWidth - spacing * (columns - 1)) / columns;

            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: [
                SizedBox(
                  width: width,
                  child: StitchKpiCard(
                    label: 'Invoiced',
                    value: _format(currency, invoiced),
                    hint: 'Current academic year',
                    icon: Icons.receipt_long_rounded,
                  ),
                ),
                SizedBox(
                  width: width,
                  child: StitchKpiCard(
                    label: 'Collected',
                    value: _format(currency, paid),
                    hint: '${rate.toStringAsFixed(1)}% collection rate',
                    statusColor: StitchChipVariant.success,
                    icon: Icons.check_circle_rounded,
                  ),
                ),
                SizedBox(
                  width: width,
                  child: StitchKpiCard(
                    label: 'Outstanding',
                    value: _format(currency, outstanding),
                    hint: outstanding > 0 ? 'Pending collection' : 'All clear',
                    statusColor: outstanding > 0
                        ? StitchChipVariant.warn
                        : StitchChipVariant.success,
                    icon: Icons.pending_rounded,
                  ),
                ),
                SizedBox(
                  width: width,
                  child: StitchKpiCard(
                    label: 'Overdue',
                    value: _format(currency, overdue),
                    hint: overdue > 0 ? 'Past due balances' : 'No overdue balance',
                    statusColor: overdue > 0
                        ? StitchChipVariant.danger
                        : StitchChipVariant.success,
                    icon: Icons.warning_amber_rounded,
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  static double _number(dynamic value) => value is num ? value.toDouble() : 0.0;

  static String _format(String currency, double value) {
    if (value.abs() >= 1000000) {
      return '$currency ${(value / 1000000).toStringAsFixed(1)}M';
    }
    if (value.abs() >= 1000) {
      return '$currency ${(value / 1000).toStringAsFixed(1)}K';
    }
    return '$currency ${value.toStringAsFixed(0)}';
  }
}
