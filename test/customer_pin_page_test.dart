import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:muhajeerbooks/app_state.dart';
import 'package:muhajeerbooks/customer_pin_page.dart';

void main() {
  testWidgets('four digits required and SMS is never offered', (tester) async {
    tester.view.physicalSize = const Size(420, 1150);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ChangeNotifierProvider<AppState>(
      create: (_) => AppState(backendConfigured: false),
      child: const MaterialApp(home: CustomerPinPage()),
    ));
    expect(find.text('Mening ma’lumotlarim'), findsOneWidget);
    expect(find.text('Profilga kirish'), findsOneWidget);
    expect(find.text('PIN esimda yo‘q'), findsOneWidget);
    await tester.ensureVisible(find.text('Oldin PIN yaratmaganman — Yangi profil'));
    await tester.tap(find.text('Oldin PIN yaratmaganman — Yangi profil'));
    await tester.pump();
    expect(find.text('Yangi profil yaratish'), findsOneWidget);
    expect(find.text('SMS kelmaydi.'), findsNothing);
    await tester.enterText(find.byType(TextFormField).at(0), 'Sinov Mijoz');
    await tester.enterText(find.byType(TextFormField).at(1), '01012345678');
    await tester.enterText(find.byType(TextFormField).at(2), '123');
    await tester.enterText(find.byType(TextFormField).at(3), '123');
    await tester.tap(find.text('PINni saqlash'));
    await tester.pump();
    expect(find.text('4 ta raqam kiriting'), findsOneWidget);
  });

  testWidgets('PIN creation requires matching four-digit confirmation', (tester) async {
    tester.view.physicalSize = const Size(420, 1150);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ChangeNotifierProvider<AppState>(
      create: (_) => AppState(backendConfigured: false),
      child: const MaterialApp(home: CustomerPinPage()),
    ));
    // New customers see the combined name, phone and PIN form immediately.
    expect(find.text('Profilga kirish'), findsOneWidget);
    await tester.ensureVisible(find.text('Oldin PIN yaratmaganman — Yangi profil'));
    await tester.tap(find.text('Oldin PIN yaratmaganman — Yangi profil'));
    await tester.pump();
    expect(find.text('Yangi profil yaratish'), findsOneWidget);
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


  testWidgets('returning customer sees login and forgotten PIN explanation',
      (tester) async {
    tester.view.physicalSize = const Size(420, 1150);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ChangeNotifierProvider<AppState>(
      create: (_) => AppState(backendConfigured: false),
      child: const MaterialApp(home: CustomerPinPage()),
    ));
    expect(find.text('Profilga kirish'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2));
    await tester.ensureVisible(find.text('PIN esimda yo‘q'));
    await tester.tap(find.text('PIN esimda yo‘q'));
    await tester.pumpAndSettle();
    expect(find.text('PIN esimda yo‘q'), findsWidgets);
    expect(find.text('PINni tiklash so‘rovi'), findsOneWidget);
    expect(find.textContaining('Admin shaxsingizni alohida tekshirgandan keyin PINni tiklaydi'), findsOneWidget);
    expect(find.text('So‘rov yuborish'), findsOneWidget);
  });
}
