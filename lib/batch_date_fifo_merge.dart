/// Merge the *read-only* date-based FIFO allocation with the existing
/// profit projection. The original recognized sales and their frozen unit
/// costs are not rewritten. Revenue for legacy imported sales is unknown.
Map<String, dynamic> withDatedFifoAllocation(
  Map<String, dynamic> report,
  Map<String, dynamic> dated,
) {
  if (dated['allocation_method'] != 'dated_fifo_sales' ||
      dated['lots'] is! List) return report;

  int number(dynamic value) => value is num
      ? value.toInt() : int.tryParse((value ?? '').toString()) ?? 0;

  final datedLots = <String, Map<String, dynamic>>{};
  for (final entry in dated['lots'] as List) {
    if (entry is Map && entry['id'] != null) {
      datedLots[entry['id'].toString()] = Map<String, dynamic>.from(entry);
    }
  }

  final allLots = <Map<String, dynamic>>[];
  final totals = <String, Map<String, int>>{};
  for (final raw in (report['lots'] as List? ?? const [])) {
    if (raw is! Map) continue;
    final lot = Map<String, dynamic>.from(raw);
    final allocation = datedLots[lot['id'].toString()];
    if (allocation != null) {
      final qty = number(lot['quantity']);
      final sold = number(allocation['fifo_outflow_units']);
      if (sold < 0 || sold > qty) return report;
      lot['estimated_sold_units'] = sold;
      lot['estimated_remaining_units'] = qty - sold;
      lot['date_fifo_applied'] = true;
      for (final name in [
        'dated_order_sales_units', 'dated_legacy_sales_units',
        'dated_order_revenue', 'dated_lot_cost',
        'dated_order_gross_profit',
      ]) {
        lot[name] = number(allocation[name]);
      }
      final key = (lot['group_key'] ?? '').toString();
      final groupTotals = totals.putIfAbsent(key, () => {
        'sold': 0,
        'remaining': 0,
        'known_units': 0,
        'legacy_units': 0,
        'known_revenue': 0,
        'lot_cost': 0,
        'known_profit': 0,
      });
      groupTotals['sold'] = groupTotals['sold']! + sold;
      groupTotals['remaining'] = groupTotals['remaining']! + qty - sold;
      groupTotals['known_units'] = groupTotals['known_units']! +
          number(allocation['dated_order_sales_units']);
      groupTotals['legacy_units'] = groupTotals['legacy_units']! +
          number(allocation['dated_legacy_sales_units']);
      groupTotals['known_revenue'] = groupTotals['known_revenue']! +
          number(allocation['dated_order_revenue']);
      groupTotals['lot_cost'] = groupTotals['lot_cost']! +
          number(allocation['dated_lot_cost']);
      groupTotals['known_profit'] = groupTotals['known_profit']! +
          number(allocation['dated_order_gross_profit']);
    }
    allLots.add(lot);
  }

  final groups = <Map<String, dynamic>>[];
  for (final raw in (report['groups'] as List? ?? const [])) {
    if (raw is! Map) continue;
    final group = Map<String, dynamic>.from(raw);
    final sums = totals[(group['group_key'] ?? '').toString()];
    if (sums != null && group['missing_lot_details'] != true) {
      final received = number(group['purchased_units']);
      group['estimated_sold_units'] = sums['sold'];
      group['estimated_remaining_units'] = sums['remaining'];
      group['estimated_sold_percent'] = received > 0
          ? double.parse((sums['sold']! * 100 / received).toStringAsFixed(1))
          : 0.0;
      group['date_fifo_applied'] = true;
      group['dated_order_sales_units'] = sums['known_units'];
      group['dated_legacy_sales_units'] = sums['legacy_units'];
      group['dated_order_revenue'] = sums['known_revenue'];
      group['dated_lot_cost'] = sums['lot_cost'];
      group['dated_order_gross_profit'] = sums['known_profit'];
    }
    groups.add(group);
  }

  return {
    ...report,
    'lots': allLots,
    'groups': groups,
    'date_fifo_applied': true,
    'allocation_method': 'dated_fifo_sales',
    'dated_fifo_unmatched_sales': number(dated['unmatched_sold_units']),
    'dated_fifo_unknown_titles': number(dated['unknown_book_units']),
    'dated_fifo_legacy_sales': number(dated['legacy_matched_units']),
  };
}
