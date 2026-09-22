import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../services/services.dart';
import '../../widgets/ai_tutor_floating_button.dart';

class StudentLmsScreen extends ConsumerWidget {
  const StudentLmsScreen({super.key});

  void _showSubmitAssignmentDialog(BuildContext context, WidgetRef ref, AssignmentModel assignment, String schoolId, String studentProfileId) {
    final urlCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Submit: ${assignment.title}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (assignment.description != null) ...[
              Text(assignment.description!, style: const TextStyle(color: AppTheme.textMuted, fontSize: 13)),
              const SizedBox(height: 12),
            ],
            Text('Max Marks: ${assignment.maxPoints.toInt()}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.accent)),
            const SizedBox(height: 12),
            TextField(
              controller: urlCtrl,
              decoration: const InputDecoration(
                labelText: 'Document Link or Answer URL',
                hintText: 'https://docs.google.com/... or cloud link',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (urlCtrl.text.trim().isEmpty) return;
              final client = ref.read(supabaseClientProvider);
              await LmsService(client).submitAssignment(
                schoolId: schoolId,
                assignmentId: assignment.id,
                studentProfileId: studentProfileId,
                contentUrl: urlCtrl.text.trim(),
              );
              ref.invalidate(assignmentsProvider((schoolId, null)));
              if (ctx.mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Assignment submitted successfully ✓')),
                );
              }
            },
            child: const Text('Submit Work'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(activeSessionProvider);
    if (session == null) {
      return const Scaffold(body: Center(child: Text('No active session')));
    }

    final schoolId = session.schoolId;
    final coursesAsync = ref.watch(coursesProvider(schoolId));
    final assignmentsAsync = ref.watch(assignmentsProvider((schoolId, null)));

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        floatingActionButton: const AiTutorFloatingButton(),
        appBar: AppBar(
          title: const Text('Learning Portal (LMS)'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.menu_book_rounded), text: 'My Courses'),
              Tab(icon: Icon(Icons.assignment_rounded), text: 'Assignments'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Courses Tab
            coursesAsync.when(
              data: (courses) {
                if (courses.isEmpty) {
                  return const Center(child: Text('No courses available yet.', style: TextStyle(color: AppTheme.textMuted)));
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: courses.length,
                  separatorBuilder: (_, i) => const SizedBox(height: 12),
                  itemBuilder: (context, i) {
                    final c = courses[i];
                    return Card(
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: AppTheme.cardDark,
                          child: Icon(Icons.class_rounded, color: AppTheme.primary),
                        ),
                        title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(c.description ?? 'Course active', maxLines: 2),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),

            // Assignments Tab
            assignmentsAsync.when(
              data: (assignments) {
                if (assignments.isEmpty) {
                  return const Center(child: Text('No pending assignments!', style: TextStyle(color: AppTheme.textMuted)));
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: assignments.length,
                  separatorBuilder: (_, i) => const SizedBox(height: 12),
                  itemBuilder: (context, i) {
                    final ass = assignments[i];
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(child: Text(ass.title, style: Theme.of(context).textTheme.titleMedium)),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppTheme.warning.withAlpha(25),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text('Due: ${ass.dueDate.day}/${ass.dueDate.month}', style: const TextStyle(color: AppTheme.warning, fontSize: 11, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                            if (ass.description != null) ...[
                              const SizedBox(height: 8),
                              Text(ass.description!, style: Theme.of(context).textTheme.bodyMedium),
                            ],
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Max Marks: ${ass.maxPoints.toInt()}', style: const TextStyle(color: AppTheme.accent, fontWeight: FontWeight.bold, fontSize: 13)),
                                ElevatedButton.icon(
                                  onPressed: () => _showSubmitAssignmentDialog(context, ref, ass, schoolId, session.profileId),
                                  icon: const Icon(Icons.upload_file_rounded, size: 16),
                                  label: const Text('Submit'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ],
        ),
      ),
    );
  }
}
