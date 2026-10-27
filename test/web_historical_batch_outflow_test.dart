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
  test('protected batch-line FIFO fields work without optional report', () {
    final lines=<Map<String,dynamic>>[
      {'id':1,'quantity':4,'fifo_outflow_units':3,'fifo_remaining_units':1},
      {'id':2,'quantity':6,'fifo_outflow_units':2,'fifo_remaining_units':4},
    ];
    final stats=historicalBatchOutflowEstimate(lines,const []);
    expect(stats,{'received':10,'outflow':5,'remaining':5});
    expect(estimatedBatchSoldLabel(stats!),
      'Taxminiy sotilgan: 5 / 10 dona • 50.0%');
  });

  test('one-decimal sold percentage visible on a collapsed batch card', () {
    expect(estimatedBatchSoldLabel(
      {'received':86,'outflow':14,'remaining':72}),
      'Taxminiy sotilgan: 14 / 86 dona • 16.3%');
    expect(estimatedBatchSoldLabel(
      {'received':127,'outflow':57,'remaining':70}),
      'Taxminiy sotilgan: 57 / 127 dona • 44.9%');
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
