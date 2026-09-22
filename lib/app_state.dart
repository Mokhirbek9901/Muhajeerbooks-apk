import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

String normalizePublisher(String value) {
  final cleaned=value.trim().replaceAll(RegExp(r'\s+'), ' ');
  final key=cleaned.toLowerCase().replaceAll('-', ' ');
  const aliases=<String,String>{
    'hilol nashr':'Hilol Nashr',
    'hilol nashriyoti':'Hilol Nashr',
    'huzur':'Huzur Nashr',
    'huzur nashr':'Huzur Nashr',
    'huzur nashriyoti':'Huzur Nashr',
    'misbah':'Misbah Nashr',
    'misbah nashr':'Misbah Nashr',
    'misbah nashriyoti':'Misbah Nashr',
    'nasim kutub':'Nasim Kutub',
    'global book':'Global Book',
    'global books':'Global Book',
    'inson':'Inson Nashriyoti',
    'inson nashr':'Inson Nashriyoti',
    'inson nashriyoti':'Inson Nashriyoti',
    'falaq nashr':'Falaq Nashr',
    'falaq nashriyoti':'Falaq Nashr',
  };
  return aliases[key] ?? cleaned;
}

String publisherKey(String value) => normalizePublisher(value).toLowerCase();

String _newOrderUuid() {
  final bytes=List<int>.generate(16,(_)=>Random.secure().nextInt(256));
  bytes[6]=(bytes[6]&0x0f)|0x40;
  bytes[8]=(bytes[8]&0x3f)|0x80;
  String h(int v)=>v.toRadixString(16).padLeft(2,'0');
  final s=bytes.map(h).join();
  return '${s.substring(0,8)}-${s.substring(8,12)}-${s.substring(12,16)}-${s.substring(16,20)}-${s.substring(20)}';
}


List<String> bookPublishers(Iterable<Book> books) {
  final names = <String, String>{};
  for (final book in books) {
    final name = normalizePublisher(book.publisher);
    if (book.isActive && name.isNotEmpty) {
      names.putIfAbsent(publisherKey(name), () => name);
    }
  }
  return names.values.toList()
    ..sort((a, b) => publisherKey(a).compareTo(publisherKey(b)));
}

bool isOptimizedBookImageUrl(String raw) {
  final value = raw.trim();
  if (value.isEmpty) return false;
  final uri = Uri.tryParse(value);
  final path = uri?.path ?? value;
  return path.contains('/book-covers/covers/') &&
      (path.contains('-opt-') || path.contains('-optimized-'));
}

String derivedBookThumbnailUrl(String raw) {
  final value = raw.trim();
  if (!isOptimizedBookImageUrl(value)) return '';
  final uri = Uri.tryParse(value);
  if (uri == null) return '';
  var path = uri.path.replaceFirst(
    '/book-covers/covers/',
    '/book-covers/covers/thumbs/',
  );
  path = path.replaceFirst(RegExp(r'\.[^.\/]+$'), '.jpg');
  return uri.replace(path: path).toString();
}

class Book {
  const Book({
    required this.id,
    this.legacyId,
    required this.title,
    required this.author,
    this.publisher = '',
    required this.category,
    required this.description,
    required this.price,
    required this.stock,
    required this.discountPercent,
    this.discountEndsAt,
    this.discountFreeDelivery = true,
    required this.imageUrl,
    this.thumbnailUrl = '',
    this.imageUrls = const [],
    required this.isActive,
    this.coverType = 'Ko‘rsatilmagan',
    this.costPrice = 0,
    this.recommended = false,
    this.preorderEnabled = false,
    this.preorderArrivalNote = '',
    this.preorderDepositMin = 5000,
    this.preorderDepositMax = 10000,
    this.preorderPriceMax = 0,
    this.createdAt,
  });

  final String id;
  final int? legacyId;
  final String title;
  final String author;
  final String publisher;
  final String category;
  final String description;
  final int price;
  final int stock;
  final int discountPercent;
  final DateTime? discountEndsAt;
  final bool discountFreeDelivery;
  final String imageUrl;
  final String thumbnailUrl;
  final List<String> imageUrls;
  final bool isActive;
  final String coverType;
  final int costPrice;
  final bool recommended;
  final bool preorderEnabled;
  final String preorderArrivalNote;
  final int preorderDepositMin;
  final int preorderDepositMax;
  final int preorderPriceMax;
  final DateTime? createdAt;

  bool get discountActive {
    if (discountPercent <= 0) return false;
    final endsAt = discountEndsAt;
    return endsAt == null || endsAt.isAfter(DateTime.now());
  }

  int get effectiveDiscountPercent => discountActive ? discountPercent : 0;
  int get currentPrice =>
      (price * (100 - effectiveDiscountPercent) / 100).round();
  bool get isDiscounted => discountActive;
  Duration? get discountRemaining {
    final endsAt = discountEndsAt;
    if (!discountActive || endsAt == null) return null;
    final remaining = endsAt.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }
  bool get inStock => stock > 0 && price > 0;
  String get previewImageUrl =>
      thumbnailUrl.trim().isNotEmpty ? thumbnailUrl.trim() : imageUrl;

  bool get galleryImagesOptimized =>
      galleryImages.every(isOptimizedBookImageUrl);

  String galleryThumbnailUrlAt(int index) {
    final images = galleryImages;
    if (index < 0 || index >= images.length) return '';
    if (index == 0 && thumbnailUrl.trim().isNotEmpty) {
      return thumbnailUrl.trim();
    }
    final derived = derivedBookThumbnailUrl(images[index]);
    return derived.isNotEmpty ? derived : images[index];
  }

  List<String> get galleryImages {
    final result = <String>[];
    for (final raw in [imageUrl, ...imageUrls]) {
      final url = raw.trim();
      if (url.isEmpty || result.contains(url)) continue;
      result.add(url);
      if (result.length == 20) break;
    }
    return result;
  }

