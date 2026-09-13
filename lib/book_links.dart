const bookShareOrigin = 'https://muhajeer-books-live-production.up.railway.app';

Uri bookShareLink(String id) =>
    Uri.parse(bookShareOrigin).replace(path: '/', queryParameters: {'book': id});

String? sharedBookId(Uri uri) {
  final id = uri.queryParameters['book'];
  if (id == null ||
      !RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')
          .hasMatch(id)) return null;
  return id.toLowerCase();
}
