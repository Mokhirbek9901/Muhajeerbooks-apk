import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class Book {
  const Book({
    required this.id,
    required this.title,
    required this.author,
    required this.category,
    required this.description,
    required this.price,
    required this.stock,
    required this.discountPercent,
    required this.imageUrl,
    required this.isActive,
  });

  final String id;
  final String title;
  final String author;
  final String category;
  final String description;
  final int price;
  final int stock;
  final int discountPercent;
  final String imageUrl;
  final bool isActive;

  int get currentPrice =>
      (price * (100 - discountPercent) / 100).round();
  bool get isDiscounted => discountPercent > 0;
  bool get inStock => stock > 0;

  factory Book.fromMap(Map<String, dynamic> map) => Book(
        id: map['id'].toString(),
        title: (map['title'] ?? '').toString(),
        author: (map['author'] ?? '').toString(),
        category: (map['category'] ?? 'Boshqa').toString(),
        description: (map['description'] ?? '').toString(),
        price: (map['price'] as num?)?.toInt() ?? 0,
        stock: (map['stock'] as num?)?.toInt() ?? 0,
        discountPercent:
            (map['discount_percent'] as num?)?.toInt() ?? 0,
        imageUrl: (map['image_url'] ?? '').toString(),
        isActive: map['is_active'] as bool? ?? true,
      );

  Map<String, dynamic> toMap() => {
        'title': title,
        'author': author,
        'category': category,
        'description': description,
        'price': price,
        'stock': stock,
        'discount_percent': discountPercent,
        'image_url': imageUrl,
        'is_active': isActive,
      };

  Book copyWith({
    String? id,
    String? title,
    String? author,
    String? category,
    String? description,
    int? price,
    int? stock,
    int? discountPercent,
    String? imageUrl,
    bool? isActive,
  }) =>
      Book(
        id: id ?? this.id,
        title: title ?? this.title,
        author: author ?? this.author,
        category: category ?? this.category,
        description: description ?? this.description,
        price: price ?? this.price,
        stock: stock ?? this.stock,
        discountPercent: discountPercent ?? this.discountPercent,
        imageUrl: imageUrl ?? this.imageUrl,
        isActive: isActive ?? this.isActive,
      );
}

class CartLine {
  const CartLine({required this.book, required this.quantity});
  final Book book;
  final int quantity;
  int get total => book.currentPrice * quantity;
}

class ShopOrder {
  const ShopOrder({
    required this.id,
    required this.customerName,
    required this.phone,
    required this.address,
    required this.deliveryType,
    required this.deliveryFee,
    required this.total,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String customerName;
  final String phone;
  final String address;
  final String deliveryType;
  final int deliveryFee;
  final int total;
  final String status;
  final DateTime createdAt;

  factory ShopOrder.fromMap(Map<String, dynamic> map) => ShopOrder(
        id: map['id'].toString(),
        customerName: (map['customer_name'] ?? '').toString(),
        phone: (map['phone'] ?? '').toString(),
        address: (map['address'] ?? '').toString(),
        deliveryType: (map['delivery_type'] ?? '').toString(),
        deliveryFee: (map['delivery_fee'] as num?)?.toInt() ?? 0,
        total: (map['total'] as num?)?.toInt() ?? 0,
        status: (map['status'] ?? 'new').toString(),
        createdAt: DateTime.tryParse((map['created_at'] ?? '').toString()) ??
            DateTime.now(),
      );
}

class BackendService {
  BackendService(this.client);
  final SupabaseClient client;

  Future<List<Book>> fetchBooks({bool includeInactive = false}) async {
    final data = await client.from('books').select().order('created_at');
    return (data as List)
        .map((e) => Book.fromMap(Map<String, dynamic>.from(e as Map)))
        .where((b) => includeInactive || b.isActive)
        .toList();
  }

  Future<void> saveBook(Book book) async {
    if (book.id.isEmpty) {
      await client.from('books').insert(book.toMap());
    } else {
      await client.from('books').update(book.toMap()).eq('id', book.id);
    }
  }

  Future<void> deleteBook(String id) async {
    await client.from('books').delete().eq('id', id);
  }

  Future<void> applyDiscountToAll(int percent) async {
    await client
        .from('books')
        .update({'discount_percent': percent}).eq('is_active', true);
  }

  Future<void> clearAllDiscounts() async {
    await client.from('books').update({'discount_percent': 0});
  }

  Future<String> uploadCover(XFile file) async {
    final Uint8List bytes = await file.readAsBytes();
    final ext = file.name.contains('.')
        ? file.name.split('.').last.toLowerCase()
        : 'jpg';
    final path =
        'covers/${DateTime.now().millisecondsSinceEpoch}_${file.name.replaceAll(' ', '_')}';
    await client.storage.from('book-covers').uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            upsert: true,
            contentType: ext == 'png' ? 'image/png' : 'image/jpeg',
          ),
        );
    return client.storage.from('book-covers').getPublicUrl(path);
  }

