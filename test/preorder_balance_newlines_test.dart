import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:muhajeerbooks/app_state.dart';
import 'package:muhajeerbooks/preorder_balance_page.dart';

class _PreorderTestState extends AppState {
  _PreorderTestState() : super(backendConfigured: false);

  @override
  Future<List<Map<String, dynamic>>> releasePreorders() async => [
        <String, dynamic>{
          'id': 'a1b2c3d4-e5f6-47e8-9a01-123456789abc',
          'source': 'web',
          'title': 'O‘smir (Dostoyevskiy)',
          'status': 'arrived',
          'deposit_credit': 5000,
          'amount_due': 23000,
          'refund_due': 0,
          'created_at': '2026-11-03T09:00:00Z',
        },
      ];
}

void main() {
  testWidgets('preorder card shows readable separate lines, not literal backslash n',
      (tester) async {
    final state = _PreorderTestState();
    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: state,
        child: const MaterialApp(home: CustomerPreorderBalancesPage()),
      ),
    );
    await tester.pumpAndSettle();

    final subtitles = tester
        .widgetList<Text>(find.byType(Text))
        .map((text) => text.data ?? '')
        .where((text) => text.startsWith('Web oldindan zakaz'))
        .toList();

    expect(subtitles, hasLength(1));
    final subtitle = subtitles.single;
    expect(subtitle, contains('Web oldindan zakaz\nHolat: Kitob keldi\n'));
    expect(subtitle, contains('Avans: ₩5,000\nQolgan to‘lov: ₩23,000\n'));
    expect(subtitle, contains('Qaytariladigan pul: ₩0'));
    expect(subtitle, isNot(contains(r'\n')));
  });
}
