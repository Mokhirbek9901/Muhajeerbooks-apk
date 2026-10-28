import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Keep finance-only historical groups in chronological order beside lots.
@visibleForTesting
List<Map<String,dynamic>> sortedProfitBatchGroups(
    List<Map<String,dynamic>> groups) {
  return [...groups]..sort((a,b) {
    final d=(b['date']??'').toString().compareTo((a['date']??'').toString());
    return d!=0?d:(a['title']??'').toString().compareTo((b['title']??'').toString());
  });
}

/// Purchase lot margin projections. This does NOT attribute old sales to lots.
/// Recorded sales use their immutable purchase-price snapshots elsewhere.
class AdminProfitBatchPanel extends StatelessWidget {
  const AdminProfitBatchPanel({
    super.key,
    required this.groups,
    required this.lots,
    this.unmatchedSalesCount = 0,
  });

  final List<Map<String,dynamic>> groups;
  final List<Map<String,dynamic>> lots;
  /// Recorded sales without a safe, date-eligible, matching receipt.
  final int unmatchedSalesCount;

  static const navy=Color(0xFF162743);
  static const muted=Color(0xFF708099);
  static const green=Color(0xFF08A776);
  static const palette=<Color>[
    Color(0xFF0CB384), Color(0xFF2B7EE5),
    Color(0xFF9862E8), Color(0xFFEA9B26),
  ];
  int _n(Map<String,dynamic> row,String key) {
    final v=row[key];
    return v is num?v.round():int.tryParse(v?.toString()??'')??0;
  }
  String _won(int n)=>(n<0?'−':'')+'₩'+
    NumberFormat('#,###','en_US').format(n.abs());

  List<Map<String,dynamic>> _groupLots(Map<String,dynamic> group) {
    final key=group['group_key'];
    return lots.where((row)=>row['group_key']==key).toList()
      ..sort((a,b)=>_n(b,'quantity').compareTo(_n(a,'quantity')));
  }

