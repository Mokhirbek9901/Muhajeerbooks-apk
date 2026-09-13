import 'dart:js_interop';

@JS('navigator.share')
external JSFunction? get _shareFunction;

@JS('navigator.share')
external JSPromise<JSAny?> _share(JSObject data);

bool get nativeBookShareAvailable => _shareFunction != null;

Future<void> nativeBookShare(String title, String url) async {
  await _share({'title': title, 'url': url}.jsify() as JSObject).toDart;
}