  Future<bool> signInAdmin(String email, String password) async {
    final result = await client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
    final user = result.user;
    if (user == null) return false;
    final profile = await client
        .from('profiles')
        .select('role')
        .eq('id', user.id)
        .maybeSingle();
    return profile != null && profile['role'] == 'admin';
  }

  Future<void> signOut() => client.auth.signOut();

  Future<String> createOrder({
    required String customerName,
    required String phone,
    required String address,
    required String deliveryType,
    required int deliveryFee,
    required int subtotal,
    required int total,
    required List<CartLine> lines,
  }) async {
    final payload = {
      'customer_name': customerName.trim(),
      'phone': phone.trim(),
      'address': address.trim(),
      'delivery_type': deliveryType,
      'delivery_fee': deliveryFee,
      'subtotal': subtotal,
      'total': total,
      'status': 'new',
      'items': lines
          .map((line) => {
                'book_id': line.book.id,
                'title': line.book.title,
                'price': line.book.currentPrice,
                'quantity': line.quantity,
                'line_total': line.total,
              })
          .toList(),
    };
    final data = await client.from('orders').insert(payload).select('id').single();
    return data['id'].toString();
  }

  Future<List<ShopOrder>> fetchOrders() async {
    final data = await client
        .from('orders')
        .select()
        .order('created_at', ascending: false);
    return (data as List)
        .map((e) => ShopOrder.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> updateOrderStatus(String id, String status) async {
    await client.from('orders').update({'status': status}).eq('id', id);
  }
}

class AppState extends ChangeNotifier {
  AppState({required this.backendConfigured});

  final bool backendConfigured;
  BackendService? _backend;
  final List<Book> _books = [];
  final Map<String, int> _cart = {};
  final Set<String> _favorites = {};
  bool loading = true;
  String? error;

  List<Book> get books => List.unmodifiable(_books);
  Set<String> get favorites => Set.unmodifiable(_favorites);

  Future<void> initialize() async {
    if (backendConfigured) {
      _backend = BackendService(Supabase.instance.client);
    }
    await refreshBooks();
  }

  Future<void> refreshBooks({bool includeInactive = false}) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      if (_backend != null) {
        _books
          ..clear()
          ..addAll(await _backend!.fetchBooks(includeInactive: includeInactive));
      } else {
        _books
          ..clear()
          ..addAll(_demoBooks);
      }
    } catch (e) {
      error = e.toString();
      if (_books.isEmpty) {
        _books.addAll(_demoBooks);
      }
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  BackendService? get backend => _backend;

  List<CartLine> get cartLines {
    final byId = {for (final b in _books) b.id: b};
    return _cart.entries
        .where((e) => byId[e.key] != null)
        .map((e) => CartLine(book: byId[e.key]!, quantity: e.value))
        .toList();
  }

  int get cartCount => _cart.values.fold(0, (a, b) => a + b);
  int get cartSubtotal => cartLines.fold(0, (a, b) => a + b.total);

  void addToCart(Book book) {
    if (!book.inStock) return;
    final current = _cart[book.id] ?? 0;
    if (current < book.stock) {
      _cart[book.id] = current + 1;
      notifyListeners();
    }
  }

  void decrementCart(Book book) {
    final current = _cart[book.id] ?? 0;
    if (current <= 1) {
      _cart.remove(book.id);
    } else {
      _cart[book.id] = current - 1;
    }
    notifyListeners();
  }

  void removeFromCart(Book book) {
    _cart.remove(book.id);
    notifyListeners();
  }

  void clearCart() {
    _cart.clear();
    notifyListeners();
  }

  void toggleFavorite(Book book) {
    if (!_favorites.add(book.id)) {
      _favorites.remove(book.id);
    }
    notifyListeners();
  }

  bool isFavorite(Book book) => _favorites.contains(book.id);

  Future<void> saveBook(Book book) async {
    if (_backend != null) {
      await _backend!.saveBook(book);
      await refreshBooks(includeInactive: true);
      return;
    }
    final saved = book.id.isEmpty
        ? book.copyWith(id: 'demo-${DateTime.now().millisecondsSinceEpoch}')
        : book;
    final index = _books.indexWhere((b) => b.id == saved.id);
    if (index == -1) {
      _books.add(saved);
    } else {
      _books[index] = saved;
    }
    notifyListeners();
  }

  Future<void> deleteBook(Book book) async {
    if (_backend != null) {
      await _backend!.deleteBook(book.id);
      await refreshBooks(includeInactive: true);
      return;
    }
    _books.removeWhere((b) => b.id == book.id);
    _cart.remove(book.id);
    _favorites.remove(book.id);
    notifyListeners();
  }

  Future<void> applyDiscountToAll(int percent) async {
    if (_backend != null) {
      await _backend!.applyDiscountToAll(percent);
      await refreshBooks(includeInactive: true);
      return;
    }
    for (var i = 0; i < _books.length; i++) {
      _books[i] = _books[i].copyWith(discountPercent: percent);
    }
    notifyListeners();
  }

  Future<void> clearAllDiscounts() async {
    if (_backend != null) {
      await _backend!.clearAllDiscounts();
      await refreshBooks(includeInactive: true);
      return;
    }
    for (var i = 0; i < _books.length; i++) {
      _books[i] = _books[i].copyWith(discountPercent: 0);
    }
    notifyListeners();
  }

  Future<String> uploadCover(XFile file) async {
    if (_backend == null) return '';
    return _backend!.uploadCover(file);
  }

  static const _demoBooks = [
    Book(
      id: 'demo-1',
      title: 'Atom odatlari',
      author: 'Jeyms Klir',
      category: 'Motivatsiya',
      description: 'Yaxshi odatlar yaratish va yomon odatlarni tark etish haqida.',
      price: 15000,
      stock: 12,
      discountPercent: 20,
      imageUrl: '',
      isActive: true,
    ),
    Book(
      id: 'demo-2',
      title: 'Boy ota, kambag‘al ota',
      author: 'Robert Kiyosaki',
      category: 'Biznes',
      description: 'Moliyaviy savodxonlik va pulga boshqacha qarash.',
      price: 17000,
      stock: 8,
      discountPercent: 0,
      imageUrl: '',
      isActive: true,
    ),
    Book(
      id: 'demo-3',
      title: 'Sofiyaning dunyosi',
      author: 'Yustayn Gorder',
      category: 'Badiiy adabiyot',
      description: 'Falsafa tarixiga roman shaklida sayohat.',
      price: 19000,
      stock: 4,
      discountPercent: 10,
      imageUrl: '',
      isActive: true,
    ),
  ];
}
