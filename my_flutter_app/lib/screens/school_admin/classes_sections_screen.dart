import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../services/services.dart';
import '../../widgets/shared_widgets.dart';

class ClassesSectionsScreen extends ConsumerWidget {
  const ClassesSectionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(activeSessionProvider);
    if (session == null) return const Scaffold(body: Center(child: Text('No active session')));

    final classesAsync = ref.watch(classesProvider(session.schoolId));
    final sectionsAsync = ref.watch(classSectionsProvider(session.schoolId));
    final yearsAsync = ref.watch(academicYearsProvider(session.schoolId));

    return Scaffold(
      appBar: AppBar(title: const Text('Classes & Sections')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddOptionsSheet(context, ref, session.schoolId, yearsAsync, classesAsync),
        icon: const Icon(Icons.add),
        label: const Text('Add Class / Section'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
      ),
      body: classesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: ErrorCard(message: e.toString())),
        data: (classes) {
          if (classes.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.class_outlined, size: 56, color: AppTheme.textMuted),
                  const SizedBox(height: 16),
                  Text('No Classes Configured', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text(
                    'Set up grade levels (e.g. Grade 10) and sections (e.g. Section A).',
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return sectionsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: ErrorCard(message: e.toString())),
            data: (sections) {
              return ListView.separated(
                padding: const EdgeInsets.all(20),
                itemCount: classes.length,
                separatorBuilder: (_, _) => const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  final cls = classes[index];
                  final classSections = sections.where((s) => s.classId == cls.id).toList();

                  return Card(
                    child: ExpansionTile(
                      shape: const Border(),
                      leading: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppTheme.secondary.withAlpha(25),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.class_rounded, color: AppTheme.secondary, size: 22),
                      ),
                      title: Text(cls.name, style: Theme.of(context).textTheme.titleMedium),
                      subtitle: Text(
                        'Academic Year: ${cls.academicYear?.name ?? 'Default'} • ${classSections.length} Sections',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      children: [
                        const Divider(height: 1),
                        if (classSections.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                const Text('No sections added to this class yet.', style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
                                const Spacer(),
                                TextButton.icon(
                                  onPressed: () => _showAddSectionDialog(context, ref, session.schoolId, cls),
                                  icon: const Icon(Icons.add, size: 16),
                                  label: const Text('Add Section'),
                                ),
                              ],
                            ),
                          )
                        else ...[
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: classSections.length,
                            itemBuilder: (ctx, idx) {
                              final sec = classSections[idx];
                              return ListTile(
                                leading: const Icon(Icons.meeting_room_outlined, size: 20, color: AppTheme.primary),
                                title: Text(sec.name, style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w500)),
                                subtitle: sec.room != null ? Text('Room: ${sec.room}', style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)) : null,
                                trailing: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primary.withAlpha(20),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Text('Active', style: TextStyle(color: AppTheme.primary, fontSize: 11, fontWeight: FontWeight.w600)),
                                ),
                              );
                            },
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                onPressed: () => _showAddSectionDialog(context, ref, session.schoolId, cls),
                                icon: const Icon(Icons.add, size: 16),
                                label: const Text('Add Section'),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  void _showAddOptionsSheet(
    BuildContext context,
    WidgetRef ref,
    String schoolId,
    AsyncValue<List<AcademicYearModel>> yearsAsync,
    AsyncValue<List<ClassModel>> classesAsync,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardDark,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('What would you like to create?', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 20),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: AppTheme.primary.withAlpha(30), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.class_rounded, color: AppTheme.primary),
              ),
              title: const Text('New Grade / Class Level', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
              subtitle: const Text('e.g. Grade 10, Form 1', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
              onTap: () {
                Navigator.pop(ctx);
                _showAddClassDialog(context, ref, schoolId, yearsAsync);
              },
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: AppTheme.secondary.withAlpha(30), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.meeting_room_rounded, color: AppTheme.secondary),
              ),
              title: const Text('New Class Section', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
              subtitle: const Text('e.g. Section A, Blue Stream', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
              onTap: () {
                Navigator.pop(ctx);
                final classes = classesAsync.value ?? [];
                if (classes.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Create a Grade/Class level first!')));
                  return;
                }
                _showAddSectionDialog(context, ref, schoolId, classes.first);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showAddClassDialog(
    BuildContext context,
    WidgetRef ref,
    String schoolId,
    AsyncValue<List<AcademicYearModel>> yearsAsync,
  ) {
    final nameCtrl = TextEditingController();
    final years = yearsAsync.value ?? [];
    if (years.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Create an Academic Year first!')));
      return;
    }
    String selectedYearId = years.firstWhere((y) => y.isCurrent, orElse: () => years.first).id;

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
              Text('Create Grade / Class Level', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              TextFormField(
                controller: nameCtrl,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: const InputDecoration(labelText: 'Class Name', hintText: 'e.g. Grade 10'),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: selectedYearId,
                dropdownColor: AppTheme.surfaceDark,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: const InputDecoration(labelText: 'Academic Year'),
                items: years.map((y) => DropdownMenuItem(value: y.id, child: Text(y.name))).toList(),
                onChanged: (val) => setState(() => selectedYearId = val!),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () async {
                  try {
                    final client = ref.read(supabaseClientProvider);
                    await AcademicStructureService(client).createClass(
                      schoolId: schoolId,
                      name: nameCtrl.text.trim(),
                      academicYearId: selectedYearId,
                    );
                    ref.invalidate(classesProvider(schoolId));
                    if (context.mounted) Navigator.pop(context);
                  } catch (e) {
                    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                },
                child: const Text('Create Class'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddSectionDialog(BuildContext context, WidgetRef ref, String schoolId, ClassModel cls) {
    final nameCtrl = TextEditingController(text: 'Section A');
    final roomCtrl = TextEditingController();

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
            Text('Add Section to ${cls.name}', style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextFormField(
              controller: nameCtrl,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: const InputDecoration(labelText: 'Section Name', hintText: 'e.g. Section A or Blue Stream'),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: roomCtrl,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: const InputDecoration(labelText: 'Room / Hall (optional)', hintText: 'e.g. Room 102'),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () async {
                try {
                  final client = ref.read(supabaseClientProvider);
                  await AcademicStructureService(client).createClassSection(
                    schoolId: schoolId,
                    classId: cls.id,
                    name: nameCtrl.text.trim(),
                    room: roomCtrl.text.trim().isNotEmpty ? roomCtrl.text.trim() : null,
                  );
                  ref.invalidate(classSectionsProvider(schoolId));
                  if (ctx.mounted) Navigator.pop(ctx);
                } catch (e) {
                  if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              },
              child: const Text('Create Section'),
            ),
          ],
        ),
      ),
    );
  }
}
