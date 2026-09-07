from pathlib import Path

p = Path('lib/app_state.dart')
s = p.read_text(encoding='utf-8')

if "import 'dart:async';" not in s:
    s = s.replace("import 'dart:convert';\n", "import 'dart:async';\nimport 'dart:convert';\n", 1)

needle = "  BackendService? _backend;\n"
if "_booksRealtime" not in s:
    assert needle in s, 'BackendService field not found'
    s = s.replace(
        needle,
        needle + "  StreamSubscription<List<Map<String, dynamic>>>? _booksRealtime;\n",
        1,
    )

old_init = """    if (_backend == null) {
      await _initializeLocalCatalog();
    } else {
      await refreshBooks();
    }
  }

  Future<void> _initializeLocalCatalog() async {
"""
new_init = """    if (_backend == null) {
      await _initializeLocalCatalog();
    } else {
      await refreshBooks();
      _startBooksRealtime();
    }
  }

  void _startBooksRealtime() {
    _booksRealtime?.cancel();
    _booksRealtime = Supabase.instance.client
        .from('books')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .listen(
          (rows) {
            final next = rows
                .map((e) => Book.fromMap(Map<String, dynamic>.from(e)))
                .where((b) => b.isActive)
                .toList();
            _books
              ..clear()
              ..addAll(next);
            _sanitizeCart();
            loading = false;
            error = null;
            notifyListeners();
          },
          onError: (Object e) {
            error = e.toString();
            notifyListeners();
          },
        );
  }

  @override
  void dispose() {
    _booksRealtime?.cancel();
    super.dispose();
  }

  Future<void> _initializeLocalCatalog() async {
"""

if "void _startBooksRealtime()" not in s:
    assert old_init in s, 'initialize block not found'
    s = s.replace(old_init, new_init, 1)

p.write_text(s, encoding='utf-8')
