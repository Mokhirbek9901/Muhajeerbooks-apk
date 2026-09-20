const bookShareOrigin = 'https://muhajeer-books-live-production.up.railway.app';

// /share/<id> keeps social previews rich; a real tap is redirected to
// /?book=<id>, where the storefront opens that exact book directly.
Uri bookShareLink(String id) =>
    Uri.parse(bookShareOrigin).replace(path: '/share/$id');

Uri bundleShareLink(String id) =>
    Uri.parse(bookShareOrigin).replace(queryParameters: {'bundle': id});

bool _validShareId(String? id) =>
    id != null &&
    RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    ).hasMatch(id);

String? sharedBundleId(Uri uri) {
  final id = uri.queryParameters['bundle'];
  return _validShareId(id) ? id!.toLowerCase() : null;
}

String? sharedBookId(Uri uri) {
  String? id = uri.queryParameters['book'];
  if ((id == null || id.isEmpty) &&
      uri.pathSegments.length == 2 &&
      uri.pathSegments.first == 'share') {
    id = uri.pathSegments[1];
  }
  return _validShareId(id) ? id!.toLowerCase() : null;
}

// Release marker: admin Kitoblar now includes the Tarifsiz description filter.
