const bookShareOrigin = 'https://muhajeer-books-live-production.up.railway.app';

// /share/<id> gives social crawlers the book preview, while real users are
// redirected by the share service to /?book=<id> so the exact book opens.
Uri bookShareLink(String id) =>
    Uri.parse(bookShareOrigin).replace(path: '/share/$id');

String? sharedBookId(Uri uri) {
  String? id = uri.queryParameters['book'];
  if ((id == null || id.isEmpty) &&
      uri.pathSegments.length == 2 &&
      uri.pathSegments.first == 'share') {
    id = uri.pathSegments[1];
  }
  if (id == null ||
      !RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')
          .hasMatch(id)) return null;
  return id.toLowerCase();
}