  factory Book.fromMap(Map<String, dynamic> map) => Book(
    id: (map['id'] ?? '').toString(),
    legacyId: (map['legacy_id'] as num?)?.toInt(),
    title: (map['title'] ?? map['name'] ?? '').toString(),
    author: (map['author'] ?? 'Ko‘rsatilmagan').toString(),
    publisher: normalizePublisher((map['publisher'] ?? '').toString()),
    category: (map['category'] ?? 'Boshqalar').toString(),
    description: (map['description'] ?? '').toString(),
    price: (map['price'] as num?)?.toInt() ?? 0,
    stock: (map['stock'] as num?)?.toInt() ?? 0,
    discountPercent: (map['discount_percent'] as num?)?.toInt() ?? 0,
    discountEndsAt: DateTime.tryParse(
      (map['discount_ends_at'] ?? '').toString(),
    )?.toLocal(),
    discountFreeDelivery: map['discount_free_delivery'] as bool? ?? true,
    imageUrl: (map['image_url'] ?? '').toString(),
    thumbnailUrl: (map['thumbnail_url'] ?? '').toString(),
    imageUrls: ((map['image_urls'] as List?) ?? const [])
        .map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty)
        .take(20)
        .toList(),
    isActive: map['is_active'] as bool? ?? true,
    coverType: (map['cover_type'] ?? map['cover'] ?? 'Ko‘rsatilmagan')
        .toString(),
    costPrice: (map['cost_price'] as num?)?.toInt() ?? 0,
    recommended: map['recommended'] as bool? ?? false,
    preorderEnabled: map['preorder_enabled'] as bool? ?? false,
    preorderArrivalNote: (map['preorder_arrival_note'] ?? '').toString(),
    preorderDepositMin: (map['preorder_deposit_min'] as num?)?.toInt() ?? 5000,
    preorderDepositMax: (map['preorder_deposit_max'] as num?)?.toInt() ?? 10000,
    preorderPriceMax: (map['preorder_price_max'] as num?)?.toInt() ?? 0,
    createdAt: DateTime.tryParse((map['created_at'] ?? '').toString()),
  );

  factory Book.fromSeed(Map<String, dynamic> map) {
    final legacyId = (map['legacy_id'] as num?)?.toInt();
    return Book.fromMap({
      ...map,
      'id': legacyId == null ? '' : 'telegram-$legacyId',
      'discount_percent': _discountFromSeed(map),
      'image_url': '',
      'is_active': true,
    });
  }

  static int _discountFromSeed(Map<String, dynamic> map) {
    final oldPrice = (map['old_price'] as num?)?.toInt() ?? 0;
    final price = (map['price'] as num?)?.toInt() ?? 0;
    if (oldPrice <= price || price <= 0) return 0;
    return (((oldPrice - price) / oldPrice) * 100).round().clamp(0, 99).toInt();
  }

  Map<String, dynamic> toDbMap() => {
    'legacy_id': legacyId,
    'title': title,
    'author': author,
    'publisher': normalizePublisher(publisher),
    'category': category,
    'description': description,
    'price': price,
    'stock': stock,
    'discount_percent': discountPercent,
    'discount_ends_at': discountEndsAt?.toUtc().toIso8601String(),
    'discount_free_delivery': discountFreeDelivery,
    'image_url': galleryImages.isEmpty ? '' : galleryImages.first,
    'thumbnail_url': thumbnailUrl,
    'image_urls': galleryImages,
    'is_active': isActive,
    'cover_type': coverType,
    'cost_price': costPrice,
    'recommended': recommended,
    'preorder_enabled': preorderEnabled,
    'preorder_arrival_note': preorderArrivalNote,
    'preorder_deposit_min': preorderDepositMin,
    'preorder_deposit_max': preorderDepositMax,
    'preorder_price_max': preorderPriceMax,
  };

  Map<String, dynamic> toLocalMap() => {
    'id': id,
    ...toDbMap(),
    'created_at': createdAt?.toIso8601String(),
  };

  Book copyWith({
    String? id,
    int? legacyId,
    String? title,
    String? author,
    String? publisher,
    String? category,
    String? description,
    int? price,
    int? stock,
    int? discountPercent,
    DateTime? discountEndsAt,
    bool? discountFreeDelivery,
    bool clearDiscountEndsAt = false,
    String? imageUrl,
    String? thumbnailUrl,
    List<String>? imageUrls,
    bool? isActive,
    String? coverType,
    int? costPrice,
    bool? recommended,
    bool? preorderEnabled,
    String? preorderArrivalNote,
    int? preorderDepositMin,
    int? preorderDepositMax,
    int? preorderPriceMax,
    DateTime? createdAt,
  }) => Book(
    id: id ?? this.id,
    legacyId: legacyId ?? this.legacyId,
    title: title ?? this.title,
    author: author ?? this.author,
    publisher: publisher ?? this.publisher,
    category: category ?? this.category,
    description: description ?? this.description,
    price: price ?? this.price,
    stock: stock ?? this.stock,
    discountPercent: discountPercent ?? this.discountPercent,
    discountEndsAt: clearDiscountEndsAt
        ? null
        : (discountEndsAt ?? this.discountEndsAt),
    discountFreeDelivery: discountFreeDelivery ?? this.discountFreeDelivery,
    imageUrl: imageUrl ?? this.imageUrl,
    thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
    imageUrls: imageUrls ?? this.imageUrls,
    isActive: isActive ?? this.isActive,
    coverType: coverType ?? this.coverType,
    costPrice: costPrice ?? this.costPrice,
    recommended: recommended ?? this.recommended,
    preorderEnabled: preorderEnabled ?? this.preorderEnabled,
    preorderArrivalNote: preorderArrivalNote ?? this.preorderArrivalNote,
    preorderDepositMin: preorderDepositMin ?? this.preorderDepositMin,
    preorderDepositMax: preorderDepositMax ?? this.preorderDepositMax,
    preorderPriceMax: preorderPriceMax ?? this.preorderPriceMax,
    createdAt: createdAt ?? this.createdAt,
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
    required this.subtotal,
    required this.total,
    required this.status,
    this.source = 'app',
    this.displayOrderNumber = 0,
    required this.items,
    required this.createdAt,
    this.paymentProofPath = '',
    this.paymentSubmittedAt,
    this.stockReserved = false,
  });

  final String id;
  final String customerName;
  final String phone;
  final String address;
  final String deliveryType;
  final int deliveryFee;
  final int subtotal;
  final int total;
  final String status;
  final String source;
  final int displayOrderNumber;
  final List<Map<String, dynamic>> items;
  final DateTime createdAt;
  final String paymentProofPath;
  final DateTime? paymentSubmittedAt;
  final bool stockReserved;

  bool get hasPaymentProof => paymentProofPath.trim().isNotEmpty;
  bool get isTelegram => source == 'telegram';
  bool get isInstagram => source == 'instagram';
  bool get isApp => source == 'app';

  String get recoveryCode {
    final compact = id.replaceAll('-', '').toLowerCase();
    if (compact.length <= 12) return compact;
    return compact.substring(compact.length - 12);
  }

  factory ShopOrder.fromMap(Map<String, dynamic> map) => ShopOrder(
    id: (map['id'] ?? '').toString(),
    customerName: (map['customer_name'] ?? '').toString(),
    phone: (map['phone'] ?? '').toString(),
    address: (map['address'] ?? '').toString(),
    deliveryType: (map['delivery_type'] ?? '').toString(),
    deliveryFee: (map['delivery_fee'] as num?)?.toInt() ?? 0,
    subtotal: (map['subtotal'] as num?)?.toInt() ?? 0,
    total: (map['total'] as num?)?.toInt() ?? 0,
    status: (map['status'] ?? 'new').toString(),
    source: (map['source'] ?? 'app').toString(),
    displayOrderNumber: (map['display_order_number'] as num?)?.toInt() ?? 0,
    items: ((map['items'] as List?) ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList(),
    createdAt:
        DateTime.tryParse((map['created_at'] ?? '').toString()) ??
        DateTime.now(),
    paymentProofPath: (map['payment_proof_path'] ?? '').toString(),
    paymentSubmittedAt: DateTime.tryParse(
      (map['payment_submitted_at'] ?? '').toString(),
    ),
    stockReserved: map['stock_reserved'] as bool? ?? false,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'customer_name': customerName,
    'phone': phone,
    'address': address,
    'delivery_type': deliveryType,
    'delivery_fee': deliveryFee,
    'subtotal': subtotal,
    'total': total,
    'status': status,
    'source': source,
    'display_order_number': displayOrderNumber,
    'items': items,
    'created_at': createdAt.toIso8601String(),
    'payment_proof_path': paymentProofPath,
    'payment_submitted_at': paymentSubmittedAt?.toIso8601String(),
    'stock_reserved': stockReserved,
  };

  ShopOrder copyWith({
    String? status,
    String? source,
    String? paymentProofPath,
    DateTime? paymentSubmittedAt,
    bool? stockReserved,
  }) => ShopOrder(
    id: id,
    customerName: customerName,
    phone: phone,
    address: address,
    deliveryType: deliveryType,
    deliveryFee: deliveryFee,
    subtotal: subtotal,
    total: total,
    status: status ?? this.status,
    source: source ?? this.source,
    displayOrderNumber: displayOrderNumber,
    items: items,
    createdAt: createdAt,
    paymentProofPath: paymentProofPath ?? this.paymentProofPath,
    paymentSubmittedAt: paymentSubmittedAt ?? this.paymentSubmittedAt,
    stockReserved: stockReserved ?? this.stockReserved,
  );
}

class BackendService {
  BackendService(this.client);
  final SupabaseClient client;

  static const String _storefrontBookColumns =
      'id,legacy_id,title,author,publisher,category,description,price,stock,'
      'discount_percent,discount_ends_at,image_url,thumbnail_url,image_urls,is_active,cover_type,recommended,preorder_enabled,'
      'preorder_arrival_note,preorder_deposit_min,preorder_deposit_max,preorder_price_max,created_at';

  Future<dynamic> _customerRpc(
    String name,
    Map<String, dynamic> params,
  ) async {
    final response = await client.functions.invoke(
      'customer-rpc',
      body: {'name': name, 'params': params},
    );
    final raw = response.data;
    Map<String, dynamic> envelope = <String, dynamic>{};
    if (raw is Map) {
      envelope = Map<String, dynamic>.from(raw);
    } else if (raw is String && raw.trim().isNotEmpty) {
      final decoded = jsonDecode(raw);
      if (decoded is Map) envelope = Map<String, dynamic>.from(decoded);
    }
    if (envelope['ok'] != true) {
      throw StateError(
        (envelope['error'] ?? 'Server so‘rovni bajarmadi.').toString(),
      );
    }
    return envelope['data'];
  }

