import 'package:flutter/material.dart';
import 'book_links.dart';
import 'store_ui.dart';
import 'design_system.dart';

/// Keep the storefront underneath so Back returns to the catalog.
class SharedBookEntry extends StatefulWidget {
  const SharedBookEntry({super.key, required this.child, required this.uri});
  final Widget child;
  final Uri uri;
  @override
  State<SharedBookEntry> createState() => _SharedBookEntryState();
}

class _SharedBookEntryState extends State<SharedBookEntry> {
  @override
  void initState() {
    super.initState();
    final id = sharedBookId(widget.uri);
    if (id != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context).push(muhajeerPageRoute<void>(
          settings: RouteSettings(name: 'mb:book:$id'),
          builder: (_) => BookDetailPage(bookId: id),
        ));
      });
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
