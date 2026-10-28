import 'package:flutter_test/flutter_test.dart';
import 'package:muhajeerbooks/batch_date_fifo_merge.dart';

void main() {
  Map<String, dynamic> base() => {
    'groups': [
      {'group_key':'old','purchased_units':10,'estimated_sold_units':1,
       'estimated_remaining_units':9,'projected_profit':50000},
      {'group_key':'new','purchased_units':10,'estimated_sold_units':0,
       'estimated_remaining_units':10,'projected_profit':60000},
    ],
    'lots': [
      {'id':1,'group_key':'old','quantity':10,
       'estimated_sold_units':1,'estimated_remaining_units':9},
      {'id':2,'group_key':'new','quantity':10,
       'estimated_sold_units':0,'estimated_remaining_units':10},
    ],
  };

  test('9 old sales, new delivery, 1 more old sale, then new lot', () {
    final original = base();
    final result=withDatedFifoAllocation(original, {
      'allocation_method':'dated_fifo_sales',
      'unmatched_sold_units':0,
      'unknown_book_units':0,
      'legacy_matched_units':0,
      'lots':[
        {'id':1,'fifo_outflow_units':10,'dated_order_sales_units':10,
         'dated_legacy_sales_units':0,'dated_order_revenue':170000,
         'dated_lot_cost':100000,'dated_order_gross_profit':70000},
        {'id':2,'fifo_outflow_units':1,'dated_order_sales_units':1,
         'dated_legacy_sales_units':0,'dated_order_revenue':17000,
         'dated_lot_cost':12000,'dated_order_gross_profit':5000},
      ],
    });
    final groups=(result['groups'] as List).cast<Map<String,dynamic>>();
    expect(groups[0]['estimated_sold_units'],10);
    expect(groups[0]['estimated_remaining_units'],0);
    expect(groups[1]['estimated_sold_units'],1);
    expect(groups[1]['estimated_remaining_units'],9);
    expect(groups[0]['dated_order_gross_profit'],70000);
    expect(groups[1]['dated_order_gross_profit'],5000);
    // Potential profit and historical accounting snapshot remain unchanged.
    expect(groups[0]['projected_profit'],50000);
    expect((original['groups'] as List).first['estimated_sold_units'],1);
  });

  test('legacy sales count but no invented legacy revenue', () {
    final result=withDatedFifoAllocation(base(),{
      'allocation_method':'dated_fifo_sales',
      'lots':[
        {'id':1,'fifo_outflow_units':5,
         'dated_order_sales_units':3,'dated_legacy_sales_units':2,
         'dated_order_revenue':51000,
         'dated_lot_cost':30000,'dated_order_gross_profit':21000},
        {'id':2,'fifo_outflow_units':0,'dated_order_sales_units':0,
         'dated_legacy_sales_units':0,
         'dated_order_revenue':0,'dated_lot_cost':0,
         'dated_order_gross_profit':0},
      ],
    });
    final g=(result['groups'] as List).first as Map;
    expect(g['estimated_sold_units'],5);
    expect(g['dated_order_sales_units'],3);
    expect(g['dated_legacy_sales_units'],2);
    expect(g['dated_order_gross_profit'],21000);
  });

  test('no backend result leaves previous report untouched', () {
    final original=base();
    expect(identical(withDatedFifoAllocation(original,{}),original),true);
  });

  test('invalid overallocations are rejected, never negative stock', () {
    final original=base();
    final merged=withDatedFifoAllocation(original,{
      'allocation_method':'dated_fifo_sales',
      'lots':[{'id':1,'fifo_outflow_units':11}],
    });
    expect(identical(merged,original),true);
  });
}
