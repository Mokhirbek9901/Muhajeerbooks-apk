import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// 30 calendar days of real recognized book-sale units, in Korea local dates.
/// Zero-sale days are visible; any date outside the queried range is neutral.
class AdminSalesHeatmap extends StatelessWidget {
  const AdminSalesHeatmap({
    super.key,required this.days,required this.totalSold,
    required this.activeDays,
  });

  final List<Map<String,dynamic>> days;
  final int totalSold;
  final int activeDays;

  static const ink=Color(0xFF1A2B44);
  static const muted=Color(0xFF718098);
  static const colors=<Color>[
    Color(0xFFEDF2F7),Color(0xFFCBEFE0),
    Color(0xFF99DDBE),Color(0xFF51C99B),Color(0xFF079469),
  ];
  static const weekdays=<String>['Du','Se','Ch','Pa','Ju','Sh','Ya'];

  static int countOf(Map<String,dynamic> row){
    final raw=row['sold'];
    return raw is num?raw.toInt():int.tryParse(raw?.toString()??'')??0;
  }
  static int amount(Map<String,dynamic> row,String key){
    final v=row[key];
    return v is num?v.round():int.tryParse(v?.toString()??'')??0;
  }
  static Color levelColor(int sold){
    if(sold<=0)return colors[0];
    if(sold<=2)return colors[1];
    if(sold<=5)return colors[2];
    if(sold<=9)return colors[3];
    return colors[4];
  }
  static String _won(int amount)=>(amount<0?'−':'')+'₩'+
    NumberFormat('#,###','en_US').format(amount.abs());

