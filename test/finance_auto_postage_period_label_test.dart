import 'package:flutter_test/flutter_test.dart';
import 'package:muhajeerbooks/finance_admin.dart';

void main() {
  test('automatic postage never presents report end as expense date', () {
    final system = <String, dynamic>{
      'category': 'postage',
      'amount': 8000,
      'note': 'Do‘kon hisobidan pochta (avtomatik hisob)',
      'source': 'system',
      '_system': true,
    };
    final november30 = financeExpenseHistorySubtitle(
      system, DateTime(2026, 11, 30));
    final november7 = financeExpenseHistorySubtitle(
      system, DateTime(2026, 11, 7));
    expect(november30, november7);
    expect(november30, contains('Tanlangan davr bo‘yicha hisob'));
    expect(november30, contains('Avtomatik hisoblangan'));
    expect(november30, isNot(contains('30.11.2026')));
    expect(november30, isNot(contains('Admin ilovadan kiritilgan')));
  });

  test('real admin expenses keep their actual expense dates', () {
    final record = <String,dynamic>{
      'note': 'Instagram', 'source': 'admin',
    };
    expect(
      financeExpenseHistorySubtitle(record, DateTime(2026,11,7)),
      contains('07.11.2026'),
    );
    expect(
      financeExpenseHistorySubtitle(record, DateTime(2026,11,7)),
      contains('Admin ilovadan kiritilgan'),
    );
  });

  test('Telegram real expenses retain their original source', () {
    expect(
      financeExpenseHistorySubtitle(
        {'source':'telegram','note':'Transport'},
        DateTime(2026,11,6),
      ),
      contains('Telegramdan kiritilgan'),
    );
  });
}
