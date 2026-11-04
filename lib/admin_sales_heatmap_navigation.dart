import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'admin_sales_heatmap.dart';
import 'business_time.dart';

/// A paginated view over the existing read-only admin sales activity.
/// Historical records remain immutable and use Korea-local calendar days.
typedef AdminSalesActivityLoader = Future<Map<String, dynamic>> Function(
  DateTime from,
  DateTime to,
);

enum SalesHeatmapPeriod { thirtyDays, month, year, all }

class AdminSalesHeatmapNavigator extends StatefulWidget {
  const AdminSalesHeatmapNavigator({
    super.key,
    required this.days,
    required this.loadRange,
    this.today,
  });

  final List<Map<String, dynamic>> days;
  final AdminSalesActivityLoader loadRange;
  /// Injected only by deterministic widget tests.
  final DateTime? today;

  @override
  State<AdminSalesHeatmapNavigator> createState() =>
      _AdminSalesHeatmapNavigatorState();
}

class _AdminSalesHeatmapNavigatorState
    extends State<AdminSalesHeatmapNavigator> {
  static const navy = Color(0xFF1A2B44);
  static const muted = Color(0xFF718098);
  static const green = Color(0xFF078B65);
  static const earliest = '2024-04-01';
  static const months = <String>[
    'Yanvar', 'Fevral', 'Mart', 'Aprel', 'May', 'Iyun',
    'Iyul', 'Avgust', 'Sentabr', 'Oktabr', 'Noyabr', 'Dekabr',
  ];

  SalesHeatmapPeriod period = SalesHeatmapPeriod.thirtyDays;
  late DateTime anchor;
  late List<Map<String, dynamic>> visible;
  bool busy = false;
  String? error;
  int generation = 0;

  DateTime get today {
    final value = widget.today ?? koreaNow();
    return DateTime(value.year, value.month, value.day);
  }

  DateTime get first => DateTime(2024, 4);
  DateTime date(DateTime value) => DateTime(value.year, value.month, value.day);
  DateTime get last => date(today);

  @override
  void initState() {
    super.initState();
    anchor = last;
    visible = List<Map<String, dynamic>>.from(widget.days);
  }

  @override
  void didUpdateWidget(covariant AdminSalesHeatmapNavigator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (period == SalesHeatmapPeriod.thirtyDays &&
        anchor.year == last.year &&
        anchor.month == last.month &&
        anchor.day == last.day &&
        !busy) {
      visible = List<Map<String, dynamic>>.from(widget.days);
    }
  }

  DateTime _start() {
    switch (period) {
      case SalesHeatmapPeriod.thirtyDays:
        final start = anchor.subtract(const Duration(days: 29));
        return start.isBefore(first) ? first : start;
      case SalesHeatmapPeriod.month:
        final start = DateTime(anchor.year, anchor.month);
        return start.isBefore(first) ? first : start;
      case SalesHeatmapPeriod.year:
        final start = DateTime(anchor.year);
        return start.isBefore(first) ? first : start;
      case SalesHeatmapPeriod.all:
        return first;
    }
  }

  DateTime _end() {
    DateTime result;
    switch (period) {
      case SalesHeatmapPeriod.thirtyDays:
        result = anchor;
        break;
      case SalesHeatmapPeriod.month:
        result = DateTime(anchor.year, anchor.month + 1, 0);
        break;
      case SalesHeatmapPeriod.year:
        result = DateTime(anchor.year + 1, 1, 0);
        break;
      case SalesHeatmapPeriod.all:
        result = last;
        break;
    }
    return result.isAfter(last) ? last : result;
  }

  String get periodTitle {
    switch (period) {
      case SalesHeatmapPeriod.thirtyDays:
        return 'Sotuv faolligi (oxirgi 30 kun)';
      case SalesHeatmapPeriod.month:
        return 'Sotuv faolligi (oy bo‘yicha)';
      case SalesHeatmapPeriod.year:
        return 'Sotuv faolligi (yil bo‘yicha)';
      case SalesHeatmapPeriod.all:
        return 'Sotuv faolligi (barcha davr)';
    }
  }

  String get rangeLabel {
    switch (period) {
      case SalesHeatmapPeriod.thirtyDays:
        return '${DateFormat('dd.MM.yyyy').format(_start())} – '
            '${DateFormat('dd.MM.yyyy').format(_end())}';
      case SalesHeatmapPeriod.month:
        return '${anchor.year}-yil, ${months[anchor.month - 1]}';
      case SalesHeatmapPeriod.year:
        return '${anchor.year}-yil';
      case SalesHeatmapPeriod.all:
        return '2024-yil apreldan hozirgacha';
    }
  }

  DateTime _shift(int direction) {
    switch (period) {
      case SalesHeatmapPeriod.thirtyDays:
        final next = anchor.add(Duration(days: direction * 30));
        return next.isAfter(last) ? last : next;
      case SalesHeatmapPeriod.month:
        return DateTime(anchor.year, anchor.month + direction, 1);
      case SalesHeatmapPeriod.year:
        return DateTime(anchor.year + direction, 1);
      case SalesHeatmapPeriod.all:
        return anchor;
    }
  }

  bool get canPrev {
    if (busy || period == SalesHeatmapPeriod.all) return false;
    final next = _shift(-1);
    if (period == SalesHeatmapPeriod.thirtyDays) {
      return !next.isBefore(first);
    }
    return !DateTime(
      period == SalesHeatmapPeriod.year ? next.year : next.year,
      period == SalesHeatmapPeriod.year ? 1 : next.month,
    ).isBefore(first);
  }

  bool get canNext {
    if (busy || period == SalesHeatmapPeriod.all) return false;
    if (period == SalesHeatmapPeriod.thirtyDays) {
      return anchor.isBefore(last);
    }
    if (period == SalesHeatmapPeriod.month) {
      return DateTime(anchor.year, anchor.month)
          .isBefore(DateTime(last.year, last.month));
    }
    return anchor.year < last.year;
  }

  Future<void> _load() async {
    final from = _start(), to = _end();
    final current = ++generation;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final data = await widget.loadRange(from, to);
      if (!mounted || current != generation) return;
      final raw = data['days'];
      if (raw is! List) throw StateError('Savdo kunlari javobi noto‘g‘ri.');
      final items = raw.whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e)).toList();
      final expected = to.difference(from).inDays + 1;
      if (items.length != expected) {
        throw StateError('Tanlangan davrning barcha kunlari olinmadi.');
      }
      setState(() {
        visible = items;
        busy = false;
      });
    } catch (e) {
      if (!mounted || current != generation) return;
      setState(() {
        busy = false;
        error = 'Sotuv davrini yuklashda xatolik: $e';
      });
    }
  }

  void _choose(SalesHeatmapPeriod value) {
    if (busy || value == period) return;
    setState(() {
      period = value;
      if (value == SalesHeatmapPeriod.thirtyDays) anchor = last;
    });
    _load();
  }

  void _go(int direction) {
    if (!(direction < 0 ? canPrev : canNext)) return;
    setState(() => anchor = _shift(direction));
    _load();
  }

  Future<void> _pickDate() async {
    if (busy || period == SalesHeatmapPeriod.all) return;
    final selected = await showDatePicker(
      context: context,
      firstDate: first,
      lastDate: last,
      initialDate: anchor.isAfter(last) ? last : anchor,
      helpText: 'Savdo davrini tanlash',
    );
    if (selected == null || !mounted) return;
    setState(() => anchor = date(selected));
    await _load();
  }

  int get total => visible.fold<int>(
    0, (sum, r) => sum + AdminSalesHeatmap.countOf(r));
  int get active => visible.where((r) =>
    AdminSalesHeatmap.countOf(r) > 0).length;

  Widget _tabs() {
    const labels = ['30 kun', 'Oy', 'Yil', 'Barcha davr'];
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F6FA),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(children: [
        for (var i = 0; i < labels.length; i++)
          Expanded(child: InkWell(
            key: Key('heatmap_tab_$i'),
            onTap: busy ? null : () => _choose(SalesHeatmapPeriod.values[i]),
            borderRadius: BorderRadius.circular(9),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 9),
              decoration: BoxDecoration(
                color: period.index == i ? green : Colors.transparent,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Text(
                labels[i],
                textAlign: TextAlign.center,
                maxLines: 1,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: period.index == i ? Colors.white : navy,
                ),
              ),
            ),
          )),
      ]),
    );
  }

  Widget _navigation() => Row(children: [
    IconButton.filledTonal(
      key: const Key('heatmap_previous'),
      tooltip: 'Oldingi davr',
      onPressed: canPrev ? () => _go(-1) : null,
      icon: const Icon(Icons.chevron_left_rounded),
    ),
    Expanded(child: InkWell(
      onTap: busy || period == SalesHeatmapPeriod.all ? null : _pickDate,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 9),
        child: Row(mainAxisAlignment: MainAxisAlignment.center,children: [
          if (period != SalesHeatmapPeriod.all)
            const Icon(Icons.calendar_today_outlined, size: 13, color: navy),
          const SizedBox(width: 5),
          Flexible(child: Text(
            rangeLabel,
            key: const Key('heatmap_period_label'),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w800,
              color: navy, fontSize: 11),
          )),
          if (period != SalesHeatmapPeriod.all)
            const Icon(Icons.keyboard_arrow_down_rounded,size:16,color:navy),
        ]),
      ),
    )),
    IconButton.filledTonal(
      key: const Key('heatmap_next'),
      tooltip: 'Keyingi davr',
      onPressed: canNext ? () => _go(1) : null,
      icon: const Icon(Icons.chevron_right_rounded),
    ),
  ]);

  Widget _stat(String title, String value, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10,vertical: 11),
    decoration: BoxDecoration(
      color: const Color(0xFFF5F8FC),
      borderRadius: BorderRadius.circular(11),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start,children: [
      Text(title,style: const TextStyle(fontSize: 11,color: muted)),
      const SizedBox(height: 3),
      Text(value,style: TextStyle(fontSize: 17,color: color,
        fontWeight: FontWeight.w900)),
    ]),
  );

  Widget _totals() => Row(children: [
    Expanded(child: _stat('Sotilgan nusxalar','$total dona',green)),
    const SizedBox(width: 8),
    Expanded(child: _stat('Savdo bo‘lgan kunlar',
      '$active / ${visible.length}',navy)),
  ]);

  Widget _monthlyTiles() {
    final monthsData = <int, int>{};
    final activeByMonth = <int, int>{};
    for (final row in visible) {
      final d = DateTime.tryParse((row['date']??'').toString());
      if (d == null) continue;
      final id = d.year * 100 + d.month;
      final count = AdminSalesHeatmap.countOf(row);
      monthsData[id] = (monthsData[id] ?? 0) + count;
      if (count > 0) activeByMonth[id] = (activeByMonth[id] ?? 0) + 1;
    }
    final maxCount = monthsData.values.fold<int>(1,
        (best, value) => value > best ? value : best);
    Color shade(int count) {
      if (count == 0) return AdminSalesHeatmap.colors[0];
      final ratio = count / maxCount;
      if (ratio >= .8) return AdminSalesHeatmap.colors[4];
      if (ratio >= .6) return AdminSalesHeatmap.colors[3];
      if (ratio >= .3) return AdminSalesHeatmap.colors[2];
      return AdminSalesHeatmap.colors[1];
    }
    final years = period == SalesHeatmapPeriod.year
      ? <int>[anchor.year]
      : <int>[for (var y = first.year; y <= last.year; y++) y];
    return LayoutBuilder(builder: (context, constraints) {
      final columns = constraints.maxWidth >= 620 ? 4 : 3;
      final width = (constraints.maxWidth - (columns - 1) * 8) / columns;
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _totals(),
        const SizedBox(height: 12),
        const Text('Oy ustiga bosing — kunlik sotuvlar ochiladi.',
          style: TextStyle(color: muted,fontSize: 11)),
        const SizedBox(height: 10),
        for (final year in years) ...[
          if (period == SalesHeatmapPeriod.all) ...[
            Padding(
              padding: const EdgeInsets.only(top: 10,bottom: 9),
              child: Text('$year-yil',style: const TextStyle(
                fontWeight: FontWeight.w900,color: navy,fontSize: 15)),
            ),
          ],
          Wrap(spacing: 8,runSpacing: 8,children: [
            for (var month = 1; month <= 12; month++)
              if (DateTime(year,month+1,0).isAfter(first) &&
                  !DateTime(year,month).isAfter(last))
                Builder(builder: (context) {
                  final key = year * 100 + month;
                  final sold = monthsData[key] ?? 0;
                  final tint = shade(sold);
                  return SizedBox(
                    width: width,
                    child: Material(
                      color: tint,
                      borderRadius: BorderRadius.circular(10),
                      child: InkWell(
                        key: Key('heatmap_month_$key'),
                        onTap: () {
                          setState(() {
                            period = SalesHeatmapPeriod.month;
                            anchor = DateTime(year,month);
                          });
                          _load();
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,vertical: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(months[month-1],maxLines:1,
                                overflow:TextOverflow.ellipsis,
                                style:TextStyle(fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color:sold >= maxCount * .8 && sold>0
                                  ? Colors.white : navy)),
                              const SizedBox(height: 8),
                              Text('$sold dona',
                                style:TextStyle(fontSize: 15,
                                  fontWeight:FontWeight.w900,
                                  color:sold >= maxCount * .8 && sold>0
                                    ? Colors.white : navy)),
                              const SizedBox(height: 3),
                              Text('${activeByMonth[key] ?? 0} faol kun',
                                style:TextStyle(fontSize: 10,
                                  color:sold >= maxCount * .8 && sold>0
                                    ? Colors.white : navy)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
          ]),
          const SizedBox(height: 4),
        ],
      ]);
    });
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(periodTitle,style: const TextStyle(
        fontSize: 17,fontWeight: FontWeight.w900,color: navy)),
      const SizedBox(height: 5),
      const Text('Har bir katak — bir kun. Rang to‘q bo‘lsa, ko‘proq kitob sotilgan.',
        style:TextStyle(fontSize:11.5,color:muted)),
      const SizedBox(height: 12),
      _tabs(),
      const SizedBox(height: 8),
      _navigation(),
      const SizedBox(height: 9),
      if (busy)
        const SizedBox(height: 195,child:Center(
          child: CircularProgressIndicator()))
      else if (error != null) ...[
        Text(error!,style:const TextStyle(color:Colors.red,fontSize:12)),
        TextButton.icon(
          onPressed:_load,icon:const Icon(Icons.refresh),
          label:const Text('Qayta urinish')),
      ] else if (period == SalesHeatmapPeriod.year ||
                 period == SalesHeatmapPeriod.all)
        _monthlyTiles()
      else
        AdminSalesHeatmap(
          days: visible,
          totalSold: total,
          activeDays: active,
          showHeading: false,
        ),
      const SizedBox(height: 6),
      if (visible.any((row)=>
          AdminSalesHeatmap.amount(row,'historic_sold')>0))
        const Text(
          '2024-yil 19-apreldan saqlangan eski sotuvlar ham qo‘shilgan. '
          'Eski tarixda foyda va tushum raqamlari to‘liq mavjud emas.',
          style:TextStyle(fontSize:11,color:muted)),
    ],
  );
}
