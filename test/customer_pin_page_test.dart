import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:muhajeerbooks/app_state.dart';
import 'package:muhajeerbooks/customer_pin_page.dart';

void main() {
  testWidgets('four digits required and SMS is never offered', (tester) async {
    await tester.pumpWidget(ChangeNotifierProvider<AppState>(
      create: (_) => AppState(backendConfigured: false),
      child: const MaterialApp(home: CustomerPinPage()),
    ));
    expect(find.text('Mening ma’lumotlarim'), findsOneWidget);
    expect(find.text('Ism, telefon va PIN'), findsOneWidget);
    expect(find.text('SMS kelmaydi.'), findsNothing);
    await tester.ensureVisible(find.text('PINim bor — boshqa telefondan kirish'));
    await tester.tap(find.text('PINim bor — boshqa telefondan kirish'));
    await tester.pumpAndSettle();
    expect(find.text('Boshqa qurilmadan kirish'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).at(0), '01012345678');
    await tester.enterText(find.byType(TextFormField).at(1), '123');
    await tester.tap(find.text('Kirish'));
    await tester.pump();
    expect(find.text('4 ta raqam kiriting'), findsOneWidget);
  });

  testWidgets('PIN creation requires matching four-digit confirmation', (tester) async {
    await tester.pumpWidget(ChangeNotifierProvider<AppState>(
      create: (_) => AppState(backendConfigured: false),
      child: const MaterialApp(home: CustomerPinPage()),
    ));
    // New customers see the combined name, phone and PIN form immediately.
    expect(find.text('Ism, telefon va PIN'), findsOneWidget);
    final inputs = find.byType(TextFormField);
    expect(inputs, findsNWidgets(4));
    await tester.enterText(inputs.at(0), 'Sinov Mijoz');
    await tester.enterText(inputs.at(1), '01012345678');
    await tester.enterText(inputs.at(2), '1234');
    await tester.enterText(inputs.at(3), '4321');
    await tester.scrollUntilVisible(
      find.text('PINni saqlash'), 180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('PINni saqlash'));
    await tester.pump();
    expect(find.text('PINlar bir xil emas'), findsOneWidget);
  });
}
