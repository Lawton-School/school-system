import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../controllers/admissions_controllers.dart';
import '../../core/theme.dart';
import '../../providers/providers.dart';
import '../../router/router.dart';
import '../../services/services.dart';
import '../../widgets/stitch_widgets.dart';

class ReceptionDashboardScreen extends ConsumerStatefulWidget {
  const ReceptionDashboardScreen({super.key});
  @override
  ConsumerState<ReceptionDashboardScreen> createState() => _ReceptionDashboardScreenState();
}

class _ReceptionDashboardScreenState extends ConsumerState<ReceptionDashboardScreen> {
  final _search = TextEditingController();
  Map<String, dynamic>? _directory;
  bool _searching = false;

  @override
  void dispose() { _search.dispose(); super.dispose(); }

  Future<void> _lookup() async {
    setState(() => _searching = true);
    try {
      final result = await ref.read(admissionsRepositoryProvider).frontDeskLookup(_search.text);
      if (mounted) setState(() => _directory = result);
    } finally { if (mounted) setState(() => _searching = false); }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(activeSessionProvider);
    final pipeline = ref.watch(admissionsPipelineProvider);
    final frontDesk = ref.watch(frontDeskWorkspaceProvider);
    return Scaffold(
      backgroundColor: AppTheme.stitchBg,
      appBar: AppBar(title: const Text('Reception'), actions: [
        IconButton(tooltip: 'Refresh', onPressed: () => ref.invalidate(admissionsPipelineProvider), icon: const Icon(Icons.refresh_rounded)),
        IconButton(tooltip: 'Sign Out', onPressed: () async {
          await ref.read(activeSessionProvider.notifier).clearSession();
          await AuthService(ref.read(supabaseClientProvider)).signOut();
        }, icon: const Icon(Icons.logout_rounded)),
      ]),
      body: RefreshIndicator(
        onRefresh: () async { ref.invalidate(admissionsPipelineProvider); await ref.read(admissionsPipelineProvider.future); },
        child: ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.all(20), children: [
          Text(session?.schoolName ?? 'School Reception', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800, color: AppTheme.stitchHeading)),
          const SizedBox(height: 4),
          const Text('Front Desk Workspace', style: TextStyle(color: AppTheme.stitchMuted)),
          const SizedBox(height: 20),
          pipeline.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => StitchCard(child: Text('Unable to load front desk summary: $e')),
            data: (data) {
              final apps = _mapList(data['applications']);
              final applied = _count(apps, {'applied'});
              final attention = _count(apps, {'review', 'info_requested', 'waitlisted'});
              final accepted = _count(apps, {'accepted'});
              return LayoutBuilder(builder: (context, constraints) {
                final cols = constraints.maxWidth >= 900 ? 4 : 2;
                return GridView.count(crossAxisCount: cols, crossAxisSpacing: 12, mainAxisSpacing: 12, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), childAspectRatio: constraints.maxWidth >= 900 ? 1.7 : 1.25, children: [
                  StitchKpiCard(label: 'New Applications', value: '$applied', hint: 'Awaiting first review', icon: Icons.person_add_alt_1_rounded),
                  StitchKpiCard(label: 'Needs Attention', value: '$attention', hint: 'Review or information follow-up', icon: Icons.pending_actions_rounded),
                  StitchKpiCard(label: 'Accepted', value: '$accepted', hint: 'Registrar/Admin completes enrollment', icon: Icons.verified_rounded),
                  StitchKpiCard(label: 'Applications', value: '${apps.length}', hint: 'Current admissions pipeline', icon: Icons.folder_shared_rounded),
                ]);
              });
            },
          ),
          const SizedBox(height: 24),
          Text('Enquiries, Appointments & Visitors', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          frontDesk.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => StitchCard(child: Text('Unable to load front desk operations: $e')),
            data: (d) => Column(children: [
              Row(children: [
                Expanded(child: StitchKpiCard(label: 'Open Enquiries', value: '${d['open_enquiries'] ?? 0}', hint: 'Needs follow-up', icon: Icons.support_agent_rounded)),
                const SizedBox(width: 10),
                Expanded(child: StitchKpiCard(label: 'Visitors On Site', value: '${d['visitors_on_site'] ?? 0}', hint: 'Currently checked in', icon: Icons.badge_outlined)),
              ]),
              const SizedBox(height: 10),
              StitchCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text("Today's Appointments · ${d['today_appointments'] ?? 0}", style: const TextStyle(fontWeight: FontWeight.w800)),
                ..._mapList(d['appointments']).take(4).map((a) => ListTile(
                  contentPadding: EdgeInsets.zero, leading: const Icon(Icons.event_rounded),
                  title: Text(a['visitor_name']?.toString() ?? 'Visitor'),
                  subtitle: Text(a['purpose']?.toString() ?? ''),
                  trailing: Text(a['status']?.toString() ?? 'scheduled'),
                )),
              ])),
              const SizedBox(height: 10),
              StitchCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Recent Enquiries', style: TextStyle(fontWeight: FontWeight.w800)),
                ..._mapList(d['enquiries']).take(4).map((e) => ListTile(
                  contentPadding: EdgeInsets.zero, leading: const Icon(Icons.contact_support_outlined),
                  title: Text(e['subject']?.toString() ?? 'Enquiry'),
                  subtitle: Text(e['contact_name']?.toString() ?? ''),
                  trailing: PopupMenuButton<String>(
                    initialValue: e['status']?.toString(),
                    onSelected: (s) async { await ref.read(admissionsRepositoryProvider).setEnquiryStatus(e['id'].toString(), s); ref.invalidate(frontDeskWorkspaceProvider); },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value:'open',child:Text('Open')), PopupMenuItem(value:'in_progress',child:Text('In Progress')),
                      PopupMenuItem(value:'resolved',child:Text('Resolved')), PopupMenuItem(value:'closed',child:Text('Closed')),
                    ],
                    child: Text(e['status']?.toString() ?? 'open'),
                  ),
                )),
              ])),
              const SizedBox(height: 10),
              StitchCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Visitors On Site', style: TextStyle(fontWeight: FontWeight.w800)),
                ..._mapList(d['visits']).where((v) => v['status']=='checked_in').take(6).map((v) => ListTile(
                  contentPadding: EdgeInsets.zero, leading: const Icon(Icons.person_pin_circle_outlined),
                  title: Text(v['visitor_name']?.toString() ?? 'Visitor'), subtitle: Text(v['purpose']?.toString() ?? ''),
                  trailing: TextButton(onPressed: () async { await ref.read(admissionsRepositoryProvider).checkOutVisitor(v['id'].toString()); ref.invalidate(frontDeskWorkspaceProvider); }, child: const Text('Check out')),
                )),
              ])),
            ]),
          ),
          const SizedBox(height: 24),
          Text('Student & Parent Lookup', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          TextField(
            controller: _search,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _lookup(),
            decoration: InputDecoration(
              hintText: 'Name, admission number, email or phone',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: IconButton(onPressed: _searching ? null : _lookup, icon: _searching ? const SizedBox(width: 18,height:18,child:CircularProgressIndicator(strokeWidth:2)) : const Icon(Icons.arrow_forward_rounded)),
            ),
          ),
          if (_directory != null) ...[
            const SizedBox(height: 10),
            StitchCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Students (${_mapList(_directory!['students']).length})', style: const TextStyle(fontWeight: FontWeight.w800)),
              ..._mapList(_directory!['students']).take(5).map((p) => ListTile(
                dense: true, contentPadding: EdgeInsets.zero, leading: const Icon(Icons.school_outlined),
                title: Text('${p['first_name'] ?? ''} ${p['last_name'] ?? ''}'.trim()),
                subtitle: Text(p['admission_number']?.toString() ?? p['email']?.toString() ?? 'No admission number'),
              )),
              const Divider(),
              Text('Parents / Guardians (${_mapList(_directory!['parents']).length})', style: const TextStyle(fontWeight: FontWeight.w800)),
              ..._mapList(_directory!['parents']).take(5).map((p) => ListTile(
                dense: true, contentPadding: EdgeInsets.zero, leading: const Icon(Icons.family_restroom_outlined),
                title: Text('${p['first_name'] ?? ''} ${p['last_name'] ?? ''}'.trim()),
                subtitle: Text(p['phone']?.toString() ?? p['email']?.toString() ?? 'No contact information'),
              )),
            ])),
          ],
          const SizedBox(height: 24),
          Text('Front Desk Actions', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          _ActionCard(icon: Icons.how_to_reg_rounded, title: 'Admissions Desk', subtitle: 'Capture new applications, review details and request missing information.', onTap: () => context.go(AppRoutes.schoolAdminAdmissions)),
          const SizedBox(height: 10),
          _ActionCard(icon: Icons.support_agent_rounded, title: 'Record Enquiry', subtitle: 'Capture a parent, visitor or prospective-family enquiry for follow-up.', onTap: () => _showEnquiryDialog(context)),
          const SizedBox(height: 10),
          _ActionCard(icon: Icons.event_available_rounded, title: 'Book Appointment', subtitle: 'Schedule a parent, prospective-family or visitor appointment.', onTap: () => _showAppointmentDialog(context)),
          const SizedBox(height: 10),
          _ActionCard(icon: Icons.login_rounded, title: 'Visitor Check-in', subtitle: 'Register a walk-in visitor currently on school premises.', onTap: () => _showVisitorDialog(context)),
          const SizedBox(height: 10),
          const StitchCard(child: Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Row(children: [
            Icon(Icons.admin_panel_settings_outlined, color: AppTheme.stitchMuted), SizedBox(width: 12),
            Expanded(child: Text('Admission decisions and student enrollment are reserved for Registrar or School Admin.', style: TextStyle(color: AppTheme.stitchMuted))),
          ]))),
        ]),
      ),
    );
  }
  Future<void> _showAppointmentDialog(BuildContext context) async {
    final session=ref.read(activeSessionProvider); if(session==null)return;
    final name=TextEditingController(), phone=TextEditingController(), purpose=TextEditingController();
    DateTime when=DateTime.now().add(const Duration(hours:1));
    await showDialog<void>(context:context,builder:(dc)=>StatefulBuilder(builder:(context,setD)=>AlertDialog(
      title:const Text('Book Appointment'),content:SizedBox(width:520,child:Column(mainAxisSize:MainAxisSize.min,children:[
        TextField(controller:name,decoration:const InputDecoration(labelText:'Visitor name *')),const SizedBox(height:10),
        TextField(controller:phone,decoration:const InputDecoration(labelText:'Phone')),const SizedBox(height:10),
        TextField(controller:purpose,decoration:const InputDecoration(labelText:'Purpose *')),const SizedBox(height:10),
        ListTile(contentPadding:EdgeInsets.zero,title:const Text('Appointment'),subtitle:Text('${when.day}/${when.month}/${when.year} ${when.hour.toString().padLeft(2,'0')}:${when.minute.toString().padLeft(2,'0')}'),
          trailing:const Icon(Icons.edit_calendar_rounded),onTap:()async{final d=await showDatePicker(context:context,firstDate:DateTime.now(),lastDate:DateTime.now().add(const Duration(days:365)),initialDate:when);if(d==null)return;final t=await showTimePicker(context:context,initialTime:TimeOfDay.fromDateTime(when));if(t!=null)setD(()=>when=DateTime(d.year,d.month,d.day,t.hour,t.minute));}),
      ])),actions:[TextButton(onPressed:()=>Navigator.pop(dc),child:const Text('Cancel')),FilledButton(onPressed:()async{
        if(name.text.trim().isEmpty||purpose.text.trim().isEmpty)return;
        await ref.read(admissionsRepositoryProvider).createAppointment(schoolId:session.schoolId,profileId:session.profileId,visitorName:name.text,purpose:purpose.text,appointmentAt:when,phone:phone.text);
        ref.invalidate(frontDeskWorkspaceProvider);if(dc.mounted)Navigator.pop(dc);
      },child:const Text('Book'))],
    )));
    name.dispose();phone.dispose();purpose.dispose();
  }

  Future<void> _showVisitorDialog(BuildContext context) async {
    final session=ref.read(activeSessionProvider); if(session==null)return;
    final name=TextEditingController(), phone=TextEditingController(), org=TextEditingController(), purpose=TextEditingController();
    await showDialog<void>(context:context,builder:(dc)=>AlertDialog(title:const Text('Visitor Check-in'),content:SizedBox(width:520,child:Column(mainAxisSize:MainAxisSize.min,children:[
      TextField(controller:name,decoration:const InputDecoration(labelText:'Visitor name *')),const SizedBox(height:10),
      TextField(controller:phone,decoration:const InputDecoration(labelText:'Phone')),const SizedBox(height:10),
      TextField(controller:org,decoration:const InputDecoration(labelText:'Organisation')),const SizedBox(height:10),
      TextField(controller:purpose,decoration:const InputDecoration(labelText:'Purpose *')),
    ])),actions:[TextButton(onPressed:()=>Navigator.pop(dc),child:const Text('Cancel')),FilledButton(onPressed:()async{
      if(name.text.trim().isEmpty||purpose.text.trim().isEmpty)return;
      await ref.read(admissionsRepositoryProvider).checkInVisitor(schoolId:session.schoolId,profileId:session.profileId,visitorName:name.text,purpose:purpose.text,phone:phone.text,organization:org.text);
      ref.invalidate(frontDeskWorkspaceProvider);if(dc.mounted)Navigator.pop(dc);
    },child:const Text('Check in'))]));
    name.dispose();phone.dispose();org.dispose();purpose.dispose();
  }

  Future<void> _showEnquiryDialog(BuildContext context) async {
    final session = ref.read(activeSessionProvider); if (session == null) return;
    final name = TextEditingController(); final phone = TextEditingController(); final subject = TextEditingController(); final notes = TextEditingController();
    await showDialog<void>(context: context, builder: (dialogContext) => AlertDialog(
      title: const Text('Record Front Desk Enquiry'),
      content: SizedBox(width: 520, child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: name, decoration: const InputDecoration(labelText: 'Contact name *')),
        const SizedBox(height: 10), TextField(controller: phone, decoration: const InputDecoration(labelText: 'Phone')),
        const SizedBox(height: 10), TextField(controller: subject, decoration: const InputDecoration(labelText: 'Subject *')),
        const SizedBox(height: 10), TextField(controller: notes, maxLines: 3, decoration: const InputDecoration(labelText: 'Notes')),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
        FilledButton(onPressed: () async {
          if (name.text.trim().isEmpty || subject.text.trim().isEmpty) return;
          await ref.read(admissionsRepositoryProvider).createFrontDeskEnquiry(
            schoolId: session.schoolId, profileId: session.profileId, contactName: name.text, phone: phone.text, subject: subject.text, notes: notes.text,
          );
          if (dialogContext.mounted) Navigator.pop(dialogContext);
          ref.invalidate(frontDeskWorkspaceProvider);
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enquiry recorded.')));
        }, child: const Text('Save Enquiry')),
      ],
    ));
    name.dispose(); phone.dispose(); subject.dispose(); notes.dispose();
  }

  static List<Map<String, dynamic>> _mapList(dynamic value) => value is! List ? const [] : value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  static int _count(List<Map<String, dynamic>> apps, Set<String> statuses) => apps.where((a) => statuses.contains(a['status']?.toString())).length;
}

class _ActionCard extends StatelessWidget {
  final IconData icon; final String title; final String subtitle; final VoidCallback onTap;
  const _ActionCard({required this.icon, required this.title, required this.subtitle, required this.onTap});
  @override
  Widget build(BuildContext context) => StitchCard(onTap: onTap, child: Row(children: [
    Container(width: 48, height: 48, decoration: BoxDecoration(color: AppTheme.primarySoft, borderRadius: BorderRadius.circular(14)), child: Icon(icon, color: AppTheme.primaryDark)),
    const SizedBox(width: 14),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.stitchHeading)),
      const SizedBox(height: 3), Text(subtitle, style: const TextStyle(color: AppTheme.stitchMuted)),
    ])),
    const Icon(Icons.chevron_right_rounded, color: AppTheme.stitchMuted),
  ]));
}
