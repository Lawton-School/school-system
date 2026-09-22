import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../services/services.dart';
import '../../widgets/shared_widgets.dart';

class StudentEnrollmentScreen extends ConsumerWidget {
  const StudentEnrollmentScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(activeSessionProvider);
    if (session == null) return const Scaffold(body: Center(child: Text('No active session')));

    final enrollmentsAsync = ref.watch(enrollmentsProvider(session.schoolId));
    final studentsAsync = ref.watch(_studentsListProvider(session.schoolId));
    final sectionsAsync = ref.watch(classSectionsProvider(session.schoolId));
    final yearsAsync = ref.watch(academicYearsProvider(session.schoolId));

    return Scaffold(
      appBar: AppBar(title: const Text('Student Enrollments')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showEnrollDialog(context, ref, session.schoolId, studentsAsync, sectionsAsync, yearsAsync),
        icon: const Icon(Icons.how_to_reg_rounded),
        label: const Text('Enroll Student'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
      ),
      body: enrollmentsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: ErrorCard(message: e.toString())),
        data: (enrollments) {
          if (enrollments.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.how_to_reg_outlined, size: 56, color: AppTheme.textMuted),
                  const SizedBox(height: 16),
                  Text('No Students Enrolled', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text(
                    'Enroll students into class sections for the current academic year.',
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          // Group by section
          final bySection = <String, List<StudentEnrollmentModel>>{};
          for (final e in enrollments) {
            final key = e.section?.displayName ?? 'Unknown Section';
            bySection.putIfAbsent(key, () => []).add(e);
          }

          final sections = bySection.keys.toList()..sort();

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: sections.length,
            itemBuilder: (context, sectionIndex) {
              final sectionName = sections[sectionIndex];
              final sectionEnrollments = bySection[sectionName]!;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (sectionIndex > 0) const SizedBox(height: 20),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withAlpha(25),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppTheme.primary.withAlpha(60)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.class_rounded, size: 14, color: AppTheme.primary),
                            const SizedBox(width: 6),
                            Text(sectionName, style: const TextStyle(color: AppTheme.primary, fontSize: 13, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('${sectionEnrollments.length} students', style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Card(
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: sectionEnrollments.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final enrollment = sectionEnrollments[index];
                        final student = enrollment.student;
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: const Color(0xFF6366F1).withAlpha(30),
                            child: Text(
                              student?.fullName.isNotEmpty == true ? student!.fullName[0].toUpperCase() : '?',
                              style: const TextStyle(color: Color(0xFF6366F1), fontWeight: FontWeight.bold),
                            ),
                          ),
                          title: Text(student?.fullName ?? 'Unknown', style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w500)),
                          subtitle: Text(
                            enrollment.rollNumber != null ? 'Roll: ${enrollment.rollNumber}' : 'No roll number',
                            style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _statusColor(enrollment.status).withAlpha(20),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              enrollment.status,
                              style: TextStyle(color: _statusColor(enrollment.status), fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'active': return AppTheme.success;
      case 'graduated': return AppTheme.secondary;
      case 'suspended': return AppTheme.warning;
      case 'withdrawn': return AppTheme.danger;
      default: return AppTheme.textMuted;
    }
  }

  void _showEnrollDialog(
    BuildContext context,
    WidgetRef ref,
    String schoolId,
    AsyncValue<List<ProfileModel>> studentsAsync,
    AsyncValue<List<ClassSectionModel>> sectionsAsync,
    AsyncValue<List<AcademicYearModel>> yearsAsync,
  ) {
    final students = studentsAsync.value ?? [];
    final sections = sectionsAsync.value ?? [];
    final years = yearsAsync.value ?? [];

    if (students.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add at least one Student profile first!')));
      return;
    }
    if (sections.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Create at least one Class Section first!')));
      return;
    }
    if (years.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Create an Academic Year first!')));
      return;
    }

    String selectedStudentId = students.first.id;
    String selectedSectionId = sections.first.id;
    String selectedYearId = years.firstWhere((y) => y.isCurrent, orElse: () => years.first).id;
    final rollCtrl = TextEditingController();

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
              Text('Enroll Student', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: selectedStudentId,
                dropdownColor: AppTheme.surfaceDark,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: const InputDecoration(labelText: 'Student'),
                items: students.map((s) => DropdownMenuItem(value: s.id, child: Text(s.fullName))).toList(),
                onChanged: (val) => setState(() => selectedStudentId = val!),
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
              DropdownButtonFormField<String>(
                initialValue: selectedYearId,
                dropdownColor: AppTheme.surfaceDark,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: const InputDecoration(labelText: 'Academic Year'),
                items: years.map((y) => DropdownMenuItem(value: y.id, child: Text(y.isCurrent ? '${y.name} (Current)' : y.name))).toList(),
                onChanged: (val) => setState(() => selectedYearId = val!),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: rollCtrl,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: const InputDecoration(labelText: 'Roll Number (optional)', hintText: 'e.g. 001'),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () async {
                  try {
                    final client = ref.read(supabaseClientProvider);
                    await AcademicStructureService(client).enrollStudent(
                      schoolId: schoolId,
                      studentProfileId: selectedStudentId,
                      classSectionId: selectedSectionId,
                      academicYearId: selectedYearId,
                      rollNumber: rollCtrl.text.trim().isNotEmpty ? rollCtrl.text.trim() : null,
                    );
                    ref.invalidate(enrollmentsProvider(schoolId));
                    if (context.mounted) Navigator.pop(context);
                  } catch (e) {
                    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                },
                child: const Text('Enroll Student'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

final _studentsListProvider = FutureProvider.family<List<ProfileModel>, String>((ref, schoolId) async {
  final client = ref.watch(supabaseClientProvider);
  return SchoolService(client).getSchoolProfiles(schoolId, role: AppRoles.student);
});
