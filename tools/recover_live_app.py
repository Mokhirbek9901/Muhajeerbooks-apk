from pathlib import Path

path = Path('lib/app_state.dart')
s = path.read_text(encoding='utf-8')

if "static const _booksKey = 'muhajeer_books_v3';" in s:
    s = s.replace(
        "static const _booksKey = 'muhajeer_books_v3';",
        "static const _booksKey = 'muhajeer_books_v4';",
        1,
    )

old_quiet = """      _books
        ..clear()
        ..addAll(fresh);
      _sanitizeCart();
      notifyListeners();"""
new_quiet = """      _books
        ..clear()
        ..addAll(fresh);
      await _local.saveBooks(_books);
      _sanitizeCart();
      notifyListeners();"""
if old_quiet in s:
    s = s.replace(old_quiet, new_quiet, 1)

old_refresh = """      if (_backend != null) {
        _books
          ..clear()
          ..addAll(
            await _backend!.fetchBooks(includeInactive: includeInactive),
          );
      } else {
        _books
          ..clear()
          ..addAll(await _local.loadBooks());
      }
      _sanitizeCart();
    } catch (e) {
      error = e.toString();
    } finally {"""
new_refresh = """      if (_backend != null) {
        final fresh = await _backend!.fetchBooks(includeInactive: includeInactive);
        _books
          ..clear()
          ..addAll(fresh);
        await _local.saveBooks(_books);
      } else {
        _books
          ..clear()
          ..addAll(await _local.loadBooks());
      }
      _sanitizeCart();
    } catch (e) {
      error = e.toString();
      if (_books.isEmpty) {
        final cached = await _local.loadBooks();
        if (cached.isNotEmpty) {
          _books
            ..clear()
            ..addAll(cached);
          _sanitizeCart();
        }
      }
    } finally {"""
if old_refresh not in s:
    raise SystemExit('refreshBooks block not found')
s = s.replace(old_refresh, new_refresh, 1)

path.write_text(s, encoding='utf-8')
print('Live catalog recovery applied')
