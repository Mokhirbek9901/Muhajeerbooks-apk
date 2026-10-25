/// A book batch reconciles existing finance expenses against its entered
/// receipt book costs. Finance entries are references, not new expenses.
class BatchExpenseMath {
  const BatchExpenseMath({
    required this.purchaseExpenses,
    required this.transportExpenses,
    required this.enteredBookCost,
    required this.hasPurchaseSelection,
  });
  final int purchaseExpenses;
  final int transportExpenses;
  final int enteredBookCost;
  final bool hasPurchaseSelection;

  int get financeTotal => purchaseExpenses + transportExpenses;
  int get enteredWithTransport => enteredBookCost + transportExpenses;
  int? get bookDifference =>
      hasPurchaseSelection ? purchaseExpenses - enteredBookCost : null;
  int? get totalDifference =>
      hasPurchaseSelection ? financeTotal - enteredWithTransport : null;
}
