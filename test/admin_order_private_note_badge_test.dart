import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muhajeerbooks/admin_order_private_note_badge.dart';

void main() {
  testWidgets('Variant 3 shows a red warning beside an admin note', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 220,
          child: AdminOrderPrivateNoteBadge(note: 'book marker 3.4 ta'),
        ),
      ),
    ));

    expect(find.byKey(const Key('admin_private_note_header_badge')),
        findsOneWidget);
    expect(find.byIcon(Icons.warning_rounded), findsOneWidget);
    expect(find.text('book marker 3.4 ta'), findsOneWidget);
    final container = tester.widget<Container>(
      find.byKey(const Key('admin_private_note_header_badge')),
    );
    final decoration = container.decoration! as BoxDecoration;
    expect(decoration.color, const Color(0xFFD9252E));
    expect(tester.takeException(), isNull);
  });

  testWidgets('No admin note means no warning at all', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: AdminOrderPrivateNoteBadge(note: '  ')),
    ));
    expect(find.byKey(const Key('admin_private_note_header_badge')),
        findsNothing);
    expect(find.byIcon(Icons.warning_rounded), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Long note does not overflow narrow iPhone card headers',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 115,
          child: AdminOrderPrivateNoteBadge(
            note: 'Markerlarni alohida qadoqlash, mijozga qo‘ng‘iroq qilish',
          ),
        ),
      ),
    ));
    expect(find.byKey(const Key('admin_private_note_header_badge')),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
