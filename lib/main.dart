import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

void main() => runApp(const MuhajeerBooksApp());

class MuhajeerBooksApp extends StatelessWidget {
  const MuhajeerBooksApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Muhajeerbooks',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF1E88E5),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: const RootNav(),
    );
  }
}

//— Model —
class Product {
  final int id;
  final String title;
  final int price;
  final int? oldPrice;
  final int rating;
  final String image;
  final String desc;

  Product({
    required this.id,
    required this.title,
    required this.price,
    this.oldPrice,
    required this.rating,
    required this.image,
    required this.desc,
  });

  factory Product.fromJson(Map<String, dynamic> j) => Product(
        id: j['id'],
        title: j['title'],
        price: j['price'],
        oldPrice: j['oldPrice'],
        rating: j['rating'],
        image: j['image'],
        desc: j['desc'],
      );
}

//— Global savat —
class Cart with ChangeNotifier {
  final Map<int, int> _items = {}; // productId -> qty
  Map<int, int> get items => _items;
  void add(int id) {
    _items.update(id, (v) => v + 1, ifAbsent: () => 1);
  }
  void remove(int id) {
    if (!_items.containsKey(id)) return;
    final q = _items[id]!;
    if (q <= 1) {
      _items.remove(id);
    } else {
      _items[id] = q - 1;
    }
  }
  void clear() => _items.clear();
}

//— Root + BottomNav —
class RootNav extends StatefulWidget {
  const RootNav({super.key});
  @override
  State<RootNav> createState() => _RootNavState();
}

class _RootNavState extends State<RootNav> {
  int idx = 0;
  final cart = Cart();

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomePage(cart: cart),
      FavoritesPage(),
      CartPage(cart: cart),
      const ProfilePage(),
    ];
    return Scaffold(
      body: pages[idx],
      bottomNavigationBar: NavigationBar(
        selectedIndex: idx,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Bosh oyna'),
          NavigationDestination(icon: Icon(Icons.favorite_border), label: 'Sevimli'),
          NavigationDestination(icon: Icon(Icons.shopping_bag_outlined), label: 'Savatda'),
          NavigationDestination(icon: Icon(Icons.person_outline), label: 'Profil'),
        ],
        onDestinationSelected: (i) => setState(() => idx = i),
      ),
    );
  }
}

//— Home (mah­sulotlar ro‘yxati) —
class HomePage extends StatefulWidget {
  final Cart cart;
  const HomePage({super.key, required this.cart});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Product> products = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final raw = await rootBundle.loadString('assets/products.json');
    final list = (json.decode(raw) as List).map((e) => Product.fromJson(e)).toList();
    setState(() => products = list);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverAppBar(
            title: const Text('Muhajeerbooks', style: TextStyle(fontWeight: FontWeight.w600)),
            floating: true,
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverToBoxAdapter(
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Izlash',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverGrid.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2, mainAxisSpacing: 16, crossAxisSpacing: 16, childAspectRatio: .66),
              itemCount: products.length,
              itemBuilder: (_, i) => _ProductCard(p: products[i], onAdd: () {
                widget.cart.add(products[i].id);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${products[i].title} savatga qo\'shildi')),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final Product p;
  final VoidCallback onAdd;
  const _ProductCard({required this.p, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => DetailPage(p: p, onAdd: onAdd))),
      child: Card(
        clipBehavior: Clip.hardEdge,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: Image.asset(p.image, fit: BoxFit.cover, width: double.infinity)),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Row(
                    children: List.generate(5, (i) => Icon(i < p.rating ? Icons.star : Icons.star_border, size: 16)),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text('${p.price} W', style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      if (p.oldPrice != null)
                        Text('${p.oldPrice} W', style: const TextStyle(decoration: TextDecoration.lineThrough, color: Colors.grey)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: onAdd,
                      child: const Text('Savatga'),
                    ),
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}

//— Ta’rif sahifasi —
class DetailPage extends StatelessWidget {
  final Product p;
  final VoidCallback onAdd;
  const DetailPage({super.key, required this.p, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(p.title)),
      body: ListView(
        children: [
          Image.asset(p.image, height: 320, fit: BoxFit.cover),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(p.desc),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text('${p.price} W', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  if (p.oldPrice != null)
                    Text('${p.oldPrice} W', style: const TextStyle(decoration: TextDecoration.lineThrough, color: Colors.grey)),
                ],
              ),
            ]),
          )
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(onPressed: onAdd, child: const Text('Sotib olish')),
        ),
      ),
    );
  }
}

//— Savat sahifasi (oddiy ko‘rinish) —
class CartPage extends StatefulWidget {
  final Cart cart;
  const CartPage({super.key, required this.cart});
  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  @override
  Widget build(BuildContext context) {
    final items = widget.cart.items;
    return Scaffold(
      appBar: AppBar(title: const Text('Savatda')),
      body: items.isEmpty
          ? const Center(child: Text('Savat bo‘sh'))
          : ListView(
              children: items.entries.map((e) => ListTile(
                    title: Text('Mahsulot #${e.key}'),
                    subtitle: Text('Soni: ${e.value}'),
                    trailing: IconButton(icon: const Icon(Icons.remove_circle_outline),
                      onPressed: () { setState(() => widget.cart.remove(e.key)); }),
                  )).toList(),
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            onPressed: items.isEmpty ? null : () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Buyurtma qabul qilindi (demo)")),
            ),
            child: const Text('Buyurtma qilish'),
          ),
        ),
      ),
    );
  }
}

//— Sevimlilar (demo) —
class FavoritesPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('Sevimli: hozircha demo')),
    );
  }
}

//— Profil —
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text('Mavjud emas', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
            SizedBox(height: 12),
            Text("Versiya: 1.0.0\nBrend: Muhajeerbooks"),
          ],
        ),
      ),
    );
  }
}
