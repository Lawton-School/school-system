import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../controllers/library_controllers.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../providers/providers.dart';
import '../../widgets/stitch_widgets.dart';

/// Screen 20 — Library Management.
///
/// Dashboard data comes from `get_library_dashboard()`. Issue/return/fine
/// mutations are server-authoritative RPCs. Teachers and registrars can view
/// the dashboard; only School Admin/Super Admin receive management actions.
class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(activeSessionProvider);
    if (session == null) {
      return const Scaffold(body: Center(child: Text('No active session')));
    }

    final dashboardAsync = ref.watch(libraryDashboardProvider);
    final canManage = session.role == AppRoles.schoolAdmin ||
        session.role == AppRoles.superAdmin;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: AppTheme.stitchBg,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 1,
          title: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'OPERATIONS',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: AppTheme.primaryDark,
                ),
              ),
              Text(
                'Library Management',
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
              tooltip: 'Refresh library',
              onPressed: () {
                ref.invalidate(libraryDashboardProvider);
                ref.invalidate(libraryFinesProvider(session.schoolId));
              },
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Catalog'),
              Tab(text: 'Overdue'),
              Tab(text: 'Fines'),
            ],
          ),
        ),
        body: dashboardAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => _ErrorState(
            message: 'Unable to load library: $error',
            onRetry: () => ref.invalidate(libraryDashboardProvider),
          ),
          data: (dashboard) {
            final catalog = _mapList(dashboard['catalog']);
            final overdue = _mapList(dashboard['overdue_items']);

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: _LibrarySummary(dashboard: dashboard),
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _CatalogTab(
                        items: catalog,
                        canManage: canManage,
                        onIssue: (book) => _issueBook(
                          context,
                          ref,
                          schoolId: session.schoolId,
                          book: book,
                        ),
                      ),
                      _OverdueTab(
                        items: overdue,
                        canManage: canManage,
                        onReturn: (issue) => _returnBook(context, ref, issue),
                        onFine: (issue) => _createFine(
                          context,
                          ref,
                          schoolId: session.schoolId,
                          issue: issue,
                        ),
                      ),
                      _FinesTab(
                        schoolId: session.schoolId,
                        canManage: canManage,
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _issueBook(
    BuildContext context,
    WidgetRef ref, {
    required String schoolId,
    required Map<String, dynamic> book,
  }) async {
    final borrowers = await ref.read(libraryBorrowersProvider(schoolId).future);
    if (!context.mounted) return;
    if (borrowers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No active borrower profiles are available.')),
      );
      return;
    }

    String? borrowerId;
    DateTime? dueDate;
    final notesController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Issue ${book['title'] ?? 'Book'}'),
          content: SizedBox(
            width: 500,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: borrowerId,
                  decoration: const InputDecoration(labelText: 'Borrower'),
                  items: borrowers.map((profile) {
                    final id = profile['id']?.toString() ?? '';
                    final name = '${profile['first_name'] ?? ''} ${profile['last_name'] ?? ''}'.trim();
                    final role = profile['role']?.toString() ?? '';
                    return DropdownMenuItem(
                      value: id,
                      child: Text('$name${role.isEmpty ? '' : ' · $role'}'),
                    );
                  }).where((item) => item.value?.isNotEmpty == true).toList(),
                  onChanged: (value) => setDialogState(() => borrowerId = value),
                ),
                const SizedBox(height: 14),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Due date'),
                  subtitle: Text(
                    dueDate == null
                        ? 'Select a due date'
                        : '${dueDate!.day}/${dueDate!.month}/${dueDate!.year}',
                  ),
                  trailing: OutlinedButton(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: dialogContext,
                        initialDate: DateTime.now().add(const Duration(days: 1)),
                        firstDate: DateTime.now().add(const Duration(days: 1)),
                        lastDate: DateTime.now().add(const Duration(days: 366)),
                      );
                      if (picked != null) setDialogState(() => dueDate = picked);
                    },
                    child: const Text('Choose'),
                  ),
                ),
                TextField(
                  controller: notesController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                    alignLabelWithHint: true,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: borrowerId == null || dueDate == null
                  ? null
                  : () => Navigator.pop(dialogContext, true),
              child: const Text('Issue Book'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || borrowerId == null || dueDate == null) {
      notesController.dispose();
      return;
    }

    try {
      final dueAt = DateTime(
        dueDate!.year,
        dueDate!.month,
        dueDate!.day,
        23,
        59,
      );
      await ref.read(libraryRepositoryProvider).issueBook(
            bookId: book['id'].toString(),
            borrowerProfileId: borrowerId!,
            dueAt: dueAt,
            notes: notesController.text,
          );
      ref.invalidate(libraryDashboardProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Book issued successfully.')),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not issue book: $error')),
        );
      }
    } finally {
      notesController.dispose();
    }
  }

  Future<void> _returnBook(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> issue,
  ) async {
    final issueId = issue['issue_id']?.toString() ?? '';
    if (issueId.isEmpty) return;
    try {
      await ref.read(libraryRepositoryProvider).returnBook(issueId: issueId);
      ref.invalidate(libraryDashboardProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Book returned successfully.')),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not return book: $error')),
        );
      }
    }
  }

  Future<void> _createFine(
    BuildContext context,
    WidgetRef ref, {
    required String schoolId,
    required Map<String, dynamic> issue,
  }) async {
    final issueId = issue['issue_id']?.toString() ?? '';
    if (issueId.isEmpty) return;

    final currency = await ref.read(libraryCurrencyProvider(schoolId).future);
    if (!context.mounted) return;
    final amountController = TextEditingController();
    final reasonController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Create Library Fine'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: 'Amount ($currency)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Reason (optional)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Create Fine'),
          ),
        ],
      ),
    );

    final amount = double.tryParse(amountController.text.trim());
    final reason = reasonController.text;
    amountController.dispose();
    reasonController.dispose();
    if (confirmed != true || amount == null || amount < 0) return;

    try {
      await ref.read(libraryRepositoryProvider).createFine(
            issueId: issueId,
            amount: amount,
            reason: reason,
          );
      ref.invalidate(libraryFinesProvider(schoolId));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fine created.')),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not create fine: $error')),
        );
      }
    }
  }
}

