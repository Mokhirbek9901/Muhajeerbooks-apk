import 'package:flutter/foundation.dart';

/// Consolidate only the *visible* expense rows. This deliberately never
/// changes finance records or the financial report used by profit charts.
/// In particular, partial date filters retain exactly their original sums.
@visibleForTesting
List<Map<String, dynamic>> consolidatedFinanceDisplayRows({
  required List<Map<String, dynamic>> rows,
  required List<Map<String, dynamic>> purchases,
  required List<Map<String, dynamic>> transports,
}) {
  final groups = <String, List<Map<String, dynamic>>>{};
  for (final purchase in purchases) {
    final key = (purchase['finance_group_id'] ?? '').toString();
    if (key.isNotEmpty && key != 'null') {
      groups.putIfAbsent(key, () => []).add(purchase);
    }
  }

  final remaining = rows.map((e) => Map<String, dynamic>.from(e)).toList();
  for (final group in groups.values) {
    if (group.length < 2) continue;
    final purchaseIds = group
        .map((e) => (e['finance_expense_id'] ?? '').toString())
        .where((id) => id.isNotEmpty && id != 'null')
        .toSet();
    final importIds = group.map((e) => (e['id'] ?? '').toString()).toSet();
    final transportIds = transports
        .where((e) => importIds.contains((e['batch_import_id'] ?? '').toString()))
        .map((e) => (e['id'] ?? '').toString())
        .toSet();

    final ids = {...purchaseIds, ...transportIds};
    final visible = remaining.where(
      (e) => ids.contains((e['id'] ?? '').toString()),
    ).toList();
    // One original row is never replaced by a synthetic total.
    if (visible.length < 2) continue;
    final firstIndex = remaining.indexWhere(
      (e) => ids.contains((e['id'] ?? '').toString()),
    );
    if (firstIndex < 0) continue;
    final amount = visible.fold<int>(0, (sum, e) {
      final value = e['amount'];
      return sum + (value is num ? value.round() : int.tryParse('$value') ?? 0);
    });
    final purchaseCount = visible.where(
      (e) => (e['category'] ?? '') == 'inventory_purchase',
    ).length;
    final transportCount = visible.where(
      (e) => (e['category'] ?? '') == 'transport',
    ).length;
    final title = (group.first['finance_group_title'] ?? 'Birlashgan partiya')
        .toString();
    final date = (group.first['finance_group_date'] ??
        visible.first['expense_date']).toString();
    remaining.removeWhere((e) => ids.contains((e['id'] ?? '').toString()));
    remaining.insert(firstIndex < remaining.length ? firstIndex : remaining.length, {
      'id': 'finance-display-group:${group.first['finance_group_id']}',
      'category': 'inventory_purchase',
      'expense_date': date,
      'amount': amount,
      'note': '$title · $purchaseCount ta kitob xaridi'
          '${transportCount > 0 ? " + $transportCount ta transport" : ""}',
      'source': 'system',
      '_consolidated_display_only': true,
    });
  }
  return remaining;
}