  void _showDay(BuildContext context,Map<String,dynamic> value){
    final date=(value['date']??'').toString();
    final d=DateTime.tryParse(date);
    final label=d!=null?DateFormat('dd.MM.yyyy').format(d):date;
    showModalBottomSheet<void>(
      context:context,showDragHandle:true,
      builder:(ctx)=>SafeArea(child:Padding(
        padding:const EdgeInsets.fromLTRB(22,10,22,25),
        child:Column(mainAxisSize:MainAxisSize.min,
          crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text('$label — sotuv faolligi',style:const TextStyle(
            color:ink,fontSize:19,fontWeight:FontWeight.w900)),
          const SizedBox(height:12),
          _line('Sotilgan kitoblar',countOf(value).toString()+' dona'),
          _line('Jami tushum',_won(amount(value,'revenue'))),
          _line('Kitoblar foydasi',_won(amount(value,'profit'))),
          const SizedBox(height:8),
          const Text('Foyda sotuv vaqtida saqlangan tan narxi '
            'asosida hisoblangan.',style:TextStyle(
              color:muted,fontSize:11.5)),
        ]),
      )),
    );
  }

  Widget _line(String title,String value)=>Padding(
    padding:const EdgeInsets.symmetric(vertical:6),
    child:Row(children:[
      Expanded(child:Text(title,
        style:const TextStyle(color:muted,fontSize:13))),
      Text(value,style:const TextStyle(color:ink,fontSize:13,
        fontWeight:FontWeight.w800)),
    ]),
  );

  @override
  Widget build(BuildContext context){
    final sorted=<Map<String,dynamic>>[
      ...days.where((d)=>DateTime.tryParse((d['date']??'').toString())!=null)
    ]..sort((a,b)=>a['date'].toString().compareTo(b['date'].toString()));

    if(sorted.isEmpty){
      return const Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text('Sotuv faolligi (oxirgi 30 kun)',style:TextStyle(
          color:ink,fontSize:17,fontWeight:FontWeight.w900)),
        SizedBox(height:15),
        SizedBox(height:175,child:Center(child:Text(
          'Sotuv faolligi yuklanmadi.',style:TextStyle(color:muted)))),
      ]);
    }

    final byDate=<String,Map<String,dynamic>>{
      for(final row in sorted) row['date'].toString().substring(0,10):row,
    };
    final first=DateTime.parse(sorted.first['date'].toString().substring(0,10));
    final last=DateTime.parse(sorted.last['date'].toString().substring(0,10));
    final start=first.subtract(Duration(days:first.weekday-1));
    final end=last.add(Duration(days:7-last.weekday));
    final weekCount=(end.difference(start).inDays+1)~/7;
    final showTotal=totalSold>=0?totalSold:
      sorted.fold<int>(0,(v,d)=>v+countOf(d));
    final showActive=activeDays>=0?activeDays:
      sorted.where((r)=>countOf(r)>0).length;

    return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      const Text('Sotuv faolligi (oxirgi 30 kun)',style:TextStyle(
        color:ink,fontSize:17,fontWeight:FontWeight.w900)),
      const SizedBox(height:5),
      const Text('Har bir katak — bir kun. Rang to‘q bo‘lsa, ko‘proq kitob sotilgan.',
        style:TextStyle(color:muted,fontSize:11.5)),
      const SizedBox(height:12),
      Row(children:[
        Expanded(child:_smallStat('Sotilgan nusxalar',
          showTotal.toString()+' dona',const Color(0xFF066F51))),
        const SizedBox(width:8),
        Expanded(child:_smallStat('Savdo bo‘lgan kunlar',
          '$showActive / ${sorted.length}',ink)),
      ]),
      const SizedBox(height:17),
      LayoutBuilder(builder:(context,constraints){
        final available=constraints.maxWidth;
        final cellSize=((available-43-(weekCount-1)*6)/weekCount)
          .clamp(22.0,46.0);
        return Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Padding(padding:const EdgeInsets.only(top:25),child:Column(children:[
            for(final label in weekdays)
              SizedBox(height:cellSize+6,width:31,
                child:Align(alignment:Alignment.centerLeft,
                  child:Text(label,style:const TextStyle(
                    fontSize:11,color:muted)))),
          ])),
          const SizedBox(width:6),
          for(var w=0;w<weekCount;w++) ...[
            if(w>0)const SizedBox(width:6),
            Column(children:[
              SizedBox(height:25,width:cellSize,
                child:Text(DateFormat('dd.MM').format(
                    start.add(Duration(days:w*7))),
                  style:const TextStyle(color:muted,fontSize:10),
                  textAlign:TextAlign.center)),
              for(var d=0;d<7;d++) ...[
                Builder(builder:(context){
                  final current=start.add(Duration(days:w*7+d));
                  final key=DateFormat('yyyy-MM-dd').format(current);
                  final row=byDate[key];
                  final active=row!=null;
                  final count=active?countOf(row):0;
                  return Padding(padding:const EdgeInsets.only(bottom:6),
                    child:Tooltip(
                      message:active
                        ? '$key: $count dona sotilgan'
                        : '$key: hisobotdan tashqari',
                      child:InkWell(
                        onTap:active?()=>_showDay(context,row):null,
                        borderRadius:BorderRadius.circular(6),
                        child:Container(
                          width:cellSize,height:cellSize,
                          decoration:BoxDecoration(
                            borderRadius:BorderRadius.circular(6),
                            color:active?levelColor(count):
                              const Color(0xFFF8FAFC),
                            border:Border.all(color:active
                              ?const Color(0x0E25516F):
                              const Color(0xFFD9E2ED)),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ]),
          ],
        ]);
      }),
      const SizedBox(height:8),
      Row(mainAxisAlignment:MainAxisAlignment.end,children:[
        const Text('Kam',style:TextStyle(color:muted,fontSize:10.5)),
        const SizedBox(width:7),
        for(final color in colors) Padding(
          padding:const EdgeInsets.only(right:4),
          child:Container(width:17,height:13,decoration:BoxDecoration(
            color:color,borderRadius:BorderRadius.circular(3)))),
        const SizedBox(width:4),
        const Text('Ko‘p',style:TextStyle(color:muted,fontSize:10.5)),
      ]),
    ]);
  }

  Widget _smallStat(String title,String value,Color color)=>Container(
    padding:const EdgeInsets.symmetric(horizontal:10,vertical:11),
    decoration:BoxDecoration(
      color:const Color(0xFFF5F8FC),
      borderRadius:BorderRadius.circular(11)),
    child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text(title,style:const TextStyle(color:muted,fontSize:11)),
      const SizedBox(height:3),
      Text(value,style:TextStyle(fontWeight:FontWeight.w900,
        color:color,fontSize:17)),
    ]),
  );
}
