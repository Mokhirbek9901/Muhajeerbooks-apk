import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muhajeerbooks/web_book_purchase_count.dart';

void main() {
  testWidgets('shows purchase events plus history and explains multiple copies', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SizedBox(
      width: 290,
      child: WebBookPurchaseCount(bookId: 'a', loader: (_) async => const BookPurchaseCount(12, 5)),
    ))));
    await tester.pumpAndSettle();
    expect(find.text('17 marta xarid qilingan'), findsOneWidget);
    expect(tester.takeException(), isNull);
    final button = tester.widget<OutlinedButton>(find.byKey(const ValueKey('book-purchase-count')));
    expect(button.style!.minimumSize!.resolve({}), const Size(0, 32));
    expect(tester.widget<Text>(find.text('17 marta xarid qilingan')).style!.fontSize, 12);
    await tester.tap(find.text('17 marta xarid qilingan'));
    await tester.pumpAndSettle();
    expect(find.textContaining('5 marta avvalgi sotuv tarixidan'), findsOneWidget);
    expect(find.textContaining('bir marta hisoblanadi'), findsOneWidget);
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
    expect(find.text('0 marta xarid qilingan'), findsNothing);
    await tester.tap(find.text('Xaridlar sonini qayta yuklash'));
    await tester.pumpAndSettle();
    expect(find.text('0 marta xarid qilingan'), findsOneWidget);
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
    expect(find.text('3 marta xarid qilingan'), findsOneWidget);
    expect(find.text('99 marta xarid qilingan'), findsNothing);
  });

  test('missing or invalid responses never become a fabricated zero', () {
    for (final value in [null, {}, {'recorded_count': -1, 'historical_count': 0}]) {
      expect(() => BookPurchaseCount.fromJson(value), throwsFormatException);
    }
  });
}
