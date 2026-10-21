import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muhajeerbooks/web_book_purchase_count.dart';

void main() {
  testWidgets('shows recorded plus historic copies and explains quantity', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SizedBox(
      width: 290,
      child: WebBookPurchaseCount(bookId: 'a', loader: (_) async => const BookPurchaseCount(12, 5)),
    ))));
    await tester.pumpAndSettle();
    expect(find.text('17 dona xarid qilingan'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('17 dona xarid qilingan'));
    await tester.pumpAndSettle();
    expect(find.textContaining('5 dona avvalgi sotuv tarixidan'), findsOneWidget);
    expect(find.textContaining('2 dona hisoblanadi'), findsOneWidget);
    await tester.tap(find.text('Yopish'));
    await tester.pumpAndSettle();
    expect(find.text('Shu kungacha xarid qilingan'), findsNothing);
  });

  testWidgets('failure is not zero and retry can show genuine zero', (tester) async {
    var calls = 0;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: WebBookPurchaseCount(
      bookId: 'a', loader: (_) async {
        if (calls++ == 0) throw StateError('offline');
        return const BookPurchaseCount(0, 0);
      },
    ))));
    await tester.pumpAndSettle();
    expect(find.text('0 dona xarid qilingan'), findsNothing);
    await tester.tap(find.text('Xaridlar sonini qayta yuklash'));
    await tester.pumpAndSettle();
    expect(find.text('0 dona xarid qilingan'), findsOneWidget);
    expect(calls, 2);
  });

  testWidgets('switching books ignores a late result from the previous book', (tester) async {
    final first = Completer<BookPurchaseCount>();
    Future<BookPurchaseCount> load(String id) => id == 'a' ? first.future : Future.value(const BookPurchaseCount(3, 0));
    Widget page(String id) => MaterialApp(home: Scaffold(body: WebBookPurchaseCount(bookId: id, loader: load)));
    await tester.pumpWidget(page('a'));
    await tester.pumpWidget(page('b'));
    await tester.pumpAndSettle();
    first.complete(const BookPurchaseCount(99, 0));
    await tester.pumpAndSettle();
    expect(find.text('3 dona xarid qilingan'), findsOneWidget);
    expect(find.text('99 dona xarid qilingan'), findsNothing);
  });

  test('missing or invalid responses never become a fabricated zero', () {
    for (final value in [null, {}, {'recorded_count': -1, 'historical_count': 0}]) {
      expect(() => BookPurchaseCount.fromJson(value), throwsFormatException);
    }
  });
}
