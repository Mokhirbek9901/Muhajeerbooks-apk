from pathlib import Path

path = Path('lib/store_ui.dart')
text = path.read_text(encoding='utf-8')

provider_import = "import 'package:provider/provider.dart';\n"
shared_import = "import 'package:shared_preferences/shared_preferences.dart';\n"
if shared_import not in text:
    if provider_import not in text:
        raise SystemExit('provider import marker not found')
    text = text.replace(provider_import, provider_import + shared_import, 1)

if 'class _PersistentScrollController extends ScrollController' not in text:
    marker = "String won(int value) => '₩${_money.format(value)}';\n"
    helper = r'''

final Map<String, double> _scrollMemory = <String, double>{};

/// iPhone/Safari browser-back yoki web sahifa qayta tiklanganda foydalanuvchini
/// ro‘yxat boshiga tashlamaydi. Xotirada darhol, SharedPreferences'da esa
/// reload'lar orasida scroll joyini saqlaydi.
class _PersistentScrollController extends ScrollController {
  _PersistentScrollController(this.storageKey)
      : super(initialScrollOffset: _scrollMemory[storageKey] ?? 0) {
    addListener(_capture);
    unawaited(_loadSaved());
  }

  final String storageKey;
  Timer? _saveTimer;
  double? _pendingRestore;
  int _restoreAttempts = 0;
  bool _restoring = false;
  bool _userMoved = false;
  bool _disposed = false;

  void _capture() {
    if (_disposed || _restoring || !hasClients) return;
    final value = offset < 0 ? 0.0 : offset;
    _userMoved = true;
    _scrollMemory[storageKey] = value;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 90), () {
      unawaited(_write(value));
    });
  }

  Future<void> _write(double value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('scroll:$storageKey', value);
    } catch (_) {
      // Scroll xotirasi asosiy ilovani bloklamaydi.
    }
  }

  Future<void> _loadSaved() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getDouble('scroll:$storageKey');
      if (_disposed || _userMoved || saved == null || saved <= 0) return;
      _scrollMemory[storageKey] = saved;
      _pendingRestore = saved;
      _scheduleRestore();
    } catch (_) {
      // Browser storage ishlamasa in-memory holatning o‘zi ishlaydi.
    }
  }

  @override
  void attach(ScrollPosition position) {
    super.attach(position);
    _scheduleRestore();
  }

  void _scheduleRestore() {
    if (_disposed || _pendingRestore == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_disposed || _pendingRestore == null) return;
      if (!hasClients || !position.hasContentDimensions) {
        _retryRestore();
        return;
      }

      final target = _pendingRestore!;
      final max = position.maxScrollExtent;
      // Katalog hali fon rejimida kelayotgan bo‘lsa, kontent yetarlicha
      // uzunlashguncha tepaga clamp qilib yubormasdan biroz kutamiz.
      if (max + 4 < target && _restoreAttempts < 30) {
        _retryRestore();
        return;
      }

      _restoring = true;
      jumpTo(target.clamp(0.0, max).toDouble());
      _restoring = false;
      _pendingRestore = null;
      _restoreAttempts = 0;
    });
  }

  void _retryRestore() {
    if (_disposed || _pendingRestore == null || _restoreAttempts++ >= 30) {
      return;
    }
    Future<void>.delayed(
      const Duration(milliseconds: 100),
      _scheduleRestore,
    );
  }

  @override
  void dispose() {
    _disposed = true;
    _saveTimer?.cancel();
    if (hasClients) {
      final value = offset < 0 ? 0.0 : offset;
      _scrollMemory[storageKey] = value;
      unawaited(_write(value));
    }
    removeListener(_capture);
    super.dispose();
  }
}
'''
    if marker not in text:
        raise SystemExit('money marker not found')
    text = text.replace(marker, marker + helper, 1)

old_home = "final ScrollController _scrollController = ScrollController();"
new_home = "final ScrollController _scrollController = _PersistentScrollController('home');"
if old_home in text:
    text = text.replace(old_home, new_home, 1)
elif new_home not in text:
    raise SystemExit('home controller marker not found')

# Category/publisher kitob ro‘yxatidan detailga kirib qaytganda ham ayni joyda
# qolishi uchun GridView'ga alohida persistent controller qo‘shamiz.
old_grid = """          : GridView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              itemCount: books.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: .57,
              ),
              itemBuilder: (_, i) => BookCard(book: books[i]),
            ),
"""
new_grid = """          : _PersistentBookGrid(
              storageKey: 'browse:${publisher ?? category}',
              books: books,
            ),
"""
if old_grid in text:
    text = text.replace(old_grid, new_grid, 1)
elif "storageKey: 'browse:${publisher ?? category}'" not in text:
    raise SystemExit('category grid marker not found')

if 'class _PersistentBookGrid extends StatefulWidget' not in text:
    marker = "\nIconData _categoryIcon(String value) {"
    widget = r'''

class _PersistentBookGrid extends StatefulWidget {
  const _PersistentBookGrid({required this.storageKey, required this.books});

  final String storageKey;
  final List<Book> books;

  @override
  State<_PersistentBookGrid> createState() => _PersistentBookGridState();
}

class _PersistentBookGridState extends State<_PersistentBookGrid> {
  late final ScrollController _controller =
      _PersistentScrollController(widget.storageKey);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GridView.builder(
        controller: _controller,
        key: PageStorageKey<String>('grid:${widget.storageKey}'),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        itemCount: widget.books.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: .57,
        ),
        itemBuilder: (_, i) => BookCard(book: widget.books[i]),
      );
}
'''
    if marker not in text:
        raise SystemExit('category icon marker not found')
    text = text.replace(marker, widget + marker, 1)

path.write_text(text, encoding='utf-8')
print('Persistent iPhone/web scroll restoration applied.')
