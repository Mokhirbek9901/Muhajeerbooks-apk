import 'package:flutter/material.dart';
import 'uzbek_customer_style.dart';

const purchasePriceExplanation =
    'Kitoblar O‘zbekistondan keltiriladi. Valyuta kursi o‘zgarishi ularning narxiga ta’sir qilishi mumkin.';

/// One copy of the web price explanation reused throughout TestFlight checkout.
class PurchasePriceNotice extends StatelessWidget {
  const PurchasePriceNotice({super.key});

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('purchase-price-notice'),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
    decoration: BoxDecoration(
      color: const Color(0xFFF3F8F5),
      border: Border.all(color: const Color(0xFFD0E3D9)),
      borderRadius: BorderRadius.circular(12),
    ),
    child: const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(radius: 12, backgroundColor: Color(0xFFE0F0E8),
          child: Icon(Icons.info_outline_rounded, color: UzbekCustomerColors.teal, size: 16)),
        SizedBox(width: 10),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Narxlar haqida', style: TextStyle(
              color: UzbekCustomerColors.navy, fontWeight: FontWeight.w800, fontSize: 13)),
            SizedBox(height: 3),
            Text(purchasePriceExplanation, style: TextStyle(
              color: UzbekCustomerColors.navy, fontSize: 12, height: 1.35)),
          ],
        )),
      ],
    ),
  );
}
