import 'dart:async';
import 'dart:html' as html;

final StreamController<void> _popController = StreamController<void>.broadcast();
bool _initialized = false;
bool _guardArmed = false;

bool get browserHistorySupported => true;

void _emitBackRequest() {
  if (!_popController.isClosed) _popController.add(null);
}

void _ensureInitialized() {
  if (_initialized) return;
  _initialized = true;

  html.window.onPopState.listen((_) {
    _guardArmed = false;
    _emitBackRequest();
  });

  html.window.addEventListener('muhajeer-swipe-back', (html.Event _) {
    _emitBackRequest();
  });
}

Stream<void> get browserPopEvents {
  _ensureInitialized();
  return _popController.stream;
}

void setBrowserBackSwipeEnabled(bool enabled) {
  _ensureInitialized();
  final root = html.document.documentElement;
  if (root == null) return;
  root.setAttribute('data-muhajeer-can-pop', enabled ? '1' : '0');
}

void pushBrowserHistoryEntry() {
  _ensureInitialized();
  if (_guardArmed) return;
  try {
    html.window.history.replaceState(
      <String, dynamic>{'muhajeer_app': true},
      html.document.title,
      html.window.location.href,
    );
    html.window.history.pushState(
      <String, dynamic>{'muhajeer_guard': true},
      html.document.title,
      html.window.location.href,
    );
    _guardArmed = true;
  } catch (_) {}
}

void restoreBrowserHistoryGuard() {
  _ensureInitialized();
  if (_guardArmed) return;
  try {
    html.window.history.pushState(
      <String, dynamic>{'muhajeer_guard': true},
      html.document.title,
      html.window.location.href,
    );
    _guardArmed = true;
  } catch (_) {}
}

void backBrowserHistoryEntry() {
  // Intentionally no-op. Flutter back must not also move browser history.
}
