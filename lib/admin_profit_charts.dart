import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Dashboard charts are painted from actual admin profit report numbers.
/// No placeholder series or hard-coded sales amounts.
class ProfitDashboardTrend extends StatelessWidget {
  const ProfitDashboardTrend({super.key,required this.daily});
  final List<Map<String,dynamic>> daily;

  static int _number(Map<String,dynamic> row,String name) {
    final value=row[name];
    return value is num ? value.round() : int.tryParse(value?.toString()??'')??0;
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Row(children:[
        const Expanded(child:Text('Daromad va foyda grafigi',
          style:TextStyle(fontWeight:FontWeight.w900,fontSize:17,color:Color(0xFF17243D)))),
        const _ProfitLegend(color:Color(0xFF14A77D),text:'Tushum'),
        const SizedBox(width:12),
        const _ProfitLegend(color:Color(0xFF2879E8),text:'Foyda'),
      ]),
      const SizedBox(height:18),
      if(daily.isEmpty)
        const SizedBox(height:200,child:Center(child:Text('Tanlangan davrda sotuv yo‘q.',
          style:TextStyle(color:Color(0xFF748197)))))
      else
        SizedBox(height:240,child:LayoutBuilder(builder:(context,c){
          final ordered=[...daily]..sort((a,b)=>
            (a['date']??'').toString().compareTo((b['date']??'').toString()));
          return CustomPaint(
            size:Size(c.maxWidth,c.maxHeight),
            painter:_ProfitLinesPainter(ordered),
          );
        })),
    ]);
  }
}

class _ProfitLegend extends StatelessWidget {
  const _ProfitLegend({required this.color,required this.text});
  final Color color;
  final String text;
  @override
  Widget build(BuildContext context)=>Row(mainAxisSize:MainAxisSize.min,children:[
    Container(width:9,height:9,decoration:BoxDecoration(
      color:color,shape:BoxShape.circle)),
    const SizedBox(width:5),
    Text(text,style:const TextStyle(color:Color(0xFF617089),fontSize:11.5)),
  ]);
}

class _ProfitLinesPainter extends CustomPainter {
  const _ProfitLinesPainter(this.daily);
  final List<Map<String,dynamic>> daily;
  static const blue=Color(0xFF2879E8);
  static const green=Color(0xFF14A77D);
  static const gray=Color(0xFF7B8799);
  int n(Map<String,dynamic> row,String key)=>ProfitDashboardTrend._number(row,key);
  String compact(int value) {
    if(value.abs()>=1000000)return (value/1000000).toStringAsFixed(1)+'M';
    if(value.abs()>=1000)return (value/1000).toStringAsFixed(0)+'k';
    return value.toString();
  }
  void label(Canvas canvas,String text,Offset offset,{TextAlign align=TextAlign.left}) {
    final painter=TextPainter(
      text:TextSpan(text:text,style:const TextStyle(color:gray,fontSize:10)),
      textDirection:ui.TextDirection.ltr,textAlign:align,maxLines:1,
    )..layout();
    painter.paint(canvas,offset);
  }
  @override
  void paint(Canvas canvas,Size size) {
    const left=47.0,top=5.0,bottom=25.0,right=7.0;
    final plot=Rect.fromLTRB(left,top,math.max(left+12,size.width-right),
      math.max(top+15,size.height-bottom));
    if(daily.isEmpty)return;
    final maxValue=math.max(1,daily.fold<int>(0,(v,row)=>math.max(v,
      math.max(n(row,'revenue'),n(row,'profit')))));
    final niceMax=(maxValue/4).ceil()*4;
    for(var i=0;i<=4;i++){
      final y=plot.bottom-(i/4)*plot.height;
      canvas.drawLine(Offset(plot.left,y),Offset(plot.right,y),
        Paint()..color=const Color(0xFFEDF1F6)..strokeWidth=1);
      final value=(niceMax*i/4).round();
      final text=compact(value);
      final tp=TextPainter(text:TextSpan(text:text,
        style:const TextStyle(color:gray,fontSize:10)),
        textDirection:ui.TextDirection.ltr)..layout();
      tp.paint(canvas,Offset(left-tp.width-9,y-tp.height/2));
    }
    final count=daily.length;
    final xs=List<double>.generate(count,(i)=>plot.left+
      (count==1?plot.width/2:i*plot.width/(count-1)));
    final indexes=<int>{0,count-1};
    if(count>3)indexes.addAll([count~/4,count~/2,(3*count)~/4]);
    for(final i in indexes.toList()..sort()){
      final d=(daily[i]['date']??'').toString();
      final title=d.length>=10?d.substring(5):d;
      final tp=TextPainter(text:TextSpan(text:title,
        style:const TextStyle(color:gray,fontSize:10)),
        textDirection:ui.TextDirection.ltr)..layout();
      tp.paint(canvas,Offset(
        (xs[i]-tp.width/2).clamp(plot.left-2,plot.right-tp.width+3),
        plot.bottom+8,
      ));
    }
    void series(String key,Color color) {
      final points=List<Offset>.generate(count,(i)=>Offset(xs[i],
        plot.bottom-(n(daily[i],key)/niceMax)*plot.height));
      final line=Path()..moveTo(points.first.dx,points.first.dy);
      for(final p in points.skip(1))line.lineTo(p.dx,p.dy);
      final area=Path.from(line)
        ..lineTo(points.last.dx,plot.bottom)
        ..lineTo(points.first.dx,plot.bottom)
        ..close();
      canvas.drawPath(area,Paint()
        ..shader=LinearGradient(begin:Alignment.topCenter,
          end:Alignment.bottomCenter,
          colors:[color.withValues(alpha:.22),color.withValues(alpha:.015)])
          .createShader(plot));
      canvas.drawPath(line,Paint()
        ..color=color..strokeWidth=2.7..style=PaintingStyle.stroke
        ..strokeJoin=StrokeJoin.round..strokeCap=StrokeCap.round);
      for(final i in [
        if(count<=12)...List<int>.generate(count,(j)=>j)
        else ...[0,count~/4,count~/2,3*count~/4,count-1],
      ]){
        canvas.drawCircle(points[i],3.5,Paint()..color=color);
      }
    }
    series('revenue',green);
    series('profit',blue);
  }
  @override
  bool shouldRepaint(covariant _ProfitLinesPainter old)=>
    old.daily!=daily;
}

