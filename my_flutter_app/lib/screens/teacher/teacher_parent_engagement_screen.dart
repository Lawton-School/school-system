import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../providers/providers.dart';
import '../../controllers/parent_controllers.dart';

final teacherParentContactsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async => ref.watch(messagingRepositoryProvider).fetchTeacherParentContacts());

class TeacherParentEngagementScreen extends ConsumerStatefulWidget {
  const TeacherParentEngagementScreen({super.key});
  @override ConsumerState<TeacherParentEngagementScreen> createState()=>_State();
}
class _State extends ConsumerState<TeacherParentEngagementScreen> {
  final message=TextEditingController(); Map<String,dynamic>? selected; bool sending=false;
  @override void dispose(){message.dispose();super.dispose();}
  Future<void> send() async {
    final c=selected,t=message.text.trim(); if(c==null||t.isEmpty||sending)return; setState(()=>sending=true);
    final sent=await ref.read(messagingRepositoryProvider).sendTeacherParentMessage(recipientProfileId:c['parent_id'].toString(),studentProfileId:c['student_id'].toString(),subjectId:c['subject_id']?.toString(),messageText:t);
    if(!mounted)return; setState(()=>sending=false); if(sent!=null)message.clear();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(sent!=null?'Message sent securely to guardian.':'Message could not be sent.')));
  }
  Future<void> manageMeeting(Map<String,dynamic> m,String action) async {
    DateTime? when; final notes=TextEditingController();
    if(action=='reschedule_requested'){
      final d=await showDatePicker(context:context,firstDate:DateTime.now(),lastDate:DateTime.now().add(const Duration(days:365)),initialDate:DateTime.now().add(const Duration(days:1)));if(d==null)return;
      final t=await showTimePicker(context:context,initialTime:TimeOfDay.now());if(t==null)return;when=DateTime(d.year,d.month,d.day,t.hour,t.minute);
    }
    if(action=='completed'){
      final ok=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(title:const Text('Complete Meeting'),content:TextField(controller:notes,minLines:3,maxLines:6,decoration:const InputDecoration(labelText:'Follow-up notes')),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Cancel')),ElevatedButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Complete'))]));if(ok!=true)return;
    }
    final ok=await ref.read(messagingRepositoryProvider).respondParentTeacherMeeting(meetingId:m['id'].toString(),status:action,scheduledAt:when,notes:notes.text);
    if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(ok?'Meeting updated.':'Meeting update failed.')));
    if(ok)setState((){});
  }

  Future<void> requestMeeting() async {
    final c=selected;if(c==null)return;
    final reason=TextEditingController();
    DateTime when=DateTime.now().add(const Duration(days:1));
    final ok=await showDialog<bool>(context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,setD)=>AlertDialog(title:const Text('Request Parent Meeting'),content:SizedBox(width:440,child:Column(mainAxisSize:MainAxisSize.min,children:[ListTile(contentPadding:EdgeInsets.zero,leading:const Icon(Icons.schedule),title:Text('${when.toLocal()}'),subtitle:const Text('Proposed date & time'),onTap:()async{final d=await showDatePicker(context:ctx,firstDate:DateTime.now(),lastDate:DateTime.now().add(const Duration(days:365)),initialDate:when);if(d==null)return;final t=await showTimePicker(context:ctx,initialTime:TimeOfDay.fromDateTime(when));if(t!=null)setD(()=>when=DateTime(d.year,d.month,d.day,t.hour,t.minute));}),TextField(controller:reason,minLines:3,maxLines:5,decoration:const InputDecoration(labelText:'Reason'))])),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Cancel')),ElevatedButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Send Request'))])));
    if(ok!=true||reason.text.trim().isEmpty)return;
    final id=await ref.read(messagingRepositoryProvider).requestParentTeacherMeeting(counterpartProfileId:c['parent_id'].toString(),studentProfileId:c['student_id'].toString(),subjectId:c['subject_id']?.toString(),scheduledAt:when,reason:reason.text);
    if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(id!=null?'Meeting request sent.':'Meeting request failed.')));
  }

  Future<void> feedback(String kind) async {
    final c=selected; if(c==null)return;
    final title=TextEditingController(),details=TextEditingController();
    final ok=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(title:Text(kind=='positive_feedback'?'Positive Feedback':kind=='attendance_concern'?'Attendance Concern':'Academic Concern'),content:SizedBox(width:440,child:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:title,decoration:const InputDecoration(labelText:'Title')),const SizedBox(height:12),TextField(controller:details,minLines:4,maxLines:7,decoration:const InputDecoration(labelText:'Details'))])),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Cancel')),ElevatedButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Send'))]));
    if(ok!=true||title.text.trim().isEmpty||details.text.trim().isEmpty)return;
    final id=await ref.read(messagingRepositoryProvider).createStudentConcern(parentProfileId:c['parent_id'].toString(),studentProfileId:c['student_id'].toString(),subjectId:c['subject_id']?.toString(),kind:kind,title:title.text,details:details.text);
    if(!mounted)return; ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(id!=null?'Update sent and guardian notified.':'Update could not be sent.')));
  }

  @override Widget build(BuildContext context){
    final meetingsFuture=ref.read(messagingRepositoryProvider).fetchParentTeacherMeetings();
    final data=ref.watch(teacherParentContactsProvider);
    return Scaffold(backgroundColor:AppTheme.stitchBg,appBar:AppBar(title:const Text('Parent Engagement'),actions:[IconButton(onPressed:()=>ref.invalidate(teacherParentContactsProvider),icon:const Icon(Icons.refresh_rounded))]),body:data.when(
      loading:()=>const Center(child:CircularProgressIndicator()),error:(e,_)=>Center(child:Text('Unable to load guardian relationships: $e')),data:(items){
      if(items.isEmpty)return const Center(child:Padding(padding:EdgeInsets.all(32),child:Text('No guardian contacts are available. Contacts appear automatically when you are assigned to an enrolled student’s class.')));
      final list=ListView.separated(padding:const EdgeInsets.all(16),itemCount:items.length,separatorBuilder:(_,__)=>const SizedBox(height:8),itemBuilder:(context,i){final x=items[i];return Card(child:ListTile(onTap:()=>setState(()=>selected=x),leading:const CircleAvatar(child:Icon(Icons.family_restroom_rounded)),title:Text(x['parent_name']?.toString()??'Guardian'),subtitle:Text((x['student_name']?.toString()??'Student')+' · '+(x['subject_name']?.toString()??(x['is_homeroom']==true?'Homeroom':'Class'))),trailing:const Icon(Icons.chevron_right_rounded)));});
      final compose=selected==null?const Center(child:Text('Select a guardian to start a student-context conversation.')):Padding(padding:const EdgeInsets.all(20),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[Text(selected!['parent_name']?.toString()??'Guardian',style:Theme.of(context).textTheme.titleLarge),const SizedBox(height:4),Text('Regarding '+(selected!['student_name']?.toString()??'student')+' · '+(selected!['subject_name']?.toString()??(selected!['is_homeroom']==true?'Homeroom':'Class')),style:const TextStyle(color:AppTheme.stitchMuted)),const SizedBox(height:16),TextField(controller:message,minLines:3,maxLines:6,decoration:const InputDecoration(labelText:'Message to guardian',hintText:'Write an update, question, concern, or positive feedback...')),const SizedBox(height:12),ElevatedButton.icon(onPressed:sending?null:send,icon:const Icon(Icons.send_rounded),label:Text(sending?'Sending...':'Send to Guardian')),const SizedBox(height:10),FutureBuilder<List<Map<String,dynamic>>>(future:meetingsFuture,builder:(context,s){final ms=s.data??const[];if(ms.isEmpty)return const SizedBox.shrink();return Card(child:Padding(padding:const EdgeInsets.all(12),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('Upcoming Meetings',style:TextStyle(fontWeight:FontWeight.w800)),...ms.where((m)=>m['status']!='cancelled'&&m['status']!='completed').take(3).map((m)=>ListTile(contentPadding:EdgeInsets.zero,leading:const Icon(Icons.event),title:Text(m['scheduled_at']?.toString()??''),subtitle:Text((m['status']??'').toString().replaceAll('_',' ')),trailing:PopupMenuButton<String>(onSelected:(v)=>manageMeeting(m,v),itemBuilder:(_)=>const [PopupMenuItem(value:'confirmed',child:Text('Confirm')),PopupMenuItem(value:'reschedule_requested',child:Text('Reschedule')),PopupMenuItem(value:'completed',child:Text('Complete')),PopupMenuItem(value:'cancelled',child:Text('Cancel'))])))])));}),const SizedBox(height:10),Wrap(spacing:8,runSpacing:8,children:[OutlinedButton.icon(onPressed:()=>feedback('academic_concern'),icon:const Icon(Icons.school_rounded),label:const Text('Academic Concern')),OutlinedButton.icon(onPressed:()=>feedback('attendance_concern'),icon:const Icon(Icons.event_busy_rounded),label:const Text('Attendance Concern')),OutlinedButton.icon(onPressed:()=>feedback('positive_feedback'),icon:const Icon(Icons.thumb_up_alt_rounded),label:const Text('Positive Feedback')),OutlinedButton.icon(onPressed:requestMeeting,icon:const Icon(Icons.calendar_month_rounded),label:const Text('Request Meeting'))]),const SizedBox(height:10),const Text('Delivery is authorized against the active teacher → student → guardian relationship.',style:TextStyle(fontSize:12,color:AppTheme.stitchMuted))]));
      return LayoutBuilder(builder:(context,b)=>b.maxWidth>=800?Row(children:[SizedBox(width:380,child:list),const VerticalDivider(width:1),Expanded(child:compose)]):Column(children:[Expanded(child:list),if(selected!=null)SizedBox(height:280,child:compose)]));
    }));
  }
}
