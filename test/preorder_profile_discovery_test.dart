import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:muhajeerbooks/app_state.dart';
import 'package:muhajeerbooks/preorder_balance_page.dart';

class _MockCustomerPreorders extends AppState {
  _MockCustomerPreorders(this.discovered)
      : super(backendConfigured: false);
  final List<Map<String, dynamic>> discovered;

  @override
  Future<List<Map<String, dynamic>>> releasePreorders() async => discovered.map((row) => Map<String, dynamic>.from(row)).toList();
}

void main() {
  testWidgets('legacy web preorder found by profile contact appears on preorder page',
      (tester) async {
    await tester.pumpWidget(ChangeNotifierProvider<AppState>(
      create: (_) => _MockCustomerPreorders([
        {
          'source': 'web',
          'ownership': 'contact',
          'id': 'fabb4d3a-fd96-470a-bcc8-738f59ce157d',
          'title': 'Sinov kitobi',
          'status': 'arrived',
          'quantity': 1,
          'created_at': '2026-10-23T12:14:20Z',
        }
      ]),
      child: const MaterialApp(
        home: CustomerPreorderBalancesPage(),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Sinov kitobi'), findsOneWidget);
    expect(find.textContaining('Web oldindan zakaz'), findsOneWidget);
    expect(find.textContaining('Kitob keldi'), findsWidgets);
    expect(find.textContaining('asl qurilmada'), findsOneWidget);
    expect(find.textContaining('Qolgan to‘lov chekini yuborish'), findsNothing);
  });

  testWidgets('notification focus places matching preorder before older records',
      (tester) async {
    await tester.pumpWidget(ChangeNotifierProvider<AppState>(
      create: (_) => _MockCustomerPreorders([
        {
          'source': 'web', 'ownership': 'device', 'id': 'other',
          'title': 'Boshqa kitob', 'status': 'waiting', 'quantity': 1,
          'created_at': '2026-10-23T18:00:00Z',
        },
        {
          'source': 'web', 'ownership': 'contact', 'id': 'focus',
          'title': 'Xabar orqali ochilgan', 'status': 'accepted', 'quantity': 1,
          'created_at': '2026-10-22T17:00:00Z',
        },
      ]),
      child: const MaterialApp(
        home: CustomerPreorderBalancesPage(focusPreorderId: 'focus'),
      ),
    ));
    await tester.pumpAndSettle();
    final target = tester.getTopLeft(find.text('Xabar orqali ochilgan'));
    final other = tester.getTopLeft(find.text('Boshqa kitob'));
    expect(target.dy, lessThan(other.dy));
  });
}
