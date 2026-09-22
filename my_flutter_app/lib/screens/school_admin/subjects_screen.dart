import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../providers/providers.dart';
import '../../services/services.dart';
import '../../widgets/shared_widgets.dart';

class SubjectsScreen extends ConsumerWidget {
  const SubjectsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(activeSessionProvider);
    if (session == null) return const Scaffold(body: Center(child: Text('No active session')));

    final subjectsAsync = ref.watch(subjectsProvider(session.schoolId));

    return Scaffold(
      appBar: AppBar(title: const Text('Subjects Catalog')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddSubjectDialog(context, ref, session.schoolId),
        icon: const Icon(Icons.add),
        label: const Text('Add Subject'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
      ),
      body: subjectsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: ErrorCard(message: e.toString())),
        data: (subjects) {
          if (subjects.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.book_outlined, size: 56, color: AppTheme.textMuted),
                  const SizedBox(height: 16),
                  Text('No Subjects Configured', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text(
                    'Create subjects (e.g. Mathematics, Physics, English).',
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: subjects.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final sub = subjects[index];
              return Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withAlpha(25),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.book_rounded, color: AppTheme.accent, size: 22),
                  ),
                  title: Text(sub.name, style: Theme.of(context).textTheme.titleMedium),
                  subtitle: sub.code != null ? Text('Code: ${sub.code}', style: Theme.of(context).textTheme.bodySmall) : null,
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withAlpha(20),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text('Active', style: TextStyle(color: AppTheme.accent, fontSize: 11, fontWeight: FontWeight.w600)),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showAddSubjectDialog(BuildContext context, WidgetRef ref, String schoolId) {
    final nameCtrl = TextEditingController();
    final codeCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.cardDark,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 24, right: 24, top: 24,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Add New Subject', style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextFormField(
              controller: nameCtrl,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: const InputDecoration(labelText: 'Subject Name', hintText: 'e.g. Mathematics'),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: codeCtrl,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: const InputDecoration(labelText: 'Subject Code (optional)', hintText: 'e.g. MATH101'),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () async {
                try {
                  final client = ref.read(supabaseClientProvider);
                  await AcademicStructureService(client).createSubject(
                    schoolId: schoolId,
                    name: nameCtrl.text.trim(),
                    code: codeCtrl.text.trim().isNotEmpty ? codeCtrl.text.trim().toUpperCase() : null,
                  );
                  ref.invalidate(subjectsProvider(schoolId));
                  if (ctx.mounted) Navigator.pop(ctx);
                } catch (e) {
                  if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              },
              child: const Text('Create Subject'),
            ),
          ],
        ),
      ),
    );
  }
}
