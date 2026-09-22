import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../services/services.dart';
import 'teacher_ai_assistant_screen.dart';

class CourseBuilderScreen extends ConsumerStatefulWidget {
  const CourseBuilderScreen({super.key});

  @override
  ConsumerState<CourseBuilderScreen> createState() => _CourseBuilderScreenState();
}

class _CourseBuilderScreenState extends ConsumerState<CourseBuilderScreen> {
  void _showCreateCourseDialog(BuildContext context, String schoolId, String profileId) {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create New Course'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Course Name (e.g. O-Level Mathematics)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descCtrl,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Description / Curriculum outline'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              final client = ref.read(supabaseClientProvider);
              await LmsService(client).createCourse(
                schoolId: schoolId,
                name: nameCtrl.text.trim(),
                description: descCtrl.text.trim(),
                teacherProfileId: profileId,
              );
              ref.invalidate(coursesProvider(schoolId));
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Create Course'),
          ),
        ],
      ),
    );
  }

  void _openCourseLessons(BuildContext context, CourseModel course) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CourseLessonsDetailScreen(course: course),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(activeSessionProvider);
    if (session == null) {
      return const Scaffold(body: Center(child: Text('No active session')));
    }

    final coursesAsync = ref.watch(coursesProvider(session.schoolId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('LMS Course Builder'),
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_awesome_rounded, color: Color(0xFF4F46E5)),
            tooltip: 'Teacher AI Copilot (Lesson Planner)',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const TeacherAiAssistantScreen(initialTabIndex: 0)),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: coursesAsync.when(
        data: (courses) {
          if (courses.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.menu_book_rounded, size: 54, color: AppTheme.textMuted),
                  const SizedBox(height: 12),
                  const Text('No courses created yet.', style: TextStyle(color: AppTheme.textMuted)),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () => _showCreateCourseDialog(context, session.schoolId, session.profileId),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Create First Course'),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: courses.length,
            separatorBuilder: (_, i) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final course = courses[i];
              return Card(
                child: ListTile(
                  onTap: () => _openCourseLessons(context, course),
                  leading: const CircleAvatar(
                    backgroundColor: AppTheme.cardDark,
                    child: Icon(Icons.school_rounded, color: AppTheme.primary),
                  ),
                  title: Text(course.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(course.description ?? 'No description', maxLines: 2, overflow: TextOverflow.ellipsis),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error loading courses: $e')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateCourseDialog(context, session.schoolId, session.profileId),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Course'),
      ),
    );
  }
}

class CourseLessonsDetailScreen extends ConsumerWidget {
  final CourseModel course;
  const CourseLessonsDetailScreen({super.key, required this.course});

  void _showAddLessonDialog(BuildContext context, WidgetRef ref) {
    final titleCtrl = TextEditingController();
    final urlCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Lesson / Topic'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(labelText: 'Lesson Title (e.g. Quadratic Equations)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: urlCtrl,
              decoration: const InputDecoration(
                labelText: 'Resource URL / Document Link',
                hintText: 'https://...',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (titleCtrl.text.trim().isEmpty) return;
              final client = ref.read(supabaseClientProvider);
              await LmsService(client).createLesson(
                schoolId: course.schoolId,
                courseId: course.id,
                title: titleCtrl.text.trim(),
                contentUrl: urlCtrl.text.trim().isNotEmpty ? urlCtrl.text.trim() : null,
              );
              ref.invalidate(lessonsProvider((course.schoolId, course.id)));
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Save Lesson'),
          ),
        ],
      ),
    );
  }

  void _showCreateAssignmentDialog(BuildContext context, WidgetRef ref, LessonModel lesson) {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final maxPtsCtrl = TextEditingController(text: '100');
    DateTime dueDate = DateTime.now().add(const Duration(days: 7));

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Add Assignment: ${lesson.title}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(labelText: 'Assignment Title'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Instructions / Prompt'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: maxPtsCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Max Marks'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: dueDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) setState(() => dueDate = picked);
                  },
                  icon: const Icon(Icons.event_rounded, size: 16),
                  label: Text('Due: ${dueDate.day}/${dueDate.month}/${dueDate.year}'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (titleCtrl.text.trim().isEmpty) return;
                final maxPts = double.tryParse(maxPtsCtrl.text.trim()) ?? 100.0;
                final client = ref.read(supabaseClientProvider);
                await LmsService(client).createAssignment(
                  schoolId: course.schoolId,
                  lessonId: lesson.id,
                  title: titleCtrl.text.trim(),
                  description: descCtrl.text.trim(),
                  dueDate: dueDate,
                  maxPoints: maxPts,
                );
                ref.invalidate(assignmentsProvider((course.schoolId, lesson.id)));
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Create Assignment'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lessonsAsync = ref.watch(lessonsProvider((course.schoolId, course.id)));

    return Scaffold(
      appBar: AppBar(
        title: Text(course.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_awesome_rounded, color: Color(0xFF4F46E5)),
            tooltip: 'Teacher AI Copilot (Lesson Planner)',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const TeacherAiAssistantScreen(initialTabIndex: 0)),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: lessonsAsync.when(
        data: (lessons) {
          if (lessons.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.library_books_rounded, size: 54, color: AppTheme.textMuted),
                  const SizedBox(height: 12),
                  const Text('No lessons in this course yet.', style: TextStyle(color: AppTheme.textMuted)),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () => _showAddLessonDialog(context, ref),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Add First Lesson'),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: lessons.length,
            separatorBuilder: (_, i) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final lesson = lessons[i];
              return Card(
                child: ExpansionTile(
                  leading: CircleAvatar(
                    backgroundColor: AppTheme.primary.withAlpha(25),
                    child: Text('${i + 1}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary)),
                  ),
                  title: Text(lesson.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: lesson.contentUrl != null
                      ? Text(lesson.contentUrl!, style: const TextStyle(color: AppTheme.primaryLight, fontSize: 12))
                      : const Text('No URL attached', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Row(
                        children: [
                          OutlinedButton.icon(
                            onPressed: () => _showCreateAssignmentDialog(context, ref, lesson),
                            icon: const Icon(Icons.assignment_add, size: 16),
                            label: const Text('Create Assignment'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddLessonDialog(context, ref),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Lesson'),
      ),
    );
  }
}
