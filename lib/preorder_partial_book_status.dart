/// Read-only view of books not included in received partial preorder batches.
/// Never changes payments, inventory, or the original request.
/// Each row: index, title, remaining_quantity, reported_quantity, unreported_quantity.
List<Map<String, dynamic>> preorderMissingBookRows(
  Map<String, dynamic> detail,
) {
  int qty(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;

  final originals = (detail['original_items'] as List? ?? const [])
      .whereType<Map>().toList();
  final batches = (detail['batches'] as List? ?? const [])
      .whereType<Map>();
  final marks = (detail['missing_items'] as List? ?? const [])
      .whereType<Map>();

  final arrived = <int, int>{};
  for (final batch in batches) {
    if (batch['status'] == 'cancelled') continue;
    for (final raw in (batch['items'] as List? ?? const [])) {
      if (raw is! Map) continue;
      final index = qty(raw['index']);
      arrived[index] = (arrived[index] ?? 0) + qty(raw['quantity']);
    }
  }
  final reported = <int, int>{};
  for (final mark in marks) {
    final index = qty(mark['index']);
    reported[index] = (reported[index] ?? 0) + qty(mark['quantity']);
  }

  final rows = <Map<String, dynamic>>[];
  for (var i = 0; i < originals.length; i++) {
    final raw = originals[i];
    final ordered = qty(raw['quantity']);
    final left = (ordered - (arrived[i] ?? 0)).clamp(0, 100000).toInt();
    if (left <= 0) continue;
    final alreadyNotified = (reported[i] ?? 0).clamp(0, left).toInt();
    rows.add({
      'index': i,
      'title': (raw['book_title'] ?? raw['title'] ?? 'Kitob').toString(),
      'remaining_quantity': left,
      'reported_quantity': alreadyNotified,
      'unreported_quantity': left - alreadyNotified,
    });
  }
  return rows;
}