  Future<List<Book>> fetchBooks({bool includeInactive = false}) async {
    // Public customers use the same read-only RPC for full and delta sync.
    // Direct table reads are reserved for the authenticated admin path.
    if (!includeInactive) {
      final snapshot = await fetchCatalogDelta('1970-01-01T00:00:00Z');
      final rows = snapshot['upserts'];
      if (rows is! List ||
          (snapshot['server_time'] ?? '').toString().trim().isEmpty) {
        throw StateError('Katalog javobi noto‘g‘ri. Qayta urinib ko‘ring.');
      }
      final books = rows
          .map((e) => Book.fromMap(Map<String, dynamic>.from(e as Map)))
          .where((book) => book.id.isNotEmpty && book.isActive)
          .toList();
      books.sort((a, b) {
        final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bTime.compareTo(aTime);
      });
      return books;
    }

    final data = await client
        .from('books')
        .select(_storefrontBookColumns)
        .order('created_at', ascending: false);
    return (data as List)
        .map((e) => Book.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<Map<String, dynamic>> fetchCatalogDelta(String since) async {
    final raw = await _customerRpc(
      'customer_catalog_delta',
      {'p_since': since},
    );
    return raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> fetchStoreNotice() async {
    final raw = await _customerRpc('customer_store_notice', const {});
    return raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
  }

  Future<void> saveBook(Book book) async {
    final payload = book.toDbMap();
    if (book.id.isEmpty ||
        book.id.startsWith('local-') ||
        book.id.startsWith('telegram-')) {
      await client.from('books').insert(payload);
    } else {
      await client.from('books').update(payload).eq('id', book.id);
    }
  }

  Future<void> deleteBook(String id) async =>
      client.from('books').delete().eq('id', id);

  Future<void> applyDiscountToAll(int percent) async {
    await client
        .from('books')
        .update({'discount_percent': percent})
        .eq('is_active', true);
  }

  Future<void> clearAllDiscounts() async {
    await client.from('books').update({'discount_percent': 0});
  }

  Future<String> uploadCover(XFile file) async {
    final Uint8List bytes = await file.readAsBytes();
    final ext = file.name.contains('.')
        ? file.name.split('.').last.toLowerCase()
        : 'jpg';
    final cleanName = file.name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final path = 'covers/${DateTime.now().millisecondsSinceEpoch}_$cleanName';
    await client.storage
        .from('book-covers')
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            upsert: false,
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

  Future<void> registerInstallation(String installId, String platform) async {
    await _customerRpc(
      'register_app_install',
      {'p_install_id': installId, 'p_platform': platform},
    );
  }

  Future<Map<String, dynamic>> subscribeRestock(
    String installId,
    String bookId,
  ) async {
    final raw = await _customerRpc(
      'customer_restock_subscribe',
      {'p_install_id': installId, 'p_book_id': bookId},
    );
    return raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
  }

  Future<void> unsubscribeRestock(String installId, String bookId) async {
    await _customerRpc(
      'customer_restock_unsubscribe',
      {'p_install_id': installId, 'p_book_id': bookId},
    );
  }

  Future<List<Map<String, dynamic>>> fetchRestockNotifications(
    String installId,
  ) async {
    final raw = await _customerRpc(
      'customer_restock_notifications',
      {'p_install_id': installId},
    );
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<List<Map<String, dynamic>>> fetchPushMessages({int limit = 50}) async {
    final raw = await _customerRpc(
      'customer_push_history',
      {'p_limit': limit.clamp(1, 100)},
    );
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<Map<String, dynamic>> submitPreorder(
    String installId,
    String bookId,
    String name,
    String phone, {
    int quantity = 1,
    required int depositAmount,
    required String paymentProofPath,
    String note = '',
  }) async {
    final raw = await _customerRpc('customer_preorder_submit', {
      'p_install_id': installId,
      'p_book_id': bookId,
      'p_customer_name': name,
      'p_phone': phone,
      'p_quantity': quantity,
      'p_deposit_amount': depositAmount,
      'p_payment_proof_path': paymentProofPath,
      'p_note': note,
    });
    return raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> requestMissingBook(String installId, String title, {String author = '', String phone = ''}) async {
    final raw = await _customerRpc('customer_book_request_submit', {'p_install_id': installId, 'p_title': title, 'p_author': author, 'p_phone': phone});
    return raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
  }

  Future<void> logSearchMiss(String installId, String query) async {
    await _customerRpc('customer_search_miss_log', {'p_install_id': installId, 'p_query': query});
  }

  Future<List<Map<String, dynamic>>> fetchBundles() async {
    final raw = await _customerRpc('customer_bundle_list', const {});
    if (raw is! List) return const [];
    return raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<String> uploadPaymentProof(XFile file) async {
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) throw StateError('Chek rasmi bo‘sh.');
    if (bytes.length > 7 * 1024 * 1024) {
      throw StateError('Chek rasmi 7 MB dan kichik bo‘lishi kerak.');
    }

    final lower = file.name.toLowerCase();
    final contentType = lower.endsWith('.png')
        ? 'image/png'
        : lower.endsWith('.webp')
        ? 'image/webp'
        : 'image/jpeg';

    final response = await client.functions.invoke(
      'payment-proof',
      body: {
        'action': 'upload',
        'file_name': file.name,
        'content_type': contentType,
        'data_base64': base64Encode(bytes),
      },
    );
    final raw = response.data;
    Map<String, dynamic> data = <String, dynamic>{};
    if (raw is Map) {
      data = Map<String, dynamic>.from(raw);
    } else if (raw is String && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) data = Map<String, dynamic>.from(decoded);
      } catch (_) {
        // Web proxy ayrim hollarda JSON javobni string ko‘rinishida qaytarishi mumkin.
      }
    }
    final path = (data['path'] ?? '').toString();
    if (path.isEmpty) {
      throw StateError(
        (data['error'] ?? 'To‘lov cheki yuklanmadi.').toString(),
      );
    }
    return path;
  }

  Future<String> createOrder({
    required String customerName,
    required String phone,
    required String address,
    required String deliveryType,
    required int deliveryFee,
    required int subtotal,
    required int total,
    required List<CartLine> lines,
    List<Map<String, dynamic>> bundleSelections = const [],
    String paymentProofPath = '',
  }) async {
    // Bir checkout urinishida ID oldindan yaratiladi. Tarmoq javobi kechiksa
    // retry aynan shu ID bilan ketadi va ikkinchi buyurtma/ombor kamayishi yaratilmaydi.
    final orderId = _newOrderUuid();
    final payload = {
      'id': orderId,
      'customer_name': customerName.trim(),
      'phone': phone.trim(),
      'address': address.trim(),
      'delivery_type': deliveryType,
      'delivery_fee': deliveryFee,
      'subtotal': subtotal,
      'total': total,
      'status': 'new',
      'source': 'app',
      'items': lines.map(_lineToMap).toList(),
      'bundle_selections': bundleSelections,
      'payment_proof_path': paymentProofPath,
      'payment_submitted_at': paymentProofPath.isEmpty
          ? null
          : DateTime.now().toIso8601String(),
    };
    // Checkoutni maksimal tez tutamiz: normal tarmoqda darhol tugaydi,
    // uzilish bo'lsa esa foydalanuvchini uzoq kuttirmaymiz.
    Object? lastError;
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final data = await client
            .from('orders')
            .insert(payload)
            .select('id')
            .single()
            .timeout(const Duration(milliseconds: 2200));
        return data['id'].toString();
      } catch (error) {
        lastError = error;
        // Birinchi insert serverda muvaffaqiyatli bo‘lib, faqat javob yo‘qolgan
        // bo‘lsa retry bir xil PK sabab 23505 qaytaradi. Bu — avvalgi buyurtma
        // allaqachon yaratilgan degani; yangi buyurtma ochmaymiz.
        if (error is PostgrestException && error.code == '23505') {
          return orderId;
        }
        if (attempt == 1) rethrow;
        await Future<void>.delayed(const Duration(milliseconds: 120));
      }
    }
    throw StateError('Buyurtma yuborilmadi: $lastError');
  }

  Future<Map<String, Map<String, dynamic>>> fetchOrderStatuses(
    List<String> ids,
  ) async {
    if (ids.isEmpty) return {};
    final data = await _customerRpc(
      'customer_order_statuses',
      {'p_ids': ids.take(50).toList()},
    );
    final result = <String, Map<String, dynamic>>{};
    for (final row in (data as List)) {
      final map = Map<String, dynamic>.from(row as Map);
      result[(map['id'] ?? '').toString()] = map;
    }
    return result;
  }

  Future<List<ShopOrder>> restoreOrders({
    required String phone,
    required String recoveryCode,
  }) async {
    final raw = await _customerRpc(
      'customer_restore_orders',
      {'p_phone': phone.trim(), 'p_recovery_code': recoveryCode.trim()},
    );
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((e) => ShopOrder.fromMap(Map<String, dynamic>.from(e)))
        .toList();
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

  static Map<String, dynamic> _lineToMap(CartLine line) => {
    'book_id': line.book.id,
    'title': line.book.title,
    'price': line.book.currentPrice,
    'original_price': line.book.price,
    'quantity': line.quantity,
    'line_total': line.total,
  };
}

class _LocalStore {
  static const _booksKey = 'muhajeer_books_v4';
  static const _ordersKey = 'muhajeer_orders_v4';
  static const _customerNoticesKey = 'muhajeer_customer_notices_v2';
  static const _favoritesKey = 'muhajeer_favorites_v2';
  static const _cartKey = 'muhajeer_cart_v2';
  static const _cartBundlesKey = 'muhajeer_cart_bundles_v1';
  static const _seedVersionKey = 'muhajeer_seed_version';
  static const _customerNameKey = 'muhajeer_customer_name';
  static const _customerPhoneKey = 'muhajeer_customer_phone';
  static const _customerAddressKey = 'muhajeer_customer_address';
  static const _customerVerifiedKey = 'muhajeer_customer_verified_v1';
  static const _installIdKey = 'muhajeer_install_id_v1';
  static const _restockSubscriptionsKey = 'muhajeer_restock_subscriptions_v1';
  static const _catalogCursorKey = 'muhajeer_catalog_cursor_v1';

  final Future<SharedPreferences> _prefs = SharedPreferences.getInstance();

  Future<List<Book>> loadBooks() async {
    final raw = (await _prefs).getString(_booksKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      return (jsonDecode(raw) as List)
          .map((e) => Book.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveBooks(List<Book> books) async {
    await (await _prefs).setString(
      _booksKey,
      jsonEncode(books.map((e) => e.toLocalMap()).toList()),
    );
  }

  Future<List<ShopOrder>> loadOrders() async {
    final raw = (await _prefs).getString(_ordersKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      return (jsonDecode(raw) as List)
          .map((e) => ShopOrder.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveOrders(List<ShopOrder> orders) async {
    await (await _prefs).setString(
      _ordersKey,
      jsonEncode(orders.map((e) => e.toMap()).toList()),
    );
  }

  Future<List<Map<String, dynamic>>> loadCustomerNotices() async {
    try {
      final raw = (await _prefs).getString(_customerNoticesKey);
      if (raw == null || raw.isEmpty) return [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveCustomerNotices(List<Map<String, dynamic>> notices) async {
    await (await _prefs).setString(_customerNoticesKey, jsonEncode(notices));
  }

  Future<Set<String>> loadFavorites() async =>
      (await _prefs).getStringList(_favoritesKey)?.toSet() ?? <String>{};

  Future<void> saveFavorites(Set<String> ids) async =>
      (await _prefs).setStringList(_favoritesKey, ids.toList());

  Future<Map<String, int>> loadCart() async {
    final raw = (await _prefs).getString(_cartKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final map = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      return map.map((key, value) => MapEntry(key, (value as num).toInt()));
    } catch (_) {
      return {};
    }
  }

  Future<void> saveCart(Map<String, int> cart) async =>
      (await _prefs).setString(_cartKey, jsonEncode(cart));

  Future<List<String>> loadCartBundles() async =>
      (await _prefs).getStringList(_cartBundlesKey) ?? <String>[];

  Future<void> saveCartBundles(List<String> ids) async =>
      (await _prefs).setStringList(_cartBundlesKey, ids);

  Future<int> seedVersion() async =>
      (await _prefs).getInt(_seedVersionKey) ?? 0;
  Future<void> setSeedVersion(int value) async =>
      (await _prefs).setInt(_seedVersionKey, value);

  Future<Map<String, String>> loadCustomer() async {
    final prefs = await _prefs;
    return {
      'name': prefs.getString(_customerNameKey) ?? '',
      'phone': prefs.getString(_customerPhoneKey) ?? '',
      'address': prefs.getString(_customerAddressKey) ?? '',
    };
  }

  Future<void> saveCustomer(String name, String phone, String address) async {
    final prefs = await _prefs;
    await prefs.setString(_customerNameKey, name);
    await prefs.setString(_customerPhoneKey, phone);
    await prefs.setString(_customerAddressKey, address);
  }

  Future<bool?> loadCustomerVerified() async =>
      (await _prefs).getBool(_customerVerifiedKey);

  Future<void> saveCustomerVerified(bool value) async =>
      (await _prefs).setBool(_customerVerifiedKey, value);

  Future<void> clearCustomer() async {
    final prefs = await _prefs;
    await prefs.remove(_customerNameKey);
    await prefs.remove(_customerPhoneKey);
    await prefs.remove(_customerAddressKey);
    await prefs.setBool(_customerVerifiedKey, false);
  }

  Future<String> installId() async {
    final prefs = await _prefs;
    final existing = prefs.getString(_installIdKey);
    if (existing != null && existing.length >= 12) return existing;
    final generated =
        'mb-${DateTime.now().microsecondsSinceEpoch}-${identityHashCode(prefs).abs()}';
    await prefs.setString(_installIdKey, generated);
    return generated;
  }

  Future<Set<String>> loadRestockSubscriptions() async =>
      (await _prefs).getStringList(_restockSubscriptionsKey)?.toSet() ??
      <String>{};

  Future<void> saveRestockSubscriptions(Set<String> ids) async =>
      (await _prefs).setStringList(_restockSubscriptionsKey, ids.toList());

  Future<String> loadCatalogCursor() async =>
      (await _prefs).getString(_catalogCursorKey) ?? '1970-01-01T00:00:00Z';

  Future<void> saveCatalogCursor(String value) async =>
      (await _prefs).setString(_catalogCursorKey, value);
}

class AppState extends ChangeNotifier with WidgetsBindingObserver {
  AppState({required this.backendConfigured});

  static const int telegramSeedVersion = 3;
  static const int deliveryFee = 4000;
  static const String bankName = 'Toss Bank';
  static const String bankAccount = '100068127720';
  static const String bankOwner = 'Ismoilov M';

  final bool backendConfigured;
  final _local = _LocalStore();
  BackendService? _backend;
  final List<Book> _books = [];
  final List<ShopOrder> _localOrders = [];
  final List<Map<String, dynamic>> _customerNotices = [];
  final Map<String, int> _cart = {};
  final Set<String> _favorites = {};
  final Set<String> _restockSubscriptions = {};
  final List<Map<String, dynamic>> _bundles = [];
  Map<String, dynamic> _storeNotice = const <String, dynamic>{};
  final List<String> _cartBundleIds = [];
  int _catalogRevision = 0;
  int get catalogRevision => _catalogRevision;
  void _touchCatalog() => _catalogRevision++;

  DateTime? get activeDiscountEndsAt {
    DateTime? latest;
    for (final book in _books) {
      if (!book.discountActive || book.discountEndsAt == null) continue;
      final end = book.discountEndsAt!;
      if (latest == null || end.isAfter(latest)) latest = end;
    }
    return latest;
  }

  int get activeGlobalDiscountPercent {
    for (final book in _books) {
      if (book.discountActive) return book.discountPercent;
    }
    return 0;
  }

  bool get fourPlusFreeDeliveryEnabled {
    for (final book in _books) {
      if (book.discountActive && !book.discountFreeDelivery) return false;
    }
    return true;
  }

  bool get discountBlocksFourPlusFreeDelivery =>
      activeGlobalDiscountPercent > 0 && !fourPlusFreeDeliveryEnabled;

  void _scheduleDiscountExpiryRefresh() {
    _discountExpiryTimer?.cancel();
    DateTime? nextExpiry;
    final now = DateTime.now();
    for (final book in _books) {
      final end = book.discountEndsAt;
      if (book.discountPercent <= 0 || end == null || !end.isAfter(now)) {
        continue;
      }
      if (nextExpiry == null || end.isBefore(nextExpiry)) nextExpiry = end;
    }
    if (nextExpiry == null) return;
    final delay = nextExpiry.difference(now);
    _discountExpiryTimer = Timer(delay, () {
      _touchCatalog();
      notifyListeners();
      _scheduleDiscountExpiryRefresh();
    });
  }

  String _catalogCursor = '1970-01-01T00:00:00Z';
  Timer? _booksFallbackTimer;
  Timer? _orderStatusTimer;
  Timer? _discountExpiryTimer;
  bool _orderStatusRefreshing = false;
  bool _restockRefreshing = false;
  bool _pushMessagesRefreshing = false;
  bool _lifecycleObserverRegistered = false;

  List<Map<String, dynamic>> get customerNotices =>
      List.unmodifiable(_customerNotices);
  int get unreadCustomerNoticeCount =>
      _customerNotices.where((n) => n['read'] != true).length;
  Map<String, dynamic>? get latestUnreadCustomerNotice {
    for (final notice in _customerNotices) {
      if (notice['read'] != true) return notice;
    }
    return null;
  }

  bool _quietBooksRefreshing = false;
  bool loading = true;
  String? error;
  bool customerVerified = false;
  Map<String, String> savedCustomer = const {
    'name': '',
    'phone': '',
    'address': '',
  };

  List<ShopOrder> get localOrders => List.unmodifiable(_localOrders);
  List<Book> get books => List.unmodifiable(_books);
  List<Map<String, dynamic>> get bundles => List.unmodifiable(_bundles);
  Map<String, dynamic> get storeNotice => Map.unmodifiable(_storeNotice);
  bool get storeNoticeEnabled => _storeNotice['enabled'] == true &&
      (_storeNotice['message'] ?? '').toString().trim().isNotEmpty;
  String get storeNoticeTitle => (_storeNotice['title'] ?? 'MUHIM MA’LUMOT').toString();
  String get storeNoticeMessage => (_storeNotice['message'] ?? '').toString();
  Set<String> get favorites => Set.unmodifiable(_favorites);
  bool isRestockSubscribed(Book book) =>
      _restockSubscriptions.contains(book.id);
  BackendService? get backend => _backend;
  bool get isOnlineBackend => _backend != null;
  String get dataModeLabel =>
      isOnlineBackend ? 'Onlayn baza' : 'Qurilmada saqlanadi';

  Future<void> initialize() async {
    if (!_lifecycleObserverRegistered) {
      WidgetsBinding.instance.addObserver(this);
      _lifecycleObserverRegistered = true;
    }
    if (backendConfigured) {
      _backend = BackendService(Supabase.instance.client);
    }

    // Eng muhim narsa — katalogni birinchi paint uchun imkon qadar tez tayyorlash.
    // Avval faqat kitob cache'ini o‘qiymiz; qolgan profil/savat/bildirishnoma
    // ma'lumotlari keyinroq parallel yuklanadi.
    List<Book> cachedBooks = const <Book>[];
    try {
      cachedBooks = await _local.loadBooks();
    } catch (_) {}

    if (cachedBooks.isNotEmpty) {
      _books
        ..clear()
        ..addAll(cachedBooks);
    } else {
      try {
        final seed = await _loadTelegramSeed();
        if (seed.isNotEmpty) {
          _books
            ..clear()
            ..addAll(seed);
        }
      } catch (_) {}
    }

    _touchCatalog();
    _scheduleDiscountExpiryRefresh();
    loading = false;
    notifyListeners();

    // Qolgan lokal holat storefront allaqachon ko‘ringandan keyin yuklanadi.
    final secondary = await Future.wait<Object?>([
      _local.loadFavorites(),
      _local.loadRestockSubscriptions(),
      _local.loadCart(),
      _local.loadCartBundles(),
      _local.loadCustomer(),
      _local.loadCustomerVerified(),
      _local.loadOrders(),
      _local.loadCustomerNotices(),
      _local.loadCatalogCursor(),
    ]);

    _favorites
      ..clear()
      ..addAll(secondary[0] as Set<String>);
    _restockSubscriptions
      ..clear()
      ..addAll(secondary[1] as Set<String>);
    _cart
      ..clear()
      ..addAll(secondary[2] as Map<String, int>);
    _cartBundleIds
      ..clear()
      ..addAll(secondary[3] as List<String>);
    savedCustomer = secondary[4] as Map<String, String>;
    final storedVerification = secondary[5] as bool?;
    _localOrders
      ..clear()
      ..addAll(secondary[6] as List<ShopOrder>);
    _customerNotices
      ..clear()
      ..addAll(secondary[7] as List<Map<String, dynamic>>);
    _catalogCursor = secondary[8] as String;

    if (storedVerification == null) {
      final legacyName = (savedCustomer['name'] ?? '').trim();
      final legacyPhone = (savedCustomer['phone'] ?? '').replaceAll(
        RegExp(r'\\D'),
        '',
      );
      customerVerified = legacyName.length >= 2 && legacyPhone.length >= 9;
      if (customerVerified) {
        unawaited(_local.saveCustomerVerified(true));
      }
    } else {
      customerVerified = storedVerification;
    }

    _sanitizeCart();
    notifyListeners();

    if (_backend == null) {
      if (_books.isEmpty) {
        await _initializeLocalCatalog();
      }
      return;
    }

    unawaited(_registerInstallation());
    unawaited(refreshBundles());
    unawaited(refreshStoreNotice());

    // Live narx va qoldiqni UI'ni bloklamasdan yangilaymiz.
    unawaited(_refreshBooksQuietly());
    _startLiveBooksSync();
    unawaited(_checkRestockNotificationsQuietly());
    unawaited(refreshCustomerPushMessages());
    unawaited(_refreshCustomerOrderStatusesQuietly());
    _orderStatusTimer?.cancel();
    _orderStatusTimer = Timer.periodic(
      const Duration(seconds: 60),
      (_) => _refreshCustomerOrderStatusesQuietly(),
    );
  }

  Future<void> _registerInstallation() async {
    try {
      final id = await _local.installId();
      final platform = kIsWeb ? 'web' : defaultTargetPlatform.name;
      await _backend?.registerInstallation(id, platform);
    } catch (_) {
      // Analytics must never slow or block shopping.
    }
  }

  Future<void> setAuthenticatedCustomer(
    String name,
    String phone, {
    bool verified = true,
  }) async {
    final cleanName = name.trim();
    final cleanPhone = phone.trim();
    savedCustomer = {
      'name': cleanName.isEmpty ? (savedCustomer['name'] ?? '') : cleanName,
      'phone': cleanPhone.isEmpty ? (savedCustomer['phone'] ?? '') : cleanPhone,
      'address': savedCustomer['address'] ?? '',
    };
    await _local.saveCustomer(
      savedCustomer['name'] ?? '',
      savedCustomer['phone'] ?? '',
      savedCustomer['address'] ?? '',
    );
    customerVerified = verified;
    await _local.saveCustomerVerified(verified);
    notifyListeners();
  }

  Future<void> signOutCustomer() async {
    // Profil lokal qurilmada saqlanadi. Uni tarmoq javobini kutmasdan darhol
    // tozalaymiz, shuning uchun tugma internet sust bo‘lsa ham ishlaydi.
    savedCustomer = const {'name': '', 'phone': '', 'address': ''};
    customerVerified = false;
    await _local.clearCustomer();
    notifyListeners();

    if (backendConfigured) {
      unawaited(Supabase.instance.client.auth.signOut().catchError((_) {}));
    }
  }

  void _startLiveBooksSync() {
    if (_backend == null || _booksFallbackTimer != null) return;

    // Mijoz roli tannarx (cost_price) ustunini o‘qimaydi. Katalogni faqat
    // public ustunlar bilan muntazam yangilaymiz; checkout baribir buyurtma
    // tugmasida live stockni serverdan qayta tekshiradi.
    // Full katalogni qayta-qayta yuklamaymiz. Har 2 daqiqada serverdan
    // faqat o'zgargan kitoblar va o'chirilgan IDlar olinadi. Checkout paytida
    // ombor baribir serverda live tekshiriladi, shuning uchun sotuv xavfsiz qoladi.
    _booksFallbackTimer = Timer.periodic(const Duration(minutes: 2), (_) {
      unawaited(_refreshBooksQuietly());
      unawaited(_checkRestockNotificationsQuietly());
      unawaited(refreshCustomerPushMessages());
    });
  }

  String _catalogStamp(Iterable<Book> items) => items
      .map(
        (b) => [
          b.id,
          b.title,
          b.author,
          b.publisher,
          b.category,
          b.description,
          b.price,
          b.stock,
          b.discountPercent,
          b.discountEndsAt?.toUtc().toIso8601String() ?? '',
          b.discountFreeDelivery,
          b.imageUrl,
          b.galleryImages.join('↕'),
          b.isActive,
          b.coverType,
          b.costPrice,
          b.recommended,
          b.preorderEnabled,
        ].join('¦'),
      )
      .join('§');

  Future<void> _refreshBooksQuietly() async {
    if (_backend == null || _quietBooksRefreshing) return;
    _quietBooksRefreshing = true;
    try {
      final delta = await _backend!.fetchCatalogDelta(_catalogCursor);
      final serverTime = (delta['server_time'] ?? '').toString().trim();
      if (serverTime.isEmpty) return;

      final isInitialSync = _catalogCursor.startsWith('1970-01-01');
      final byId = <String, Book>{
        if (!isInitialSync)
          for (final book in _books) book.id: book,
      };

      final deletedRaw = delta['deleted_ids'];
      if (deletedRaw is List) {
        for (final id in deletedRaw) {
          byId.remove(id.toString());
        }
      }

      final upsertsRaw = delta['upserts'];
      if (upsertsRaw is List) {
        for (final raw in upsertsRaw.whereType<Map>()) {
          final book = Book.fromMap(Map<String, dynamic>.from(raw));
          if (book.id.isEmpty) continue;
          if (book.isActive) {
            byId[book.id] = book;
          } else {
            byId.remove(book.id);
          }
        }
      }

      final merged = byId.values.toList()
        ..sort((a, b) {
          final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          return bTime.compareTo(aTime);
        });

      final changed = _catalogStamp(merged) != _catalogStamp(_books);
      _catalogCursor = serverTime;
      unawaited(_local.saveCatalogCursor(_catalogCursor));

      if (!changed) return;
      _books
        ..clear()
        ..addAll(merged);
      _sanitizeCart();
      _touchCatalog();
      _scheduleDiscountExpiryRefresh();
      notifyListeners();
      // Diskka yozish UI ni kutib turmasin.
      unawaited(_local.saveBooks(_books));
    } catch (_) {
      // Oddiy internet uzilishida ekrandagi oxirgi katalog saqlanadi.
    } finally {
      _quietBooksRefreshing = false;
    }
  }

  Future<void> refreshStoreNotice() async {
    if (_backend == null) return;
    try {
      final notice = await _backend!.fetchStoreNotice();
      _storeNotice = notice;
      notifyListeners();
    } catch (_) {
      // Muhim xabar yuklanmasa savdo jarayoni ishlashda davom etadi.
    }
  }

  Future<void> refreshBundles() async {
    if (_backend == null) return;
    try {
      final rows = await _backend!.fetchBundles();
      _bundles
        ..clear()
        ..addAll(rows);
      notifyListeners();
    } catch (_) {
      // Setlar vaqtincha yuklanmasa katalog ishlashda davom etadi.
    }
  }

  String addBundleToCart(Map<String, dynamic> bundle) {
    final rawItems = bundle['items'];
    if (rawItems is! List || rawItems.isEmpty) return 'Set tarkibi bo‘sh.';
    final additions = <String, int>{};
    for (final raw in rawItems.whereType<Map>()) {
      final item = Map<String, dynamic>.from(raw);
      final id = (item['book_id'] ?? '').toString();
      final qty = (item['quantity'] as num?)?.toInt() ?? 1;
      final book = _books.where((b) => b.id == id).firstOrNull;
      if (book == null || !book.inStock) {
        return '${(item['title'] ?? 'Kitob')} hozir mavjud emas.';
      }
      final next = (_cart[id] ?? 0) + qty;
      if (next > book.stock) return '${book.title} omborda yetarli emas.';
      additions[id] = qty;
    }
    for (final entry in additions.entries) {
      _cart[entry.key] = (_cart[entry.key] ?? 0) + entry.value;
    }
    final bundleId = (bundle['id'] ?? '').toString();
    if (bundleId.isNotEmpty) _cartBundleIds.add(bundleId);
    unawaited(_local.saveCartBundles(_cartBundleIds));
    _persistCart();
    notifyListeners();
    return 'Set savatchaga qo‘shildi ✅';
  }

  Future<String> submitPreorder(
    Book book, {
    required String customerName,
    required String phone,
    required int depositAmount,
    required XFile paymentProof,
    String note = '',
  }) async {
    if (_backend == null) return 'Oldindan buyurtma uchun internet kerak.';
    final min = book.preorderDepositMin;
    final max = book.preorderDepositMax;
    if (depositAmount < min || depositAmount > max) {
      return 'Oldindan to‘lov ₩$min–₩$max oralig‘ida bo‘lishi kerak.';
    }
    final proofPath = await _backend!.uploadPaymentProof(paymentProof);
    final installId = await _local.installId();
    await _backend!.submitPreorder(
      installId,
      book.id,
      customerName,
      phone,
      depositAmount: depositAmount,
      paymentProofPath: proofPath,
      note: note,
    );
    return 'Oldindan buyurtma qabul qilindi ✅';
  }

  Future<String> requestMissingBook(String title) async {
    if (_backend == null) return 'So‘rov yuborish uchun internet kerak.';
    final clean = title.trim();
    if (clean.length < 2) return 'Kitob nomini yozing.';
    final installId = await _local.installId();
    await _backend!.requestMissingBook(installId, clean, phone: savedCustomer['phone'] ?? '');
    return 'So‘rovingiz yuborildi ✅';
  }

  Future<void> recordSearchMiss(String query) async {
    if (_backend == null || query.trim().length < 2) return;
    try { await _backend!.logSearchMiss(await _local.installId(), query.trim()); } catch (_) {}
  }

  Future<String> toggleRestockNotification(Book book) async {
    if (book.inStock) return 'Kitob hozir sotuvda mavjud.';
    if (_backend == null) return 'Xabar berish uchun internet kerak.';

    final installId = await _local.installId();
    if (_restockSubscriptions.contains(book.id)) {
      await _backend!.unsubscribeRestock(installId, book.id);
      _restockSubscriptions.remove(book.id);
      await _local.saveRestockSubscriptions(_restockSubscriptions);
      notifyListeners();
      return 'Xabar berish bekor qilindi.';
    }

    final result = await _backend!.subscribeRestock(installId, book.id);
    if (result['already_available'] == true) {
      await refreshBooks();
      return 'Kitob hozir sotuvda mavjud.';
    }

    _restockSubscriptions.add(book.id);
    await _local.saveRestockSubscriptions(_restockSubscriptions);
    notifyListeners();
    return 'Kitob kelganda sizga xabar beramiz ✅';
  }

  Future<void> _checkRestockNotificationsQuietly() async {
    if (_backend == null ||
        _restockRefreshing ||
        _restockSubscriptions.isEmpty) {
      return;
    }
    _restockRefreshing = true;
    try {
      final installId = await _local.installId();
      final rows = await _backend!.fetchRestockNotifications(installId);
      if (rows.isEmpty) return;

      var changed = false;
      for (final row in rows) {
        final bookId = (row['book_id'] ?? '').toString();
        final title = (row['title'] ?? 'Kitob').toString();
        final at = (row['notified_at'] ?? DateTime.now().toIso8601String())
            .toString();
        final noticeId = 'restock:$bookId:$at';
        if (_customerNotices.any(
          (n) => (n['id'] ?? '').toString() == noticeId,
        )) {
          continue;
        }
        _customerNotices.insert(0, {
          'id': noticeId,
          'status': 'restock',
          'book_id': bookId,
          'title': '📚 Kitob yana sotuvda!',
          'message': '$title yana mavjud. Hozir buyurtma berishingiz mumkin.',
          'created_at': at,
          'read': false,
        });
        _restockSubscriptions.remove(bookId);
        changed = true;
      }
      if (!changed) return;
      if (_customerNotices.length > 50) {
        _customerNotices.removeRange(50, _customerNotices.length);
      }
      await Future.wait([
        _local.saveCustomerNotices(_customerNotices),
        _local.saveRestockSubscriptions(_restockSubscriptions),
      ]);
      notifyListeners();
    } catch (_) {
      // Network error should not block shopping.
    } finally {
      _restockRefreshing = false;
    }
  }

  Future<void> refreshCustomerPushMessages() async {
    if (_backend == null || _pushMessagesRefreshing) return;
    _pushMessagesRefreshing = true;
    try {
      final rows = await _backend!.fetchPushMessages(limit: 50);
      if (rows.isEmpty) return;

      final existingIds = _customerNotices
          .map((n) => (n['id'] ?? '').toString())
          .toSet();
      var changed = false;

      for (final row in rows) {
        final rawId = (row['id'] ?? '').toString().trim();
        if (rawId.isEmpty) continue;
        final noticeId = 'push:$rawId';
        if (existingIds.contains(noticeId)) continue;

        _customerNotices.add({
          'id': noticeId,
          'status': 'push',
          'title': (row['title'] ?? 'Muhajeer Books').toString(),
          'message': (row['body'] ?? '').toString(),
          'created_at':
              (row['sent_at'] ?? DateTime.now().toIso8601String()).toString(),
          'read': false,
        });
        existingIds.add(noticeId);
        changed = true;
      }

      if (!changed) return;
      _customerNotices.sort((a, b) {
        final aAt = DateTime.tryParse((a['created_at'] ?? '').toString()) ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final bAt = DateTime.tryParse((b['created_at'] ?? '').toString()) ??
            DateTime.fromMillisecondsSinceEpoch(0);
        return bAt.compareTo(aAt);
      });
      if (_customerNotices.length > 50) {
        _customerNotices.removeRange(50, _customerNotices.length);
      }
      await _local.saveCustomerNotices(_customerNotices);
      notifyListeners();
    } catch (_) {
      // Push ruxsati bo'lmasa ham in-app inbox ishlashi kerak.
    } finally {
      _pushMessagesRefreshing = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(refreshCustomerPushMessages());
      unawaited(_refreshCustomerOrderStatusesQuietly());
      unawaited(_checkRestockNotificationsQuietly());
    }
  }

  @override
  void dispose() {
    if (_lifecycleObserverRegistered) {
      WidgetsBinding.instance.removeObserver(this);
      _lifecycleObserverRegistered = false;
    }
    _booksFallbackTimer?.cancel();
    _orderStatusTimer?.cancel();
    _discountExpiryTimer?.cancel();
    super.dispose();
  }

  Future<void> _initializeLocalCatalog() async {
    loading = true;
    notifyListeners();
    try {
      var localBooks = await _local.loadBooks();
      final version = await _local.seedVersion();
      if (version < telegramSeedVersion) {
        final seed = await _loadTelegramSeed();
        final custom = localBooks
            .where(
              (b) => !b.id.startsWith('demo-') && !b.id.startsWith('telegram-'),
            )
            .toList();
        final existingTitles = <String>{};
        final merged = <Book>[];
        for (final book in [...seed, ...custom]) {
          final key = _normalize(book.title);
          if (existingTitles.add(key)) merged.add(book);
        }
        localBooks = merged;
        await _local.saveBooks(localBooks);
        await _local.setSeedVersion(telegramSeedVersion);
      }
      _books
        ..clear()
        ..addAll(localBooks.isEmpty ? await _loadTelegramSeed() : localBooks);
      if (localBooks.isEmpty) await _local.saveBooks(_books);
      _sanitizeCart();
    } catch (e) {
      error = e.toString();
      _books
        ..clear()
        ..addAll(await _loadTelegramSeed());
    } finally {
      _touchCatalog();
      loading = false;
      notifyListeners();
    }
  }

  Future<List<Book>> _loadTelegramSeed() async {
    final raw = await rootBundle.loadString('assets/data/migrated_books.json');
    return (jsonDecode(raw) as List)
        .map((e) => Book.fromSeed(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> refreshBooks({bool includeInactive = false}) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      if (_backend != null) {
        final fresh = await _backend!.fetchBooks(
          includeInactive: includeInactive,
        );
        _books
          ..clear()
          ..addAll(fresh);
        await _local.saveBooks(_books);
      } else {
        _books
          ..clear()
          ..addAll(await _local.loadBooks());
      }
      _sanitizeCart();
    } catch (e) {
      error = e.toString();
      if (_books.isEmpty) {
        final cached = await _local.loadBooks();
        if (cached.isNotEmpty) {
          _books
            ..clear()
            ..addAll(cached);
          _sanitizeCart();
        } else {
          try {
            final seed = await _loadTelegramSeed();
            if (seed.isNotEmpty) {
              _books
                ..clear()
                ..addAll(seed);
              _sanitizeCart();
            }
          } catch (_) {}
        }
      }
    } finally {
      _touchCatalog();
      _scheduleDiscountExpiryRefresh();
      loading = false;
      notifyListeners();
    }
  }

  List<CartLine> get cartLines {
    final byId = {for (final b in _books) b.id: b};
    return _cart.entries
        .where((e) => byId[e.key] != null && e.value > 0)
        .map((e) => CartLine(book: byId[e.key]!, quantity: e.value))
        .toList();
  }

  int get cartCount => _cart.values.fold(0, (a, b) => a + b);

  List<Map<String, dynamic>> get cartBundles {
    final result = <Map<String, dynamic>>[];
    for (final id in _cartBundleIds) {
      for (final bundle in _bundles) {
        if ((bundle['id'] ?? '').toString() == id) {
          result.add(bundle);
          break;
        }
      }
    }
    return result;
  }

  List<CartLine> get cartStandaloneLines {
    final remaining = Map<String, int>.from(_cart);
    for (final bundle in cartBundles) {
      for (final raw in ((bundle['items'] as List?) ?? const []).whereType<Map>()) {
        final item = Map<String, dynamic>.from(raw);
        final id = (item['book_id'] ?? '').toString();
        final qty = (item['quantity'] as num?)?.toInt() ?? 1;
        final left = (remaining[id] ?? 0) - qty;
        if (left > 0) {
          remaining[id] = left;
        } else {
          remaining.remove(id);
        }
      }
    }
    final byId = {for (final b in _books) b.id: b};
    return remaining.entries
        .where((e) => e.value > 0 && byId[e.key] != null)
        .map((e) => CartLine(book: byId[e.key]!, quantity: e.value))
        .toList();
  }

  int get cartDisplayCount =>
      cartBundles.length +
      cartStandaloneLines.fold(0, (sum, line) => sum + line.quantity);

  // Set ichidagi kitoblar 4+ bepul yetkazish aksiyasiga hisoblanmaydi.
  // Setning pochtasi faqat admin belgilagan delivery_included qiymatiga bog‘liq.
  int get cartStandaloneBookCount =>
      cartStandaloneLines.fold(0, (sum, line) => sum + line.quantity);

  int get cartBundleDiscount {
    var saving = 0;
    for (final id in _cartBundleIds) {
      Map<String, dynamic>? bundle;
      for (final candidate in _bundles) {
        if ((candidate['id'] ?? '').toString() == id) {
          bundle = candidate;
          break;
        }
      }
      if (bundle == null) continue;
      final setPrice = (bundle['price'] as num?)?.toInt() ?? 0;
      var liveTotal = 0;
      for (final raw in ((bundle['items'] as List?) ?? const []).whereType<Map>()) {
        final item = Map<String, dynamic>.from(raw);
        final bookId = (item['book_id'] ?? '').toString();
        final qty = (item['quantity'] as num?)?.toInt() ?? 1;
        for (final book in _books) {
          if (book.id == bookId) {
            liveTotal += book.currentPrice * qty;
            break;
          }
        }
      }
      if (liveTotal > setPrice) saving += liveTotal - setPrice;
    }
    final raw = cartLines.fold(0, (a, b) => a + b.total);
    return saving.clamp(0, raw).toInt();
  }

  bool get cartBundleDeliveryIncluded {
    for (final id in _cartBundleIds) {
      for (final bundle in _bundles) {
        if ((bundle['id'] ?? '').toString() == id &&
            bundle['delivery_included'] == true) return true;
      }
    }
    return false;
  }

  List<Map<String, dynamic>> get cartBundleSelections =>
      _cartBundleIds.map((id) => {'bundle_id': id}).toList();

  // Savat jami set ichidagi kitoblarning alohida narxidan hisoblanmaydi.
  // Har bir set uchun admin belgilagan set narxi aynan olinadi; setdan tashqari
  // kitoblar esa odatdagi joriy narxida qo‘shiladi.
  int get cartBundleSubtotal {
    var total = 0;
    for (final bundle in cartBundles) {
      total += (bundle['price'] as num?)?.toInt() ?? 0;
    }
    return total;
  }

  int get cartStandaloneSubtotal =>
      cartStandaloneLines.fold(0, (sum, line) => sum + line.total);

  int get cartSubtotal => cartBundleSubtotal + cartStandaloneSubtotal;

  // 4+ qoidasida bitta set — ichida nechta kitob bo‘lishidan qat’i nazar —
  // savatda 1 ta mahsulot hisoblanadi. Set + 3 ta alohida kitob = 4 ta.
  // Agar istalgan setga admin "pochta set narxiga kiritilgan" deb belgilagan
  // bo‘lsa, shu savat uchun yana pochta puli olinmaydi.
  int get cartDeliveryFee =>
      cartBundleDeliveryIncluded ||
              (cartDisplayCount >= 4 && fourPlusFreeDeliveryEnabled)
          ? 0
          : deliveryFee;

  void addToCart(Book book) {
    if (!book.inStock) return;
    final current = _cart[book.id] ?? 0;
    if (current < book.stock) {
      _cart[book.id] = current + 1;
      _persistCart();
      notifyListeners();
    }
  }

  void decrementCart(Book book) {
    // Bu tugma faqat setdan tashqari qatorlarda ko‘rinadi. Alohida kitob
    // miqdorini o‘zgartirish savatdagi setlarni bekor qilmasligi kerak.
    final current = _cart[book.id] ?? 0;
    if (current <= 1) {
      _cart.remove(book.id);
    } else {
      _cart[book.id] = current - 1;
    }
    _persistCart();
    notifyListeners();
  }

  void removeFromCart(Book book) {
    // Alohida kitobni o‘chirish set narxi va setning pochta sozlamasiga
    // tegmasin.
    _cart.remove(book.id);
    _persistCart();
    notifyListeners();
  }

  void removeBundleFromCart(Map<String, dynamic> bundle) {
    final bundleId = (bundle['id'] ?? '').toString();
    final index = _cartBundleIds.indexOf(bundleId);
    if (index < 0) return;
    for (final raw in ((bundle['items'] as List?) ?? const []).whereType<Map>()) {
      final item = Map<String, dynamic>.from(raw);
      final id = (item['book_id'] ?? '').toString();
      final qty = (item['quantity'] as num?)?.toInt() ?? 1;
      final left = (_cart[id] ?? 0) - qty;
      if (left > 0) {
        _cart[id] = left;
      } else {
        _cart.remove(id);
      }
    }
    _cartBundleIds.removeAt(index);
    unawaited(_local.saveCartBundles(_cartBundleIds));
    _persistCart();
    notifyListeners();
  }

  void clearCart() {
    _cartBundleIds.clear();
    unawaited(_local.saveCartBundles(_cartBundleIds));
    _cart.clear();
    _persistCart();
    notifyListeners();
  }

  void toggleFavorite(Book book) {
    if (!_favorites.add(book.id)) _favorites.remove(book.id);
    _local.saveFavorites(_favorites);
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
        ? book.copyWith(
            id: 'local-${DateTime.now().microsecondsSinceEpoch}',
            createdAt: DateTime.now(),
          )
        : book;
    final index = _books.indexWhere((b) => b.id == saved.id);
    if (index == -1) {
      _books.insert(0, saved);
    } else {
      _books[index] = saved;
    }
    _touchCatalog();
    await _local.saveBooks(_books);
    notifyListeners();
  }

  Future<void> deleteBook(Book book) async {
    if (_backend != null &&
        !book.id.startsWith('local-') &&
        !book.id.startsWith('telegram-')) {
      await _backend!.deleteBook(book.id);
      await refreshBooks(includeInactive: true);
      return;
    }
    _books.removeWhere((b) => b.id == book.id);
    _touchCatalog();
    _cart.remove(book.id);
    _favorites.remove(book.id);
    await Future.wait([
      _local.saveBooks(_books),
      _local.saveCart(_cart),
      _local.saveFavorites(_favorites),
    ]);
    notifyListeners();
  }

  Future<void> applyDiscountToAll(int percent) async {
    final safe = percent.clamp(0, 99).toInt();
    if (_backend != null) {
      await _backend!.applyDiscountToAll(safe);
      await refreshBooks(includeInactive: true);
      return;
    }
    for (var i = 0; i < _books.length; i++) {
      _books[i] = _books[i].copyWith(discountPercent: safe);
    }
    _touchCatalog();
    await _local.saveBooks(_books);
    notifyListeners();
  }

  Future<void> clearAllDiscounts() => applyDiscountToAll(0);

  Future<String> uploadCover(XFile file) async {
    if (_backend == null) return '';
    return _backend!.uploadCover(file);
  }

  Future<String> placeOrder({
    required String customerName,
    required String phone,
    required String address,
    required String deliveryType,
    required int deliveryFee,
    XFile? paymentProof,
  }) async {
    final lines = cartLines;
    if (lines.isEmpty) throw StateError('Savatcha bo‘sh.');
    for (final line in lines) {
      if (line.quantity > line.book.stock) {
        throw StateError('${line.book.title} omborda yetarli emas.');
      }
    }

    if (_backend != null && paymentProof == null) {
      throw StateError('To‘lov chekini tanlang.');
    }

    final subtotal = cartSubtotal;
    final isGyeongsanPickup = deliveryType == '경산 직접수령';
    final safeDeliveryFee =
        isGyeongsanPickup ? 0 : cartDeliveryFee;
    final total = subtotal + safeDeliveryFee;
    await _local.saveCustomer(
      customerName.trim(),
      phone.trim(),
      address.trim(),
    );
    savedCustomer = {
      'name': customerName.trim(),
      'phone': phone.trim(),
      'address': address.trim(),
    };

    var paymentProofPath = '';
    if (paymentProof != null) {
      paymentProofPath = _backend != null
          ? await _backend!.uploadPaymentProof(paymentProof)
          : 'local:${paymentProof.name}';
    }

    final now = DateTime.now();
    final items = lines.map(BackendService._lineToMap).toList();

    if (_backend != null) {
      final id = await _backend!.createOrder(
        customerName: customerName,
        phone: phone,
        address: address,
        deliveryType: deliveryType,
        deliveryFee: safeDeliveryFee,
        subtotal: subtotal,
        total: total,
        lines: lines,
        bundleSelections: cartBundleSelections,
        paymentProofPath: paymentProofPath,
      );

      final receipt = ShopOrder(
        id: id,
        customerName: customerName.trim(),
        phone: phone.trim(),
        address: address.trim(),
        deliveryType: deliveryType,
        deliveryFee: safeDeliveryFee,
        subtotal: subtotal,
        total: total,
        status: 'new',
        items: items,
        createdAt: now,
        paymentProofPath: paymentProofPath,
        paymentSubmittedAt: paymentProofPath.isEmpty ? null : now,
        stockReserved: true,
      );
      _localOrders.removeWhere((o) => o.id == id);
      _localOrders.insert(0, receipt);
      _cart.clear();
      _cartBundleIds.clear();
      await Future.wait([
        _local.saveOrders(_localOrders),
        _local.saveCart(_cart),
        _local.saveCartBundles(_cartBundleIds),
      ]);
      // Buyurtmadan keyin butun katalogni emas, faqat ombori o'zgargan
      // kitoblarni delta orqali yangilaymiz.
      await _refreshBooksQuietly();
      return id;
    }

    final id = 'MB-${now.millisecondsSinceEpoch.toString().substring(5)}';
    final order = ShopOrder(
      id: id,
      customerName: customerName.trim(),
      phone: phone.trim(),
      address: address.trim(),
      deliveryType: deliveryType,
      deliveryFee: safeDeliveryFee,
      subtotal: subtotal,
      total: total,
      status: 'new',
      items: items,
      createdAt: now,
      paymentProofPath: paymentProofPath,
      paymentSubmittedAt: paymentProofPath.isEmpty ? null : now,
      stockReserved: false,
    );

    _localOrders.insert(0, order);
    _cart.clear();
    _cartBundleIds.clear();
    await Future.wait([
      _local.saveOrders(_localOrders),
      _local.saveCart(_cart),
      _local.saveCartBundles(_cartBundleIds),
    ]);
    notifyListeners();
    return id;
  }

  Future<List<ShopOrder>> fetchOrders() async {
    if (_backend != null) return _backend!.fetchOrders();
    _localOrders
      ..clear()
      ..addAll(await _local.loadOrders());
    return List.unmodifiable(_localOrders);
  }

  Future<void> updateOrderStatus(String id, String status) async {
    if (_backend != null) {
      await _backend!.updateOrderStatus(id, status);
      await refreshBooks(includeInactive: true);
      return;
    }
    final index = _localOrders.indexWhere((o) => o.id == id);
    if (index < 0) return;
    final old = _localOrders[index];
    if (old.status == 'cancelled' && status != 'cancelled') {
      throw StateError('Bekor qilingan buyurtmani qayta ochib bo‘lmaydi.');
    }

    final shouldReserve = [
      'accepted',
      'paid',
      'shipping',
      'done',
    ].contains(status);
    var reserved = old.stockReserved;

    if (shouldReserve && !reserved) {
      if (!_canReserveLocalStock(old.items)) {
        throw StateError('Buyurtmani qabul qilish uchun ombor yetarli emas.');
      }
      _reserveLocalStock(old.items);
      reserved = true;
    } else if (status == 'cancelled' && reserved) {
      _restoreLocalStock(old.items);
      reserved = false;
    }

    _localOrders[index] = old.copyWith(status: status, stockReserved: reserved);
    _touchCatalog();
    await Future.wait([
      _local.saveOrders(_localOrders),
      _local.saveBooks(_books),
    ]);
    notifyListeners();
  }

  Future<void> resetLocalCatalogFromTelegram() async {
    if (_backend != null) return;
    _books
      ..clear()
      ..addAll(await _loadTelegramSeed());
    _touchCatalog();
    _cart.clear();
    _favorites.clear();
    await Future.wait([
      _local.saveBooks(_books),
      _local.saveCart(_cart),
      _local.saveFavorites(_favorites),
      _local.setSeedVersion(telegramSeedVersion),
    ]);
    notifyListeners();
  }

  Future<List<ShopOrder>> customerOrdersByPhone(String phone) async {
    final key = _customerPhoneKey(phone);
    if (key.isEmpty) return [];

    _localOrders
      ..clear()
      ..addAll(await _local.loadOrders());

    if (_backend != null && _localOrders.isNotEmpty) {
      try {
        final uuidIds = _localOrders
            .where(
              (o) =>
                  !const {'shipping', 'done', 'cancelled'}.contains(o.status),
            )
            .map((o) => o.id)
            .where((id) => RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(id))
            .toList();
        final statuses = await _backend!.fetchOrderStatuses(uuidIds);
        for (var i = 0; i < _localOrders.length; i++) {
          final row = statuses[_localOrders[i].id];
          if (row == null) continue;
          _localOrders[i] = _localOrders[i].copyWith(
            status: (row['status'] ?? _localOrders[i].status).toString(),
            stockReserved:
                row['stock_reserved'] as bool? ?? _localOrders[i].stockReserved,
          );
        }
        await _local.saveOrders(_localOrders);
      } catch (_) {
        // Temporary network failure: keep the last known local order history.
      }
    }

    return _localOrders
        .where((o) => _customerPhoneKey(o.phone) == key)
        .toList();
  }

  Future<int> restoreCustomerOrders({
    required String phone,
    required String recoveryCode,
  }) async {
    if (_backend == null) {
      throw StateError('Buyurtmalarni tiklash uchun internet kerak.');
    }

    final restored = await _backend!.restoreOrders(
      phone: phone,
      recoveryCode: recoveryCode,
    );
    if (restored.isEmpty) return 0;

    final merged = <String, ShopOrder>{
      for (final order in _localOrders) order.id: order,
      for (final order in restored) order.id: order,
    };
    final sorted = merged.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    _localOrders
      ..clear()
      ..addAll(sorted.take(100));

    final cleanPhone = phone.trim();
    savedCustomer = {
      'name': savedCustomer['name'] ?? '',
      'phone': cleanPhone,
      'address': savedCustomer['address'] ?? '',
    };
    await Future.wait([
      _local.saveOrders(_localOrders),
      _local.saveCustomer(
        savedCustomer['name'] ?? '',
        cleanPhone,
        savedCustomer['address'] ?? '',
      ),
    ]);
    notifyListeners();
    return restored.length;
  }

  Future<void> markCustomerNoticesRead() async {
    var changed = false;
    for (final notice in _customerNotices) {
      if (notice['read'] != true) {
        notice['read'] = true;
        changed = true;
      }
    }
    if (!changed) return;
    await _local.saveCustomerNotices(_customerNotices);
    notifyListeners();
  }

  Future<void> _refreshCustomerOrderStatusesQuietly() async {
    if (_backend == null || _localOrders.isEmpty || _orderStatusRefreshing) {
      return;
    }
    _orderStatusRefreshing = true;
    try {
      final uuidIds = _localOrders
          .where(
            (o) => !const {'shipping', 'done', 'cancelled'}.contains(o.status),
          )
          .map((o) => o.id)
          .where((id) => RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(id))
          .toList();
      if (uuidIds.isEmpty) return;
      final statuses = await _backend!.fetchOrderStatuses(uuidIds);
      var ordersChanged = false;
      var noticesChanged = false;
      for (var i = 0; i < _localOrders.length; i++) {
        final oldOrder = _localOrders[i];
        final row = statuses[oldOrder.id];
        if (row == null) continue;
        final newStatus = (row['status'] ?? oldOrder.status).toString();
        final newReserved =
            row['stock_reserved'] as bool? ?? oldOrder.stockReserved;
        if (newStatus == oldOrder.status &&
            newReserved == oldOrder.stockReserved) {
          continue;
        }
        _localOrders[i] = oldOrder.copyWith(
          status: newStatus,
          stockReserved: newReserved,
        );
        ordersChanged = true;

        if (newStatus != oldOrder.status &&
            const {
              'accepted',
              'paid',
              'shipping',
              'cancelled',
            }.contains(newStatus)) {
          final noticeId = '${oldOrder.id}:$newStatus';
          final exists = _customerNotices.any(
            (n) => (n['id'] ?? '').toString() == noticeId,
          );
          if (!exists) {
            _customerNotices.insert(0, {
              'id': noticeId,
              'order_id': oldOrder.id,
              'status': newStatus,
              'title': switch (newStatus) {
                'accepted' => '✅ Buyurtmangiz qabul qilindi',
                'paid' => '💳 To‘lovingiz tasdiqlandi',
                'shipping' => '🚚 Buyurtmangiz pochtaga topshirildi',
                'cancelled' => '❌ Buyurtmangiz bekor qilindi',
                _ => 'Buyurtma yangilandi',
              },
              'message': switch (newStatus) {
                'accepted' => 'Buyurtmangiz tasdiqlandi va tayyorlanmoqda.',
                'paid' => 'To‘lov tekshirildi. Buyurtmangiz tayyorlanmoqda.',
                'shipping' => 'Buyurtmangiz pochtaga topshirildi. 1–3 ish kunida yetkaziladi.',
                'cancelled' => 'Buyurtma bekor qilindi. Savol bo‘lsa Muhajeer Books bilan bog‘laning.',
                _ => 'Buyurtmangiz holati yangilandi.',
              },
              'created_at': DateTime.now().toIso8601String(),
              'read': false,
            });
            noticesChanged = true;
          }
        }
      }
      if (_customerNotices.length > 50) {
        _customerNotices.removeRange(50, _customerNotices.length);
        noticesChanged = true;
      }
      if (ordersChanged) await _local.saveOrders(_localOrders);
      if (noticesChanged) {
        await _local.saveCustomerNotices(_customerNotices);
      }
      if (ordersChanged || noticesChanged) notifyListeners();
    } catch (_) {
      // A temporary network failure must not break the customer UI.
    } finally {
      _orderStatusRefreshing = false;
    }
  }

  void _sanitizeCart() {
    final byId = {for (final b in _books) b.id: b};
    _cart.removeWhere((id, qty) => byId[id] == null || qty <= 0);
    for (final entry in _cart.entries.toList()) {
      final stock = byId[entry.key]!.stock;
      if (entry.value > stock) _cart[entry.key] = stock;
      if ((_cart[entry.key] ?? 0) <= 0) _cart.remove(entry.key);
    }
    _persistCart();
  }

  bool _canReserveLocalStock(List<Map<String, dynamic>> items) {
    for (final item in items) {
      final id = (item['book_id'] ?? '').toString();
      final qty = (item['quantity'] as num?)?.toInt() ?? 0;
      final book = _books.where((b) => b.id == id).firstOrNull;
      if (book == null || book.stock < qty) return false;
    }
    return true;
  }

  void _reserveLocalStock(List<Map<String, dynamic>> items) {
    for (final item in items) {
      final id = (item['book_id'] ?? '').toString();
      final qty = (item['quantity'] as num?)?.toInt() ?? 0;
      final index = _books.indexWhere((b) => b.id == id);
      if (index >= 0)
        _books[index] = _books[index].copyWith(
          stock: _books[index].stock - qty,
        );
    }
  }

  void _restoreLocalStock(List<Map<String, dynamic>> items) {
    for (final item in items) {
      final id = (item['book_id'] ?? '').toString();
      final qty = (item['quantity'] as num?)?.toInt() ?? 0;
      final index = _books.indexWhere((b) => b.id == id);
      if (index >= 0)
        _books[index] = _books[index].copyWith(
          stock: _books[index].stock + qty,
        );
    }
  }

  void _persistCart() => _local.saveCart(_cart);

  static String _customerPhoneKey(String raw) {
    var digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('00')) digits = digits.substring(2);
    if (digits.length == 12 && digits.startsWith('998')) return digits;
    if (digits.length == 9 && !digits.startsWith('0')) return '998$digits';
    if (digits.length == 11 && digits.startsWith('010')) {
      return '82${digits.substring(1)}';
    }
    if (digits.length == 12 && digits.startsWith('8210')) return digits;
    return '';
  }

  static String _normalize(String input) => input
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9а-яёўқғҳ]+', unicode: true), '')
      .trim();
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
