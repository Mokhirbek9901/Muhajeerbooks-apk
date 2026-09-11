import 'dart:async';
import 'dart:html' as html;

final StreamController<void> _popController = StreamController<void>.broadcast();
bool _initialized = false;

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
    html.window.history.pushState(
      <String, dynamic>{'muhajeer_internal': true},
      html.document.title,
      html.window.location.href,
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
