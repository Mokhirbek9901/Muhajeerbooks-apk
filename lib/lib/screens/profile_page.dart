import 'package:flutter/material.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const CircleAvatar(radius: 40, child: Icon(Icons.person, size: 40)),
            const SizedBox(height: 10),
            const Text('Foydalanuvchi: Mavjud emas',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const Divider(height: 30),
            ListTile(
              leading: const Icon(Icons.shopping_bag_outlined),
              title: const Text('Buyurtmalarim'),
              onTap: () {},
            ),
            ListTile(
              leading: const Icon(Icons.language),
              title: const Text('Tilni sozlash'),
              onTap: () {},
            ),
            ListTile(
              leading: const Icon(Icons.phone),
              title: const Text('Biz bilan bog‘lanish'),
              subtitle: const Text('@muhajeerbooks_admin'),
            ),
            const Spacer(),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent, minimumSize: const Size.fromHeight(50)),
              onPressed: () {},
              child: const Text('Chiqish'),
            ),
          ],
        ),
      ),
    );
  }
}
