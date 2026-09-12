import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app_state.dart';
import 'app_state_fixed.dart';

class CartStockAlertBridge extends StatefulWidget {
  const CartStockAlertBridge({super.key, required this.child});

  final Widget child;

  @override
  State<CartStockAlertBridge> createState() => _CartStockAlertBridgeState();
}

class _CartSnapshot {
  const _CartSnapshot({required this.title, required this.stock});

  final String title;
  final int stock;
}

class _CartStockAlertBridgeState extends State<CartStockAlertBridge> {
  Map<String, _CartSnapshot> _previousCart = const {};
  bool _primed = false;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final currentCart = <String, _CartSnapshot>{
      for (final line in state.cartLines)
        line.book.id: _CartSnapshot(
          title: line.book.title,
          stock: line.book.stock,
        ),
    };

    if (!_primed) {
      _previousCart = currentCart;
      _primed = true;
    } else {
      final suppress = state is AppStateFixed && state.suppressCartStockAlert;
      if (!suppress) {
        final booksById = {for (final book in state.books) book.id: book};
        final soldOutTitles = <String>[];

        for (final entry in _previousCart.entries) {
          if (currentCart.containsKey(entry.key)) continue;
          final currentBook = booksById[entry.key];
          if (currentBook != null &&
              currentBook.stock <= 0 &&
              entry.value.stock > 0) {
            soldOutTitles.add(entry.value.title);
          }
        }

        if (soldOutTitles.isNotEmpty) {
          final message = soldOutTitles.length == 1
              ? '“${soldOutTitles.first}” hozirgina sotildi va savatdan olib tashlandi.'
              : '${soldOutTitles.length} ta kitob hozirgina sotildi va savatdan olib tashlandi: ${soldOutTitles.join(', ')}';

          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(
                  duration: const Duration(seconds: 6),
                  content: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.inventory_2_outlined,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          message,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                ),
              );
          });
        }
      }
      _previousCart = currentCart;
    }

    return widget.child;
  }
}
