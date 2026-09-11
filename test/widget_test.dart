import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muhajeerbooks/main.dart';

void main() {
  test('Muhajeer Books app can be created in demo mode', () {
    final app = MuhajeerBooksApp(backendConfigured: false);
    expect(app, isA<Widget>());
  });
}
