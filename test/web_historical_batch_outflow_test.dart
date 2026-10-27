import 'package:flutter_test/flutter_test.dart';
import 'package:muhajeerbooks/web_batch_history_pro.dart';

void main() {
  test('historical receipt includes FIFO outflow, not another stock debit', () {
    final lines=<Map<String,dynamic>>[
      {'id':65,'quantity':2,'book_id':'uzrnoma'},
      {'id':66,'quantity':4,'book_id':'previously-sold'},
    ];
    final lots=<Map<String,dynamic>>[
      {'id':65,'estimated_sold_units':0,'estimated_remaining_units':2},
      {'id':66,'estimated_sold_units':4,'estimated_remaining_units':0},
    ];
    expect(historicalBatchOutflowEstimate(lines,lots),
      {'received':6,'outflow':4,'remaining':2});
    // Caller must never mutate catalogue stock; only read the projection.
    expect(lines[1]['quantity'],4);
  });
  test('incomplete historical batches never display partial totals as exact', () {
    final lines=<Map<String,dynamic>>[
      {'id':1,'quantity':2},{'id':2,'quantity':3}];
    final lots=<Map<String,dynamic>>[
      {'id':1,'estimated_sold_units':1,'estimated_remaining_units':1}];
    expect(historicalBatchOutflowEstimate(lines,lots),isNull);
  });
  test('inconsistent sales estimates are rejected instead of invented', () {
    final lines=<Map<String,dynamic>>[{'id':1,'quantity':3}];
    final lots=<Map<String,dynamic>>[
      {'id':1,'estimated_sold_units':4,'estimated_remaining_units':0}];
    expect(historicalBatchOutflowEstimate(lines,lots),isNull);
  });
}