class _LibrarySummary extends StatelessWidget {
  final Map<String, dynamic> dashboard;
  const _LibrarySummary({required this.dashboard});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 900 ? 4 : 2;
        return GridView.count(
          crossAxisCount: columns,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: constraints.maxWidth >= 900 ? 1.8 : 1.45,
          children: [
            StitchKpiCard(
              label: 'Books',
              value: '${dashboard['books'] ?? 0}',
              hint: 'Total catalog stock',
              icon: Icons.menu_book_rounded,
            ),
            StitchKpiCard(
              label: 'Available',
              value: '${dashboard['available'] ?? 0}',
              hint: 'Ready to issue',
              icon: Icons.inventory_2_rounded,
              statusColor: StitchChipVariant.success,
            ),
            StitchKpiCard(
              label: 'Issued',
              value: '${dashboard['issued'] ?? 0}',
              hint: '${dashboard['due_today'] ?? 0} due today',
              icon: Icons.assignment_ind_rounded,
            ),
            StitchKpiCard(
              label: 'Overdue',
              value: '${dashboard['overdue'] ?? 0}',
              hint: 'Needs follow-up',
              icon: Icons.warning_amber_rounded,
              statusColor: StitchChipVariant.warn,
            ),
          ],
        );
      },
    );
  }
}

class _CatalogTab extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final bool canManage;
  final void Function(Map<String, dynamic>) onIssue;

  const _CatalogTab({
    required this.items,
    required this.canManage,
    required this.onIssue,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const _EmptyState(
        icon: Icons.library_books_outlined,
        message: 'No books are in the library catalog yet.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final book = items[index];
        final available = (book['available_quantity'] as num?)?.toInt() ?? 0;
        return StitchCard(
          child: ListTile(
            leading: const CircleAvatar(
              backgroundColor: AppTheme.primarySoft,
              child: Icon(Icons.menu_book_rounded, color: AppTheme.primaryDark),
            ),
            title: Text(
              book['title']?.toString() ?? 'Untitled Book',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              [
                if ((book['author']?.toString() ?? '').isNotEmpty) book['author'],
                if ((book['shelf_code']?.toString() ?? '').isNotEmpty) 'Shelf ${book['shelf_code']}',
                '$available available',
              ].join(' • '),
            ),
            trailing: canManage
                ? FilledButton.tonal(
                    onPressed: available > 0 ? () => onIssue(book) : null,
                    child: Text(available > 0 ? 'Issue' : 'Unavailable'),
                  )
                : StitchChip(
                    label: book['stock_status']?.toString() ?? 'available',
                    variant: available > 0
                        ? StitchChipVariant.success
                        : StitchChipVariant.neutral,
                  ),
          ),
        );
      },
    );
  }
}

