import 'package:flutter_test/flutter_test.dart';
import 'package:muhajeerbooks/web_batch_add_picker.dart';

void main() {
  test('New batch automatically snapshots catalog unit cost at selection', () {
    const initialCatalogCost=10000;
    final octoberBatch=batchLineSnapshotPayload(
      bookId:'same-book',quantity:5,unitCost:initialCatalogCost,
      manuallyEdited:false);
    // Catalog changes later, but the existing batch owns its old price.
    const newerCatalogCost=12000;
    final novemberBatch=batchLineSnapshotPayload(
      bookId:'same-book',quantity:3,unitCost:newerCatalogCost,
      manuallyEdited:false);
    expect(octoberBatch['unit_cost'],10000);
    expect(novemberBatch['unit_cost'],12000);
    expect(octoberBatch['quantity'],5);
    expect(octoberBatch['edited_cost'],false);
    expect(octoberBatch['unit_cost'],isNot(novemberBatch['unit_cost']));
  });

  test('Saved unit cost is included even without manual override', () {
    final received=batchLineSnapshotPayload(
      bookId:'book-1',quantity:2,unitCost:8500,manuallyEdited:false);
    expect(received,containsPair('unit_cost',8500));
    expect(received,containsPair('edited_cost',false));
  });

  test('Only an explicit change marks batch cost as manual', () {
    final adjusted=batchLineSnapshotPayload(
      bookId:'book-1',quantity:2,unitCost:9750,manuallyEdited:true);
    expect(adjusted['unit_cost'],9750);
    expect(adjusted['edited_cost'],true);
  });
}
