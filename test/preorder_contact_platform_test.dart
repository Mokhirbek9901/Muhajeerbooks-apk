import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muhajeerbooks/preorder_instagram.dart';

void main() {
  test('Instagram and Telegram usernames have different validation rules', () {
    expect(validPreorderContact('@reader.01', PreorderContactPlatform.instagram), true);
    expect(validPreorderContact('@reader.01', PreorderContactPlatform.telegram), false);
    expect(validPreorderContact('@reader_0123', PreorderContactPlatform.telegram), true);
    expect(validPreorderContact('@abc', PreorderContactPlatform.telegram), false);
    for (final bad in ['', 'has space', 'https://t.me/reader_0123']) {
      expect(validPreorderContact(bad, PreorderContactPlatform.telegram), false);
      expect(validPreorderContact(bad, PreorderContactPlatform.instagram), false);
    }
  });

  testWidgets('customer can choose Telegram and must enter its username', (tester) async {
    final username = TextEditingController();
    addTearDown(username.dispose);
    PreorderContactPlatform platform = PreorderContactPlatform.instagram;
    final key = GlobalKey<FormState>();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: StatefulBuilder(builder: (context, setState) {
        return SingleChildScrollView(child: Form(
          key: key,
          child: Column(children: [
            PreorderContactField(
              controller: username,
              platform: platform,
              onPlatformChanged: (value) => setState(() => platform = value),
            ),
            ElevatedButton(onPressed: () => key.currentState?.validate(), child: const Text('Tekshirish')),
          ]),
        ));
      })),
    ));
    expect(find.text('Instagram username (majburiy)'), findsOneWidget);
    await tester.tap(find.text('Telegram').first);
    await tester.pumpAndSettle();
    expect(find.text('Telegram username (majburiy)'), findsOneWidget);
    await tester.tap(find.text('Tekshirish'));
    await tester.pumpAndSettle();
    expect(find.text('Telegram username kiriting: @username'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).first, '@reader_0123');
    await tester.tap(find.text('Tekshirish'));
    await tester.pumpAndSettle();
    expect(find.text('Telegram username kiriting: @username'), findsNothing);
  });
}