class _OverdueTab extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final bool canManage;
  final void Function(Map<String, dynamic>) onReturn;
  final void Function(Map<String, dynamic>) onFine;

  const _OverdueTab({
    required this.items,
    required this.canManage,
    required this.onReturn,
    required this.onFine,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const _EmptyState(
        icon: Icons.task_alt_rounded,
        message: 'No overdue library issues.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final issue = items[index];
        return StitchCard(
          child: ListTile(
            leading: const CircleAvatar(
              backgroundColor: Color(0xFFFFF7ED),
              child: Icon(Icons.schedule_rounded, color: AppTheme.warning),
            ),
            title: Text(
              issue['title']?.toString() ?? 'Library Book',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              '${issue['borrower_name'] ?? 'Borrower'} • ${issue['days_overdue'] ?? 0} days overdue',
            ),
            trailing: canManage
                ? Wrap(
                    spacing: 6,
                    children: [
                      OutlinedButton(
                        onPressed: () => onFine(issue),
                        child: const Text('Fine'),
                      ),
                      FilledButton(
                        onPressed: () => onReturn(issue),
                        child: const Text('Return'),
                      ),
                    ],
                  )
                : const StitchChip(
                    label: 'Overdue',
                    variant: StitchChipVariant.warn,
                  ),
          ),
        );
      },
    );
  }
}

class _FinesTab extends ConsumerWidget {
  final String schoolId;
  final bool canManage;

  const _FinesTab({required this.schoolId, required this.canManage});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final finesAsync = ref.watch(libraryFinesProvider(schoolId));
    final currency = ref.watch(libraryCurrencyProvider(schoolId)).valueOrNull ?? 'Currency';

    return finesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _ErrorState(
        message: 'Unable to load fines: $error',
        onRetry: () => ref.invalidate(libraryFinesProvider(schoolId)),
      ),
      data: (fines) {
        if (fines.isEmpty) {
          return const _EmptyState(
            icon: Icons.receipt_long_outlined,
            message: 'No library fines recorded.',
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: fines.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final fine = fines[index];
            final status = fine['status']?.toString() ?? 'unpaid';
            final amount = (fine['amount'] as num?)?.toDouble() ?? 0;
            return StitchCard(
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: AppTheme.primarySoft,
                  child: Icon(Icons.payments_outlined, color: AppTheme.primaryDark),
                ),
                title: Text(
                  '$currency ${amount.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  fine['reason']?.toString().trim().isNotEmpty == true
                      ? fine['reason'].toString()
                      : 'Issue ${fine['issue_id']?.toString().substring(0, 8) ?? ''}',
                ),
                trailing: status == 'paid'
                    ? const StitchChip(
                        label: 'Paid',
                        variant: StitchChipVariant.success,
                      )
                    : canManage
                        ? FilledButton.tonal(
                            onPressed: () async {
                              final id = fine['id']?.toString() ?? '';
                              if (id.isEmpty) return;
                              try {
                                await ref.read(libraryRepositoryProvider).markFinePaid(id);
                                ref.invalidate(libraryFinesProvider(schoolId));
                              } catch (error) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Could not mark fine paid: $error')),
                                  );
                                }
                              }
                            },
                            child: const Text('Mark Paid'),
                          )
                        : const StitchChip(
                            label: 'Unpaid',
                            variant: StitchChipVariant.warn,
                          ),
              ),
            );
          },
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: AppTheme.stitchMuted),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.stitchMuted),
            ),
          ],
        ),
      ),
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
            const Icon(Icons.error_outline_rounded, size: 44),
            const SizedBox(height: 10),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
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

List<Map<String, dynamic>> _mapList(dynamic value) {
  if (value is! List) return <Map<String, dynamic>>[];
  return value
      .whereType<Map>()
      .map((row) => Map<String, dynamic>.from(row))
      .toList(growable: false);
}
