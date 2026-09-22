import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../services/services.dart';
import '../../widgets/stitch_widgets.dart';

class SchoolFinanceScreen extends ConsumerStatefulWidget {
  const SchoolFinanceScreen({super.key});

  @override
  ConsumerState<SchoolFinanceScreen> createState() => _SchoolFinanceScreenState();
}

class _SchoolFinanceScreenState extends ConsumerState<SchoolFinanceScreen> {
  // ── FEE TYPE DIALOG ──────────────────────────────────────────
  void _showAddFeeTypeDialog(BuildContext context, String schoolId) {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final amountCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create Fee Type'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Fee Name (e.g. Term 1 Tuition)')),
            const SizedBox(height: 10),
            TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Description (optional)')),
            const SizedBox(height: 10),
            TextField(
              controller: amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Standard Amount (\$)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty || amountCtrl.text.trim().isEmpty) return;
              final amount = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
              final client = ref.read(supabaseClientProvider);
              await SchoolFinanceService(client).createFeeType(
                schoolId: schoolId,
                name: nameCtrl.text.trim(),
                description: descCtrl.text.trim().isNotEmpty ? descCtrl.text.trim() : null,
                amount: amount,
              );
              ref.invalidate(feeTypesProvider(schoolId));
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  // ── BATCH INVOICE DIALOG ─────────────────────────────────────
  void _showBatchInvoiceDialog(BuildContext context, String schoolId, List<FeeTypeModel> feeTypes, List<AcademicYearModel> academicYears, List<ClassSectionModel> sections) {
    AcademicYearModel? selectedYear = academicYears.isNotEmpty ? academicYears.first : null;
    ClassSectionModel? selectedSection = sections.isNotEmpty ? sections.first : null;
    final Set<String> selectedFeeIds = {};
    DateTime dueDate = DateTime.now().add(const Duration(days: 30));

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: const Text('Batch Generate Term Invoices'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<AcademicYearModel>(
                  initialValue: selectedYear,
                  decoration: const InputDecoration(labelText: 'Academic Year'),
                  items: academicYears.map((y) => DropdownMenuItem(value: y, child: Text(y.name))).toList(),
                  onChanged: (v) => setStateDialog(() => selectedYear = v),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<ClassSectionModel>(
                  initialValue: selectedSection,
                  decoration: const InputDecoration(labelText: 'Class Section'),
                  items: sections.map((s) => DropdownMenuItem(value: s, child: Text(s.name))).toList(),
                  onChanged: (v) => setStateDialog(() => selectedSection = v),
                ),
                const SizedBox(height: 14),
                const Text('Select Fee Types to Include:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                ...feeTypes.map((ft) => CheckboxListTile(
                  dense: true,
                  title: Text('${ft.name} (\$${ft.amount.toStringAsFixed(2)})'),
                  value: selectedFeeIds.contains(ft.id),
                  onChanged: (v) => setStateDialog(() {
                    if (v == true) {
                      selectedFeeIds.add(ft.id);
                    } else {
                      selectedFeeIds.remove(ft.id);
                    }
                  }),
                )),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Due Date: ${dueDate.day}/${dueDate.month}/${dueDate.year}',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    TextButton(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: dueDate,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (picked != null) setStateDialog(() => dueDate = picked);
                      },
                      child: const Text('Change'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (selectedYear == null || selectedSection == null || selectedFeeIds.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please select year, section, and at least one fee type.')),
                  );
                  return;
                }
                final client = ref.read(supabaseClientProvider);
                final selectedFees = feeTypes.where((f) => selectedFeeIds.contains(f.id)).toList();
                final feeItems = selectedFees.map((f) => {'fee_type_id': f.id, 'amount': f.amount}).toList();
                final count = await SchoolFinanceService(client).generateBatchInvoices(
                  schoolId: schoolId,
                  classSectionId: selectedSection!.id,
                  academicYearId: selectedYear!.id,
                  feeItems: feeItems,
                  dueDate: dueDate,
                );
                ref.invalidate(invoicesProvider(schoolId));
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Generated $count invoices successfully ✓')),
                  );
                }
              },
              child: const Text('Generate Invoices'),
            ),
          ],
        ),
      ),
    );
  }

  // ── BURSARY DIALOG ───────────────────────────────────────────
  void _showCreateBursaryDialog(BuildContext context, String schoolId) {
    final nameCtrl = TextEditingController();
    final valueCtrl = TextEditingController();
    bool isPercentage = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setD) => AlertDialog(
          title: const Text('Create Bursary / Scholarship'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Bursary Name (e.g. Academic Excellence Bursary)')),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Text('Discount Type:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const Spacer(),
                  ChoiceChip(label: const Text('Percentage'), selected: isPercentage, onSelected: (v) => setD(() => isPercentage = true)),
                  const SizedBox(width: 6),
                  ChoiceChip(label: const Text('Fixed \$'), selected: !isPercentage, onSelected: (v) => setD(() => isPercentage = false)),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: valueCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: isPercentage ? 'Discount % (e.g. 50)' : 'Fixed Amount (\$)'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty || valueCtrl.text.trim().isEmpty) return;
                final value = double.tryParse(valueCtrl.text.trim()) ?? 0.0;
                final client = ref.read(supabaseClientProvider);
                await SchoolFinanceService(client).createBursary(
                  schoolId: schoolId,
                  name: nameCtrl.text.trim(),
                  discountPercentage: isPercentage ? value : null,
                  discountAmount: isPercentage ? null : value,
                );
                ref.invalidate(bursariesProvider(schoolId));
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  // ── PAYROLL DIALOG ───────────────────────────────────────────
  void _showAddPayrollDialog(BuildContext context, String schoolId, List<ProfileModel> staff) {
    ProfileModel? selectedStaff = staff.isNotEmpty ? staff.first : null;
    final baseCtrl = TextEditingController();
    final allowCtrl = TextEditingController(text: '0');
    final dedCtrl = TextEditingController(text: '0');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setD) => AlertDialog(
          title: const Text('New Payroll Entry'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<ProfileModel>(
                  initialValue: selectedStaff,
                  decoration: const InputDecoration(labelText: 'Staff Member'),
                  items: staff.map((s) => DropdownMenuItem(value: s, child: Text(s.fullName))).toList(),
                  onChanged: (v) => setD(() => selectedStaff = v),
                ),
                const SizedBox(height: 10),
                TextField(controller: baseCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Base Salary (\$)')),
                const SizedBox(height: 10),
                TextField(controller: allowCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Allowances (\$)')),
                const SizedBox(height: 10),
                TextField(controller: dedCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Deductions (\$)')),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (selectedStaff == null || baseCtrl.text.trim().isEmpty) return;
                final client = ref.read(supabaseClientProvider);
                await SchoolFinanceService(client).createPayrollEntry(
                  schoolId: schoolId,
                  staffProfileId: selectedStaff!.id,
                  baseSalary: double.tryParse(baseCtrl.text.trim()) ?? 0.0,
                  allowances: double.tryParse(allowCtrl.text.trim()) ?? 0.0,
                  deductions: double.tryParse(dedCtrl.text.trim()) ?? 0.0,
                  paymentDate: DateTime.now(),
                );
                ref.invalidate(staffPayrollProvider(schoolId));
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Create Voucher'),
            ),
          ],
        ),
      ),
    );
  }

  // ── EXPENSE LOG DIALOG ───────────────────────────────────────
  void _showLogExpenseDialog(BuildContext context, String schoolId, String profileId) {
    final titleCtrl = TextEditingController();
    final amtCtrl = TextEditingController();
    String category = 'Utilities';
    final categories = ['Utilities', 'Maintenance', 'Stationery', 'Transport', 'Events', 'Catering', 'Other'];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setD) => AlertDialog(
          title: const Text('Log School Expense'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Expense Description')),
              const SizedBox(height: 10),
              TextField(controller: amtCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Amount (\$)')),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: category,
                decoration: const InputDecoration(labelText: 'Category'),
                items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (v) => setD(() => category = v ?? 'Other'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (titleCtrl.text.trim().isEmpty || amtCtrl.text.trim().isEmpty) return;
                final client = ref.read(supabaseClientProvider);
                await SchoolFinanceService(client).logExpense(
                  schoolId: schoolId,
                  title: titleCtrl.text.trim(),
                  category: category,
                  amount: double.tryParse(amtCtrl.text.trim()) ?? 0.0,
                  spentByProfileId: profileId,
                  spentAt: DateTime.now(),
                );
                ref.invalidate(expensesProvider(schoolId));
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Log Expense'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(activeSessionProvider);
    if (session == null) return const Scaffold(body: Center(child: Text('No active session')));
    final schoolId = session.schoolId;

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: AppTheme.stitchBg,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 1,
          title: const Row(
            children: [
              Text('FINANCE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: AppTheme.primaryDark)),
              SizedBox(width: 8),
              Text('Dashboard', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: AppTheme.stitchHeading)),
            ],
          ),
          bottom: const TabBar(
            isScrollable: true,
            labelColor: AppTheme.primary,
            unselectedLabelColor: AppTheme.stitchMuted,
            indicatorColor: AppTheme.primary,
            tabs: [
              Tab(icon: Icon(Icons.receipt_long_rounded), text: 'Invoices & Fees'),
              Tab(icon: Icon(Icons.card_giftcard_rounded), text: 'Bursaries'),
              Tab(icon: Icon(Icons.account_balance_wallet_rounded), text: 'Expenses & Budgets'),
              Tab(icon: Icon(Icons.payments_rounded), text: 'Staff Payroll'),
            ],
          ),
        ),
        body: Column(
          children: [
            // Finance KPI Header — real data from getFinanceDashboardMetrics()
            Consumer(
              builder: (context, ref, _) {
                final metricsAsync = ref.watch(financeDashboardMetricsProvider);
                return metricsAsync.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (_, _) => const SizedBox.shrink(),
                  data: (m) {
                    final invoiced = m['total_invoiced'] ?? m['invoiced'] ?? 0.0;
                    final collected = m['total_collected'] ?? m['collected'] ?? 0.0;
                    final outstanding = m['total_outstanding'] ?? m['outstanding'] ?? 0.0;
                    final expenses = m['total_expenses'] ?? m['expenses'] ?? 0.0;
                    final rate = m['collection_rate'] ?? (invoiced > 0 ? (collected / invoiced * 100) : 0.0);

                    String fmt(dynamic v) {
                      final d = (v is num) ? v.toDouble() : 0.0;
                      if (d >= 1000000) return '\$${(d / 1000000).toStringAsFixed(1)}M';
                      if (d >= 1000) return '\$${(d / 1000).toStringAsFixed(1)}K';
                      return '\$${d.toStringAsFixed(0)}';
                    }

                    return LayoutBuilder(
                      builder: (ctx, constraints) {
                        final isMobile = constraints.maxWidth < 600;
                        return Container(
                          color: Colors.white,
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                          child: isMobile
                              ? GridView.count(
                                  crossAxisCount: 2,
                                  crossAxisSpacing: 10,
                                  mainAxisSpacing: 10,
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  childAspectRatio: 2.2,
                                  children: [
                                    StitchKpiCard(label: 'Invoiced', value: fmt(invoiced), hint: 'Current term', icon: Icons.receipt_long_rounded),
                                    StitchKpiCard(label: 'Collected', value: fmt(collected), hint: '${rate.toStringAsFixed(1)}% rate', statusColor: StitchChipVariant.success, icon: Icons.check_circle_rounded),
                                    StitchKpiCard(label: 'Outstanding', value: fmt(outstanding), hint: outstanding > 0 ? 'Pending collection' : 'All clear', statusColor: outstanding > 0 ? StitchChipVariant.warn : StitchChipVariant.success, icon: Icons.pending_rounded),
                                    StitchKpiCard(label: 'Expenses', value: fmt(expenses), hint: 'Current month', statusColor: StitchChipVariant.neutral, icon: Icons.account_balance_wallet_rounded),
                                  ],
                                )
                              : Row(
                                  children: [
                                    Expanded(child: StitchKpiCard(label: 'Invoiced', value: fmt(invoiced), hint: 'Current term', icon: Icons.receipt_long_rounded)),
                                    const SizedBox(width: 10),
                                    Expanded(child: StitchKpiCard(label: 'Collected', value: fmt(collected), hint: '${rate.toStringAsFixed(1)}% rate', statusColor: StitchChipVariant.success, icon: Icons.check_circle_rounded)),
                                    const SizedBox(width: 10),
                                    Expanded(child: StitchKpiCard(label: 'Outstanding', value: fmt(outstanding), hint: outstanding > 0 ? 'Pending' : 'All clear', statusColor: outstanding > 0 ? StitchChipVariant.warn : StitchChipVariant.success, icon: Icons.pending_rounded)),
                                    const SizedBox(width: 10),
                                    Expanded(child: StitchKpiCard(label: 'Expenses', value: fmt(expenses), hint: 'Current month', statusColor: StitchChipVariant.neutral, icon: Icons.account_balance_wallet_rounded)),
                                  ],
                                ),
                        );
                      },
                    );
                  },
                );
              },
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _InvoicesTab(schoolId: schoolId, profileId: session.profileId, onAddFeeType: _showAddFeeTypeDialog, onBatchInvoice: _showBatchInvoiceDialog),
                  _BursariesTab(schoolId: schoolId, onCreateBursary: _showCreateBursaryDialog),
                  _ExpensesBudgetsTab(schoolId: schoolId, profileId: session.profileId, onLogExpense: _showLogExpenseDialog),
                  _PayrollTab(schoolId: schoolId, onAddPayroll: _showAddPayrollDialog),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}


// ─────────────────────────────────────────────────────────────────
// TAB 1: INVOICES & FEES
// ─────────────────────────────────────────────────────────────────
class _InvoicesTab extends ConsumerWidget {
  final String schoolId;
  final String profileId;
  final void Function(BuildContext, String) onAddFeeType;
  final void Function(BuildContext, String, List<FeeTypeModel>, List<AcademicYearModel>, List<ClassSectionModel>) onBatchInvoice;

  const _InvoicesTab({required this.schoolId, required this.profileId, required this.onAddFeeType, required this.onBatchInvoice});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feeTypesAsync = ref.watch(feeTypesProvider(schoolId));
    final invoicesAsync = ref.watch(invoicesProvider(schoolId));
    final yearsAsync = ref.watch(academicYearsProvider(schoolId));
    final sectionsAsync = ref.watch(classSectionsProvider(schoolId));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Fee Catalog Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Fee Catalog', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              TextButton.icon(
                onPressed: () => onAddFeeType(context, schoolId),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Add Fee Type'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          feeTypesAsync.when(
            data: (fees) {
              if (fees.isEmpty) {
                return const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: Text('No fee types configured. Add one to get started.', style: TextStyle(color: AppTheme.textMuted))),
                  ),
                );
              }
              return Card(
                child: Column(
                  children: fees.map((ft) => ListTile(
                    leading: const CircleAvatar(backgroundColor: AppTheme.primary, child: Icon(Icons.attach_money_rounded, color: Colors.white, size: 18)),
                    title: Text(ft.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: ft.description != null ? Text(ft.description!) : null,
                    trailing: Text('\$${ft.amount.toStringAsFixed(2)}', style: const TextStyle(color: AppTheme.success, fontWeight: FontWeight.bold, fontSize: 16)),
                  )).toList(),
                ),
              );
            },
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('Error: $e'),
          ),

          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Student Invoices', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ElevatedButton.icon(
                onPressed: () {
                  final fees = feeTypesAsync.value ?? [];
                  final years = yearsAsync.value ?? [];
                  final sections = sectionsAsync.value ?? [];
                  onBatchInvoice(context, schoolId, fees, years, sections);
                },
                icon: const Icon(Icons.receipt_rounded, size: 14),
                label: const Text('Batch Generate'),
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          invoicesAsync.when(
            data: (invoices) {
              if (invoices.isEmpty) {
                return const Card(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(child: Text('No invoices generated yet.', style: TextStyle(color: AppTheme.textMuted))),
                  ),
                );
              }
              return Column(
                children: invoices.take(30).map((inv) => _InvoiceCard(invoice: inv, showStudentName: true)).toList(),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Error loading invoices: $e'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// TAB 2: BURSARIES
// ─────────────────────────────────────────────────────────────────
class _BursariesTab extends ConsumerWidget {
  final String schoolId;
  final void Function(BuildContext, String) onCreateBursary;

  const _BursariesTab({required this.schoolId, required this.onCreateBursary});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bursariesAsync = ref.watch(bursariesProvider(schoolId));
    final studentBursariesAsync = ref.watch(studentBursariesProvider((schoolId, null)));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Scholarship Schemes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              TextButton.icon(
                onPressed: () => onCreateBursary(context, schoolId),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Create Bursary'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          bursariesAsync.when(
            data: (bursaries) {
              if (bursaries.isEmpty) {
                return const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: Text('No bursary schemes configured yet.', style: TextStyle(color: AppTheme.textMuted))),
                  ),
                );
              }
              return Card(
                child: Column(
                  children: bursaries.map((b) => ListTile(
                    leading: const CircleAvatar(backgroundColor: AppTheme.accent, child: Icon(Icons.card_giftcard_rounded, color: Colors.white, size: 18)),
                    title: Text(b.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.success.withAlpha(25),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(b.discountLabel, style: const TextStyle(color: AppTheme.success, fontWeight: FontWeight.bold)),
                    ),
                  )).toList(),
                ),
              );
            },
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('Error: $e'),
          ),

          const SizedBox(height: 20),
          const Text('Active Student Bursaries', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          studentBursariesAsync.when(
            data: (assignments) {
              if (assignments.isEmpty) {
                return const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: Text('No bursaries linked to students yet.', style: TextStyle(color: AppTheme.textMuted))),
                  ),
                );
              }
              return Card(
                child: Column(
                  children: assignments.map((a) => ListTile(
                    title: Text(a.student?.fullName ?? 'Unknown Student', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(a.bursary?.name ?? 'Unknown Bursary'),
                    trailing: a.bursary != null
                        ? Text(a.bursary!.discountLabel, style: const TextStyle(color: AppTheme.accent, fontWeight: FontWeight.bold))
                        : null,
                  )).toList(),
                ),
              );
            },
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('Error: $e'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// TAB 3: EXPENSES & BUDGETS
// ─────────────────────────────────────────────────────────────────
class _ExpensesBudgetsTab extends ConsumerWidget {
  final String schoolId;
  final String profileId;
  final void Function(BuildContext, String, String) onLogExpense;

  const _ExpensesBudgetsTab({required this.schoolId, required this.profileId, required this.onLogExpense});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expensesAsync = ref.watch(expensesProvider(schoolId));
    final yearsAsync = ref.watch(academicYearsProvider(schoolId));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Expenses
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('School Expenditure Log', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              TextButton.icon(
                onPressed: () => onLogExpense(context, schoolId, profileId),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Log Expense'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          expensesAsync.when(
            data: (expenses) {
              if (expenses.isEmpty) {
                return const Card(
                  child: Padding(padding: EdgeInsets.all(16), child: Center(child: Text('No expenses logged yet.', style: TextStyle(color: AppTheme.textMuted)))),
                );
              }
              final total = expenses.fold(0.0, (s, e) => s + e.amount);
              return Column(
                children: [
                  // Summary Banner
                  Container(
                    padding: const EdgeInsets.all(14),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF7C3AED), Color(0xFF4F46E5)]),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total Expenses (All Time)', style: TextStyle(color: Colors.white70, fontSize: 12)),
                        Text('\$${total.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22)),
                      ],
                    ),
                  ),
                  ...expenses.take(20).map((e) => Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppTheme.cardDark,
                        child: Text(e.category[0], style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary)),
                      ),
                      title: Text(e.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('${e.category} • ${e.spentAt.day}/${e.spentAt.month}/${e.spentAt.year}'),
                      trailing: Text('\$${e.amount.toStringAsFixed(2)}', style: const TextStyle(color: AppTheme.warning, fontWeight: FontWeight.bold)),
                    ),
                  )),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Error: $e'),
          ),

          const SizedBox(height: 20),
          const Text('Department Budgets', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          yearsAsync.when(
            data: (years) {
              if (years.isEmpty) return const Text('No academic years found.', style: TextStyle(color: AppTheme.textMuted));
              final activeYear = years.firstWhere((y) => y.isCurrent, orElse: () => years.first);
              final budgetsAsync = ref.watch(budgetsProvider((schoolId, activeYear.id)));
              return budgetsAsync.when(
                data: (budgets) {
                  if (budgets.isEmpty) {
                    return const Card(
                      child: Padding(padding: EdgeInsets.all(16), child: Center(child: Text('No department budgets allocated yet.', style: TextStyle(color: AppTheme.textMuted)))),
                    );
                  }
                  return Column(
                    children: budgets.map((b) {
                      final utilization = b.utilizationPercentage.clamp(0.0, 100.0);
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(b.departmentName, style: const TextStyle(fontWeight: FontWeight.bold)),
                                  Text('\$${b.spentAmount.toStringAsFixed(0)} / \$${b.allocatedAmount.toStringAsFixed(0)}',
                                      style: TextStyle(
                                        color: utilization > 90 ? AppTheme.danger : AppTheme.textMuted,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      )),
                                ],
                              ),
                              const SizedBox(height: 8),
                              LinearProgressIndicator(
                                value: utilization / 100.0,
                                color: utilization > 90 ? AppTheme.danger : (utilization > 70 ? AppTheme.warning : AppTheme.success),
                                backgroundColor: AppTheme.borderDark,
                                minHeight: 8,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              const SizedBox(height: 4),
                              Text('${utilization.toStringAsFixed(1)}% utilized • \$${b.remainingBudget.toStringAsFixed(2)} remaining',
                                  style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('Error: $e'),
              );
            },
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('Error: $e'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// TAB 4: STAFF PAYROLL
// ─────────────────────────────────────────────────────────────────
class _PayrollTab extends ConsumerWidget {
  final String schoolId;
  final void Function(BuildContext, String, List<ProfileModel>) onAddPayroll;

  const _PayrollTab({required this.schoolId, required this.onAddPayroll});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final payrollAsync = ref.watch(staffPayrollProvider(schoolId));
    final profilesAsync = ref.watch(schoolProfilesProvider(schoolId));

    return payrollAsync.when(
      data: (payroll) {
        final pending = payroll.where((p) => p.status == 'pending').toList();
        final processed = payroll.where((p) => p.status == 'processed').toList();

        final staffProfiles = (profilesAsync.value ?? [])
            .where((p) => p.role == 'teacher' || p.role == 'staff')
            .toList();

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Salary Vouchers', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ElevatedButton.icon(
                    onPressed: () => onAddPayroll(context, schoolId, staffProfiles),
                    icon: const Icon(Icons.add_rounded, size: 14),
                    label: const Text('New Voucher'),
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              if (pending.isNotEmpty) ...[
                const Text('⏳ Pending Approval', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.warning)),
                const SizedBox(height: 8),
                ...pending.map((p) => _PayrollCard(payroll: p, onProcess: () async {
                  final client = ref.read(supabaseClientProvider);
                  await SchoolFinanceService(client).processPayroll(p.id);
                  ref.invalidate(staffPayrollProvider(schoolId));
                })),
                const SizedBox(height: 16),
              ],

              if (processed.isNotEmpty) ...[
                const Text('✅ Processed Payments', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.success)),
                const SizedBox(height: 8),
                ...processed.map((p) => _PayrollCard(payroll: p, onProcess: null)),
              ],

              if (payroll.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(child: Text('No payroll records yet. Create the first salary voucher.', style: TextStyle(color: AppTheme.textMuted))),
                  ),
                ),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }
}

class _PayrollCard extends StatelessWidget {
  final StaffPayrollModel payroll;
  final VoidCallback? onProcess;

  const _PayrollCard({required this.payroll, required this.onProcess});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(payroll.staff?.fullName ?? 'Unknown Staff', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                Text('${payroll.paymentDate.day}/${payroll.paymentDate.month}/${payroll.paymentDate.year}',
                    style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _PayStat(label: 'Base', value: '\$${payroll.baseSalary.toStringAsFixed(2)}', color: AppTheme.textPrimary),
                _PayStat(label: '+ Allow.', value: '\$${payroll.allowances.toStringAsFixed(2)}', color: AppTheme.success),
                _PayStat(label: '- Deduct.', value: '\$${payroll.deductions.toStringAsFixed(2)}', color: AppTheme.danger),
                _PayStat(label: 'Net Pay', value: '\$${payroll.netSalary.toStringAsFixed(2)}', color: AppTheme.accent),
              ],
            ),
            if (onProcess != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onProcess,
                  icon: const Icon(Icons.check_circle_rounded, size: 16),
                  label: const Text('Mark as Processed & Paid'),
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.success),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PayStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _PayStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 13)),
        Text(label, style: const TextStyle(color: AppTheme.textMuted, fontSize: 10)),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// SHARED INVOICE CARD
// ─────────────────────────────────────────────────────────────────
class _InvoiceCard extends StatelessWidget {
  final InvoiceModel invoice;
  final bool showStudentName;

  const _InvoiceCard({required this.invoice, this.showStudentName = false});

  Color get _statusColor {
    switch (invoice.status) {
      case 'paid': return AppTheme.success;
      case 'partial': return AppTheme.warning;
      default: return AppTheme.danger;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _statusColor.withAlpha(25),
          child: Icon(Icons.receipt_rounded, color: _statusColor, size: 20),
        ),
        title: Text(
          showStudentName ? (invoice.student?.fullName ?? 'Student') : 'Invoice #${invoice.id.substring(0, 8)}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text('Due: ${invoice.dueDate.day}/${invoice.dueDate.month}/${invoice.dueDate.year} • Paid: \$${invoice.paidAmount.toStringAsFixed(2)} of \$${invoice.totalAmount.toStringAsFixed(2)}'),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _statusColor.withAlpha(25),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(invoice.status.toUpperCase(), style: TextStyle(color: _statusColor, fontWeight: FontWeight.bold, fontSize: 10)),
        ),
      ),
    );
  }
}