class ProfitDashboardDonut extends StatelessWidget {
  const ProfitDashboardDonut({super.key,required this.categoryProfit});
  final Map<String,int> categoryProfit;
  static const colors=[
    Color(0xFF317AF3),
    Color(0xFF0BA987),
    Color(0xFFFFB02E),
    Color(0xFFF4675B),
    Color(0xFF9A65E8),
    Color(0xFFABB6C6),
    Color(0xFF29B2D8),
    Color(0xFF4ABF73),
  ];
  @override
  Widget build(BuildContext context){
    final sorted=categoryProfit.entries.where((e)=>e.value>0).toList()
      ..sort((a,b)=>b.value.compareTo(a.value));
    final entries=<MapEntry<String,int>>[
      ...sorted.take(5),
      if(sorted.length>5)
        MapEntry('Boshqa',sorted.skip(5).fold<int>(0,(s,e)=>s+e.value)),
    ];
    final total=entries.fold<int>(0,(s,e)=>s+e.value);
    final chart= SizedBox(width:173,height:173,child:Stack(alignment:Alignment.center,
      children:[
        CustomPaint(size:const Size(170,170),
          painter:_ProfitDonutPainter(entries.map((e)=>e.value).toList(),colors)),
        Column(mainAxisSize:MainAxisSize.min,children:[
          Text(total>=1000000?(total/1000000).toStringAsFixed(1)+'M':
            NumberFormat('#,###').format(total),
            style:const TextStyle(fontWeight:FontWeight.w900,fontSize:22,
              color:Color(0xFF17243D))),
          const Text('₩ foyda',style:TextStyle(fontSize:11.5,
            color:Color(0xFF66758A))),
        ]),
      ],
    ));
    final legend=Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      for(var i=0;i<entries.length;i++) Padding(
        padding:const EdgeInsets.symmetric(vertical:5),child:Row(
          mainAxisSize:MainAxisSize.min,children:[
            Container(width:10,height:10,decoration:BoxDecoration(
              color:colors[i%colors.length],shape:BoxShape.circle)),
            const SizedBox(width:7),
            Flexible(child:Text(entries[i].key,maxLines:1,
              overflow:TextOverflow.ellipsis,
              style:const TextStyle(color:Color(0xFF4D5B71),fontSize:11.5))),
            const SizedBox(width:7),
            Text(total==0?'—':
              ((entries[i].value*100/total).round()).toString()+'%',
              style:const TextStyle(fontSize:11.5,fontWeight:FontWeight.w800)),
          ],
        ),
      ),
    ]);
    return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      const Text('Kategoriya bo‘yicha foyda',
        style:TextStyle(fontWeight:FontWeight.w900,fontSize:17,
          color:Color(0xFF17243D))),
      const SizedBox(height:14),
      if(entries.isEmpty)
        const SizedBox(height:185,child:Center(
          child:Text('Hisoblash uchun sotuv yo‘q.',
            style:TextStyle(color:Color(0xFF748197)))))
      else LayoutBuilder(builder:(context,c){
        if(c.maxWidth<360) return Column(children:[chart,
          const SizedBox(height:10),legend]);
        return Row(children:[
          chart,const SizedBox(width:10),Expanded(child:legend),
        ]);
      }),
    ]);
  }
}

class _ProfitDonutPainter extends CustomPainter {
  const _ProfitDonutPainter(this.values,this.colors);
  final List<int> values;
  final List<Color> colors;
  @override
  void paint(Canvas canvas,Size size){
    final total=values.fold<int>(0,(a,b)=>a+b);
    final rect=Rect.fromCircle(center:Offset(size.width/2,size.height/2),
      radius:math.min(size.width,size.height)*.40);
    const gap=.017;
    double angle=-math.pi/2;
    if(total==0) {
      canvas.drawArc(rect,0,math.pi*2,false,Paint()
        ..color=const Color(0xFFEAF0F6)..strokeWidth=20
        ..style=PaintingStyle.stroke);
      return;
    }
    for(var i=0;i<values.length;i++){
      final sweep=math.pi*2*values[i]/total;
      canvas.drawArc(rect,angle+gap/2,math.max(0,sweep-gap),false,
        Paint()..color=colors[i%colors.length]
        ..style=PaintingStyle.stroke..strokeWidth=19);
      angle+=sweep;
    }
  }
  @override
  bool shouldRepaint(covariant _ProfitDonutPainter old)=>
    old.values!=values;
}
