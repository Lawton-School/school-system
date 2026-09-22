import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../services/services.dart';
import '../../widgets/shared_widgets.dart';

const _relationshipTypes = ['father', 'mother', 'guardian', 'other'];

class ParentStudentMappingScreen extends ConsumerWidget {
  const ParentStudentMappingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(activeSessionProvider);
    if (session == null) return const Scaffold(body: Center(child: Text('No active session')));

    final relationshipsAsync = ref.watch(parentRelationshipsProvider(session.schoolId));
    final parentsAsync = ref.watch(_parentsListProvider(session.schoolId));
    final studentsAsync = ref.watch(_studentsListProvider2(session.schoolId));

    return Scaffold(
      appBar: AppBar(title: const Text('Parent–Student Links')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showLinkDialog(context, ref, session.schoolId, parentsAsync, studentsAsync),
        icon: const Icon(Icons.family_restroom_rounded),
        label: const Text('Link Parent'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
      ),
      body: relationshipsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: ErrorCard(message: e.toString())),
        data: (relationships) {
          if (relationships.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.family_restroom_outlined, size: 56, color: AppTheme.textMuted),
                  const SizedBox(height: 16),
                  Text('No Parent–Student Links', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text(
                    'Link parent profiles to student profiles to enable cross-school visibility.',
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          // Group by parent name
          final byParent = <String, List<UserRelationshipModel>>{};
          for (final rel in relationships) {
            final key = rel.parent?.fullName ?? rel.parentId;
            byParent.putIfAbsent(key, () => []).add(rel);
          }

          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: byParent.length,
            separatorBuilder: (_, _) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final parentName = byParent.keys.elementAt(index);
              final children = byParent[parentName]!;
              final parent = children.first.parent;

              return Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ListTile(
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFF3B82F6).withAlpha(30),
                        child: Text(
                          parentName.isNotEmpty ? parentName[0].toUpperCase() : 'P',
                          style: const TextStyle(color: Color(0xFF3B82F6), fontWeight: FontWeight.bold),
                        ),
                      ),
                      title: Text(parentName, style: Theme.of(context).textTheme.titleMedium),
                      subtitle: Text(parent?.email ?? parent?.phone ?? 'Parent', style: Theme.of(context).textTheme.bodySmall),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: const Color(0xFF3B82F6).withAlpha(20), borderRadius: BorderRadius.circular(12)),
                        child: Text('${children.length} child(ren)', style: const TextStyle(color: Color(0xFF3B82F6), fontSize: 11, fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const Divider(height: 1),
                    ...children.map((rel) {
                      final student = rel.student;
                      return ListTile(
                        contentPadding: const EdgeInsets.fromLTRB(56, 4, 16, 4),
                        leading: const Icon(Icons.school_rounded, size: 18, color: Color(0xFF6366F1)),
                        title: Text(student?.fullName ?? 'Student', style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w500)),
                        subtitle: Text('Relationship: ${rel.relationshipType}', style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                      );
                    }),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showLinkDialog(
    BuildContext context,
    WidgetRef ref,
    String schoolId,
    AsyncValue<List<ProfileModel>> parentsAsync,
    AsyncValue<List<ProfileModel>> studentsAsync,
  ) {
    final parents = parentsAsync.value ?? [];
    final students = studentsAsync.value ?? [];

    if (parents.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add at least one Parent profile first!')));
      return;
    }
    if (students.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add at least one Student profile first!')));
      return;
    }

    String selectedParentId = parents.first.id;
    String selectedStudentId = students.first.id;
    String selectedRelType = 'guardian';

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
              Text('Link Parent to Student', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text('This allows parents to view their child\'s grades and schedule.', style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: selectedParentId,
                dropdownColor: AppTheme.surfaceDark,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: const InputDecoration(labelText: 'Parent'),
                items: parents.map((p) => DropdownMenuItem(value: p.id, child: Text(p.fullName))).toList(),
                onChanged: (val) => setState(() => selectedParentId = val!),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: selectedStudentId,
                dropdownColor: AppTheme.surfaceDark,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: const InputDecoration(labelText: 'Student (Child)'),
                items: students.map((s) => DropdownMenuItem(value: s.id, child: Text(s.fullName))).toList(),
                onChanged: (val) => setState(() => selectedStudentId = val!),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: selectedRelType,
                dropdownColor: AppTheme.surfaceDark,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: const InputDecoration(labelText: 'Relationship Type'),
                items: _relationshipTypes.map((r) => DropdownMenuItem(value: r, child: Text(r[0].toUpperCase() + r.substring(1)))).toList(),
                onChanged: (val) => setState(() => selectedRelType = val!),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () async {
                  try {
                    final client = ref.read(supabaseClientProvider);
                    await AcademicStructureService(client).createRelationship(
                      schoolId: schoolId,
                      parentProfileId: selectedParentId,
                      studentProfileId: selectedStudentId,
                      relationshipType: selectedRelType,
                    );
                    ref.invalidate(parentRelationshipsProvider(schoolId));
                    if (context.mounted) Navigator.pop(context);
                  } catch (e) {
                    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                },
                child: const Text('Save Link'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

final _parentsListProvider = FutureProvider.family<List<ProfileModel>, String>((ref, schoolId) async {
  final client = ref.watch(supabaseClientProvider);
  return SchoolService(client).getSchoolProfiles(schoolId, role: AppRoles.parent);
});

final _studentsListProvider2 = FutureProvider.family<List<ProfileModel>, String>((ref, schoolId) async {
  final client = ref.watch(supabaseClientProvider);
  return SchoolService(client).getSchoolProfiles(schoolId, role: AppRoles.student);
});
