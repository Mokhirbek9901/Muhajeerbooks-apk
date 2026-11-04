import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:muhajeerbooks/admin_sales_heatmap_navigation.dart';

void main() {
  final today = DateTime(2026, 11, 5);
  final historicalStart = DateTime(2024, 4, 1);
  final requested = <DateTimeRange>[];

  List<Map<String, dynamic>> sample(DateTime from, DateTime to) => [
    for (var i=0; i<=to.difference(from).inDays; i++)
      () {
        final date = from.add(Duration(days:i));
        final legacy = date.year == 2024 &&
            date.month == 4 && date.day == 19;
        final recent = date.year == 2026 &&
            date.month == 11 && date.day == 4;
        return <String,dynamic>{
          'date': DateFormat('yyyy-MM-dd').format(date),
          'sold': legacy ? 11 : (recent ? 3 : 0),
          'historic_sold': legacy ? 11 : 0,
          'revenue': legacy ? null : (recent ? 45000 : null),
          'profit': legacy ? null : (recent ? 9000 : null),
        };
      }(),
  ];

  Future<Map<String,dynamic>> fetch(DateTime from, DateTime to) async {
    requested.add(DateTimeRange(start: from,end: to));
    if (from.isBefore(historicalStart) || to.isAfter(today)) {
      throw StateError('Requested outside historical bounds');
    }
    return {'days': sample(from,to)};
  }

  Future<void> show(WidgetTester tester) async {
    requested.clear();
    tester.view.physicalSize=const Size(390, 900);
    tester.view.devicePixelRatio=1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home: Scaffold(
      body: SingleChildScrollView(
        child: Padding(padding: const EdgeInsets.all(12),
          child: AdminSalesHeatmapNavigator(
            days: sample(today.subtract(const Duration(days:29)),today),
            loadRange: fetch,
            today: today,
          ),
        ),
      ),
    )));
    await tester.pumpAndSettle();
  }

  testWidgets('variant C: arrow navigation, daily counts and future guard',
      (tester) async {
    await show(tester);
    expect(find.text('Sotuv faolligi (oxirgi 30 kun)'),findsOneWidget);
    expect(find.text('3 dona'),findsOneWidget);
    expect(find.text('1 / 30'),findsOneWidget);
    expect(tester.widget<IconButton>(find.byKey(
      const Key('heatmap_next'))).onPressed,isNull);

    await tester.tap(find.byKey(const Key('heatmap_previous')));
    await tester.pumpAndSettle();
    expect(requested.last.end.isBefore(today),isTrue);
    expect(find.text('0 dona'),findsOneWidget);
    expect(tester.widget<IconButton>(find.byKey(
      const Key('heatmap_next'))).onPressed,isNotNull);
    await tester.tap(find.byKey(const Key('heatmap_next')));
    await tester.pumpAndSettle();
    expect(requested.last.end,today);

    await tester.tap(find.byKey(const Key('heatmap_tab_1')));
    await tester.pumpAndSettle();
    expect(find.text('2026-yil, Noyabr'),findsOneWidget);
    expect(requested.last.start,DateTime(2026,11,1));
    expect(requested.last.end,today);
    await tester.tap(find.byKey(const Key('heatmap_previous')));
    await tester.pumpAndSettle();
    expect(find.text('2026-yil, Oktabr'),findsOneWidget);
    expect(requested.last.start,DateTime(2026,10,1));
    expect(requested.last.end,DateTime(2026,10,31));
  });

  testWidgets('year 2024 and entire archive navigate to 2024 April without losing sales',
      (tester) async {
    await show(tester);
    await tester.tap(find.byKey(const Key('heatmap_tab_3')));
    await tester.pumpAndSettle();
    expect(requested.last.start,DateTime(2024,4,1));
    expect(requested.last.end,today);
    expect(find.text('2024-yil'),findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('heatmap_month_202404')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('heatmap_month_202404')));
    await tester.pumpAndSettle();
    expect(find.text('2024-yil, Aprel'),findsOneWidget);
    expect(find.text('11 dona'),findsOneWidget);
    expect(requested.last.start,DateTime(2024,4,1));
    expect(requested.last.end,DateTime(2024,4,30));
    expect(tester.widget<IconButton>(find.byKey(
      const Key('heatmap_previous'))).onPressed,isNull);
    await tester.tap(find.byKey(const Key('heatmap_next')));
    await tester.pumpAndSettle();
    expect(find.text('2024-yil, May'),findsOneWidget);
    expect(requested.last.start,DateTime(2024,5,1));
  });

  testWidgets('year mode uses complete calendar year, not only 30 days',
      (tester) async {
    await show(tester);
    await tester.tap(find.byKey(const Key('heatmap_tab_2')));
    await tester.pumpAndSettle();
    expect(requested.last.start,DateTime(2026,1,1));
    expect(requested.last.end,today);
    await tester.tap(find.byKey(const Key('heatmap_previous')));
    await tester.pumpAndSettle();
    expect(find.text('2025-yil'),findsOneWidget);
    expect(requested.last.start,DateTime(2025,1,1));
    expect(requested.last.end,DateTime(2025,12,31));
    await tester.tap(find.byKey(const Key('heatmap_previous')));
    await tester.pumpAndSettle();
    expect(find.text('2024-yil'),findsOneWidget);
    expect(requested.last.start,DateTime(2024,4,1));
    expect(requested.last.end,DateTime(2024,12,31));
    expect(tester.widget<IconButton>(find.byKey(
      const Key('heatmap_previous'))).onPressed,isNull);
  });
}
