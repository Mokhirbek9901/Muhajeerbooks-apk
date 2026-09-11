import 'dart:async';
import 'dart:html' as html;

final StreamController<void> _popController = StreamController<void>.broadcast();
bool _initialized = false;
bool _guardArmed = false;

bool get browserHistorySupported => true;

void _ensureInitialized() {
  if (_initialized) return;
  _initialized = true;
  html.window.onPopState.listen((_) {
    // Safari edge-swipe moved from our guard entry back to the app entry.
    // Do not reload/navigate the document. Flutter will pop its own route and,
    // when needed, re-arm the guard for the next internal back gesture.
    _guardArmed = false;
    if (!_popController.isClosed) _popController.add(null);
  });
}

Stream<void> get browserPopEvents {
  _ensureInitialized();
  return _popController.stream;
}

void pushBrowserHistoryEntry() {
  _ensureInitialized();
  if (_guardArmed) return;
  try {
    // Keep both entries on the exact same document/URL. The first entry is the
    // stable app state, the second is a lightweight Safari back-swipe guard.
    // We intentionally keep only ONE guard regardless of Flutter route depth.
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
  } catch (_) {
    // History sync must never block navigation.
  }
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
  } catch (_) {
    // Safari/browser history is best effort only.
  }
}

void backBrowserHistoryEntry() {
  // Intentionally no-op.
  // Flutter's own back button must NOT move browser history; moving both was
  // the source of Safari reloads / returning to the top of the catalogue.
}