  void _showGroupDetails(BuildContext context,Map<String,dynamic> group) {
    if (group['missing_lot_details']==true) {
      showModalBottomSheet<void>(
        context:context,isScrollControlled:true,showDragHandle:true,
        builder:(context)=>SafeArea(child:Padding(
          padding:const EdgeInsets.all(22),
          child:Column(mainAxisSize:MainAxisSize.min,
            crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text((group['title']??'Partiya').toString(),
              style:const TextStyle(fontWeight:FontWeight.w900,fontSize:20,
                color:navy)),
            const SizedBox(height:14),
            _line('Mavjud moliya xaridlari',
              _n(group,'finance_purchase_count').toString()+' ta'),
            _line('Moliyadagi xarajat',
              _won(_n(group,'finance_recorded_cost'))),
            const SizedBox(height:12),
            const Text('Bu partiya uchun kitoblar hali biriktirilmagan. '
              'Kelgan kitoblar soni, FIFO hisobiy chiqimi va kutilayotgan '
              'foydani hozircha aniqlab bo‘lmaydi. '
              'Biznes asboblari → Partiyalar tarixi bo‘limida kitoblarni '
              'shu partiyaga kiriting. Xarajat qayta yozilmaydi.',
              style:TextStyle(color:muted,fontSize:13,height:1.5)),
            const SizedBox(height:8),
          ]),
        )),
      );
      return;
    }
    final items=_groupLots(group);
    showModalBottomSheet<void>(
      context:context,isScrollControlled:true,showDragHandle:true,
      builder:(context)=>SafeArea(child:FractionallySizedBox(
        heightFactor:.86,
        child:ListView(padding:const EdgeInsets.fromLTRB(18,7,18,28),children:[
          Text((group['title']??'Partiya').toString(),
            style:const TextStyle(color:navy,fontSize:22,
              fontWeight:FontWeight.w900)),
          const SizedBox(height:5),
          Text('Sana: '+(group['date']??'').toString()+
            ' · '+_n(group,'purchased_units').toString()+' dona',
            style:const TextStyle(color:muted,fontSize:12)),
          const SizedBox(height:7),
          _line(group['date_fifo_applied']==true
              ? 'Sotuv sanalari bo‘yicha FIFO'
              : 'Ombor bo‘yicha hisobiy chiqim (FIFO)',
            _n(group,'estimated_sold_units').toString()+' / '+
            _n(group,'purchased_units').toString()+' dona'),
          _line('FIFO bo‘yicha sotilish foizi',
            _soldRate(group).toStringAsFixed(0)+'%'),
          if(group['date_fifo_applied']==true) ...[
            _line('Narxi ma’lum sotuvlar',
              _n(group,'dated_order_sales_units').toString()+' dona'),
            _line('Eski tarixdan biriktirilgan',
              _n(group,'dated_legacy_sales_units').toString()+' dona'),
            _line('Shu partiya tannarxi bilan yalpi foyda (narxi ma’lum)',
              _won(_n(group,'dated_order_gross_profit'))),
          ],
          const SizedBox(height:12),
          Container(
            padding:const EdgeInsets.all(13),
            decoration:BoxDecoration(
              color:const Color(0xFFEAF7F2),
              borderRadius:BorderRadius.circular(12)),
            child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              const Text('Taxminiy partiya foydasi',style:TextStyle(
                color:navy,fontWeight:FontWeight.w700,fontSize:12)),
              Text(_won(_n(group,'projected_profit')),
                style:const TextStyle(color:green,fontSize:25,
                  fontWeight:FontWeight.w900)),
              const SizedBox(height:5),
              Text('Kelgan barcha nusxa hozirgi sotuv narxida sotilsa. '
                'Bu hali haqiqiy olingan foyda emas.',
                style:const TextStyle(color:muted,fontSize:11.5)),
            ]),
          ),
          const SizedBox(height:16),
          const Text('Partiyaga kiritilgan kitoblar',style:TextStyle(
            color:navy,fontWeight:FontWeight.w900,fontSize:16)),
          const SizedBox(height:5),
          for(final item in items) ...[
            const Divider(height:19),
            Text((item['book_title']??'Kitob').toString(),
              style:const TextStyle(color:navy,fontWeight:FontWeight.w800)),
            const SizedBox(height:5),
            _line('Kelgan',_n(item,'quantity').toString()+' dona'),
            _line(item['date_fifo_applied']==true
                ? 'Sotuv sanasi bo‘yicha FIFO'
                : 'Hisobiy chiqim (FIFO)',
              _n(item,'estimated_sold_units').toString()+' dona'),
            _line('O‘sha partiyadagi tan narxi',
              _won(_n(item,'unit_cost'))),
            _line('Hozirgi sotuv narxi',_won(_n(item,'sale_price'))),
            _line('Taxminiy foyda',item['projected_profit']==null
              ?'Hisoblab bo‘lmaydi'
              :_won(_n(item,'projected_profit'))),
          ],
          const SizedBox(height:15),
          Text(group['date_fifo_applied']==true
              ? 'Sotuvlar kelgan partiya sanasi va sotilgan sanaga qarab '
                'ketma-ket biriktiriladi: avval eski partiyadagi qoldiq '
                'tugaydi. Tarixiy sotuvda narx bo‘lmasa, foyda to‘liq '
                'hisoblanmaydi. Ombor, haqiqiy sotuv va Moliya '
                'yozuvlari o‘zgartirilmaydi.'
              : 'FIFO hisobiy chiqimi hozirgi ombor qoldig‘idan taxmin '
                'qilinadi; bu tasdiqlangan sotuv emas.',
            style:const TextStyle(color:muted,fontSize:11.5,height:1.45)),
        ]),
      )),
    );
  }

  Widget _line(String title,String value)=>Padding(
    padding:const EdgeInsets.symmetric(vertical:3),
    child:Row(children:[
      Expanded(child:Text(title,style:const TextStyle(color:muted,
        fontSize:12))),
      Text(value,style:const TextStyle(color:navy,
        fontSize:12,fontWeight:FontWeight.w700)),
    ]),
  );

  double _soldRate(Map<String,dynamic> group) {
    final count=_n(group,'purchased_units');
    if(count<=0) return 0;
    return (_n(group,'estimated_sold_units')*100.0/count).clamp(0.0,100.0).toDouble();
  }

  Widget _groupRow(BuildContext context,Map<String,dynamic> group,
    int index,int positiveTotal,{bool compact=false}) {
    final incomplete=group['missing_lot_details']==true;
    final amount=_n(group,'projected_profit');
    final share=positiveTotal>0&&amount>0
      ?(amount/positiveTotal).clamp(0.0,1.0):0.0;
    final received=_n(group,'purchased_units');
    final estimatedSold=_n(group,'estimated_sold_units').clamp(0,received>0?received:0);
    final percent=_soldRate(group);
    final color=palette[index%palette.length];
    return InkWell(
      borderRadius:BorderRadius.circular(12),
      onTap:()=>_showGroupDetails(context,group),
      child:Padding(
        padding:const EdgeInsets.symmetric(vertical:12,horizontal:3),
        child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Row(children:[
            CircleAvatar(radius:15,backgroundColor:const Color(0xFFF2F5FA),
              child:Text((index+1).toString(),
                style:const TextStyle(fontSize:12,color:navy,
                  fontWeight:FontWeight.w900))),
            const SizedBox(width:8),
            Container(width:32,height:32,decoration:BoxDecoration(
              color:color.withValues(alpha:.10),
              borderRadius:BorderRadius.circular(8)),
              child:Icon(Icons.inventory_2_outlined,color:color,size:19)),
            const SizedBox(width:9),
            Expanded(child:Column(
              crossAxisAlignment:CrossAxisAlignment.start,children:[
                Text((group['title']??'Partiya').toString(),maxLines:incomplete?2:1,
                  overflow:TextOverflow.ellipsis,
                  style:const TextStyle(color:navy,fontSize:12,
                    fontWeight:FontWeight.w800)),
                const SizedBox(height:3),
                Text(incomplete
                    ? '${_n(group,'finance_purchase_count')} ta xarid yozuvi · kitoblar biriktirilmagan'
                    : '$received dona kelgan · '+
                      _n(group,'book_titles').toString()+' xil kitob',
                  style:const TextStyle(color:muted,fontSize:10.5)),
              ],
            )),
            const SizedBox(width:8),
            Column(crossAxisAlignment:CrossAxisAlignment.end,children:[
              Text(incomplete?'Hisoblanmagan':_won(amount),
                style:TextStyle(color:incomplete?muted:green,
                  fontWeight:FontWeight.w900,fontSize:13)),
              const SizedBox(height:3),
              Text(incomplete?'Kitoblar kiritilmagan'
                  :'Foyda ulushi: ${(share*100).round()}%',
                style:const TextStyle(color:muted,fontSize:10)),
            ]),
            const Icon(Icons.chevron_right_rounded,color:muted,size:17),
          ]),
          if (incomplete) ...[
            const SizedBox(height:11),
            Text('Moliyada: ${_won(_n(group,'finance_recorded_cost'))} · '
              'Foydani hisoblash uchun partiyadagi kitoblarni kiriting.',
              style:const TextStyle(color:muted,fontSize:11,height:1.4)),
          ] else ...[
          const SizedBox(height:11),
          Row(children:[
            Expanded(child:Text(group['date_fifo_applied']==true
                ? 'Sotuv sanasi bo‘yicha FIFO'
                : 'FIFO chiqimi (hisobiy)',
              style:const TextStyle(color:navy,fontSize:11,
                fontWeight:FontWeight.w700))),
            Text('${percent.toStringAsFixed(0)}%',
              style:TextStyle(color:color,fontWeight:FontWeight.w800,
                fontSize:12)),
          ]),
          const SizedBox(height:5),
          LinearProgressIndicator(value:percent/100,minHeight:7,
            borderRadius:BorderRadius.circular(6),
            color:color,backgroundColor:const Color(0xFFE9EEF5)),
          const SizedBox(height:5),
          Text('$estimatedSold / $received dona FIFO hisob · '
            '${_n(group,'estimated_remaining_units')} dona qolgan',
            style:const TextStyle(color:muted,fontSize:11)),
          ],
        ]),
      ),
    );
  }

  void _showAll(BuildContext context,int total) {
    showModalBottomSheet<void>(context:context,isScrollControlled:true,
      showDragHandle:true,builder:(context)=>SafeArea(
        child:FractionallySizedBox(heightFactor:.82,
          child:ListView(padding:const EdgeInsets.all(17),children:[
            const Text('Barcha xarid partiyalari',style:TextStyle(
              color:navy,fontSize:21,fontWeight:FontWeight.w900)),
            const SizedBox(height:7),
            const Text('Quyidagi summalar taxminiy: kirgan barcha nusxalar '
              'hozirgi sotuv narxida sotilgan deb hisoblanadi.',
              style:TextStyle(color:muted,fontSize:12)),
            const SizedBox(height:12),
            for(var i=0;i<sortedProfitBatchGroups(groups).length;i++) ...[
              _groupRow(context,sortedProfitBatchGroups(groups)[i],i,total),
              const Divider(height:1),
            ],
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visibleGroups=sortedProfitBatchGroups(groups);
    final positiveTotal=groups.fold<int>(0,(sum,g){
      final value=_n(g,'projected_profit');
      return sum+(value>0?value:0);
    });
    return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Row(children:[
        const Expanded(child:Text('Partiyalar bo‘yicha foyda',
          style:TextStyle(color:navy,fontWeight:FontWeight.w900,fontSize:17))),
        if(groups.isNotEmpty) TextButton(
          onPressed:()=>_showAll(context,positiveTotal),
          child:const Text('Barchasini ko‘rish',
            style:TextStyle(fontSize:11))),
      ]),
      const SizedBox(height:2),
      const Text('Kutilayotgan foyda · jami kelgan kitoblar',
        style:TextStyle(color:muted,fontSize:11)),
      const SizedBox(height:9),
      if(groups.isEmpty)
        const SizedBox(height:220,child:Center(
          child:Text('Partiya ma’lumotlari topilmadi.',
            style:TextStyle(color:muted))))
      else for(var i=0;i<visibleGroups.length&&i<4;i++) ...[
        _groupRow(context,visibleGroups[i],i,positiveTotal),
        if(i+1<visibleGroups.length&&i<3)
          const Divider(height:1,color:Color(0xFFE8EDF4)),
      ],
      const SizedBox(height:9),
      Text(groups.any((g)=>g['date_fifo_applied']==true)
          ? 'FIFO sotuv sanasi bilan kelgan sana asosida avtomatik '
            'taqsimlanadi. Eski qoldiq tugamaguncha yangi partiyadan '
            'ayrilmaydi. Noma’lum kitob va eski narxsiz sotuvlar '
            'foyda hisobini cheklashi mumkin. Foyda ulushi sotilish '
            'foizi emas.'
          : 'FIFO hozirgi ombor qoldig‘i bo‘yicha taxmin; '
            'aniq sotuv emas. Foyda ulushi sotilish foizi emas.',
        style:const TextStyle(color:muted,fontSize:10.5,height:1.35)),
    ]);
  }
}
