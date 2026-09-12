import 'dart:async';

bool get browserHistorySupported => false;
Stream<void> get browserPopEvents => const Stream<void>.empty();
void setBrowserBackSwipeEnabled(bool enabled) {}
void pushBrowserHistoryEntry() {}
void restoreBrowserHistoryGuard() {}
void backBrowserHistoryEntry() {}
