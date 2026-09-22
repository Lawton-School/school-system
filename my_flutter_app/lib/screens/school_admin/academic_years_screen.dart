import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../providers/providers.dart';
import '../../services/services.dart';
import '../../widgets/shared_widgets.dart';

class AcademicYearsScreen extends ConsumerWidget {
  const AcademicYearsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(activeSessionProvider);
    if (session == null) return const Scaffold(body: Center(child: Text('No active session')));

    final yearsAsync = ref.watch(academicYearsProvider(session.schoolId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Academic Years'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddYearDialog(context, ref, session.schoolId),
        icon: const Icon(Icons.add),
        label: const Text('Add Year'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
      ),
      body: yearsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: ErrorCard(message: e.toString())),
        data: (years) {
          if (years.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.calendar_month_outlined, size: 56, color: AppTheme.textMuted),
                  const SizedBox(height: 16),
                  Text('No Academic Years Configured', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text(
                    'Create an academic year (e.g. 2026–2027) to get started.',
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: years.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final year = years[index];
              final dateFormat = DateFormat('MMM d, yyyy');
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: year.isCurrent ? AppTheme.secondary.withAlpha(30) : AppTheme.primary.withAlpha(20),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          Icons.calendar_today_rounded,
                          color: year.isCurrent ? AppTheme.secondary : AppTheme.primary,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(year.name, style: Theme.of(context).textTheme.titleMedium),
                                const SizedBox(width: 8),
                                if (year.isCurrent)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppTheme.secondary.withAlpha(30),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: AppTheme.secondary.withAlpha(80)),
                                    ),
                                    child: const Text(
                                      'CURRENT',
                                      style: TextStyle(color: AppTheme.secondary, fontSize: 10, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${dateFormat.format(year.startDate)} – ${dateFormat.format(year.endDate)}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      if (!year.isCurrent)
                        TextButton(
                          onPressed: () async {
                            final client = ref.read(supabaseClientProvider);
                            await AcademicStructureService(client).setCurrentAcademicYear(session.schoolId, year.id);
                            ref.invalidate(academicYearsProvider(session.schoolId));
                          },
                          child: const Text('Set Current'),
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showAddYearDialog(BuildContext context, WidgetRef ref, String schoolId) {
    final nameCtrl = TextEditingController(text: '${DateTime.now().year}–${DateTime.now().year + 1}');
    DateTime startDate = DateTime.now();
    DateTime endDate = DateTime.now().add(const Duration(days: 365));
    bool isCurrent = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.cardDark,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => Padding(
          padding: EdgeInsets.only(
            left: 24, right: 24, top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Create Academic Year', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              TextFormField(
                controller: nameCtrl,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: const InputDecoration(labelText: 'Academic Year Name', hintText: 'e.g. 2026–2027'),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: startDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2040),
                        );
                        if (picked != null) setState(() => startDate = picked);
                      },
                      icon: const Icon(Icons.date_range, size: 18),
                      label: Text('Start: ${DateFormat('yyyy-MM-dd').format(startDate)}'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: endDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2040),
                        );
                        if (picked != null) setState(() => endDate = picked);
                      },
                      icon: const Icon(Icons.date_range, size: 18),
                      label: Text('End: ${DateFormat('yyyy-MM-dd').format(endDate)}'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Set as Current Academic Year', style: TextStyle(color: AppTheme.textPrimary)),
                value: isCurrent,
                activeThumbColor: AppTheme.primary,
                onChanged: (val) => setState(() => isCurrent = val),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () async {
                  try {
                    final client = ref.read(supabaseClientProvider);
                    await AcademicStructureService(client).createAcademicYear(
                      schoolId: schoolId,
                      name: nameCtrl.text.trim(),
                      startDate: startDate,
                      endDate: endDate,
                      isCurrent: isCurrent,
                    );
                    ref.invalidate(academicYearsProvider(schoolId));
                    if (context.mounted) Navigator.pop(context);
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                    }
                  }
                },
                child: const Text('Create Academic Year'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
