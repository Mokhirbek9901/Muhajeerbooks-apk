import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app_state.dart';
import 'muhajeer_ai.dart';

class MuhajeerAiPage extends StatefulWidget {
  const MuhajeerAiPage({super.key});
  @override State<MuhajeerAiPage> createState()=>_MuhajeerAiPageState();
}
class _MuhajeerAiPageState extends State<MuhajeerAiPage>{
  final q=TextEditingController(); String answer=''; bool busy=false; String mode='advisor';
  final modes=const {'advisor':'Kitob maslahatchi','search':'Aqlli qidiruv','similar':'O‘xshash kitoblar','marketing':'Reklama matni','analytics':'Savdo/Ombor tahlili'};
  Future<void> run() async {
    final text=q.text.trim(); if(text.isEmpty||busy)return;
    setState(()=>busy=true);
    try{
      final books=context.read<AppState>().books;
      if(mode=='search'||mode=='similar'){
        final ids=await MuhajeerAi.search(text,books);
        final matches=ids.map((id)=>books.where((b)=>b.id==id).firstOrNull).whereType<Book>().toList();
        answer=matches.isEmpty?'Mos kitob topilmadi.':matches.map((b)=>'• ${b.title} — ₩${b.currentPrice} (${b.stock} dona)').join('\n');
      }else{
        answer=await MuhajeerAi.ask(mode:mode,query:text,books:books);
      }
    }catch(_){answer='AI vaqtincha javob bera olmadi. Qayta urinib ko‘ring.';}
    if(mounted)setState(()=>busy=false);
  }
  @override void dispose(){q.dispose();super.dispose();}
  @override Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:const Text('Muhajeer AI')),
    body:ListView(padding:const EdgeInsets.all(18),children:[
      const Text('AI yordamchi',style:TextStyle(fontSize:25,fontWeight:FontWeight.w900)),
      const SizedBox(height:6),const Text('Ombordagi real kitoblar asosida qidiradi, tavsiya va matn tayyorlaydi.'),
      const SizedBox(height:16),
      DropdownButtonFormField<String>(value:mode,items:modes.entries.map((e)=>DropdownMenuItem(value:e.key,child:Text(e.value))).toList(),onChanged:(v)=>setState(()=>mode=v??mode)),
      const SizedBox(height:12),
      TextField(controller:q,minLines:2,maxLines:5,decoration:InputDecoration(
        hintText: mode=='analytics'?'Masalan: Qaysi kitoblarni qayta olib kelish kerak?':'Masalan: Yig‘latadigan, ta’sirli roman kerak',
        border:const OutlineInputBorder())),
      const SizedBox(height:12),FilledButton.icon(onPressed:busy?null:run,icon:const Icon(Icons.auto_awesome),label:Text(busy?'AI ishlayapti…':'So‘rash')),
      if(answer.isNotEmpty)...[const SizedBox(height:20),SelectableText(answer,style:const TextStyle(fontSize:16,height:1.45))],
    ]),
  );
}
