// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:js_util' as js;

bool get nativeBookShareAvailable => js.hasProperty(html.window.navigator, 'share');

Future<void> nativeBookShare(String title, String url) async {
  await js.promiseToFuture<Object?>(js.callMethod(
    html.window.navigator, 'share', [js.jsify({'title': title, 'url': url})],
  ));
}
