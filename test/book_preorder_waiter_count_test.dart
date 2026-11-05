import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muhajeerbooks/book_preorder_waiter_count.dart';

void main() {
  testWidgets('preorder detail shows unique waiting people', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: BookPreorderWaiterCount(
        bookId: 'test-book',
        loader: (id) async {
          expect(id, 'test-book');
          return 3;
        },
      )),
    ));
    await tester.pumpAndSettle();
    expect(find.text('3 kishi kutyapti'), findsOneWidget);
    expect(find.byIcon(Icons.people_alt_outlined), findsOneWidget);
  });

  testWidgets('manual refresh updates count without exposing private data',
      (tester) async {
    var requests = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: BookPreorderWaiterCount(
        bookId: 'test-book',
        loader: (id) async => ++requests,
      )),
    ));
    await tester.pumpAndSettle();
    expect(find.text('1 kishi kutyapti'), findsOneWidget);
    await tester.tap(find.byKey(
      const ValueKey('book-preorder-waiter-count')));
    await tester.pumpAndSettle();
    expect(find.text('2 kishi kutyapti'), findsOneWidget);
  });

  testWidgets('RPC failure never displays misleading zero', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: BookPreorderWaiterCount(
        bookId: 'test-book',
        loader: (id) async => throw StateError('Network unavailable'),
      )),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Kutayotganlar sonini yangilash'), findsOneWidget);
    expect(find.text('0 kishi kutyapti'), findsNothing);
  });
}
