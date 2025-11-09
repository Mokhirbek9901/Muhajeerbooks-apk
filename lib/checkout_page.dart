import 'package:flutter/material.dart';

class CheckoutPage extends StatefulWidget {
  final String productName;
  final int price;

  const CheckoutPage({super.key, required this.productName, required this.price});

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Buyurtma rasmiylashtirish')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Kitob: ${widget.productName}', style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 10),
            Text('Narx: ${widget.price} W', style: const TextStyle(fontSize: 16, color: Colors.green)),
            const Divider(height: 30),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Ism Familiya'),
            ),
            TextField(
              controller: _addressController,
              decoration: const InputDecoration(labelText: 'Manzil (shahar, tuman, ko‘cha)'),
            ),
            const SizedBox(height: 20),
            const Text('To‘lov turi:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.all(10),
              child: const Text(
                'Karta orqali to‘lov: \nWoori Bank (우리 은행)\n1002-959-131332\nNom: ISMOILOV M.',
                style: TextStyle(fontSize: 15),
              ),
            ),
            const Spacer(),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green, minimumSize: const Size.fromHeight(50)),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Buyurtma qabul qilindi ✅')),
                );
              },
              child: const Text('Buyurtma qilish', style: TextStyle(fontSize: 18)),
            ),
          ],
        ),
      ),
    );
  }
}
