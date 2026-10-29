import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muhajeerbooks/preorder_instagram.dart';

void main() {
  test('contact accepts usernames, never uses arbitrary links as an identity', () {
    expect(normalizePreorderInstagram(' @reader_01 '), 'reader_01');
    expect(validPreorderInstagram('@reader.01'), isTrue);
    for (final invalid in ['', 'a b', 'https://instagram.com/reader', 'x' * 31]) {
      expect(validPreorderInstagram(invalid), isFalse);
    }
  });
  testWidgets('preorder cannot pass validation without Instagram contact', (tester) async {
    final form = GlobalKey<FormState>();
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Form(key: form,
      child: PreorderInstagramField(controller: controller)))));
    expect(form.currentState!.validate(), isFalse);
    await tester.pump();
    expect(find.text('Instagram username kiriting: @username'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), '@reader_01');
    expect(form.currentState!.validate(), isTrue);
  });
}
