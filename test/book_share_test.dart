import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:muhajeerbooks/app_state.dart';
import 'package:muhajeerbooks/book_links.dart';
import 'package:muhajeerbooks/shared_book_entry.dart';
import 'package:muhajeerbooks/store_ui.dart';

const id = 'd6c1745a-4d94-4c19-8fa0-1c0852e37d97';

class TestCatalog extends AppState {
  TestCatalog() : super(backendConfigured: false);
  @override
  List<Book> get books => loading ? [] : const [Book(
    id: id, title: 'Ulashiladigan kitob', author: 'Muallif', category: 'Badiiy',
    description: 'Tavsif', price: 25000, stock: 3, discountPercent: 0,
    imageUrl: '', isActive: true,
  )];
  void finishLoading() { loading = false; notifyListeners(); }
}

void main() {
  test('shared link points to the public book without admin parameters', () {
    final link = bookShareLink(id);
    expect(link.scheme, 'https');
    expect(link.queryParameters, {'book': id});
    expect(link.fragment, isEmpty);
    expect(sharedBookId(link), id);
    expect(sharedBookId(Uri.parse('$bookShareOrigin/?book=invalid')), isNull);
    expect(sharedBookId(Uri.parse(bookShareOrigin)), isNull);
  });

  testWidgets('incoming link waits for catalog and Back returns to catalog', (tester) async {
    final state = TestCatalog();
    await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(
      value: state,
      child: MaterialApp(home: SharedBookEntry(
        uri: bookShareLink(id),
        child: const Scaffold(body: Text('Asosiy katalog')),
      )),
    ));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    state.finishLoading();
    await tester.pumpAndSettle();
    expect(find.byType(BookDetailPage), findsOneWidget);
    expect(find.text('Ulashiladigan kitob'), findsOneWidget);
    await tester.tap(find.byTooltip('Kitobni ulashish'));
    await tester.pumpAndSettle();
    expect(find.text('Havolani nusxalash'), findsOneWidget);
    expect(find.text('Telegram orqali yuborish'), findsOneWidget);
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.pop();
    await tester.pumpAndSettle();
    navigator.pop();
    await tester.pumpAndSettle();
    expect(find.text('Asosiy katalog'), findsOneWidget);
    state.notifyListeners();
    await tester.pumpAndSettle();
    expect(find.byType(BookDetailPage), findsNothing);
  });
}
