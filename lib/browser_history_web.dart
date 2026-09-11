import 'dart:async';
import 'dart:html' as html;

final StreamController<void> _popController = StreamController<void>.broadcast();
bool _initialized = false;
int _historySerial = 0;

bool get browserHistorySupported => true;

void _ensureInitialized() {
  if (_initialized) return;
  _initialized = true;
  html.window.onPopState.listen((_) {
    if (!_popController.isClosed) _popController.add(null);
  });
}

Stream<void> get browserPopEvents {
  _ensureInitialized();
  return _popController.stream;
}

void pushBrowserHistoryEntry() {
  _ensureInitialized();
  try {
    _historySerial += 1;
    final uri = Uri.parse(html.window.location.href);
    final base = uri.replace(fragment: '').toString();
    html.window.history.pushState(
      <String, dynamic>{
        'muhajeer_internal': true,
        'muhajeer_serial': _historySerial,
      },
      html.document.title,
      '$base#mb-$_historySerial',
    );
  } catch (_) {
    // History sync must never block navigation.
  }
}

void backBrowserHistoryEntry() {
  _ensureInitialized();
  try {
    html.window.history.back();
  } catch (_) {
    // Browser back is best effort only.
  }
}
