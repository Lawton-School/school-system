import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../services/services.dart';
import '../../widgets/shared_widgets.dart';

class TeacherAssignmentScreen extends ConsumerWidget {
  const TeacherAssignmentScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(activeSessionProvider);
    if (session == null) return const Scaffold(body: Center(child: Text('No active session')));

    final classTeachersAsync = ref.watch(classTeachersProvider(session.schoolId));
    final profilesAsync = ref.watch(_teachersListProvider(session.schoolId));
    final sectionsAsync = ref.watch(classSectionsProvider(session.schoolId));
    final subjectsAsync = ref.watch(subjectsProvider(session.schoolId));

    return Scaffold(
      appBar: AppBar(title: const Text('Teacher Assignments')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAssignTeacherDialog(context, ref, session.schoolId, profilesAsync, sectionsAsync, subjectsAsync),
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Assign Teacher'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
      ),
      body: classTeachersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: ErrorCard(message: e.toString())),
        data: (assignments) {
          if (assignments.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.assignment_ind_outlined, size: 56, color: AppTheme.textMuted),
                  const SizedBox(height: 16),
                  Text('No Teacher Assignments', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text(
                    'Assign teachers to class sections as Subject Teachers or Homeroom Teachers.',
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: assignments.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final item = assignments[index];
              return Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: CircleAvatar(
                    backgroundColor: item.isPrimaryHomeroomTeacher ? AppTheme.secondary.withAlpha(30) : AppTheme.primary.withAlpha(30),
                    child: Icon(
                      item.isPrimaryHomeroomTeacher ? Icons.home_work_rounded : Icons.school_rounded,
                      color: item.isPrimaryHomeroomTeacher ? AppTheme.secondary : AppTheme.primary,
                      size: 20,
                    ),
                  ),
                  title: Text(item.teacher?.fullName ?? 'Teacher', style: Theme.of(context).textTheme.titleMedium),
                  subtitle: Text(
                    'Section: ${item.section?.displayName ?? 'Section'} • Subject: ${item.subject?.name ?? 'Homeroom'}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  trailing: item.isPrimaryHomeroomTeacher
                      ? Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.secondary.withAlpha(25),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.secondary.withAlpha(80)),
                          ),
                          child: const Text('Homeroom', style: TextStyle(color: AppTheme.secondary, fontSize: 10, fontWeight: FontWeight.bold)),
                        )
                      : Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withAlpha(25),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text('Subject Teacher', style: TextStyle(color: AppTheme.primary, fontSize: 10, fontWeight: FontWeight.w600)),
                        ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showAssignTeacherDialog(
    BuildContext context,
    WidgetRef ref,
    String schoolId,
    AsyncValue<List<ProfileModel>> profilesAsync,
    AsyncValue<List<ClassSectionModel>> sectionsAsync,
    AsyncValue<List<SubjectModel>> subjectsAsync,
  ) {
    final teachers = profilesAsync.value ?? [];
    final sections = sectionsAsync.value ?? [];
    final subjects = subjectsAsync.value ?? [];

    if (teachers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add at least one Teacher user first!')));
      return;
    }
    if (sections.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Create at least one Class Section first!')));
      return;
    }

    String selectedTeacherId = teachers.first.id;
    String selectedSectionId = sections.first.id;
    String? selectedSubjectId = subjects.isNotEmpty ? subjects.first.id : null;
    bool isHomeroom = false;

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
              Text('Assign Teacher', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: selectedTeacherId,
                dropdownColor: AppTheme.surfaceDark,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: const InputDecoration(labelText: 'Teacher'),
                items: teachers.map((t) => DropdownMenuItem(value: t.id, child: Text(t.fullName))).toList(),
                onChanged: (val) => setState(() => selectedTeacherId = val!),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: selectedSectionId,
                dropdownColor: AppTheme.surfaceDark,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: const InputDecoration(labelText: 'Class Section'),
                items: sections.map((s) => DropdownMenuItem(value: s.id, child: Text(s.displayName))).toList(),
                onChanged: (val) => setState(() => selectedSectionId = val!),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String?>(
                initialValue: selectedSubjectId,
                dropdownColor: AppTheme.surfaceDark,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: const InputDecoration(labelText: 'Subject (optional for Homeroom)'),
                items: [
                  const DropdownMenuItem<String?>(value: null, child: Text('None (Homeroom Teacher)')),
                  ...subjects.map((s) => DropdownMenuItem<String?>(value: s.id, child: Text(s.name))),
                ],
                onChanged: (val) => setState(() => selectedSubjectId = val),
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Primary Homeroom Teacher', style: TextStyle(color: AppTheme.textPrimary)),
                subtitle: const Text('Main teacher responsible for this section', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                value: isHomeroom,
                activeThumbColor: AppTheme.secondary,
                onChanged: (val) => setState(() => isHomeroom = val),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () async {
                  try {
                    final client = ref.read(supabaseClientProvider);
                    await AcademicStructureService(client).assignTeacher(
                      schoolId: schoolId,
                      classSectionId: selectedSectionId,
                      teacherProfileId: selectedTeacherId,
                      subjectId: selectedSubjectId,
                      isPrimaryHomeroomTeacher: isHomeroom,
                    );
                    ref.invalidate(classTeachersProvider(schoolId));
                    if (context.mounted) Navigator.pop(context);
                  } catch (e) {
                    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                },
                child: const Text('Save Assignment'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

final _teachersListProvider = FutureProvider.family<List<ProfileModel>, String>((ref, schoolId) async {
  final client = ref.watch(supabaseClientProvider);
  return SchoolService(client).getSchoolProfiles(schoolId, role: AppRoles.teacher);
});
