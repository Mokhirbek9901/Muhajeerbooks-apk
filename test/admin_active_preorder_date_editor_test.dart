import 'package:flutter_test/flutter_test.dart';
import 'package:muhajeerbooks/admin_ui.dart';

void main() {
  test('managed advance-sale dates take precedence over catalog note', () {
    final source = <String, dynamic>{
      'date': '2026-11-17',
      'end_date': '2026-11-21',
    };
    final start = preorderActiveDate('7~10-noyabr', source, end: false)!;
    final end = preorderActiveDate('7~10-noyabr', source, end: true)!;
    expect([start.year, start.month, start.day], [2026, 11, 17]);
    expect([end.year, end.month, end.day], [2026, 11, 21]);
  });

  test('reads date ranges added through the catalog independently', () {
    const note = '2026-11-08 ~ 2026-11-12';
    expect(preorderActiveDate(note, null, end: false)!.day, 8);
    expect(preorderActiveDate(note, null, end: true)!.day, 12);
  });

  test('unstructured old ETA does not silently become a false date', () {
    expect(preorderActiveDate('7~10-noyabr', null, end: false), isNull);
    expect(preorderActiveDate('', null, end: true), isNull);
  });
}
