import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../providers/providers.dart';

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
  @override Widget build(BuildContext context){
    final data=ref.watch(teacherParentContactsProvider);
    return Scaffold(backgroundColor:AppTheme.stitchBg,appBar:AppBar(title:const Text('Parent Engagement'),actions:[IconButton(onPressed:()=>ref.invalidate(teacherParentContactsProvider),icon:const Icon(Icons.refresh_rounded))]),body:data.when(
      loading:()=>const Center(child:CircularProgressIndicator()),error:(e,_)=>Center(child:Text('Unable to load guardian relationships: $e')),data:(items){
      if(items.isEmpty)return const Center(child:Padding(padding:EdgeInsets.all(32),child:Text('No guardian contacts are available. Contacts appear automatically when you are assigned to an enrolled student’s class.')));
      final list=ListView.separated(padding:const EdgeInsets.all(16),itemCount:items.length,separatorBuilder:(_,__)=>const SizedBox(height:8),itemBuilder:(context,i){final x=items[i];return Card(child:ListTile(onTap:()=>setState(()=>selected=x),leading:const CircleAvatar(child:Icon(Icons.family_restroom_rounded)),title:Text(x['parent_name']?.toString()??'Guardian'),subtitle:Text((x['student_name']?.toString()??'Student')+' · '+(x['subject_name']?.toString()??(x['is_homeroom']==true?'Homeroom':'Class'))),trailing:const Icon(Icons.chevron_right_rounded)));});
      final compose=selected==null?const Center(child:Text('Select a guardian to start a student-context conversation.')):Padding(padding:const EdgeInsets.all(20),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[Text(selected!['parent_name']?.toString()??'Guardian',style:Theme.of(context).textTheme.titleLarge),const SizedBox(height:4),Text('Regarding '+(selected!['student_name']?.toString()??'student')+' · '+(selected!['subject_name']?.toString()??(selected!['is_homeroom']==true?'Homeroom':'Class')),style:const TextStyle(color:AppTheme.stitchMuted)),const SizedBox(height:16),TextField(controller:message,minLines:3,maxLines:6,decoration:const InputDecoration(labelText:'Message to guardian',hintText:'Write an update, question, concern, or positive feedback...')),const SizedBox(height:12),ElevatedButton.icon(onPressed:sending?null:send,icon:const Icon(Icons.send_rounded),label:Text(sending?'Sending...':'Send to Guardian')),const SizedBox(height:10),const Text('Delivery is authorized against the active teacher → student → guardian relationship.',style:TextStyle(fontSize:12,color:AppTheme.stitchMuted))]));
      return LayoutBuilder(builder:(context,b)=>b.maxWidth>=800?Row(children:[SizedBox(width:380,child:list),const VerticalDivider(width:1),Expanded(child:compose)]):Column(children:[Expanded(child:list),if(selected!=null)SizedBox(height:280,child:compose)]));
    }));
  }
}
