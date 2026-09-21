import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:local_auth/local_auth.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'admin_session.dart';
import 'app_state.dart';
import 'brand.dart';
import 'book_story_page.dart';
import 'design_system.dart';
import 'finance_admin.dart';
import 'catalog_resume.dart';
import 'admin_resume_session.dart';

const _navy = Color(0xFF10213D);
const _orange = Color(0xFFFF8A00);
final _money = NumberFormat('#,###', 'en_US');
String _won(int value) => '₩${_money.format(value)}';
const Set<String> _canonicalBookCategories = {
  'Badiiy adabiyot','Biznes va moliya','Bolalar adabiyoti','Diniy-ma’rifiy',
  'Islom tarixi','Jahon adabiyoti','Jamiyat va kommunikatsiya','O‘zbek adabiyoti',
  'Oila va nikoh','Psixologiya va shaxsiy rivojlanish','Qur’on va islom ilmlari',
  'Ta’lim va tillar','Tarix va biografiya','Texnologiya','Tibbiyot va jamiyat',
};

String _validatedAiBookCategory(dynamic value) {
  final raw=(value??'').toString().trim();
  final key=raw.toLowerCase().replaceAll(RegExp(r"[’ʻ‘']"), '');
  for(final category in _canonicalBookCategories) {
    if(category.toLowerCase().replaceAll(RegExp(r"[’ʻ‘']"), '')==key) return category;
  }
  return '';
}


class _UploadedBookImage {
  const _UploadedBookImage({required this.url, required this.thumbnailUrl});
  final String url;
  final String thumbnailUrl;
}

img.Image _resizeWithin(img.Image source, int maxWidth, int maxHeight) {
  if (source.width <= maxWidth && source.height <= maxHeight) return source;
  final widthScale = maxWidth / source.width;
  final heightScale = maxHeight / source.height;
  final scale = widthScale < heightScale ? widthScale : heightScale;
  return img.copyResize(
    source,
    width: (source.width * scale).round().clamp(1, maxWidth),
    height: (source.height * scale).round().clamp(1, maxHeight),
    interpolation: img.Interpolation.cubic,
  );
}

Uint8List _encodeJpegTarget(
  img.Image source, {
  required int targetBytes,
  required int startQuality,
  required int minQuality,
}) {
  var quality = startQuality;
  var bytes = Uint8List.fromList(img.encodeJpg(source, quality: quality));
  while (bytes.length > targetBytes && quality > minQuality) {
    quality = (quality - 4).clamp(minQuality, 100);
    bytes = Uint8List.fromList(img.encodeJpg(source, quality: quality));
  }
  return bytes;
}

Map<String, Uint8List>? _prepareBookImageVariants(Uint8List sourceBytes) {
  final decoded = img.decodeImage(sourceBytes);
  if (decoded == null) return null;
  final oriented = img.bakeOrientation(decoded);

  var fullImage = _resizeWithin(oriented, 1200, 1800);
  var fullBytes = _encodeJpegTarget(
    fullImage,
    targetBytes: 220 * 1024,
    startQuality: 76,
    minQuality: 60,
  );
  if (fullBytes.length > 280 * 1024) {
    fullImage = _resizeWithin(fullImage, 1050, 1575);
    fullBytes = _encodeJpegTarget(
      fullImage,
      targetBytes: 240 * 1024,
      startQuality: 72,
      minQuality: 58,
    );
  }

  // 480px thumbnail stays light enough for the Free-plan catalog, while
  // remaining crisp on modern 2x/3x phone screens.
  final thumbImage = _resizeWithin(oriented, 480, 720);
  final thumbBytes = _encodeJpegTarget(
    thumbImage,
    targetBytes: 46 * 1024,
    startQuality: 78,
    minQuality: 60,
  );

  return <String, Uint8List>{'full': fullBytes, 'thumb': thumbBytes};
}

Uint8List? _prepareBookThumbnail(Uint8List sourceBytes) {
  final decoded = img.decodeImage(sourceBytes);
  if (decoded == null) return null;
  final oriented = img.bakeOrientation(decoded);
  final thumbImage = _resizeWithin(oriented, 480, 720);
  return _encodeJpegTarget(
    thumbImage,
    targetBytes: 46 * 1024,
    startQuality: 78,
    minQuality: 60,
  );
}

Map<String, dynamic> _functionResponseMap(dynamic raw) {
  if (raw is Map) return Map<String, dynamic>.from(raw);
  if (raw is String && raw.trim().isNotEmpty) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {
      // Proxy ayrim hollarda JSON javobni string ko‘rinishida qaytaradi.
    }
  }
  return <String, dynamic>{};
}

class _AdminApi {
  _AdminApi(this.secret);
  final String secret;
  SupabaseClient get client => Supabase.instance.client;

  Future<dynamic> _rpc(
    String name, {
    Map<String, dynamic>? params,
  }) async {
    final response = await client.functions.invoke(
      'admin-rpc',
      body: {'name': name, 'params': params ?? <String, dynamic>{}},
    );
    final data = _functionResponseMap(response.data);
    if (data['ok'] != true) {
      throw StateError((data['error'] ?? 'Admin amali bajarilmadi.').toString());
    }
    return data['data'];
  }

  Future<bool> verify() async {
    final result = await _rpc(
      'admin_verify',
      params: {'p_secret': secret},
    );
    return result == true;
  }

  Future<List<Book>> books() async {
    final data = await _rpc(
      'admin_list_books',
      params: {'p_secret': secret},
    );
    return (data as List)
        .map((e) => Book.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> saveBook(Book book) async {
    await _rpc(
      'admin_save_book',
      params: {
        'p_secret': secret,
        'p_id':
            book.id.isEmpty ||
                book.id.startsWith('local-') ||
                book.id.startsWith('telegram-')
            ? null
            : book.id,
        'p_data': {
          'title': book.title,
          'author': book.author,
          'publisher': normalizePublisher(book.publisher),
          'category': book.category,
          'description': book.description,
          'price': book.price,
          'stock': book.stock,
          'discount_percent': book.discountPercent,
          'image_url': book.galleryImages.isEmpty
              ? ''
              : book.galleryImages.first,
          'thumbnail_url': book.thumbnailUrl,
          'image_urls': book.galleryImages,
          'is_active': book.isActive,
          'cover': book.coverType,
          'cost_price': book.costPrice,
          'recommended': book.recommended,
          'preorder_enabled': book.preorderEnabled,
          'preorder_arrival_note': book.preorderArrivalNote,
          'preorder_deposit_min': book.preorderDepositMin,
          'preorder_deposit_max': book.preorderDepositMax,
        },
      },
    );
  }

  Future<_UploadedBookImage> uploadCover(XFile file) async {
    final sourceBytes = await file.readAsBytes();
    if (sourceBytes.isEmpty) throw StateError('Rasm bo‘sh.');
    if (sourceBytes.length > 20 * 1024 * 1024) {
      throw StateError('Rasm hajmi 20 MB dan kichik bo‘lishi kerak.');
    }

    final prepared = await compute(
      _prepareBookImageVariants,
      Uint8List.fromList(sourceBytes),
    );

    Uint8List uploadBytes;
    Uint8List? thumbBytes;
    String contentType;
    String uploadName;

    if (prepared != null) {
      uploadBytes = prepared['full']!;
      thumbBytes = prepared['thumb'];
      contentType = 'image/jpeg';
      final base = file.name.replaceFirst(RegExp(r'\.[^.]+$'), '');
      uploadName = 'opt-${base.isEmpty ? 'cover' : base}.jpg';
    } else {
      if (sourceBytes.length > 7 * 1024 * 1024) {
        throw StateError(
          'Bu rasmni optimallashtirib bo‘lmadi. Boshqa JPG/PNG rasm tanlang.',
        );
      }
      uploadBytes = Uint8List.fromList(sourceBytes);
      final lower = file.name.toLowerCase();
      contentType = lower.endsWith('.png')
          ? 'image/png'
          : lower.endsWith('.webp')
          ? 'image/webp'
          : 'image/jpeg';
      uploadName = file.name;
    }

    final body = <String, dynamic>{
      'admin_code': secret,
      'file_name': uploadName,
      'content_type': contentType,
      'data_base64': base64Encode(uploadBytes),
    };
    if (thumbBytes != null && thumbBytes.isNotEmpty) {
      body['thumb_base64'] = base64Encode(thumbBytes);
    }

    final response = await client.functions.invoke(
      'admin-cover-upload',
      body: body,
    );
    final data = _functionResponseMap(response.data);
    final url = (data['url'] ?? '').toString().trim();
    if (url.isEmpty) {
      throw StateError((data['error'] ?? 'Rasm yuklanmadi.').toString());
    }
    return _UploadedBookImage(
      url: url,
      thumbnailUrl: (data['thumbnail_url'] ?? '').toString().trim(),
    );
  }

  Future<void> backfillThumbnail(Book book) async {
    final sourceGallery = book.galleryImages;
    if (book.id.isEmpty || sourceGallery.isEmpty) return;
    if (book.thumbnailUrl.trim().isNotEmpty && book.galleryImagesOptimized) {
      return;
    }

    final optimizedGallery = <String>[];
    var firstThumbnail = book.thumbnailUrl.trim();
    var changed = false;

    for (var index = 0; index < sourceGallery.length; index++) {
      final sourceUrl = sourceGallery[index].trim();
      if (sourceUrl.isEmpty) continue;

      if (isOptimizedBookImageUrl(sourceUrl)) {
        optimizedGallery.add(sourceUrl);
        if (index == 0 && firstThumbnail.isEmpty) {
          firstThumbnail = derivedBookThumbnailUrl(sourceUrl);
        }
        continue;
      }

      try {
        final uri = Uri.tryParse(sourceUrl);
        if (uri == null || !(uri.scheme == 'https' || uri.scheme == 'http')) {
          optimizedGallery.add(sourceUrl);
          continue;
        }

        final downloaded = await http
            .get(uri)
            .timeout(const Duration(seconds: 20));
        if (downloaded.statusCode < 200 || downloaded.statusCode >= 300) {
          optimizedGallery.add(sourceUrl);
          continue;
        }
        if (downloaded.bodyBytes.isEmpty ||
            downloaded.bodyBytes.length > 10 * 1024 * 1024) {
          optimizedGallery.add(sourceUrl);
          continue;
        }

        final prepared = await compute(
          _prepareBookImageVariants,
          Uint8List.fromList(downloaded.bodyBytes),
        );
        if (prepared == null) {
          optimizedGallery.add(sourceUrl);
          continue;
        }
        final fullBytes = prepared['full'];
        final thumbBytes = prepared['thumb'];
        if (fullBytes == null ||
            fullBytes.isEmpty ||
            thumbBytes == null ||
            thumbBytes.isEmpty) {
          optimizedGallery.add(sourceUrl);
          continue;
        }

        final response = await client.functions.invoke(
          'admin-cover-upload',
          body: {
            'admin_code': secret,
            'file_name': 'optimized-${book.id}-$index.jpg',
            'content_type': 'image/jpeg',
            'data_base64': base64Encode(fullBytes),
            'thumb_base64': base64Encode(thumbBytes),
          },
        );
        final data = _functionResponseMap(response.data);
        final optimizedUrl = (data['url'] ?? '').toString().trim();
        final thumbUrl = (data['thumbnail_url'] ?? '').toString().trim();
        if (optimizedUrl.isEmpty || thumbUrl.isEmpty) {
          optimizedGallery.add(sourceUrl);
          continue;
        }

        optimizedGallery.add(optimizedUrl);
        if (index == 0) firstThumbnail = thumbUrl;
        changed = true;

        // Edge Function rate limitini oshirmaslik uchun rasmlarni navbat bilan o'tkazamiz.
        if (index + 1 < sourceGallery.length) {
          await Future<void>.delayed(const Duration(milliseconds: 2200));
        }
      } catch (_) {
        optimizedGallery.add(sourceUrl);
      }
    }

    if (optimizedGallery.isEmpty) return;
    final first = optimizedGallery.first;
    if (firstThumbnail.isEmpty) {
      firstThumbnail = derivedBookThumbnailUrl(first);
    }

    if (!changed &&
        firstThumbnail == book.thumbnailUrl.trim() &&
        optimizedGallery.length == sourceGallery.length) {
      return;
    }

    await saveBook(
      book.copyWith(
        imageUrl: first,
        thumbnailUrl: firstThumbnail,
        imageUrls: optimizedGallery,
      ),
    );
  }

  Uri _serverUri(String path) {
    if (kIsWeb) return Uri.base.resolve(path);
    return Uri.parse('https://muhajeer-books-live-production.up.railway.app' + path);
  }

  Future<String> aiAsk(String query) async {
    final booksData = await books();
    final salesData = await sales();
    final ordersData = await orders();
    final context = <String,dynamic>{
      'books': booksData.take(300).map((b)=>{'title':b.title,'author':b.author,'publisher':b.publisher,'category':b.category,'price':b.currentPrice,'cost_price':b.costPrice,'stock':b.stock,'active':b.isActive}).toList(),
      'sales': salesData.take(1000).map((s)=>{'book_id':s['book_id'],'title':s['title'],'quantity':s['quantity']??s['qty'],'unit_price':s['unit_price']??s['price'],'total':s['total'],'cost_price':s['cost_price'],'created_at':s['created_at']}).toList(),
      'orders': ordersData.take(500).map((o)=>{'status':o.status,'source':o.source,'delivery_fee':o.deliveryFee,'subtotal':o.subtotal,'total':o.total,'items':o.items,'created_at':o.createdAt.toIso8601String(),'stock_reserved':o.stockReserved}).toList(),
    };
    final r=await http.post(_serverUri('/api/admin-ai'),headers:{'Content-Type':'application/json'},body:jsonEncode({'admin_code':secret,'query':query,'context':context})).timeout(const Duration(seconds:120));
    final data=jsonDecode(r.body);
    if(r.statusCode!=200) throw StateError((data['error']??'Admin AI ishlamadi').toString());
    return (data['text']??'').toString();
  }

  Future<Map<String,dynamic>> researchBook({required String title, String author='', String publisher=''}) async {
    final r=await http.post(_serverUri('/api/admin-ai/book-research'),headers:{'Content-Type':'application/json'},body:jsonEncode({'admin_code':secret,'title':title,'author':author,'publisher':publisher})).timeout(const Duration(seconds:120));
    final data=jsonDecode(r.body);
    if(r.statusCode!=200 || data is! Map) throw StateError(data is Map ? (data['error']??'Kitob topilmadi').toString() : 'Kitob topilmadi');
    final result=Map<String,dynamic>.from(data);
    result['category']=_validatedAiBookCategory(result['category']);
    return result;
  }

  Future<List<Map<String,dynamic>>> researchBooksBulk(List<Book> books) async {
    final payload=books.map((b)=>{'id':b.id,'title':b.title,'author':b.author,'publisher':b.publisher}).toList();
    final r=await http.post(
      _serverUri('/api/admin-ai/books-bulk-research'),
      headers:{'Content-Type':'application/json'},
      body:jsonEncode({'admin_code':secret,'books':payload}),
    ).timeout(const Duration(seconds:180));
    final raw=jsonDecode(r.body);
    if(r.statusCode!=200 || raw is! Map) {
      throw StateError(raw is Map ? (raw['error']??'Ommaviy AI qidiruv ishlamadi').toString() : 'Ommaviy AI qidiruv ishlamadi');
    }
    return ((raw['books'] as List?)??const [])
        .whereType<Map>()
        .map((e){
          final row=Map<String,dynamic>.from(e);
          row['category']=_validatedAiBookCategory(row['category']);
          return row;
        })
        .toList();
  }

  Future<void> deleteBook(String id) async {
    await _rpc(
      'admin_delete_book',
      params: {'p_secret': secret, 'p_id': id},
    );
  }

  Future<void> applyDiscount(
    int percent,
    DateTime endsAt, {
    required bool freeDeliveryForFourPlus,
  }) async {
    await _rpc(
      'admin_apply_discount_until',
      params: {
        'p_secret': secret,
        'p_percent': percent,
        'p_ends_at': endsAt.toUtc().toIso8601String(),
        'p_free_delivery': freeDeliveryForFourPlus,
      },
    );
  }

  Future<void> clearDiscounts() async {
    await _rpc('admin_clear_discounts', params: {'p_secret': secret});
  }

  Future<List<ShopOrder>> orders() async {
    final data = await _rpc(
      'admin_list_orders',
      params: {'p_secret': secret},
    );
    return (data as List)
        .map((e) => ShopOrder.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<List<Map<String, dynamic>>> sales() async {
    final raw = await _rpc(
      'admin_list_sales',
      params: {'p_secret': secret, 'p_limit': 5000},
    );
    return ((raw as List?) ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<String> paymentProofUrl(String path) async {
    final response = await client.functions.invoke(
      'payment-proof',
      body: {'action': 'view', 'admin_code': secret, 'path': path},
    );
    final raw = response.data;
    final data = raw is Map
        ? Map<String, dynamic>.from(raw)
        : <String, dynamic>{};
    final url = (data['url'] ?? '').toString();
    if (url.isEmpty)
      throw StateError((data['error'] ?? 'Chek ochilmadi.').toString());
    return url;
  }

  Future<void> setStock(Book book, int value) async {
    await saveBook(book.copyWith(stock: value < 0 ? 0 : value));
  }

  Future<void> updateOrderStatus(String id, String status) async {
    await _rpc(
      'admin_update_order_status',
      params: {'p_secret': secret, 'p_id': id, 'p_status': status},
    );
  }

  Future<Map<String, dynamic>> userStats() async {
    final raw = await _rpc(
      'admin_user_stats',
      params: {'p_secret': secret},
    );
    return raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
  }

  Future<List<Map<String, dynamic>>> customers() async {
    final raw = await _rpc(
      'admin_list_customers',
      params: {'p_secret': secret},
    );
    return ((raw as List?) ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<Map<String, dynamic>> merchandisingInsights() async {
    final raw = await _rpc(
      'admin_merchandising_insights',
      params: {'p_secret': secret},
    );
    return raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
  }

  Future<List<Map<String, dynamic>>> bundles() async {
    final raw = await _rpc(
      'admin_bundle_list',
      params: {'p_secret': secret},
    );
    return ((raw as List?) ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<void> saveBundle({
    String? id,
    required String title,
    required String description,
    required int price,
    String imageUrl = '',
    bool active = true,
    bool deliveryIncluded = false,
    required List<Map<String, dynamic>> items,
  }) async {
    await _rpc(
      'admin_bundle_save',
      params: {
        'p_secret': secret,
        'p_id': id,
        'p_title': title,
        'p_description': description,
        'p_price': price,
        'p_image_url': imageUrl,
        'p_is_active': active,
        'p_delivery_included': deliveryIncluded,
        'p_items': items,
      },
    );
  }

  Future<void> deleteBundle(String id) async {
    await _rpc(
      'admin_bundle_delete',
      params: {'p_secret': secret, 'p_id': id},
    );
  }

  Future<List<Map<String, dynamic>>> restockWaitlist() async {
    final raw = await _rpc(
      'admin_restock_waitlist',
      params: {'p_secret': secret},
    );
    return ((raw as List?) ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<List<Map<String, dynamic>>> shippingQueue() async {
    final raw = await _rpc(
      'admin_shipping_queue_list',
      params: {'p_secret': secret},
    );
    return ((raw as List?) ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<Map<String, dynamic>> addShippingQueue({
    required String name,
    required String phone,
    required String address,
    required String books,
  }) async {
    final raw = await _rpc(
      'admin_shipping_queue_add',
      params: {
        'p_secret': secret,
        'p_name': name,
        'p_phone': phone,
        'p_address': address,
        'p_books': books,
        'p_address_photo_file_id': '',
      },
    );
    return raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
  }

  Future<void> dismissShippingQueue({
    required String kind,
    required String id,
  }) async {
    await _rpc(
      'admin_shipping_queue_dismiss',
      params: {'p_secret': secret, 'p_kind': kind, 'p_id': id},
    );
  }
}

class AdminGatePage extends StatefulWidget {
  const AdminGatePage({super.key});

  @override
  State<AdminGatePage> createState() => _AdminGatePageState();
}

class _AdminGatePageState extends State<AdminGatePage> {
  static const _biometricPreferenceKey = 'muhajeer_admin_biometrics_v1';
  static const _secureAdminCodeKey = 'muhajeer_admin_code_v1';

  final code = TextEditingController();
  final LocalAuthentication _localAuth = LocalAuthentication();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  bool loading = false;
  bool biometricLoading = false;
  bool biometricAvailable = false;
  bool biometricEnabled = false;
  bool obscure = true;
  String? error;

  bool get _nativeBiometrics {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      unawaited(_checkWebAdminSession());
    } else {
      unawaited(_prepareBiometric());
    }
  }

  @override
  void dispose() {
    code.dispose();
    super.dispose();
  }

  Future<void> _checkWebAdminSession() async {
    if (!kIsWeb) return;
    final fragment = Uri.base.fragment;
    if (!fragment.startsWith('admin_session=')) return;
    final token = Uri.decodeComponent(
      fragment.substring('admin_session='.length),
    );
    if (token.trim().isEmpty) return;
    if (mounted) {
      setState(() {
        loading = true;
        error = null;
      });
    }
    try {
      final api = _AdminApi(token.trim());
      if (!await api.verify()) {
        if (mounted) {
          setState(
            () => error = 'Face ID / Passkey sessiyasi eskirgan. Qayta kiring.',
          );
        }
        return;
      }
      await _openDashboard(token.trim());
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Face ID / Passkey bilan kirishda xatolik.');
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _openWebPasskey(String mode) async {
    if (!kIsWeb) return;
    final uri = Uri.base.resolve('passkey.html?mode=$mode');
    final ok = await launchUrl(uri, webOnlyWindowName: '_self');
    if (!ok && mounted) {
      setState(() => error = 'Face ID / Passkey oynasi ochilmadi.');
    }
  }

  Future<bool> _deviceHasBiometrics() async {
    if (!_nativeBiometrics) return false;
    try {
      final supported = await _localAuth.isDeviceSupported();
      final canCheck = await _localAuth.canCheckBiometrics;
      final available = await _localAuth.getAvailableBiometrics();
      return supported && canCheck && available.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<void> _prepareBiometric() async {
    if (!_nativeBiometrics) return;
    final available = await _deviceHasBiometrics();
    final prefs = await SharedPreferences.getInstance();
    final enabled =
        available && (prefs.getBool(_biometricPreferenceKey) ?? false);
    if (!mounted) return;
    setState(() {
      biometricAvailable = available;
      biometricEnabled = enabled;
    });
    if (enabled) {
      unawaited(
        Future<void>.delayed(const Duration(milliseconds: 450), () async {
          if (mounted) await _biometricLogin();
        }),
      );
    }
  }

  Future<void> _openDashboard(String secret) async {
    if (!mounted) return;
    // Paid AI Story is enabled only for this verified admin session.
    AdminSession.set(secret);
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => AdminDashboardPage(secret: secret)),
    );
  }

  Future<void> _saveBiometricSecret(String secret) async {
    if (!_nativeBiometrics) return;
    final available = await _deviceHasBiometrics();
    if (!available) return;

    final prefs = await SharedPreferences.getInstance();
    final alreadyEnabled = prefs.getBool(_biometricPreferenceKey) ?? false;
    if (alreadyEnabled) {
      await _secureStorage.write(key: _secureAdminCodeKey, value: secret);
      if (mounted) {
        setState(() {
          biometricAvailable = true;
          biometricEnabled = true;
        });
      }
      return;
    }

    if (!mounted) return;
    final enable = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Face ID / biometrik kirish'),
        content: const Text(
          'Keyingi safar admin kodini yozmasdan Face ID yoki barmoq izi bilan kirishni yoqasizmi?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Hozir emas'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.fingerprint_rounded),
            label: const Text('Yoqish'),
          ),
        ],
      ),
    );
    if (enable != true) return;

    try {
      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Admin panel uchun biometrik kirishni tasdiqlang',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
      if (!authenticated) return;
      await _secureStorage.write(key: _secureAdminCodeKey, value: secret);
      await prefs.setBool(_biometricPreferenceKey, true);
      if (mounted) {
        setState(() {
          biometricAvailable = true;
          biometricEnabled = true;
        });
      }
    } catch (_) {
      // Kod bilan kirish har doim zaxira usul bo‘lib qoladi.
    }
  }

  Future<void> _biometricLogin() async {
    if (!_nativeBiometrics || biometricLoading || loading) return;
    setState(() {
      biometricLoading = true;
      error = null;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!(prefs.getBool(_biometricPreferenceKey) ?? false)) return;

      final storedSecret = await _secureStorage.read(key: _secureAdminCodeKey);
      if (storedSecret == null || storedSecret.trim().isEmpty) {
        await prefs.setBool(_biometricPreferenceKey, false);
        if (mounted) {
          setState(() {
            biometricEnabled = false;
            error = 'Biometrik kirishni qayta yoqish uchun avval admin kodi bilan kiring.';
          });
        }
        return;
      }

      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Muhajeer Books admin paneliga kirish',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
      if (!authenticated) return;

      final api = _AdminApi(storedSecret.trim());
      if (!await api.verify()) {
        await _secureStorage.delete(key: _secureAdminCodeKey);
        await prefs.setBool(_biometricPreferenceKey, false);
        if (mounted) {
          setState(() {
            biometricEnabled = false;
            error = 'Admin kodi o‘zgargan. Yangi kod bilan bir marta kiring.';
          });
        }
        return;
      }
      await _openDashboard(storedSecret.trim());
    } on PlatformException {
      if (mounted) {
        setState(() {
          error = 'Face ID / biometrik tekshiruv ishlamadi. Kod bilan kiring.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          error = 'Biometrik kirishda xatolik. Kod bilan kiring.';
        });
      }
    } finally {
      if (mounted) setState(() => biometricLoading = false);
    }
  }

  Future<void> _login() async {
    final value = code.text.trim();
    if (value.isEmpty) return;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final api = _AdminApi(value);
      if (!await api.verify()) {
        if (mounted) setState(() => error = 'Admin kodi noto‘g‘ri.');
        return;
      }
      await _saveBiometricSecret(value);
      await _openDashboard(value);
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Kirishda xatolik. Internetni tekshiring.');
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 470),
              child: AppSurface(
                padding: const EdgeInsets.all(24),
                shadow: true,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const MuhajeerLogoBadge(size: 92, radius: 25),
                    const SizedBox(height: 18),
                    Text(
                      'Muhajeer Books Admin',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 7),
                    const Text(
                      'Savdo, ombor, kitoblar va buyurtmalarni xavfsiz boshqarish markazi.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.muted, height: 1.45),
                    ),
                    const SizedBox(height: 22),
                    TextField(
                      controller: code,
                      obscureText: obscure,
                      autofocus: false,
                      onSubmitted: (_) => _login(),
                      decoration: InputDecoration(
                        labelText: 'Admin kodi',
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        suffixIcon: IconButton(
                          onPressed: () => setState(() => obscure = !obscure),
                          icon: Icon(
                            obscure
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                    ),
                    if (error != null) ...[
                      const SizedBox(height: 10),
                      AppInfoPill(
                        icon: Icons.error_outline_rounded,
                        label: error!,
                        foreground: AppColors.danger,
                        background: AppColors.dangerSoft,
                        border: const Color(0xFFFFCCD1),
                      ),
                    ],
                    const SizedBox(height: 15),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: loading ? null : _login,
                        icon: loading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.login_rounded),
                        label: Text(
                          loading
                              ? 'Tekshirilmoqda...'
                              : 'Boshqaruv paneliga kirish',
                        ),
                      ),
                    ),
                    if (kIsWeb) ...[
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: loading
                              ? null
                              : () => _openWebPasskey('login'),
                          icon: const Icon(Icons.face_rounded),
                          label: const Text('Face ID / Passkey bilan kirish'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: loading
                            ? null
                            : () => _openWebPasskey('register'),
                        icon: const Icon(
                          Icons.add_moderator_outlined,
                          size: 19,
                        ),
                        label: const Text('Face ID / Passkey ni yoqish'),
                      ),
                    ],
                    if (biometricAvailable && biometricEnabled) ...[
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: biometricLoading ? null : _biometricLogin,
                          icon: biometricLoading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.fingerprint_rounded),
                          label: Text(
                            biometricLoading
                                ? 'Tekshirilmoqda...'
                                : 'Face ID / biometrika bilan kirish',
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.verified_user_outlined,
                          size: 15,
                          color: AppColors.success,
                        ),
                        SizedBox(width: 5),
                        Text(
                          'Himoyalangan admin kirishi',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: AppColors.muted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({
    super.key,
    required this.secret,
    this.initialTab = 0,
  });
  final String secret;
  final int initialTab;

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> with WidgetsBindingObserver {
  late int tab;
  late final _AdminApi api;
  Timer? _liveRefreshTimer;
  bool _liveRefreshInFlight = false;
  final _overviewKey = GlobalKey<_OverviewAdminState>();
  final _booksKey = GlobalKey<_BooksAdminState>();
  final _inventoryKey = GlobalKey<_InventoryAdminState>();
  final _ordersKey = GlobalKey<_OrdersAdminState>();
  final _salesKey = GlobalKey<_SalesAdminState>();
  final _customersKey = GlobalKey<_CustomersAdminState>();
  final Set<int> _loadedTabs = <int>{0};
  DateTime? _awayAt;
  AppLifecycleState _lastLifecycleState = AppLifecycleState.resumed;
  static const _resumeTimeout = Duration(minutes: 10);

  static const titles = [
    'Boshqaruv markazi',
    'Kitoblar',
    'Ombor',
    'Buyurtmalar',
    'Sotilgan kitoblar',
    'Mijozlar',
    'Moliya',
    'Admin AI',
  ];
  static const icons = [
    Icons.dashboard_rounded,
    Icons.menu_book_rounded,
    Icons.inventory_2_rounded,
    Icons.receipt_long_rounded,
    Icons.sell_rounded,
    Icons.people_alt_rounded,
    Icons.account_balance_wallet_rounded,
    Icons.auto_awesome_rounded,
  ];

  @override
  void initState() {
    super.initState();
    tab = widget.initialTab.clamp(0, titles.length - 1).toInt();
    _loadedTabs.add(tab);
    api = _AdminApi(widget.secret);
    WidgetsBinding.instance.addObserver(this);
    CatalogResume.instance.setAdminPanelActive(true);
    unawaited(AdminResumeSession.start(widget.secret, tab: tab));
    _liveRefreshTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      unawaited(AdminResumeSession.touch(tab: tab));
      unawaited(_refreshActiveTabQuietly());
    });
  }

  Future<void> _refreshActiveTabQuietly() async {
    if (!mounted || _liveRefreshInFlight) return;
    _liveRefreshInFlight = true;
    try {
      switch (tab) {
        case 0:
          final state = _overviewKey.currentState;
          if (state != null) await state.reloadQuietly();
        case 1:
          final state = _booksKey.currentState;
          if (state != null) await state.reloadQuietly();
        case 2:
          final state = _inventoryKey.currentState;
          if (state != null) await state.loadQuietly();
        case 3:
          final state = _ordersKey.currentState;
          if (state != null) await state.reloadQuietly();
        case 4:
          final state = _salesKey.currentState;
          if (state != null) await state.reloadQuietly();
        case 5:
          final state = _customersKey.currentState;
          if (state != null) await state.reloadQuietly();
        case 6:
          // Moliya sahifasi o'zining siyraklashtirilgan refreshini boshqaradi.
          break;
      }
    } finally {
      _liveRefreshInFlight = false;
    }
  }

  @override
  void dispose() {
    CatalogResume.instance.setAdminPanelActive(false);
    if (_lastLifecycleState == AppLifecycleState.resumed) {
      // Foydalanuvchi adminni ataylab yopsa keyingi refreshda qayta ochilmasin.
      unawaited(AdminResumeSession.clear());
    }
    WidgetsBinding.instance.removeObserver(this);
    _liveRefreshTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lastLifecycleState = state;
    if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _awayAt ??= DateTime.now();
      unawaited(AdminResumeSession.touch(tab: tab));
      return;
    }
    if (state != AppLifecycleState.resumed) return;

    final leftAt = _awayAt;
    _awayAt = null;
    if (leftAt == null || DateTime.now().difference(leftAt) <= _resumeTimeout) {
      unawaited(AdminResumeSession.touch(tab: tab));
      return;
    }

    if (mounted) {
      // 10 daqiqagacha aynan turgan admin joyi saqlanadi. Faqat 10 daqiqadan
      // oshgandagina adminning o'z bosh paneliga qaytamiz; storefrontga emas.
      final dashboardRoute = ModalRoute.of(context);
      setState(() {
        tab = 0;
        _loadedTabs.add(0);
      });
      unawaited(AdminResumeSession.touch(tab: 0));
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || dashboardRoute == null) return;
        Navigator.of(context).popUntil((route) => identical(route, dashboardRoute));
      });
    }
  }

  void _selectTab(int value) {
    if (value == tab && _loadedTabs.contains(value)) return;
    setState(() {
      tab = value;
      _loadedTabs.add(value);
    });
    unawaited(AdminResumeSession.touch(tab: value));
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      _loadedTabs.contains(0)
          ? _OverviewAdmin(key: _overviewKey, api: api)
          : const SizedBox.shrink(),
      _loadedTabs.contains(1)
          ? _BooksAdmin(key: _booksKey, api: api)
          : const SizedBox.shrink(),
      _loadedTabs.contains(2)
          ? _InventoryAdmin(key: _inventoryKey, api: api)
          : const SizedBox.shrink(),
      _loadedTabs.contains(3)
          ? _OrdersAdmin(key: _ordersKey, api: api)
          : const SizedBox.shrink(),
      _loadedTabs.contains(4)
          ? _SalesAdmin(key: _salesKey, api: api)
          : const SizedBox.shrink(),
      _loadedTabs.contains(5)
          ? _CustomersAdmin(key: _customersKey, api: api)
          : const SizedBox.shrink(),
      _loadedTabs.contains(6)
          ? FinanceAdminPage(secret: widget.secret)
          : const SizedBox.shrink(),
      _loadedTabs.contains(7) ? _AdminAiPage(api: api) : const SizedBox.shrink(),
    ];
    const railDestinations = [
      NavigationRailDestination(
        icon: Icon(Icons.dashboard_outlined),
        selectedIcon: Icon(Icons.dashboard_rounded),
        label: Text('Bosh sahifa'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.menu_book_outlined),
        selectedIcon: Icon(Icons.menu_book_rounded),
        label: Text('Kitoblar'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.inventory_2_outlined),
        selectedIcon: Icon(Icons.inventory_2_rounded),
        label: Text('Ombor'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.receipt_long_outlined),
        selectedIcon: Icon(Icons.receipt_long_rounded),
        label: Text('Buyurtmalar'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.sell_outlined),
        selectedIcon: Icon(Icons.sell_rounded),
        label: Text('Sotilgan kitoblar'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.people_alt_outlined),
        selectedIcon: Icon(Icons.people_alt_rounded),
        label: Text('Mijozlar'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.account_balance_wallet_outlined),
        selectedIcon: Icon(Icons.account_balance_wallet_rounded),
        label: Text('Moliya'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.auto_awesome_outlined),
        selectedIcon: Icon(Icons.auto_awesome_rounded),
        label: Text('Admin AI'),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 900;
        final extended = constraints.maxWidth >= 1180;
        return Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.white,
            title: Row(
              children: [
                if (!desktop) ...[
                  const MuhajeerLogoBadge(
                    size: 36,
                    radius: 10,
                    showShadow: false,
                  ),
                  const SizedBox(width: 9),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titles[tab],
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                        ),
                      ),
                      const Text(
                        'Muhajeer Books boshqaruvi',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: AppColors.muted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: const [
              Padding(
                padding: EdgeInsets.only(right: 14),
                child: AppInfoPill(
                  icon: Icons.cloud_done_rounded,
                  label: 'Onlayn',
                  foreground: AppColors.success,
                  background: AppColors.successSoft,
                  border: Color(0xFFCDEAD7),
                ),
              ),
            ],
          ),
          body: desktop
              ? Row(
                  children: [
                    NavigationRail(
                      extended: extended,
                      selectedIndex: tab,
                      onDestinationSelected: _selectTab,
                      labelType: extended
                          ? NavigationRailLabelType.none
                          : NavigationRailLabelType.selected,
                      groupAlignment: -.72,
                      leading: Padding(
                        padding: const EdgeInsets.only(top: 12, bottom: 20),
                        child: extended
                            ? const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  MuhajeerLogoBadge(
                                    size: 46,
                                    radius: 13,
                                    showShadow: false,
                                  ),
                                  SizedBox(width: 10),
                                  Text(
                                    'Muhajeer\nBooks',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      height: 1.05,
                                    ),
                                  ),
                                ],
                              )
                            : const MuhajeerLogoBadge(
                                size: 46,
                                radius: 13,
                                showShadow: false,
                              ),
                      ),
                      destinations: railDestinations,
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(
                      child: IndexedStack(index: tab, children: pages),
                    ),
                  ],
                )
              : IndexedStack(index: tab, children: pages),
          bottomNavigationBar: desktop
              ? null
              : NavigationBar(
                  selectedIndex: tab,
                  onDestinationSelected: _selectTab,
                  labelBehavior:
                      NavigationDestinationLabelBehavior.onlyShowSelected,
                  destinations: List.generate(
                    titles.length,
                    (i) => NavigationDestination(
                      icon: Icon(icons[i]),
                      label: i == 0 ? 'Bosh' : titles[i],
                    ),
                  ),
                ),
        );
      },
    );
  }
}

class _OverviewData {
  const _OverviewData(this.books, this.orders);
  final List<Book> books;
  final List<ShopOrder> orders;
}

class _OverviewAdmin extends StatefulWidget {
  const _OverviewAdmin({super.key, required this.api});
  final _AdminApi api;

  @override
  State<_OverviewAdmin> createState() => _OverviewAdminState();
}

class _OverviewAdminState extends State<_OverviewAdmin> {
  late Future<_OverviewData> future;

  @override
  void initState() {
    super.initState();
    future = load();
  }

  Future<_OverviewData> load() async =>
      _OverviewData(await widget.api.books(), await widget.api.orders());
  void reload() {
    if (mounted) setState(() => future = load());
  }

  Future<void> reloadQuietly() async {
    try {
      final data = await load();
      if (!mounted) return;
      setState(() => future = Future.value(data));
    } catch (_) {
      // Background refresh must not replace visible data.
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<_OverviewData>(
    future: future,
    builder: (context, snap) {
      // Faqat birinchi yuklanishda katta spinner ko‘rsatamiz.
      // 15 soniyalik fon yangilanishida oldingi ma’lumot ekranda qoladi.
      if (snap.connectionState == ConnectionState.waiting &&
          snap.data == null) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snap.hasError) {
        return Center(
          child: AppSurface(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.cloud_off_rounded,
                  size: 44,
                  color: AppColors.danger,
                ),
                const SizedBox(height: 10),
                const Text(
                  'Ma’lumotni yuklab bo‘lmadi',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 10),
                FilledButton.tonalIcon(
                  onPressed: reload,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Qayta urinish'),
                ),
              ],
            ),
          ),
        );
      }
      final data = snap.data ?? const _OverviewData([], []);
      final books = data.books;
      final orders = data.orders;
      final now = DateTime.now();
      final todayOrders = orders
          .where(
            (o) =>
                o.createdAt.year == now.year &&
                o.createdAt.month == now.month &&
                o.createdAt.day == now.day,
          )
          .length;
      final newOrders = orders.where((o) => o.status == 'new').length;
      final proofOrders = orders
          .where((o) => o.status == 'new' && o.hasPaymentProof)
          .length;
      final activeRevenue = orders
          .where((o) => ['accepted', 'paid', 'shipping'].contains(o.status))
          .fold<int>(0, (sum, o) => sum + o.total);
      final completedRevenue = orders
          .where((o) => o.status == 'shipping')
          .fold<int>(0, (sum, o) => sum + o.total);
      final totalStock = books.fold<int>(0, (sum, b) => sum + b.stock);
      final lowStock = books.where((b) => b.stock <= 2).toList()
        ..sort((a, b) => a.stock.compareTo(b.stock));
      final recent = orders.take(5).toList();
      final activeStatuses = {'accepted', 'paid', 'shipping'};
      final activeOrders = orders
          .where((o) => activeStatuses.contains(o.status))
          .toList();
      final monthOrders = orders.where((o) {
        return o.createdAt.year == now.year &&
            o.createdAt.month == now.month &&
            o.status != 'cancelled';
      }).toList();
      final monthRevenue = monthOrders
          .where(
            (o) =>
                o.status == 'shipping' ||
                (o.isApp && ['accepted', 'paid'].contains(o.status)),
          )
          .fold<int>(0, (sum, o) => sum + o.total);
      final todayRevenue = orders
          .where((o) {
            return o.createdAt.year == now.year &&
                o.createdAt.month == now.month &&
                o.createdAt.day == now.day &&
                (o.status == 'shipping' ||
                    (o.isApp && ['accepted', 'paid'].contains(o.status)));
          })
          .fold<int>(0, (sum, o) => sum + o.total);
      final averageOrder = activeOrders.isEmpty
          ? 0
          : activeRevenue ~/ activeOrders.length;
      final acceptedOrders = orders.where((o) => o.status == 'accepted').length;
      final shippingOrders = orders.where((o) => o.status == 'shipping').length;
      final cancelledOrders = orders
          .where((o) => o.status == 'cancelled')
          .length;
      final outOfStock = books.where((b) => b.stock == 0).length;
      final completionRate = orders.isEmpty
          ? 0
          : ((shippingOrders / orders.length) * 100).round();
      final cancelRate = orders.isEmpty
          ? 0
          : ((cancelledOrders / orders.length) * 100).round();

      return RefreshIndicator(
        onRefresh: () async => reload(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(18),
          children: [
            AppPageHeading(
              title: 'Boshqaruv markazi',
              subtitle: 'Savdo, buyurtmalar va ombor holati real vaqtga yaqin ko‘rinishda.',
              trailing: IconButton.filledTonal(
                onPressed: reload,
                tooltip: 'Yangilash',
                icon: const Icon(Icons.refresh_rounded),
              ),
            ),
            const SizedBox(height: 18),
            InkWell(
              borderRadius: BorderRadius.circular(AppRadii.large),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => Scaffold(
                      appBar: AppBar(title: const Text('Kutayotganlar')),
                      body: _RestockAdmin(api: widget.api),
                    ),
                  ),
                );
              },
              child: AppSurface(
                backgroundColor: AppColors.surfaceSoft,
                shadow: true,
                child: Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Icon(
                        Icons.notifications_active_rounded,
                        color: AppColors.navy,
                      ),
                    ),
                    const SizedBox(width: 13),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Kutayotganlar',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Sotuvga qaytishini kutish so‘rovlarini ko‘rish',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.muted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.navy,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            InkWell(
              borderRadius: BorderRadius.circular(AppRadii.large),
              onTap: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => _PreorderAdminPage(api: widget.api)),
                );
                reload();
              },
              child: AppSurface(
                backgroundColor: const Color(0xFFFFF4DF),
                shadow: true,
                child: const Row(
                  children: [
                    SizedBox(
                      width: 50,
                      height: 50,
                      child: Icon(Icons.event_available_rounded, color: AppColors.navy, size: 29),
                    ),
                    SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Oldindan sotuvda', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                          SizedBox(height: 2),
                          Text('Yangi kitoblar • oldindan buyurtmalar • Story', style: TextStyle(fontSize: 12, color: AppColors.muted, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: AppColors.navy),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, c) {
                final cardWidth = c.maxWidth >= 1200
                    ? (c.maxWidth - 36) / 4
                    : c.maxWidth >= 760
                    ? (c.maxWidth - 24) / 3
                    : c.maxWidth >= 480
                    ? (c.maxWidth - 12) / 2
                    : c.maxWidth;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    SizedBox(
                      width: cardWidth,
                      child: AppMetricCard(
                        icon: Icons.new_releases_outlined,
                        label: 'Yangi buyurtmalar',
                        value: '$newOrders',
                        accent: AppColors.orange,
                        note: proofOrders > 0
                            ? '$proofOrders ta chek kutilmoqda'
                            : 'Tekshirish navbati',
                      ),
                    ),
                    SizedBox(
                      width: cardWidth,
                      child: AppMetricCard(
                        icon: Icons.today_outlined,
                        label: 'Bugungi buyurtma',
                        value: '$todayOrders',
                        accent: AppColors.info,
                        note: DateFormat('yyyy.MM.dd').format(now),
                      ),
                    ),
                    SizedBox(
                      width: cardWidth,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(AppRadii.large),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => Scaffold(
                                appBar: AppBar(title: const Text('Zakaslar')),
                                body: _ShippingQueueAdmin(api: widget.api),
                              ),
                            ),
                          );
                        },
                        child: const AppMetricCard(
                          icon: Icons.local_shipping_outlined,
                          label: 'Zakaslar',
                          value: 'Ochish',
                          accent: AppColors.navy,
                          note: 'Pochta uchun nusxa olish',
                        ),
                      ),
                    ),
                    SizedBox(
                      width: cardWidth,
                      child: AppMetricCard(
                        icon: Icons.inventory_2_outlined,
                        label: 'Ombordagi dona',
                        value: '$totalStock',
                        accent: const Color(0xFF6B5DD3),
                        note: '${books.length} xil kitob',
                      ),
                    ),
                    SizedBox(
                      width: cardWidth,
                      child: AppMetricCard(
                        icon: Icons.payments_outlined,
                        label: 'Faol savdo',
                        value: _won(activeRevenue),
                        accent: AppColors.success,
                        note: 'Qabul qilingan buyurtmalar',
                      ),
                    ),
                    SizedBox(
                      width: cardWidth,
                      child: AppMetricCard(
                        icon: Icons.task_alt_rounded,
                        label: 'Jo‘natilgan savdo',
                        value: _won(completedRevenue),
                        accent: AppColors.navy,
                        note: 'Jo‘natilgan buyurtmalar',
                      ),
                    ),
                    SizedBox(
                      width: cardWidth,
                      child: AppMetricCard(
                        icon: Icons.warning_amber_rounded,
                        label: 'Kam qolgan kitob',
                        value: '${lowStock.length}',
                        accent: AppColors.warning,
                        note: '2 dona yoki undan kam',
                      ),
                    ),
                    SizedBox(
                      width: cardWidth,
                      child: AppMetricCard(
                        icon: Icons.calendar_month_outlined,
                        label: 'Bu oy savdo',
                        value: _won(monthRevenue),
                        accent: AppColors.info,
                        note: '${monthOrders.length} ta buyurtma',
                      ),
                    ),
                    SizedBox(
                      width: cardWidth,
                      child: AppMetricCard(
                        icon: Icons.calculate_outlined,
                        label: 'O‘rtacha buyurtma',
                        value: _won(averageOrder),
                        accent: const Color(0xFF7A5AF8),
                        note: 'Faol buyurtmalar bo‘yicha',
                      ),
                    ),
                    SizedBox(
                      width: cardWidth,
                      child: AppMetricCard(
                        icon: Icons.point_of_sale_outlined,
                        label: 'Bugungi savdo',
                        value: _won(todayRevenue),
                        accent: AppColors.success,
                        note: '$todayOrders ta buyurtma',
                      ),
                    ),
                    SizedBox(
                      width: cardWidth,
                      child: AppMetricCard(
                        icon: Icons.remove_shopping_cart_outlined,
                        label: 'Tugagan kitob',
                        value: '$outOfStock',
                        accent: AppColors.danger,
                        note: 'Omborda 0 dona',
                      ),
                    ),
                  ],
                );
              },
            ),
  const SizedBox(height: 14),
  Card(
    clipBehavior: Clip.antiAlias,
    child: ListTile(
      minTileHeight: 72,
      leading: Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.warning.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.percent_rounded),
      ),
      title: const Text(
        'Chegirma berish',
        style: TextStyle(fontWeight: FontWeight.w800),
      ),
      subtitle: const Text('Kitoblarga aksiya foizini boshqaring'),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => Scaffold(
              appBar: AppBar(
                title: const Text('Chegirma boshqaruvi'),
              ),
              body: _DiscountAdmin(api: widget.api),
            ),
          ),
        );
      },
    ),
  ),
  const SizedBox(height: 10),
  Card(
    clipBehavior: Clip.antiAlias,
    child: ListTile(
      minTileHeight: 72,
      leading: Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.successSoft,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.auto_awesome_rounded, color: AppColors.success),
      ),
      title: const Text('Savdo imkoniyatlari',
          style: TextStyle(fontWeight: FontWeight.w800)),
      subtitle: const Text(
        'Pre-order • kitob so‘rovlari • setlar • qidiruvlar • qayta olib kelish',
      ),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => _MerchandisingAdminPage(api: widget.api),
        ),
      ),
    ),
  ),
            const SizedBox(height: 20),
            AppSurface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AppSectionHeader(
                    title: 'Buyurtmalar statistikasi',
                    subtitle: 'Holatlar va ishlov berish ko‘rsatkichlari',
                    icon: Icons.analytics_outlined,
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      AppInfoPill(
                        icon: Icons.fiber_new_rounded,
                        label: '$newOrders yangi',
                        foreground: AppColors.orange,
                        background: AppColors.warningSoft,
                      ),
                      AppInfoPill(
                        icon: Icons.inventory_rounded,
                        label: '$acceptedOrders qabul qilingan',
                        foreground: AppColors.success,
                        background: AppColors.successSoft,
                      ),
                      AppInfoPill(
                        icon: Icons.local_shipping_rounded,
                        label: '$shippingOrders jo‘natilgan',
                        foreground: AppColors.info,
                        background: const Color(0xFFEAF2FF),
                      ),
                      AppInfoPill(
                        icon: Icons.cancel_outlined,
                        label: '$cancelledOrders bekor',
                        foreground: AppColors.danger,
                        background: AppColors.dangerSoft,
                      ),
                      AppInfoPill(
                        icon: Icons.receipt_long_outlined,
                        label: '$proofOrders yangi chek',
                        foreground: AppColors.success,
                        background: AppColors.successSoft,
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _AdminProgressStat(
                    label: 'Jo‘natilgan buyurtmalar',
                    value: completionRate,
                    color: AppColors.success,
                  ),
                  const SizedBox(height: 12),
                  _AdminProgressStat(
                    label: 'Bekor qilingan buyurtmalar',
                    value: cancelRate,
                    color: AppColors.danger,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            LayoutBuilder(
              builder: (context, c) {
                final wide = c.maxWidth >= 900;
                final lowCard = AppSurface(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppSectionHeader(
                        title: 'Ombor nazorati',
                        subtitle: 'Eng avval e’tibor beriladigan qoldiqlar',
                        icon: Icons.warning_amber_rounded,
                        trailing: AppInfoPill(label: '${lowStock.length} ta'),
                      ),
                      const SizedBox(height: 12),
                      if (lowStock.isEmpty)
                        const AppInfoPill(
                          icon: Icons.check_circle_rounded,
                          label: 'Hamma qoldiq yaxshi',
                          foreground: AppColors.success,
                          background: AppColors.successSoft,
                          border: Color(0xFFCDEAD7),
                        )
                      else
                        ...lowStock
                            .take(6)
                            .map(
                              (b) => ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                leading: _AdminBookThumb(
                                  url: b.previewImageUrl,
                                ),
                                title: Text(
                                  b.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                subtitle: Text(
                                  _won(b.currentPrice),
                                  style: const TextStyle(fontSize: 11.5),
                                ),
                                trailing: AppInfoPill(
                                  label: '${b.stock} dona',
                                  foreground: b.stock == 0
                                      ? AppColors.danger
                                      : AppColors.warning,
                                  background: b.stock == 0
                                      ? AppColors.dangerSoft
                                      : AppColors.warningSoft,
                                  border: b.stock == 0
                                      ? const Color(0xFFFFCCD1)
                                      : const Color(0xFFFFDCA0),
                                ),
                              ),
                            ),
                    ],
                  ),
                );
                final recentCard = AppSurface(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppSectionHeader(
                        title: 'So‘nggi buyurtmalar',
                        subtitle: 'Yaqinda kelgan mijoz buyurtmalari',
                        icon: Icons.receipt_long_outlined,
                        trailing: AppInfoPill(label: '${orders.length} ta'),
                      ),
                      const SizedBox(height: 12),
                      if (recent.isEmpty)
                        const Text(
                          'Hozircha buyurtma yo‘q.',
                          style: TextStyle(color: AppColors.muted),
                        )
                      else
                        ...recent.map(
                          (o) => ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: AppColors.surfaceSoft,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: const Icon(
                                Icons.person_outline_rounded,
                                size: 19,
                              ),
                            ),
                            title: Text(
                              o.customerName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            subtitle: Text(
                              DateFormat('MM.dd • HH:mm').format(o.createdAt),
                              style: const TextStyle(fontSize: 11.5),
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                _AdminOrderStatusChip(status: o.status),
                                const SizedBox(height: 3),
                                Text(
                                  _won(o.total),
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                );
                if (!wide)
                  return Column(
                    children: [recentCard, const SizedBox(height: 12), lowCard],
                  );
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: recentCard),
                    const SizedBox(width: 12),
                    Expanded(child: lowCard),
                  ],
                );
              },
            ),
          ],
        ),
      );
    },
  );
}

class _ShippingQueueAdmin extends StatefulWidget {
  const _ShippingQueueAdmin({required this.api});
  final _AdminApi api;

  @override
  State<_ShippingQueueAdmin> createState() => _ShippingQueueAdminState();
}

class _ShippingQueueAdminState extends State<_ShippingQueueAdmin> {
  List<Map<String, dynamic>> rows = const [];
  bool loading = true;
  String? error;
  String filter = 'all';

  @override
  void initState() {
    super.initState();
    unawaited(reload());
  }

  Future<void> reload() async {
    if (mounted)
      setState(() {
        loading = true;
        error = null;
      });
    try {
      final data = await widget.api.shippingQueue();
      if (!mounted) return;
      setState(() => rows = data);
    } catch (e) {
      if (!mounted) return;
      setState(() => error = 'Zakaslarni yuklab bo‘lmadi.');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  List<Map<String, dynamic>> get visibleRows {
    if (filter == 'all') return rows;
    return rows
        .where((row) => (row['source'] ?? '').toString() == filter)
        .toList();
  }

  String sourceLabel(String source) {
    switch (source) {
      case 'telegram':
        return 'Telegram bot';
      case 'app':
        return 'Ilova / Web';
      case 'instagram':
        return 'Instagram';
      case 'manual':
        return 'Qo‘lda';
      default:
        return 'Zakas';
    }
  }

  IconData sourceIcon(String source) {
    switch (source) {
      case 'telegram':
        return Icons.send_rounded;
      case 'app':
        return Icons.phone_iphone_rounded;
      case 'instagram':
        return Icons.camera_alt_outlined;
      case 'manual':
        return Icons.edit_note_rounded;
      default:
        return Icons.local_shipping_outlined;
    }
  }

  Future<void> copyValue(String label, String value) async {
    final clean = value.trim();
    if (clean.isEmpty || clean == '—') return;
    await Clipboard.setData(ClipboardData(text: clean));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('$label nusxalandi')));
  }

  Future<void> addManual() async {
    final name = TextEditingController();
    final phone = TextEditingController();
    final address = TextEditingController();
    final books = TextEditingController();
    bool saving = false;
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Qo‘lda zakas qo‘shish'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: name,
                    decoration: const InputDecoration(
                      labelText: 'Ism',
                      prefixIcon: Icon(Icons.person_outline_rounded),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: phone,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Telefon',
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: address,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Manzil',
                      prefixIcon: Icon(Icons.location_on_outlined),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: books,
                    minLines: 3,
                    maxLines: 6,
                    decoration: const InputDecoration(
                      labelText: 'Kitoblar',
                      hintText: 'Dafina 1 ta\nSaodat asri 2 ta',
                      prefixIcon: Icon(Icons.menu_book_outlined),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving
                  ? null
                  : () => Navigator.pop(dialogContext, false),
              child: const Text('Bekor qilish'),
            ),
            FilledButton.icon(
              onPressed: saving
                  ? null
                  : () async {
                      if (name.text.trim().isEmpty ||
                          phone.text.trim().isEmpty ||
                          address.text.trim().isEmpty ||
                          books.text.trim().isEmpty) {
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          const SnackBar(
                            content: Text('Barcha maydonlarni to‘ldiring.'),
                          ),
                        );
                        return;
                      }
                      setDialogState(() => saving = true);
                      try {
                        await widget.api.addShippingQueue(
                          name: name.text.trim(),
                          phone: phone.text.trim(),
                          address: address.text.trim(),
                          books: books.text.trim(),
                        );
                        if (dialogContext.mounted)
                          Navigator.pop(dialogContext, true);
                      } catch (_) {
                        setDialogState(() => saving = false);
                        if (dialogContext.mounted) {
                          ScaffoldMessenger.of(dialogContext).showSnackBar(
                            const SnackBar(content: Text('Zakas saqlanmadi.')),
                          );
                        }
                      }
                    },
              icon: saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(saving ? 'Saqlanmoqda...' : 'Saqlash'),
            ),
          ],
        ),
      ),
    );
    name.dispose();
    phone.dispose();
    address.dispose();
    books.dispose();
    if (ok == true) {
      await reload();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Zakas saqlandi.')));
      }
    }
  }

  Future<void> removeRow(Map<String, dynamic> row) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Zakasni o‘chirish'),
        content: const Text(
          'Rostdan ham bu zakasni pochta ro‘yxatidan o‘chirasizmi?\n\nAsl buyurtma, ombor va statistika o‘zgarmaydi.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Yo‘q'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.delete_outline_rounded),
            label: const Text('Ha, o‘chirish'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.api.dismissShippingQueue(
        kind: (row['queue_kind'] ?? '').toString(),
        id: (row['queue_id'] ?? '').toString(),
      );
      await reload();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Zakas pochta ro‘yxatidan o‘chirildi.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Zakasni o‘chirib bo‘lmadi.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = visibleRows;
    if (loading && rows.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    return RefreshIndicator(
      onRefresh: reload,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(18),
        children: [
          AppPageHeading(
            title: 'Pochta uchun zakaslar',
            subtitle: 'Ism, telefon va manzilni alohida nusxalab pochta ilovasiga joylang.',
            trailing: FilledButton.icon(
              onPressed: addManual,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Qo‘lda qo‘shish'),
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: Text('Barchasi (${rows.length})'),
                selected: filter == 'all',
                onSelected: (_) => setState(() => filter = 'all'),
              ),
              ChoiceChip(
                label: const Text('Bot'),
                selected: filter == 'telegram',
                onSelected: (_) => setState(() => filter = 'telegram'),
              ),
              ChoiceChip(
                label: const Text('Ilova'),
                selected: filter == 'app',
                onSelected: (_) => setState(() => filter = 'app'),
              ),
              ChoiceChip(
                label: const Text('Instagram'),
                selected: filter == 'instagram',
                onSelected: (_) => setState(() => filter = 'instagram'),
              ),
              ChoiceChip(
                label: const Text('Qo‘lda'),
                selected: filter == 'manual',
                onSelected: (_) => setState(() => filter = 'manual'),
              ),
            ],
          ),
          if (error != null) ...[
            const SizedBox(height: 12),
            AppInfoPill(
              icon: Icons.error_outline_rounded,
              label: error!,
              foreground: AppColors.danger,
              background: AppColors.dangerSoft,
            ),
          ],
          const SizedBox(height: 14),
          if (list.isEmpty)
            const AppSurface(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 34),
                child: Center(
                  child: Text(
                    'Hozircha zakas yo‘q.',
                    style: TextStyle(color: AppColors.muted),
                  ),
                ),
              ),
            )
          else
            ...list.map((row) {
              final source = (row['source'] ?? '').toString();
              final name = (row['name'] ?? '—').toString();
              final phone = (row['phone'] ?? '—').toString();
              final address = (row['address'] ?? '—').toString();
              final books = (row['books'] ?? '• Kitob ma’lumoti yo‘q')
                  .toString();
              final displayOrderNumberValue = int.tryParse(
                (row['display_order_number'] ?? '').toString(),
              );
              final displayOrderNumber = displayOrderNumberValue == null ||
                      displayOrderNumberValue <= 0
                  ? ''
                  : displayOrderNumberValue.toString().padLeft(4, '0');
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: AppSurface(
                  shadow: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: AppColors.surfaceSoft,
                              borderRadius: BorderRadius.circular(13),
                            ),
                            child: Icon(
                              sourceIcon(source),
                              color: AppColors.navy,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                Text(
                                  '${sourceLabel(source)}${displayOrderNumber.isEmpty ? '' : ' · №$displayOrderNumber'}',
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    color: AppColors.muted,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Pochta ro‘yxatidan o‘chirish',
                            onPressed: () => removeRow(row),
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              color: AppColors.danger,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _ShippingCopyRow(
                        icon: Icons.person_outline_rounded,
                        label: 'Ism',
                        value: name,
                        onCopy: () => copyValue('Ism', name),
                      ),
                      const SizedBox(height: 9),
                      _ShippingCopyRow(
                        icon: Icons.phone_outlined,
                        label: 'Telefon',
                        value: phone,
                        onCopy: () => copyValue('Telefon', phone),
                      ),
                      const SizedBox(height: 9),
                      _ShippingCopyRow(
                        icon: Icons.location_on_outlined,
                        label: 'Manzil',
                        value: address,
                        onCopy: () => copyValue('Manzil', address),
                      ),
                      const SizedBox(height: 14),
                      const Divider(),
                      const SizedBox(height: 8),
                      const Text(
                        '📚 Kitoblar',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 6),
                      SelectableText(
                        books,
                        style: const TextStyle(height: 1.45),
                      ),
                    ],
                  ),
                ),
              );
            }),
          const SizedBox(height: 60),
        ],
      ),
    );
  }
}

class _ShippingCopyRow extends StatelessWidget {
  const _ShippingCopyRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onCopy,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 19, color: AppColors.muted),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.muted,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              SelectableText(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Nusxa olish',
          onPressed: onCopy,
          icon: const Icon(Icons.copy_rounded, size: 20),
        ),
      ],
    );
  }
}

class _AdminProgressStat extends StatelessWidget {
  const _AdminProgressStat({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final safeValue = value.clamp(0, 100).toInt();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            Text(
              '$safeValue%',
              style: TextStyle(color: color, fontWeight: FontWeight.w900),
            ),
          ],
        ),
        const SizedBox(height: 7),
        ClipRRect(
          borderRadius: BorderRadius.circular(100),
          child: LinearProgressIndicator(
            value: safeValue / 100,
            minHeight: 8,
            backgroundColor: AppColors.surfaceSoft,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

class _AdminStatCard extends StatelessWidget {
  const _AdminStatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
  });
  final IconData icon;
  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) => Container(
    width: 210,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFFE6E8EC)),
    ),
    child: Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: .10),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: accent),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 2,
                style: const TextStyle(
                  fontSize: 11.5,
                  color: Colors.black54,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _InventoryAdmin extends StatefulWidget {
  const _InventoryAdmin({super.key, required this.api});
  final _AdminApi api;

  @override
  State<_InventoryAdmin> createState() => _InventoryAdminState();
}

class _InventoryAdminState extends State<_InventoryAdmin> {
  final Set<String> busy = {};
  List<Book> all = [];
  String query = '';
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool showLoading = true}) async {
    if (mounted && showLoading) {
      setState(() {
        loading = true;
        error = null;
      });
    }
    try {
      final loaded = await widget.api.books();
      loaded.sort((a, b) {
        final stockCompare = a.stock.compareTo(b.stock);
        if (stockCompare != 0) return stockCompare;
        return a.title.toLowerCase().compareTo(b.title.toLowerCase());
      });
      if (!mounted) return;
      setState(() {
        all = loaded;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = e.toString();
        loading = false;
      });
    }
  }

  Future<void> loadQuietly() => _load(showLoading: false);

  Future<void> change(Book book, int delta) async {
    if (busy.contains(book.id)) return;
    final index = all.indexWhere((b) => b.id == book.id);
    if (index < 0) return;

    final oldBook = all[index];
    final newStock = (oldBook.stock + delta).clamp(0, 99999).toInt();
    if (newStock == oldBook.stock) return;
    final updated = oldBook.copyWith(stock: newStock);

    setState(() {
      busy.add(book.id);
      all[index] = updated;
    });

    try {
      await widget.api.setStock(updated, newStock);
      context.read<AppState>().refreshBooks();
    } catch (e) {
      if (!mounted) return;
      setState(() => all[index] = oldBook);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Ombor xatosi: $e')));
    } finally {
      if (mounted) setState(() => busy.remove(book.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = query.trim().toLowerCase();
    final visibleBooks = all
        .where((b) => q.isEmpty || b.title.toLowerCase().contains(q))
        .toList();
    final total = all.fold<int>(0, (s, b) => s + b.stock);
    final low = all.where((b) => b.stock <= 2).length;
    final out = all.where((b) => b.stock == 0).length;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AppPageHeading(
                title: 'Ombor boshqaruvi',
                subtitle: 'Qoldiqni tez o‘zgartiring. +/− bosilganda kitob joyi o‘zgarmaydi.',
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  AppInfoPill(
                    icon: Icons.inventory_2_outlined,
                    label: '$total dona',
                  ),
                  AppInfoPill(
                    icon: Icons.warning_amber_rounded,
                    label: '$low kam qolgan',
                    foreground: AppColors.warning,
                    background: AppColors.warningSoft,
                  ),
                  AppInfoPill(
                    icon: Icons.remove_shopping_cart_outlined,
                    label: '$out tugagan',
                    foreground: AppColors.danger,
                    background: AppColors.dangerSoft,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                onChanged: (v) => setState(() => query = v),
                decoration: const InputDecoration(
                  hintText: 'Kitob nomi bo‘yicha qidiring...',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
            ],
          ),
        ),
        if (loading)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else if (error != null)
          Expanded(
            child: Center(
              child: AppSurface(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.cloud_off_rounded,
                      size: 42,
                      color: AppColors.danger,
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Omborni yuklab bo‘lmadi',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 10),
                    FilledButton.tonalIcon(
                      onPressed: _load,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Qayta urinish'),
                    ),
                  ],
                ),
              ),
            ),
          )
        else if (visibleBooks.isEmpty)
          const Expanded(
            child: Center(
              child: Text(
                'Kitob topilmadi',
                style: TextStyle(color: AppColors.muted),
              ),
            ),
          )
        else
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              itemCount: visibleBooks.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final b = visibleBooks[i];
                final isBusy = busy.contains(b.id);
                return Card(
                  key: ValueKey(b.id),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Row(
                      children: [
                        _AdminBookThumb(url: b.previewImageUrl),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                b.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${_won(b.currentPrice)} • ${b.stock == 0
                                    ? 'Tugagan'
                                    : b.stock <= 2
                                    ? 'Kam qolgan'
                                    : 'Qoldiq yaxshi'}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: b.stock == 0
                                      ? AppColors.danger
                                      : b.stock <= 2
                                      ? AppColors.warning
                                      : AppColors.success,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton.outlined(
                              onPressed: isBusy ? null : () => change(b, -1),
                              icon: const Icon(Icons.remove_rounded),
                            ),
                            SizedBox(
                              width: 52,
                              child: Text(
                                '${b.stock}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            IconButton.filledTonal(
                              onPressed: isBusy ? null : () => change(b, 1),
                              icon: const Icon(Icons.add_rounded),
                            ),
                            const SizedBox(width: 4),
                            PopupMenuButton<int>(
                              enabled: !isBusy,
                              tooltip: 'Tez qo‘shish',
                              onSelected: (v) => change(b, v),
                              itemBuilder: (_) => const [
                                PopupMenuItem(value: 5, child: Text('+5 dona')),
                                PopupMenuItem(
                                  value: 10,
                                  child: Text('+10 dona'),
                                ),
                                PopupMenuItem(
                                  value: 20,
                                  child: Text('+20 dona'),
                                ),
                              ],
                            ),
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: isBusy
                                  ? const Padding(
                                      padding: EdgeInsets.all(3),
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : null,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}


class _CatalogGroupsAdminPage extends StatefulWidget {
  const _CatalogGroupsAdminPage({required this.api});
  final _AdminApi api;
  @override State<_CatalogGroupsAdminPage> createState()=>_CatalogGroupsAdminPageState();
}
class _CatalogGroupsAdminPageState extends State<_CatalogGroupsAdminPage> with SingleTickerProviderStateMixin {
  late final TabController tabs;
  late Future<List<Book>> future;
  @override void initState(){super.initState();tabs=TabController(length:2,vsync:this);future=widget.api.books();}
  @override void dispose(){tabs.dispose();super.dispose();}
  Future<void> reload() async {final b=await widget.api.books();if(mounted)setState(()=>future=Future.value(b));}
  List<MapEntry<String,int>> groups(List<Book> books,bool pub){
    final m=<String,int>{};
    for(final b in books){final raw=pub?normalizePublisher(b.publisher):b.category.trim();final n=raw.isEmpty?(pub?'Ko‘rsatilmagan':'Boshqalar'):raw;m[n]=(m[n]??0)+1;}
    final r=m.entries.toList()..sort((a,b)=>a.key.toLowerCase().compareTo(b.key.toLowerCase()));return r;
  }
  Future<void> edit(List<Book> books,bool pub,[String? name]) async {
    final ok=await Navigator.push<bool>(context,MaterialPageRoute(builder:(_)=>_CatalogGroupEditorPage(api:widget.api,books:books,publisher:pub,currentName:name)));
    if(ok==true)await reload();
  }
  Widget list(List<Book> books,bool pub)=>RefreshIndicator(onRefresh:reload,child:ListView(
    physics:const AlwaysScrollableScrollPhysics(),padding:const EdgeInsets.fromLTRB(16,14,16,100),children:[
      AppSurface(backgroundColor:AppColors.surfaceSoft,child:Row(children:[
        Icon(pub?Icons.apartment_rounded:Icons.category_rounded,color:AppColors.navy),const SizedBox(width:12),
        Expanded(child:Text(pub?'Nashriyot nomini o‘zgartiring yoki ichiga kitoblarni tanlab qo‘shing.':'Kategoriya nomini o‘zgartiring yoki ichiga kitoblarni tanlab qo‘shing.',style:const TextStyle(fontWeight:FontWeight.w700,color:AppColors.muted))),
      ])),const SizedBox(height:12),
      ...groups(books,pub).map((e)=>Card(margin:const EdgeInsets.only(bottom:8),child:ListTile(
        leading:CircleAvatar(child:Icon(pub?Icons.apartment_rounded:Icons.category_rounded,size:19)),
        title:Text(e.key,style:const TextStyle(fontWeight:FontWeight.w900)),subtitle:Text('${e.value} ta kitob'),
        trailing:const Icon(Icons.edit_rounded),onTap:()=>edit(books,pub,e.key),
      ))),
    ]));
  @override Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:const Text('Katalog bo‘limlari'),bottom:TabBar(controller:tabs,tabs:const[
      Tab(icon:Icon(Icons.category_rounded),text:'Kategoriyalar'),Tab(icon:Icon(Icons.apartment_rounded),text:'Nashriyotlar'),
    ])),
    floatingActionButton:FutureBuilder<List<Book>>(future:future,builder:(context,s)=>FloatingActionButton.extended(
      onPressed:s.hasData?()=>edit(s.data!,tabs.index==1):null,icon:const Icon(Icons.add_rounded),label:const Text('Yangi'))),
    body:FutureBuilder<List<Book>>(future:future,builder:(context,s){
      if(s.connectionState==ConnectionState.waiting&&!s.hasData)return const Center(child:CircularProgressIndicator());
      if(s.hasError)return Center(child:FilledButton.tonalIcon(onPressed:()=>setState(()=>future=widget.api.books()),icon:const Icon(Icons.refresh_rounded),label:const Text('Qayta yuklash')));
      final books=s.data??const <Book>[];return TabBarView(controller:tabs,children:[list(books,false),list(books,true)]);
    }),
  );
}
class _CatalogGroupEditorPage extends StatefulWidget {
  const _CatalogGroupEditorPage({required this.api,required this.books,required this.publisher,this.currentName});
  final _AdminApi api; final List<Book> books; final bool publisher; final String? currentName;
  @override State<_CatalogGroupEditorPage> createState()=>_CatalogGroupEditorPageState();
}
class _CatalogGroupEditorPageState extends State<_CatalogGroupEditorPage>{
  late final TextEditingController name; final search=TextEditingController(); final selected=<String>{}; bool saving=false;
  String value(Book b)=>widget.publisher?normalizePublisher(b.publisher):b.category.trim();
  bool same(String a,String b)=>widget.publisher?publisherKey(a)==publisherKey(b):a.trim().toLowerCase()==b.trim().toLowerCase();
  @override void initState(){super.initState();name=TextEditingController(text:widget.currentName??'');final cur=widget.currentName;if(cur!=null){for(final b in widget.books){final v=value(b);final d=v.isEmpty?(widget.publisher?'Ko‘rsatilmagan':'Boshqalar'):v;if(same(d,cur))selected.add(b.id);}}search.addListener(refresh);}
  void refresh(){if(mounted)setState((){});}
  @override void dispose(){search.removeListener(refresh);search.dispose();name.dispose();super.dispose();}
  Future<void> save() async {
    final newName=name.text.trim();if(newName.isEmpty){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Nomini kiriting.')));return;}
    setState(()=>saving=true);
    try{
      final cur=widget.currentName;
      for(final b in widget.books){
        final raw=value(b);final display=raw.isEmpty?(widget.publisher?'Ko‘rsatilmagan':'Boshqalar'):raw;
        final was=cur!=null&&same(display,cur);final should=selected.contains(b.id);Book? updated;
        if(should&&!same(raw,newName))updated=widget.publisher?b.copyWith(publisher:normalizePublisher(newName)):b.copyWith(category:newName);
        else if(!should&&was)updated=widget.publisher?b.copyWith(publisher:''):b.copyWith(category:'Boshqalar');
        if(updated!=null)await widget.api.saveBook(updated);
      }
      if(mounted)Navigator.pop(context,true);
    }catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Saqlashda xatolik: $e')));}
    finally{if(mounted)setState(()=>saving=false);}
  }
  @override Widget build(BuildContext context){
    final q=search.text.trim().toLowerCase();final visible=widget.books.where((b)=>q.isEmpty||b.title.toLowerCase().contains(q)||b.author.toLowerCase().contains(q)||b.category.toLowerCase().contains(q)||b.publisher.toLowerCase().contains(q)).toList()..sort((a,b)=>a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    return Scaffold(
      appBar:AppBar(title:Text(widget.publisher?'Nashriyotni tahrirlash':'Kategoriyani tahrirlash')),
      body:Column(children:[
        Padding(padding:const EdgeInsets.fromLTRB(16,16,16,8),child:Column(children:[
          TextField(controller:name,decoration:InputDecoration(labelText:widget.publisher?'Nashriyot nomi':'Kategoriya nomi',prefixIcon:Icon(widget.publisher?Icons.apartment_rounded:Icons.category_rounded))),
          const SizedBox(height:10),TextField(controller:search,decoration:const InputDecoration(labelText:'Kitob qidirish',prefixIcon:Icon(Icons.search_rounded))),
          const SizedBox(height:8),Row(children:[Text('${selected.length} ta kitob tanlangan',style:const TextStyle(fontWeight:FontWeight.w800)),const Spacer(),
            TextButton(onPressed:()=>setState((){for(final b in visible){selected.add(b.id);}}),child:const Text('Barchasini tanlash'))]),
        ])),const Divider(height:1),
        Expanded(child:ListView.builder(itemCount:visible.length,itemBuilder:(context,i){final b=visible[i];final checked=selected.contains(b.id);return CheckboxListTile(
          value:checked,onChanged:saving?null:(v)=>setState((){if(v==true)selected.add(b.id);else selected.remove(b.id);}),
          title:Text(b.title,style:const TextStyle(fontWeight:FontWeight.w800)),
          subtitle:Text(widget.publisher?'Hozir: ${normalizePublisher(b.publisher).isEmpty?'Ko‘rsatilmagan':normalizePublisher(b.publisher)}':'Hozir: ${b.category}'),
          controlAffinity:ListTileControlAffinity.leading,
        );})),
      ]),
      bottomNavigationBar:SafeArea(minimum:const EdgeInsets.all(16),child:FilledButton.icon(onPressed:saving?null:save,
        icon:saving?const SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2)):const Icon(Icons.save_rounded),
        label:Text(saving?'Saqlanmoqda…':'Saqlash'))),
    );
  }
}


class _BulkAiBookEditorPage extends StatefulWidget {
  const _BulkAiBookEditorPage({required this.api, required this.books});
  final _AdminApi api; final List<Book> books;
  @override State<_BulkAiBookEditorPage> createState()=>_BulkAiBookEditorPageState();
}
class _BulkAiBookEditorPageState extends State<_BulkAiBookEditorPage> {
  final selectedBooks=<String>{}; final fields=<String>{};
  final proposals=<String,Map<String,dynamic>>{}; final search=TextEditingController();
  bool researching=false,saving=false; int done=0,total=0;
  static const fieldItems=<({String key,String label,IconData icon})>[
    (key:'title',label:'Kitob nomi',icon:Icons.menu_book_rounded),
    (key:'author',label:'Yozuvchi',icon:Icons.person_rounded),
    (key:'publisher',label:'Nashriyot',icon:Icons.apartment_rounded),
    (key:'category',label:'Kategoriya',icon:Icons.category_rounded),
    (key:'description',label:'Tavsif',icon:Icons.notes_rounded),
  ];
  @override void initState(){super.initState();selectedBooks.addAll(widget.books.map((b)=>b.id));search.addListener(_refresh);}
  void _refresh(){if(mounted)setState((){});}
  @override void dispose(){search.removeListener(_refresh);search.dispose();super.dispose();}
  List<Book> get visible {final q=search.text.trim().toLowerCase();return widget.books.where((b)=>q.isEmpty||b.title.toLowerCase().contains(q)||b.author.toLowerCase().contains(q)).toList();}

  Future<void> research() async {
    if(researching||fields.isEmpty||selectedBooks.isEmpty){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Avval kamida bitta maydon va bitta kitobni + bilan tanlang.')));return;}
    final chosen=widget.books.where((b)=>selectedBooks.contains(b.id)).toList();
    setState((){researching=true;done=0;total=chosen.length;proposals.clear();});
    try{
      for(var i=0;i<chosen.length;i+=12){
        final end=(i+12<chosen.length)?i+12:chosen.length;
        final result=await widget.api.researchBooksBulk(chosen.sublist(i,end));
        for(final row in result){final id=(row['id']??'').toString();if(id.isNotEmpty)proposals[id]=row;}
        if(mounted)setState(()=>done=end);
      }
      if(!mounted)return;
      final ok=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(
        title:const Text('AI ma’lumotlarni tayyorladi'),
        content:Text('${proposals.length} ta kitob uchun ma’lumot topildi. Faqat + bilan tanlangan maydonlar o‘zgaradi. Tanlanmagan maydonlar va AI topa olmagan qiymatlar aslicha qoladi.'),
        actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Hozircha saqlamaslik')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Hammasini saqlash'))],
      ));
      if(ok==true)await saveAll();
    }catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('AI qidiruvda xatolik: $e')));}
    finally{if(mounted)setState(()=>researching=false);}
  }
  String pick(Map<String,dynamic> p,String key,String old){if(!fields.contains(key))return old;final v=(p[key]??'').toString().trim();return v.isEmpty?old:v;}
  Future<void> saveAll() async {
    if(saving)return;setState(()=>saving=true);var saved=0;
    try{
      for(final b in widget.books){
        if(!selectedBooks.contains(b.id))continue;final p=proposals[b.id];if(p==null)continue;
        final updated=b.copyWith(title:pick(p,'title',b.title),author:pick(p,'author',b.author),publisher:pick(p,'publisher',b.publisher),category:pick(p,'category',b.category),description:pick(p,'description',b.description));
        await widget.api.saveBook(updated);saved++;
      }
      if(!mounted)return;ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('$saved ta kitob yangilandi.')));Navigator.pop(context,true);
    }catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Saqlashda xatolik: $e')));}
    finally{if(mounted)setState(()=>saving=false);}
  }
  Widget fieldChip(({String key,String label,IconData icon}) item){final on=fields.contains(item.key);return FilterChip(selected:on,avatar:Icon(on?Icons.check_rounded:Icons.add_rounded,size:18),label:Text(item.label),onSelected:researching||saving?null:(v)=>setState((){if(v)fields.add(item.key);else fields.remove(item.key);}));}
  @override Widget build(BuildContext context){
    final list=visible;
    return Scaffold(
      appBar:AppBar(title:const Text('AI bilan ommaviy tahrirlash')),
      body:Column(children:[
        Padding(padding:const EdgeInsets.fromLTRB(16,14,16,10),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          const Text('Qaysi ma’lumotlar o‘zgarsin?',style:TextStyle(fontSize:17,fontWeight:FontWeight.w900)),
          const SizedBox(height:5),const Text('+ bilan tanlangan maydonlargina AI topgan ma’lumot bilan yangilanadi. Qolganlari aslicha qoladi.',style:TextStyle(color:AppColors.muted,height:1.35)),
          const SizedBox(height:10),Wrap(spacing:8,runSpacing:8,children:fieldItems.map(fieldChip).toList()),
          const SizedBox(height:12),TextField(controller:search,decoration:const InputDecoration(hintText:'Kitob yoki muallif...',prefixIcon:Icon(Icons.search_rounded))),
          const SizedBox(height:8),Row(children:[
            Text('${selectedBooks.length} / ${widget.books.length} ta tanlangan',style:const TextStyle(fontWeight:FontWeight.w800)),const Spacer(),
            TextButton(onPressed:researching||saving?null:()=>setState(()=>selectedBooks.addAll(list.map((b)=>b.id))),child:const Text('Barchasini +')),
            TextButton(onPressed:researching||saving?null:()=>setState(()=>selectedBooks.clear()),child:const Text('Tozalash')),
          ]),
          if(researching)...[const SizedBox(height:4),LinearProgressIndicator(value:total==0?null:done/total),const SizedBox(height:5),Text('AI tekshirmoqda: $done / $total',style:const TextStyle(fontWeight:FontWeight.w700,color:AppColors.muted))],
        ])),
        const Divider(height:1),
        Expanded(child:ListView.builder(itemCount:list.length,itemBuilder:(context,i){
          final b=list[i],on=selectedBooks.contains(b.id),p=proposals[b.id];
          return ListTile(leading:_AdminBookThumb(url:b.previewImageUrl),title:Text(b.title,style:const TextStyle(fontWeight:FontWeight.w800)),
            subtitle:Text(p==null?b.author:'AI ma’lumoti tayyor • ${b.author}'),
            trailing:IconButton(tooltip:on?'Tanlangan':'Tanlash',onPressed:researching||saving?null:()=>setState((){if(on)selectedBooks.remove(b.id);else selectedBooks.add(b.id);}),icon:Icon(on?Icons.check_circle_rounded:Icons.add_circle_outline_rounded,color:on?AppColors.success:AppColors.navy)),
            onTap:researching||saving?null:()=>setState((){if(on)selectedBooks.remove(b.id);else selectedBooks.add(b.id);}));
        })),
      ]),
      bottomNavigationBar:SafeArea(minimum:const EdgeInsets.all(16),child:FilledButton.icon(
        onPressed:researching||saving?null:research,
        icon:researching||saving?const SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2)):const Icon(Icons.auto_awesome_rounded),
        label:Text(researching?'AI tekshirmoqda $done/$total':saving?'Saqlanmoqda...':'AI bilan bir martada to‘ldirish'),
      )),
    );
  }
}


class _BooksAdmin extends StatefulWidget {
  const _BooksAdmin({super.key, required this.api});
  final _AdminApi api;

  @override
  State<_BooksAdmin> createState() => _BooksAdminState();
}

class _BooksAdminState extends State<_BooksAdmin> {
  String query = '';
  String filter = 'all';
  late Future<List<Book>> future;
  Set<String> soldBookIds = <String>{};
  Set<String> soldTitleKeys = <String>{};
  bool salesLoaded = false;

  static const Set<String> _problemFilterKeys = <String>{
    'problems',
    'low_profit',
    'below_cost',
    'recent',
    'out_of_stock',
    'low_stock',
    'invalid_image',
    'missing_author',
  };

  String _titleKey(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  bool _missingImage(Book book) => book.galleryImages.isEmpty;

  bool _missingDescription(Book book) {
    final value = book.description
        .trim()
        .toLowerCase()
        .replaceAll('’', "'")
        .replaceAll('`', "'")
        .replaceAll('.', '')
        .replaceAll(RegExp(r'\s+'), ' ');
    return value.isEmpty ||
        value == "ma'lumot kiritilmagan" ||
        value == 'tavsif kiritilmagan';
  }

  bool _missingAuthor(Book book) {
    final value = book.author.trim().toLowerCase();
    return value.isEmpty ||
        value == 'ko‘rsatilmagan' ||
        value == "ko'rsatilmagan" ||
        value == 'ko`rsatilmagan';
  }

  bool _invalidImage(Book book) {
    if (book.galleryImages.isEmpty) return false;
    return book.galleryImages.any((raw) {
      final value = raw.trim();
      final uri = Uri.tryParse(value);
      return uri == null ||
          !(uri.scheme == 'http' || uri.scheme == 'https') ||
          uri.host.isEmpty ||
          value.toLowerCase().contains('placeholder');
    });
  }

  bool _belowCost(Book book) =>
      book.costPrice > 0 &&
      book.currentPrice > 0 &&
      book.currentPrice < book.costPrice;

  bool _lowProfit(Book book) {
    if (book.costPrice <= 0 || book.currentPrice <= 0) return false;
    final profit = book.currentPrice - book.costPrice;
    final margin = profit / book.currentPrice;
    return margin < 0.20;
  }

  bool _recent(Book book) {
    final created = book.createdAt;
    if (created == null) return false;
    return created.isAfter(DateTime.now().subtract(const Duration(days: 7)));
  }

  bool _outOfStock(Book book) => book.stock <= 0;
  bool _lowStock(Book book) => book.stock > 0 && book.stock <= 2;

  bool _hasProblem(Book book) =>
      _missingImage(book) ||
      _missingDescription(book) ||
      book.costPrice <= 0 ||
      _invalidImage(book) ||
      _missingAuthor(book) ||
      _outOfStock(book) ||
      _lowStock(book) ||
      _belowCost(book) ||
      _lowProfit(book);

  bool _unsold(Book book) {
    if (!salesLoaded) return false;
    if (soldBookIds.contains(book.id)) return false;
    return !soldTitleKeys.contains(_titleKey(book.title));
  }

  bool _matchesFilter(Book book) {
    switch (filter) {
      case 'missing_image':
        return _missingImage(book);
      case 'missing_description':
        return _missingDescription(book);
      case 'missing_cost':
        return book.costPrice <= 0;
      case 'active':
        return book.isActive;
      case 'hidden':
        return !book.isActive;
      case 'unsold':
        return _unsold(book);
      case 'problems':
        return _hasProblem(book);
      case 'low_profit':
        return _lowProfit(book);
      case 'below_cost':
        return _belowCost(book);
      case 'recent':
        return _recent(book);
      case 'out_of_stock':
        return _outOfStock(book);
      case 'low_stock':
        return _lowStock(book);
      case 'invalid_image':
        return _invalidImage(book);
      case 'missing_author':
        return _missingAuthor(book);
      default:
        return true;
    }
  }

  String _filterLabel(String value) {
    switch (value) {
      case 'problems':
        return 'Muammoli kitoblar';
      case 'low_profit':
        return 'Foydasi past';
      case 'below_cost':
        return 'Narxi tannarxdan past';
      case 'recent':
        return 'Yaqinda qo‘shilgan';
      case 'out_of_stock':
        return 'Omborda tugagan';
      case 'low_stock':
        return 'Kam qolgan';
      case 'invalid_image':
        return 'Rasmi bor, lekin xato';
      case 'missing_author':
        return 'Muallifi kiritilmagan';
      default:
        return 'Muammoli';
    }
  }

  int _countFor(List<Book> all, String value) {
    switch (value) {
      case 'problems':
        return all.where(_hasProblem).length;
      case 'low_profit':
        return all.where(_lowProfit).length;
      case 'below_cost':
        return all.where(_belowCost).length;
      case 'recent':
        return all.where(_recent).length;
      case 'out_of_stock':
        return all.where(_outOfStock).length;
      case 'low_stock':
        return all.where(_lowStock).length;
      case 'invalid_image':
        return all.where(_invalidImage).length;
      case 'missing_author':
        return all.where(_missingAuthor).length;
      default:
        return 0;
    }
  }

  @override
  void initState() {
    super.initState();
    future = widget.api.books();
    unawaited(_startThumbnailBackfill(future));
    unawaited(_loadSales());
  }

  Future<void> _startThumbnailBackfill(Future<List<Book>> source) async {
    try {
      final books = await source;
      await _backfillMissingThumbnails(books);
    } catch (_) {
      // Eski rasmlarni kichraytirish admin ishini hech qachon bloklamaydi.
    }
  }

  Future<void> _backfillMissingThumbnails(List<Book> books) async {
    final pending = books
        .where(
          (book) =>
              book.id.isNotEmpty &&
              book.imageUrl.trim().isNotEmpty &&
              (book.thumbnailUrl.trim().isEmpty ||
                  !book.galleryImagesOptimized),
        )
        .toList();
    for (var i = 0; i < pending.length; i++) {
      if (!mounted) return;
      try {
        await widget.api.backfillThumbnail(pending[i]);
      } catch (_) {
        // Bitta eski rasm xato bo‘lsa qolganlari davom etadi.
      }
      if (i + 1 < pending.length) {
        await Future<void>.delayed(const Duration(milliseconds: 2300));
      }
    }
  }

  Future<void> _loadSales() async {
    try {
      final rows = await widget.api.sales();
      final ids = <String>{};
      final titles = <String>{};
      for (final row in rows) {
        final id = (row['book_id'] ?? '').toString().trim();
        if (id.isNotEmpty && id != 'null') ids.add(id);
        final title = (row['title'] ?? '').toString().trim();
        if (title.isNotEmpty) titles.add(_titleKey(title));
      }
      if (!mounted) return;
      setState(() {
        soldBookIds = ids;
        soldTitleKeys = titles;
        salesLoaded = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => salesLoaded = true);
    }
  }

  void reload({bool syncStore = true}) {
    if (!mounted) return;
    setState(() => future = widget.api.books());
    unawaited(_loadSales());
    if (syncStore) {
      context.read<AppState>().refreshBooks();
    }
  }

  Future<void> reloadQuietly() async {
    try {
      final data = await widget.api.books();
      if (!mounted) return;
      setState(() => future = Future.value(data));
    } catch (_) {
      // Keep the previous list visible when a background fetch fails.
    }
  }

  Future<void> openForm([Book? book]) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => _BookForm(api: widget.api, book: book),
      ),
    );
    if (changed == true && mounted) reload();
  }

  Future<void> openBulkAi(List<Book> books) async {
    if (books.isEmpty) return;
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => _BulkAiBookEditorPage(api: widget.api, books: books),
      ),
    );
    if (changed == true && mounted) reload();
  }

  Future<void> openCatalogGroups() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => _CatalogGroupsAdminPage(api: widget.api),
      ),
    );
    if (mounted) reload();
  }

  Future<void> remove(Book book) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Kitobni o‘chirish'),
        content: Text('“${book.title}” o‘chirilsinmi?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Yo‘q'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('O‘chirish'),
          ),
        ],
      ),
    );
    if (yes == true) {
      await widget.api.deleteBook(book.id);
      if (mounted) reload();
    }
  }

  Future<void> _openProblemFilters(List<Book> all) async {
    final options = <({String key, String label, IconData icon})>[
      (
        key: 'problems',
        label: 'Muammoli kitoblar',
        icon: Icons.warning_amber_rounded,
      ),
      (
        key: 'low_profit',
        label: 'Foydasi past',
        icon: Icons.trending_down_rounded,
      ),
      (
        key: 'below_cost',
        label: 'Narxi tannarxdan past',
        icon: Icons.money_off_csred_outlined,
      ),
      (
        key: 'recent',
        label: 'Yaqinda qo‘shilgan',
        icon: Icons.fiber_new_rounded,
      ),
      (
        key: 'out_of_stock',
        label: 'Omborda tugagan',
        icon: Icons.inventory_2_outlined,
      ),
      (key: 'low_stock', label: 'Kam qolgan', icon: Icons.low_priority_rounded),
      (
        key: 'invalid_image',
        label: 'Rasmi bor, lekin xato',
        icon: Icons.broken_image_outlined,
      ),
      (
        key: 'missing_author',
        label: 'Muallifi kiritilmagan',
        icon: Icons.person_off_outlined,
      ),
    ];

    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Muammoli',
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 4),
              const Text(
                'Kerakli turini tanlang — ro‘yxatda faqat o‘sha kitoblar qoladi.',
                style: TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 10),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: options.map((option) {
                      final count = _countFor(all, option.key);
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 4,
                        ),
                        leading: Icon(option.icon, color: _navy),
                        title: Text(
                          option.label,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '$count',
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            if (filter == option.key) ...[
                              const SizedBox(width: 8),
                              const Icon(
                                Icons.check_circle_rounded,
                                color: _orange,
                              ),
                            ],
                          ],
                        ),
                        onTap: () => Navigator.pop(sheetContext, option.key),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (selected != null && mounted) {
      setState(() => filter = selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Book>>(
      future: future,
      builder: (context, snap) {
        final all = snap.data ?? const <Book>[];
        final q = query.trim().toLowerCase();
        final books = all
            .where(
              (b) =>
                  _matchesFilter(b) &&
                  (q.isEmpty ||
                      b.title.toLowerCase().contains(q) ||
                      b.author.toLowerCase().contains(q)),
            )
            .toList();
        final totalStock = all.fold<int>(0, (s, b) => s + b.stock);
        final missingImages = all.where(_missingImage).length;
        final missingDescriptions = all.where(_missingDescription).length;
        final missingCost = all.where((b) => b.costPrice <= 0).length;
        final activeBooks = all.where((b) => b.isActive).length;
        final hiddenBooks = all.where((b) => !b.isActive).length;
        final unsoldBooks = salesLoaded ? all.where(_unsold).length : 0;
        final problemBooks = all.where(_hasProblem).length;

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _MiniStat(
                        label: 'Kitob',
                        value: '${all.length}',
                        selected: filter == 'all',
                        onTap: () => setState(() => filter = 'all'),
                      ),
                      _MiniStat(label: 'Ombor', value: '$totalStock dona'),
                      _MiniStat(
                        label: 'Rasm yuklanmagan',
                        value: '$missingImages',
                        selected: filter == 'missing_image',
                        onTap: () => setState(() => filter = 'missing_image'),
                      ),
                      _MiniStat(
                        label: 'Tarifsiz',
                        value: '$missingDescriptions',
                        selected: filter == 'missing_description',
                        onTap: () =>
                            setState(() => filter = 'missing_description'),
                      ),
                      _MiniStat(
                        label: 'Tan narxi kiritilmagan',
                        value: '$missingCost',
                        selected: filter == 'missing_cost',
                        onTap: () => setState(() => filter = 'missing_cost'),
                      ),
                      _MiniStat(
                        label: 'Sotuvda ko‘rsatilgan',
                        value: '$activeBooks',
                        selected: filter == 'active',
                        onTap: () => setState(() => filter = 'active'),
                      ),
                      _MiniStat(
                        label: 'Sotuvda ko‘rsatilmagan',
                        value: '$hiddenBooks',
                        selected: filter == 'hidden',
                        onTap: () => setState(() => filter = 'hidden'),
                      ),
                      _MiniStat(
                        label: 'Sotilmagan kitoblar',
                        value: salesLoaded ? '$unsoldBooks' : '…',
                        selected: filter == 'unsold',
                        onTap: salesLoaded
                            ? () => setState(() => filter = 'unsold')
                            : null,
                      ),
                      _MiniStat(
                        label: 'Muammoli',
                        value: '$problemBooks',
                        selected: _problemFilterKeys.contains(filter),
                        onTap: () => _openProblemFilters(all),
                      ),
                    ],
                  ),
                  if (_problemFilterKeys.contains(filter)) ...[
                    const SizedBox(height: 10),
                    InputChip(
                      avatar: const Icon(Icons.tune_rounded, size: 17),
                      label: Text('Muammoli → ${_filterLabel(filter)}'),
                      onDeleted: () => setState(() => filter = 'all'),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          onChanged: (v) => setState(() => query = v),
                          decoration: const InputDecoration(
                            hintText: 'Kitob yoki muallif...',
                            prefixIcon: Icon(Icons.search),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: reload,
                        icon: const Icon(Icons.refresh_rounded),
                      ),
                      const SizedBox(width: 4),
                      FilledButton.icon(
                        onPressed: () => openForm(),
                        icon: const Icon(Icons.add),
                        label: const Text('Qo‘shish'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 9),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: all.isEmpty ? null : () => openBulkAi(all),
                      icon: const Icon(Icons.auto_awesome_rounded),
                      label: const Text('AI bilan ommaviy tahrirlash'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: openCatalogGroups,
                      icon: const Icon(Icons.account_tree_rounded),
                      label: const Text('Kategoriyalar / Nashriyotlar'),
                    ),
                  ),
                ],
              ),
            ),
            if (snap.connectionState == ConnectionState.waiting &&
                snap.data == null)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (snap.hasError)
              Expanded(child: Center(child: Text('Xatolik: ${snap.error}')))
            else if (books.isEmpty)
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.search_off_rounded,
                          size: 44,
                          color: Colors.black38,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          filter == 'unsold' && !salesLoaded
                              ? 'Sotuvlar tekshirilmoqda...'
                              : 'Bu filtrda kitob topilmadi.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 22),
                  itemCount: books.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final b = books[i];
                    final profit = b.currentPrice - b.costPrice;
                    final showCostLine =
                        _problemFilterKeys.contains(filter) ||
                        filter == 'missing_cost';
                    return Card(
                      child: ListTile(
                        leading: _AdminBookThumb(url: b.previewImageUrl),
                        title: Text(
                          b.title,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        subtitle: Text(
                          [
                            '${b.author} • ${b.stock} dona • ${_won(b.currentPrice)}${b.isActive ? '' : ' • Yashirilgan'}',
                            if (showCostLine)
                              b.costPrice <= 0
                                  ? 'Tannarx kiritilmagan'
                                  : 'Tannarx ${_won(b.costPrice)} • Foyda ${_won(profit)}',
                          ].join('\n'),
                        ),
                        isThreeLine: showCostLine,
                        trailing: PopupMenuButton<String>(
                          onSelected: (v) =>
                              v == 'edit' ? openForm(b) : remove(b),
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                              value: 'edit',
                              child: Text('Tahrirlash'),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: Text('O‘chirish'),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}

class _AdminBookThumb extends StatelessWidget {
  const _AdminBookThumb({required this.url});
  final String url;

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) {
      return Container(
        width: 48,
        height: 64,
        decoration: BoxDecoration(
          color: const Color(0xFFF2F3F5),
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: const Icon(Icons.menu_book_rounded, color: _navy),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        url,
        width: 48,
        height: 64,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          width: 48,
          height: 64,
          alignment: Alignment.center,
          color: const Color(0xFFF2F3F5),
          child: const Icon(Icons.broken_image_outlined),
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.value,
    this.onTap,
    this.selected = false,
  });
  final String label;
  final String value;
  final VoidCallback? onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final child = AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: selected ? AppColors.navy : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: selected ? AppColors.navy : const Color(0xFFE7E9ED),
        ),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          fontWeight: FontWeight.w800,
          color: selected ? Colors.white : null,
        ),
      ),
    );
    if (onTap == null) return child;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: child,
      ),
    );
  }
}

class _PreorderAdminPage extends StatefulWidget {
  const _PreorderAdminPage({required this.api});
  final _AdminApi api;
  @override
  State<_PreorderAdminPage> createState() => _PreorderAdminPageState();
}

class _PreorderAdminPageState extends State<_PreorderAdminPage> {
  late Future<List<Object>> future;
  @override
  void initState() { super.initState(); future = _load(); }
  Future<List<Object>> _load() async => <Object>[
    await widget.api.books(),
    await widget.api.merchandisingInsights(),
  ];
  void reload() => setState(() => future = _load());

  Future<void> _edit([Book? book]) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => _BookForm(api: widget.api, book: book, preorderMode: true)),
    );
    if (changed == true) reload();
  }

  Future<void> _openProof(String path) async {
    try {
      final url = await widget.api.paymentProofUrl(path);
      final uri = Uri.tryParse(url);
      if (uri == null || !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw StateError('Chek ochilmadi');
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Chekni ochishda xatolik: $e')));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Oldindan sotuvda')),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () => _edit(),
      icon: const Icon(Icons.add_rounded),
      label: const Text('Yangi kitob'),
    ),
    body: FutureBuilder<List<Object>>(
      future: future,
      builder: (context, snap) {
        if (!snap.hasData) {
          if (snap.hasError) return Center(child: Text('Xatolik: ${snap.error}'));
          return const Center(child: CircularProgressIndicator());
        }
        final books = (snap.data![0] as List<Book>).where((b) => b.preorderEnabled).toList();
        final insight = Map<String,dynamic>.from(snap.data![1] as Map);
        final requests = ((insight['preorders'] as List?) ?? const []).whereType<Map>().map((e)=>Map<String,dynamic>.from(e)).toList();
        return RefreshIndicator(
          onRefresh: () async { reload(); await future; },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16,16,16,100),
            children: [
              AppSectionHeader(
                title: 'Oldindan sotuvdagi kitoblar',
                subtitle: 'Rasm, ma’lumot, kelish muddati va oldindan to‘lov',
                icon: Icons.event_available_rounded,
                trailing: AppInfoPill(icon: Icons.menu_book_rounded, label: '${books.length} ta'),
              ),
              const SizedBox(height: 12),
              if (books.isEmpty)
                const AppSurface(child: Text('Hozircha oldindan sotuvdagi kitob yo‘q. “Yangi kitob”ni bosing.'))
              else
                ...books.map((b) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: AppSurface(
                    child: Row(
                      children: [
                        _AdminBookThumb(url: b.previewImageUrl),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(b.title, style: const TextStyle(fontSize:16,fontWeight:FontWeight.w900)),
                          const SizedBox(height:4),
                          Text(b.preorderArrivalNote.isEmpty ? 'Kelish muddati kiritilmagan' : 'Taxminiy kelishi: ${b.preorderArrivalNote}', style: const TextStyle(color:AppColors.muted)),
                          Text('Oldindan to‘lov: ${_won(b.preorderDepositMin)} – ${_won(b.preorderDepositMax)}', style: const TextStyle(fontWeight:FontWeight.w700)),
                        ])),
                        PopupMenuButton<String>(
                          onSelected: (v) {
                            if (v=='edit') _edit(b);
                            if (v=='story') Navigator.push(context, MaterialPageRoute(builder:(_)=>BookStoryPage(book:b)));
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(value:'edit', child:Text('Tahrirlash')),
                            PopupMenuItem(value:'story', child:Text('Story / ulashish')),
                          ],
                        ),
                      ],
                    ),
                  ),
                )),
              const SizedBox(height: 20),
              AppSectionHeader(
                title: 'Oldindan buyurtmalar',
                subtitle: 'Mijoz yuborgan oldindan to‘lovlar',
                icon: Icons.receipt_long_rounded,
                trailing: AppInfoPill(icon: Icons.people_alt_outlined, label: '${requests.length} ta'),
              ),
              const SizedBox(height: 10),
              if (requests.isEmpty)
                const AppSurface(child: Text('Hozircha oldindan buyurtma yo‘q.'))
              else
                ...requests.map((r) => Padding(
                  padding: const EdgeInsets.only(bottom: 9),
                  child: AppSurface(child: Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                    Text((r['title']??'Kitob').toString(),style:const TextStyle(fontWeight:FontWeight.w900)),
                    const SizedBox(height:4),
                    Text('${r['customer_name']??'Mijoz'} • ${r['phone']??''}'),
                    Text('Oldindan to‘lov: ${_won((r['deposit_amount'] as num?)?.toInt()??0)}',style:const TextStyle(fontWeight:FontWeight.w800)),
                    if ((r['note']??'').toString().trim().isNotEmpty) Text('Izoh: ${r['note']}'),
                    if ((r['payment_proof_path']??'').toString().trim().isNotEmpty)
                      Align(alignment:Alignment.centerLeft,child:TextButton.icon(
                        onPressed:()=>_openProof(r['payment_proof_path'].toString()),
                        icon:const Icon(Icons.receipt_outlined),
                        label:const Text('To‘lov chekini ko‘rish'),
                      )),
                  ])),
                )),
            ],
          ),
        );
      },
    ),
  );
}

class _BookForm extends StatefulWidget {
  const _BookForm({required this.api, this.book, this.preorderMode = false});
  final _AdminApi api;
  final Book? book;
  final bool preorderMode;

  @override
  State<_BookForm> createState() => _BookFormState();
}

class _BookFormState extends State<_BookForm> {
  final key = GlobalKey<FormState>();
  late final TextEditingController title;
  late final TextEditingController author;
  late final TextEditingController publisher;
  late final TextEditingController category;
  late final TextEditingController description;
  late final TextEditingController price;
  late final TextEditingController stock;
  late final TextEditingController discount;
  late final TextEditingController image;
  late final TextEditingController cost;
  late final TextEditingController preorderArrival;
  late final TextEditingController preorderMin;
  late final TextEditingController preorderMax;
  final picker = ImagePicker();
  String cover = 'Ko‘rsatilmagan';
  bool active = true;
  bool recommended = false;
  bool preorderEnabled = false;
  bool saving = false;
  bool uploadingImage = false;
  bool researchingBook = false;
  List<String> gallery = [];
  String thumbnailUrl = '';
  final Map<String, String> thumbnailByUrl = <String, String>{};

  @override
  void initState() {
    super.initState();
    final b = widget.book;
    title = TextEditingController(text: b?.title ?? '');
    author = TextEditingController(
      text: b?.author == 'Ko‘rsatilmagan' ? '' : b?.author ?? '',
    );
    publisher = TextEditingController(text: b?.publisher ?? '');
    category = TextEditingController(text: b?.category ?? 'Boshqalar');
    description = TextEditingController(text: b?.description ?? '');
    price = TextEditingController(text: b == null ? '' : '${b.price}');
    stock = TextEditingController(text: b == null ? '' : '${b.stock}');
    discount = TextEditingController(
      text: b == null ? '0' : '${b.discountPercent}',
    );
    gallery = b?.galleryImages.toList() ?? <String>[];
    thumbnailUrl = b?.thumbnailUrl.trim() ?? '';
    if (b != null && b.imageUrl.trim().isNotEmpty && thumbnailUrl.isNotEmpty) {
      thumbnailByUrl[b.imageUrl.trim()] = thumbnailUrl;
    }
    image = TextEditingController(
      text: gallery.isNotEmpty ? gallery.first : b?.imageUrl ?? '',
    );
    cost = TextEditingController(
      text: b == null || b.costPrice == 0 ? '' : '${b.costPrice}',
    );
    cover = b?.coverType ?? 'Ko‘rsatilmagan';
    active = b?.isActive ?? true;
    recommended = b?.recommended ?? false;
    preorderEnabled = widget.preorderMode || (b?.preorderEnabled ?? false);
    preorderArrival = TextEditingController(text: b?.preorderArrivalNote ?? '');
    preorderMin = TextEditingController(text: '${b?.preorderDepositMin ?? 5000}');
    preorderMax = TextEditingController(text: '${b?.preorderDepositMax ?? 10000}');
    if (widget.preorderMode && b == null) stock.text = '0';
    image.addListener(_imageChanged);
  }

  void _imageChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    image.removeListener(_imageChanged);
    for (final c in [
      title,
      author,
      publisher,
      category,
      description,
      price,
      stock,
      discount,
      image,
      cost,
      preorderArrival,
      preorderMin,
      preorderMax,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Widget field(
    TextEditingController c,
    String label, {
    bool number = false,
    bool required = false,
    int lines = 1,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 11),
    child: TextFormField(
      controller: c,
      minLines: lines > 1 ? 4 : 1,
      maxLines: lines,
      keyboardType: number
          ? TextInputType.number
          : lines > 1
          ? TextInputType.multiline
          : TextInputType.text,
      textInputAction: number
          ? TextInputAction.next
          : lines > 1
          ? TextInputAction.newline
          : TextInputAction.next,
      enableSuggestions: !number,
      autocorrect: !number,
      decoration: InputDecoration(labelText: label),
      validator: required
          ? (v) => v == null || v.trim().isEmpty ? 'Majburiy' : null
          : null,
    ),
  );

  Future<void> _pasteDescription() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final pasted = data?.text ?? '';
    if (pasted.isEmpty) return;

    final source = description.text;
    final selection = description.selection;
    final rawStart = selection.isValid ? selection.start : source.length;
    final rawEnd = selection.isValid ? selection.end : source.length;
    final start = rawStart.clamp(0, source.length).toInt();
    final end = rawEnd.clamp(start, source.length).toInt();
    final next = source.replaceRange(start, end, pasted);

    description.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: start + pasted.length),
    );
    if (mounted) setState(() {});
  }

  Future<void> _copyDescription() async {
    final text = description.text;
    if (text.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Tavsif nusxalandi ✅')));
  }

  void _clearDescription() {
    description.clear();
    setState(() {});
  }

  Widget _descriptionEditor() => Padding(
    padding: const EdgeInsets.only(bottom: 11),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: description,
          minLines: 6,
          maxLines: 10,
          keyboardType: TextInputType.multiline,
          textInputAction: TextInputAction.newline,
          enableInteractiveSelection: true,
          enableSuggestions: true,
          autocorrect: true,
          decoration: const InputDecoration(
            labelText: 'Tavsif',
            alignLabelWithHint: true,
            hintText: 'Kitob haqida tavsifni yozing yoki pastdagi “Qo‘yish” tugmasidan foydalaning.',
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.tonalIcon(
              onPressed: _pasteDescription,
              icon: const Icon(Icons.content_paste_rounded, size: 18),
              label: const Text('Qo‘yish'),
            ),
            OutlinedButton.icon(
              onPressed: description.text.isEmpty ? null : _copyDescription,
              icon: const Icon(Icons.copy_rounded, size: 18),
              label: const Text('Nusxa olish'),
            ),
            TextButton.icon(
              onPressed: description.text.isEmpty ? null : _clearDescription,
              icon: const Icon(Icons.backspace_outlined, size: 18),
              label: const Text('Tozalash'),
            ),
          ],
        ),
        const SizedBox(height: 5),
        const Text(
          '“Qo‘yish” clipboarddagi matnni aynan kursor turgan joyga qo‘shadi.',
          style: TextStyle(fontSize: 11.5, color: AppColors.muted),
        ),
      ],
    ),
  );

  void _syncCoverController() {
    final first = gallery.isEmpty ? '' : gallery.first;
    if (image.text != first) image.text = first;
    if (first.isEmpty) {
      thumbnailUrl = '';
      return;
    }
    final mapped = thumbnailByUrl[first]?.trim() ?? '';
    if (mapped.isNotEmpty) {
      thumbnailUrl = mapped;
      return;
    }
    final oldBook = widget.book;
    if (oldBook != null && oldBook.imageUrl.trim() == first) {
      thumbnailUrl = oldBook.thumbnailUrl.trim();
    } else {
      thumbnailUrl = '';
    }
  }

  Future<void> pickAndUploadImages() async {
    if (uploadingImage) return;
    final slots = 10 - gallery.length;
    if (slots <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bitta kitobga maksimal 10 ta rasm qo‘yiladi.'),
        ),
      );
      return;
    }

    try {
      final picked = await picker.pickMultiImage(
        imageQuality: 92,
        maxWidth: 2200,
        maxHeight: 3000,
      );
      if (picked.isEmpty) return;

      final selected = picked.take(slots).toList();
      setState(() => uploadingImage = true);
      var uploadedCount = 0;
      final errors = <String>[];

      // Har bir rasm alohida yuklanadi. Bitta rasmda xato bo‘lsa ham
      // oldin muvaffaqiyatli yuklangan rasmlar yo‘qolib ketmaydi.
      for (final file in selected) {
        try {
          final uploaded = await widget.api.uploadCover(file);
          final url = uploaded.url.trim();
          if (url.isEmpty) {
            errors.add('${file.name}: bo‘sh manzil qaytdi');
            continue;
          }
          final thumb = uploaded.thumbnailUrl.trim();
          if (thumb.isNotEmpty) thumbnailByUrl[url] = thumb;
          if (!mounted) return;
          if (!gallery.contains(url)) {
            setState(() {
              gallery = [...gallery, url].take(10).toList();
              _syncCoverController();
            });
            uploadedCount++;
          }
        } catch (e) {
          errors.add('${file.name}: $e');
        }
      }

      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      if (uploadedCount == 0) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              errors.isEmpty
                  ? 'Rasm yuklanmadi.'
                  : 'Rasm yuklanmadi: ${errors.first}',
            ),
          ),
        );
      } else if (errors.isEmpty) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              '$uploadedCount ta rasm yuklandi ✅ Saqlash tugmasini bosing.',
            ),
          ),
        );
      } else {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              '$uploadedCount ta rasm yuklandi, ${errors.length} ta rasmda xato bo‘ldi.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Rasm tanlashda xatolik: $e')));
      }
    } finally {
      if (mounted) setState(() => uploadingImage = false);
    }
  }

  void _makeCover(int index) {
    if (index <= 0 || index >= gallery.length) return;
    setState(() {
      final selected = gallery.removeAt(index);
      gallery.insert(0, selected);
      _syncCoverController();
    });
  }

  void _removeGalleryImage(int index) {
    if (index < 0 || index >= gallery.length) return;
    setState(() {
      final removed = gallery.removeAt(index);
      thumbnailByUrl.remove(removed);
      _syncCoverController();
    });
  }

  Future<void> _researchBook() async {
    if (title.text.trim().isEmpty || researchingBook) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Avval kitob nomini kiriting.')));
      return;
    }
    setState(()=>researchingBook=true);
    try {
      final data=await widget.api.researchBook(title:title.text.trim(),author:author.text.trim(),publisher:publisher.text.trim());
      if(!mounted) return;
      final proposed=<String,String>{'Nomi':(data['title']??'').toString(),'Muallif':(data['author']??'').toString(),'Nashriyot':(data['publisher']??'').toString(),'Kategoriya':(data['category']??'').toString(),'Muqova':(data['cover']??'').toString(),'Tavsif':(data['description']??'').toString()};
      final ok=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(
        title:const Text('AI internetdan topdi'),
        content:SizedBox(width:520,child:SingleChildScrollView(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          ...proposed.entries.where((item)=>item.value.trim().isNotEmpty).map((item)=>Padding(padding:const EdgeInsets.only(bottom:8),child:Text(item.key + ': ' + item.value))),
          if((data['notes']??'').toString().trim().isNotEmpty) Text('Izoh: ' + data['notes'].toString()),
          const SizedBox(height:8),const Text('Bu ma’lumotlar hali saqlanmaydi. Avval maydonlarga qo‘llashga ruxsat bering.',style:TextStyle(fontWeight:FontWeight.w700)),
        ]))),
        actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Bekor qilish')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Qo‘llash'))],
      ));
      if(ok!=true || !mounted) return;
      void setIf(TextEditingController x,String name){final v=(data[name]??'').toString().trim();if(v.isNotEmpty)x.text=v;}
      setIf(title,'title'); setIf(author,'author'); setIf(publisher,'publisher'); setIf(category,'category'); setIf(description,'description');
      final cv=(data['cover']??'').toString().trim(); if(cv.isNotEmpty) cover=cv;
      setState((){});
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Maydonlarga qo‘llandi. Bazaga yozish uchun “Saqlash”ni bosing.')));
    } catch(e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('AI qidiruvda xatolik: ' + e.toString())));
    } finally { if(mounted) setState(()=>researchingBook=false); }
  }

  Future<void> save() async {
    if (!key.currentState!.validate()) return;
    final p = int.tryParse(price.text.trim()) ?? -1;
    final s = int.tryParse(stock.text.trim()) ?? -1;
    final d = int.tryParse(discount.text.trim()) ?? 0;
    final c = int.tryParse(cost.text.trim()) ?? 0;
    final preorderMinValue = int.tryParse(preorderMin.text.trim()) ?? 5000;
    final preorderMaxValue = int.tryParse(preorderMax.text.trim()) ?? 10000;
    if (p < 0 || s < 0 || d < 0 || d > 99 || c < 0 ||
        (preorderEnabled && (preorderMinValue < 0 || preorderMaxValue < preorderMinValue))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Narx, ombor yoki chegirma qiymatini tekshiring.'),
        ),
      );
      return;
    }
    var urls = gallery
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .take(20)
        .toList();
    final manualCover = image.text.trim();
    if (urls.isEmpty && manualCover.isNotEmpty) urls = [manualCover];
    setState(() => saving = true);
    try {
      await widget.api.saveBook(
        Book(
          id: widget.book?.id ?? '',
          legacyId: widget.book?.legacyId,
          title: title.text.trim(),
          author: author.text.trim().isEmpty
              ? 'Ko‘rsatilmagan'
              : author.text.trim(),
          publisher: normalizePublisher(publisher.text),
          category: category.text.trim().isEmpty
              ? 'Boshqalar'
              : category.text.trim(),
          description: description.text.trim().isEmpty
              ? 'Ma’lumot kiritilmagan.'
              : description.text.trim(),
          price: p,
          stock: s,
          discountPercent: d,
          imageUrl: urls.isEmpty ? '' : urls.first,
          thumbnailUrl: urls.isEmpty ? '' : thumbnailUrl.trim(),
          imageUrls: urls,
          isActive: active,
          coverType: cover,
          costPrice: c,
          recommended: recommended,
          preorderEnabled: preorderEnabled,
          preorderArrivalNote: preorderArrival.text.trim(),
          preorderDepositMin: preorderMinValue,
          preorderDepositMax: preorderMaxValue,
          createdAt: widget.book?.createdAt,
        ),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Saqlashda xatolik: $e')));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = gallery.isNotEmpty ? gallery.first : image.text.trim();
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.preorderMode
              ? (widget.book == null ? 'Oldindan sotuvga kitob qo‘shish' : 'Oldindan sotuvni tahrirlash')
              : (widget.book == null ? 'Kitob qo‘shish' : 'Kitobni tahrirlash'),
        ),
      ),
      body: Form(
        key: key,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            FilledButton.tonalIcon(
              onPressed: researchingBook ? null : _researchBook,
              icon: researchingBook ? const SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2)) : const Icon(Icons.travel_explore_rounded),
              label: Text(researchingBook ? 'Internetdan qidirilmoqda...' : 'AI bilan internetdan ma’lumot topish'),
            ),
            const SizedBox(height: 14),
            Center(
              child: Container(
                width: 150,
                height: 210,
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F5F7),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE4E6EA)),
                ),
                clipBehavior: Clip.antiAlias,
                child: imageUrl.isEmpty
                    ? const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.photo_library_outlined,
                            size: 46,
                            color: _navy,
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Rasm yo‘q',
                            style: TextStyle(color: Colors.black54),
                          ),
                        ],
                      )
                    : Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Center(
                          child: Icon(Icons.broken_image_outlined, size: 44),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 10),
            Center(
              child: FilledButton.tonalIcon(
                onPressed: uploadingImage || gallery.length >= 10
                    ? null
                    : pickAndUploadImages,
                icon: uploadingImage
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add_photo_alternate_outlined),
                label: Text(
                  uploadingImage
                      ? 'Yuklanmoqda...'
                      : 'Rasmlar tanlash (${gallery.length}/10)',
                ),
              ),
            ),
            const SizedBox(height: 10),
            if (gallery.isNotEmpty)
              SizedBox(
                height: 116,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: gallery.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) => Container(
                    width: 78,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: i == 0 ? AppColors.orange : AppColors.border,
                        width: i == 0 ? 2 : 1,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        Expanded(
                          child: Image.network(
                            gallery[i],
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                const Icon(Icons.broken_image_outlined),
                          ),
                        ),
                        SizedBox(
                          height: 34,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              IconButton(
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints.tightFor(
                                  width: 32,
                                  height: 32,
                                ),
                                tooltip: i == 0
                                    ? 'Muqova rasmi'
                                    : 'Muqova qilish',
                                onPressed: i == 0 ? null : () => _makeCover(i),
                                icon: Icon(
                                  i == 0
                                      ? Icons.star_rounded
                                      : Icons.star_border_rounded,
                                  size: 18,
                                  color: i == 0
                                      ? AppColors.orange
                                      : AppColors.muted,
                                ),
                              ),
                              IconButton(
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints.tightFor(
                                  width: 32,
                                  height: 32,
                                ),
                                tooltip: 'Olib tashlash',
                                onPressed: () => _removeGalleryImage(i),
                                icon: const Icon(
                                  Icons.delete_outline_rounded,
                                  size: 17,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            const Padding(
              padding: EdgeInsets.only(top: 8, bottom: 14),
              child: Text(
                '1-rasm — kitob muqovasi. U ilovada ham, Telegram botda ham asosiy rasm bo‘ladi. Qolgan rasmlar kitob ichini ko‘rsatish uchun. Maksimal 10 ta.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ),
            field(title, 'Kitob nomi', required: true),
            field(author, 'Muallif'),
            field(publisher, 'Nashriyot'),
            field(category, 'Kategoriya'),
            _descriptionEditor(),
            Row(
              children: [
                Expanded(
                  child: field(
                    price,
                    widget.preorderMode ? 'Taxminiy narx (₩)' : 'Asl narx (₩)',
                    number: true,
                    required: true,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: field(stock, 'Ombor', number: true, required: true),
                ),
              ],
            ),
            if (widget.preorderMode) ...[
              const Text(
                'Bu taxminiy narx. Yakuniy narx kitob kelganda aniq bo‘ladi.',
                style: TextStyle(fontSize: 12, color: AppColors.muted, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
            ],
            Row(
              children: [
                Expanded(child: field(discount, 'Chegirma %', number: true)),
                const SizedBox(width: 8),
                Expanded(child: field(cost, 'Tannarx (₩)', number: true)),
              ],
            ),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text(
                'Rasm URL (ixtiyoriy)',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: const Text(
                'Odatda yuqoridagi “Rasm tanlash” tugmasi yetadi.',
              ),
              children: [field(image, 'Muqova rasm URL')],
            ),
            DropdownButtonFormField<String>(
              initialValue:
                  [
                    'Qattiq',
                    'Yumshoq',
                    'Flexible',
                    'Ko‘rsatilmagan',
                  ].contains(cover)
                  ? cover
                  : 'Ko‘rsatilmagan',
              decoration: const InputDecoration(labelText: 'Muqova turi'),
              items: const [
                DropdownMenuItem(
                  value: 'Ko‘rsatilmagan',
                  child: Text('Ko‘rsatilmagan'),
                ),
                DropdownMenuItem(value: 'Qattiq', child: Text('Qattiq')),
                DropdownMenuItem(value: 'Yumshoq', child: Text('Yumshoq')),
                DropdownMenuItem(value: 'Flexible', child: Text('Flexible')),
              ],
              onChanged: (v) => cover = v ?? cover,
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              value: active,
              onChanged: (v) => setState(() => active = v),
              title: const Text('Sotuvda ko‘rsatish'),
              contentPadding: EdgeInsets.zero,
            ),
            SwitchListTile(
              value: recommended,
              onChanged: (v) => setState(() => recommended = v),
              title: const Text('Tavsiya etilgan kitob'),
              contentPadding: EdgeInsets.zero,
            ),
            SwitchListTile(
              value: preorderEnabled,
              onChanged: widget.preorderMode ? null : (v) => setState(() => preorderEnabled = v),
              title: const Text('Oldindan sotuv ochiq'),
              subtitle: const Text('Mijoz kitob kelishidan oldin band qilib, oldindan to‘lov yubora oladi.'),
              contentPadding: EdgeInsets.zero,
            ),
            if (preorderEnabled) ...[
              const SizedBox(height: 6),
              field(preorderArrival, 'Taxminiy kelish muddati', required: true),
              Row(
                children: [
                  Expanded(child: field(preorderMin, 'Oldindan to‘lov min (₩)', number: true, required: true)),
                  const SizedBox(width: 10),
                  Expanded(child: field(preorderMax, 'Oldindan to‘lov max (₩)', number: true, required: true)),
                ],
              ),
              const Text(
                'Mijozga “oldindan to‘lov” deb ko‘rsatiladi. Tavsiya: ₩5,000–₩10,000.',
                style: TextStyle(fontSize: 11.5, color: AppColors.muted),
              ),
            ],
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: saving || uploadingImage ? null : save,
              icon: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: const Text('Saqlash'),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrdersAdmin extends StatefulWidget {
  const _OrdersAdmin({super.key, required this.api});
  final _AdminApi api;

  @override
  State<_OrdersAdmin> createState() => _OrdersAdminState();
}

class _OrdersAdminState extends State<_OrdersAdmin> {
  late Future<List<ShopOrder>> future;
  String filter = 'all';
  String query = '';
  final Set<String> busy = {};

  @override
  void initState() {
    super.initState();
    future = widget.api.orders();
  }

  void reload() {
    if (mounted) setState(() => future = widget.api.orders());
  }

  Future<void> reloadQuietly() async {
    try {
      final data = await widget.api.orders();
      if (!mounted) return;
      setState(() => future = Future.value(data));
    } catch (_) {
      // Keep the current orders visible during background refresh.
    }
  }

  Future<void> changeStatus(ShopOrder order, String status) async {
    if (!order.isApp) {
      if (mounted) {
        final message = order.isInstagram
            ? 'Instagram savdosi Telegram botdan boshqariladi.'
            : 'Telegram buyurtmasi botdan boshqariladi.';
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      }
      return;
    }
    if (busy.contains(order.id)) return;
    if (status == 'accepted') {
      final yes = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          icon: const Icon(
            Icons.inventory_2_rounded,
            color: Color(0xFF138A4B),
            size: 44,
          ),
          title: const Text('Buyurtmani qabul qilasizmi?'),
          content: const Text(
            'Qabul qilinganda buyurtma sotilgan kitoblar va statistikaga qo‘shiladi. Bepul yetkazishda pochta do‘kon xarajati sifatida hisoblanadi.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Yo‘q'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Qabul qilish'),
            ),
          ],
        ),
      );
      if (yes != true) return;
    }
    if (status == 'cancelled') {
      final yes = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Buyurtmani bekor qilish'),
          content: Text(
            order.stockReserved
                ? 'Bu buyurtma ombordan ajratilgan. Bekor qilsangiz kitoblar omborga avtomatik qaytariladi.'
                : 'Buyurtma bekor qilinsinmi?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Yo‘q'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Bekor qilish'),
            ),
          ],
        ),
      );
      if (yes != true) return;
    }

    setState(() => busy.add(order.id));
    try {
      await widget.api.updateOrderStatus(order.id, status);
      await context.read<AppState>().refreshBooks();
      if (mounted) {
        reload();
        final message = status == 'accepted'
            ? 'Buyurtma qabul qilindi. Sotuv va statistika yangilandi ✅'
            : status == 'cancelled'
            ? 'Buyurtma bekor qilindi.'
            : 'Buyurtma holati yangilandi.';
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Xatolik: $e')));
    } finally {
      if (mounted) setState(() => busy.remove(order.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ShopOrder>>(
      future: future,
      builder: (context, snap) {
        final all = snap.data ?? const <ShopOrder>[];
        final q = query.trim().toLowerCase();
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final yesterday = today.subtract(const Duration(days: 1));
        final orders = all.where((o) {
          final created = o.createdAt.toLocal();
          final orderDay = DateTime(created.year, created.month, created.day);
          final matchStatus = switch (filter) {
            'all' => o.status != 'cancelled',
            'today' => o.status != 'cancelled' && orderDay == today,
            'yesterday' => o.status != 'cancelled' && orderDay == yesterday,
            _ => o.status == filter,
          };
          final matchQuery =
              q.isEmpty ||
              o.customerName.toLowerCase().contains(q) ||
              o.phone.toLowerCase().contains(q) ||
              o.id.toLowerCase().contains(q);
          return matchStatus && matchQuery;
        }).toList();
        final newCount = all.where((o) => o.status == 'new').length;
        final proofCount = all
            .where((o) => o.status == 'new' && o.hasPaymentProof)
            .length;

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Buyurtmalar',
                          style: TextStyle(
                            fontSize: 25,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      Badge(
                        isLabelVisible: newCount > 0,
                        label: Text('$newCount'),
                        child: IconButton.filledTonal(
                          onPressed: reload,
                          icon: const Icon(Icons.refresh_rounded),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          onChanged: (v) => setState(() => query = v),
                          decoration: const InputDecoration(
                            hintText: 'Mijoz, telefon yoki buyurtma ID...',
                            prefixIcon: Icon(Icons.search_rounded),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: proofCount > 0
                              ? const Color(0xFFEAF7EF)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE6E8EC)),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.receipt_outlined,
                              size: 18,
                              color: Color(0xFF138A4B),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              '$proofCount chek',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _OrderFilterChip(
                          label: 'Barchasi',
                          value: 'all',
                          selected: filter,
                          onTap: (v) => setState(() => filter = v),
                        ),
                        _OrderFilterChip(
                          label: 'Bugun',
                          value: 'today',
                          selected: filter,
                          onTap: (v) => setState(() => filter = v),
                        ),
                        _OrderFilterChip(
                          label: 'Kecha',
                          value: 'yesterday',
                          selected: filter,
                          onTap: (v) => setState(() => filter = v),
                        ),
                        _OrderFilterChip(
                          label: 'Yangi',
                          value: 'new',
                          selected: filter,
                          onTap: (v) => setState(() => filter = v),
                        ),
                        _OrderFilterChip(
                          label: 'Qabul qilingan',
                          value: 'accepted',
                          selected: filter,
                          onTap: (v) => setState(() => filter = v),
                        ),
                        _OrderFilterChip(
                          label: 'Jo‘natilgan',
                          value: 'shipping',
                          selected: filter,
                          onTap: (v) => setState(() => filter = v),
                        ),
                        _OrderFilterChip(
                          label: 'Bekor',
                          value: 'cancelled',
                          selected: filter,
                          onTap: (v) => setState(() => filter = v),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Avtomatik 15 soniyalik refresh paytida eski ma'lumotni ekranda
            // qoldiramiz. Katta loading faqat sahifa birinchi marta ochilganda chiqadi.
            if (snap.connectionState == ConnectionState.waiting &&
                snap.data == null)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (snap.hasError)
              Expanded(child: Center(child: Text('Xatolik: ${snap.error}')))
            else if (orders.isEmpty)
              const Expanded(
                child: Center(child: Text('Bu bo‘limda buyurtma yo‘q')),
              )
            else
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: orders.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => _ProfessionalOrderCard(
                    order: orders[i],
                    api: widget.api,
                    loading: busy.contains(orders[i].id),
                    onStatus: (status) => changeStatus(orders[i], status),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _OrderFilterChip extends StatelessWidget {
  const _OrderFilterChip({
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final String value;
  final String selected;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 7),
    child: ChoiceChip(
      label: Text(label),
      selected: selected == value,
      onSelected: (_) => onTap(value),
    ),
  );
}

class _ProfessionalOrderCard extends StatelessWidget {
  const _ProfessionalOrderCard({
    required this.order,
    required this.api,
    required this.loading,
    required this.onStatus,
  });
  final ShopOrder order;
  final _AdminApi api;
  final bool loading;
  final ValueChanged<String> onStatus;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: _navy.withValues(alpha: .08),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.receipt_long_rounded, color: _navy),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                order.customerName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
            _AdminOrderStatusChip(status: order.status),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: [
              if (order.isTelegram) ...[
                const Icon(
                  Icons.send_rounded,
                  size: 15,
                  color: Color(0xFF229ED9),
                ),
                const SizedBox(width: 4),
                const Text(
                  'Telegramdan zakas',
                  style: TextStyle(
                    color: Color(0xFF1976A3),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Text(' • '),
              ],
              if (order.isInstagram) ...[
                const Icon(
                  Icons.photo_camera_outlined,
                  size: 15,
                  color: Color(0xFFC13584),
                ),
                const SizedBox(width: 4),
                const Text(
                  'Instagram savdo',
                  style: TextStyle(
                    color: Color(0xFFC13584),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
              Text(
                _won(order.total),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const Text(' • '),
              Expanded(
                child: Text(
                  order.phone,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (order.hasPaymentProof)
                const Padding(
                  padding: EdgeInsets.only(left: 6),
                  child: Icon(
                    Icons.receipt_rounded,
                    size: 17,
                    color: Color(0xFF138A4B),
                  ),
                ),
            ],
          ),
        ),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  order.status == 'cancelled'
                      ? ''
                      : "№ ${order.displayOrderNumber > 0 ? order.displayOrderNumber.toString().padLeft(4, '0') : order.id}",
                  style: const TextStyle(fontSize: 11, color: Colors.black45),
                ),
              ),
              Text(
                DateFormat('yyyy.MM.dd HH:mm').format(order.createdAt),
                style: const TextStyle(fontSize: 11, color: Colors.black45),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F8FA),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              '📱 ${order.phone}\n📍 ${order.address}\n🚚 ${order.deliveryType} • ${_won(order.deliveryFee)}',
              style: const TextStyle(height: 1.55),
            ),
          ),
          const SizedBox(height: 12),
          ...order.items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${item['title']} × ${item['quantity']}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  Text(
                    _won((item['line_total'] as num?)?.toInt() ?? 0),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 22),
          Row(
            children: [
              const Text('Jami', style: TextStyle(fontWeight: FontWeight.w800)),
              const Spacer(),
              Text(
                _won(order.total),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: _navy,
                ),
              ),
            ],
          ),
          if (order.hasPaymentProof) ...[
            const SizedBox(height: 12),
            _PaymentProofPanel(api: api, path: order.paymentProofPath),
          ],
          const SizedBox(height: 14),
          if (loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(10),
                child: CircularProgressIndicator(),
              ),
            )
          else
            _OrderActions(order: order, onStatus: onStatus),
        ],
      ),
    );
  }
}

class _OrderActions extends StatelessWidget {
  const _OrderActions({required this.order, required this.onStatus});
  final ShopOrder order;
  final ValueChanged<String> onStatus;

  @override
  Widget build(BuildContext context) {
    if (!order.isApp) {
      return AppInfoPill(
        icon: order.isInstagram
            ? Icons.photo_camera_outlined
            : Icons.send_rounded,
        label: order.isInstagram
            ? 'Instagram savdo — botdan boshqariladi'
            : 'Telegram buyurtmasi — botdan boshqariladi',
        foreground: order.isInstagram
            ? const Color(0xFFC13584)
            : const Color(0xFF1976A3),
        background: order.isInstagram
            ? const Color(0xFFFCEAF4)
            : const Color(0xFFEAF7FD),
        border: Color(0xFFC8E8F6),
      );
    }
    if (order.status == 'cancelled' ||
        order.status == 'shipping' ||
        order.status == 'done') {
      return const SizedBox.shrink();
    }
    String? primaryStatus;
    String? primaryLabel;
    IconData? primaryIcon;
    if (order.status == 'new') {
      primaryStatus = 'accepted';
      primaryLabel = 'Qabul qilish';
      primaryIcon = Icons.check_circle_rounded;
    } else if (order.status == 'accepted' || order.status == 'paid') {
      primaryStatus = 'shipping';
      primaryLabel = 'Jo‘natildi';
      primaryIcon = Icons.local_shipping_rounded;
    }

    return Row(
      children: [
        if (primaryStatus != null)
          Expanded(
            child: FilledButton.icon(
              onPressed: () => onStatus(primaryStatus!),
              icon: Icon(primaryIcon),
              label: Text(primaryLabel!),
            ),
          ),
        if (primaryStatus != null) const SizedBox(width: 8),
        OutlinedButton.icon(
          onPressed: () => onStatus('cancelled'),
          icon: const Icon(Icons.close_rounded),
          label: const Text('Bekor'),
        ),
      ],
    );
  }
}

class _AdminOrderStatusChip extends StatelessWidget {
  const _AdminOrderStatusChip({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final (label, fg, bg, border, icon) = switch (status) {
      'accepted' => (
        'Qabul qilindi',
        AppColors.success,
        AppColors.successSoft,
        const Color(0xFFCDEAD7),
        Icons.inventory_2_rounded,
      ),
      'paid' => (
        'To‘landi',
        AppColors.info,
        AppColors.infoSoft,
        const Color(0xFFCFE0FA),
        Icons.verified_rounded,
      ),
      'shipping' => (
        'Jo‘natildi',
        AppColors.success,
        AppColors.successSoft,
        const Color(0xFFCDEAD7),
        Icons.local_shipping_rounded,
      ),
      // Eski buildlardan qolgan 'done' yozuvi uchrasa ham alohida
      // bosqich ko‘rsatmaymiz: Jo‘natildi yakuniy holat.
      'done' => (
        'Jo‘natildi',
        AppColors.success,
        AppColors.successSoft,
        const Color(0xFFCDEAD7),
        Icons.local_shipping_rounded,
      ),
      'cancelled' => (
        'Bekor',
        AppColors.danger,
        AppColors.dangerSoft,
        const Color(0xFFFFCCD1),
        Icons.cancel_rounded,
      ),
      _ => (
        'Yangi',
        AppColors.navy,
        AppColors.surfaceSoft,
        AppColors.border,
        Icons.new_releases_rounded,
      ),
    };
    return AppInfoPill(
      icon: icon,
      label: label,
      foreground: fg,
      background: bg,
      border: border,
    );
  }
}

class _PaymentProofPanel extends StatelessWidget {
  const _PaymentProofPanel({required this.api, required this.path});
  final _AdminApi api;
  final String path;

  Future<void> openProof(BuildContext context) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final url = await api.paymentProofUrl(path);
      if (!context.mounted) return;
      Navigator.pop(context);
      await showDialog<void>(
        context: context,
        builder: (_) => Dialog(
          insetPadding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720, maxHeight: 820),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: const Text(
                    'To‘lov cheki',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  trailing: IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ),
                const Divider(height: 1),
                Flexible(
                  child: InteractiveViewer(
                    minScale: .5,
                    maxScale: 4,
                    child: Image.network(url, fit: BoxFit.contain),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Chekni ochishda xatolik: $e')));
    }
  }

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFEAF7EF),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFFBDE2C9)),
    ),
    child: Row(
      children: [
        const Icon(Icons.receipt_rounded, color: Color(0xFF138A4B)),
        const SizedBox(width: 9),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'To‘lov cheki yuborilgan',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              Text(
                'Chek maxfiy saqlanadi.',
                style: TextStyle(fontSize: 11, color: Colors.black54),
              ),
            ],
          ),
        ),
        FilledButton.tonalIcon(
          onPressed: () => openProof(context),
          icon: const Icon(Icons.visibility_outlined),
          label: const Text('Ko‘rish'),
        ),
      ],
    ),
  );
}

class _RestockAdmin extends StatefulWidget {
  const _RestockAdmin({super.key, required this.api});
  final _AdminApi api;

  @override
  State<_RestockAdmin> createState() => _RestockAdminState();
}

class _RestockAdminState extends State<_RestockAdmin> {
  late Future<List<Map<String, dynamic>>> future;

  @override
  void initState() {
    super.initState();
    future = widget.api.restockWaitlist();
  }

  int _asInt(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _when(dynamic value) {
    final dt = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
    if (dt == null) return '';
    return DateFormat('dd.MM.yyyy HH:mm').format(dt);
  }

  void reload() {
    if (!mounted) return;
    setState(() => future = widget.api.restockWaitlist());
  }

  Future<void> reloadQuietly() async {
    try {
      final data = await widget.api.restockWaitlist();
      if (!mounted) return;
      setState(() => future = Future.value(data));
    } catch (_) {
      // Fon yangilanishi eski ma'lumotni ekranda qoldiradi.
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting &&
            snap.data == null) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(
            child: AppSurface(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.notifications_off_outlined,
                    size: 42,
                    color: AppColors.danger,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Kutayotganlar ro‘yxatini yuklab bo‘lmadi',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 10),
                  FilledButton.tonalIcon(
                    onPressed: reload,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Qayta urinish'),
                  ),
                ],
              ),
            ),
          );
        }

        final rows = snap.data ?? const <Map<String, dynamic>>[];
        final totalWaiting = rows.fold<int>(
          0,
          (sum, row) => sum + _asInt(row['waiting_count']),
        );

        return ListView(
          padding: const EdgeInsets.all(18),
          children: [
            const AppPageHeading(
              title: 'Sotuvga qaytishini kutayotganlar',
              subtitle: 'Mavjud bo‘lmagan qaysi kitobni nechta mijoz kutayotganini shu yerda ko‘rasiz.',
            ),
            const SizedBox(height: 16),
            AppSurface(
              backgroundColor: AppColors.surfaceSoft,
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Icon(
                      Icons.notifications_active_rounded,
                      color: _navy,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$totalWaiting ta kutish so‘rovi',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          '${rows.length} ta kitob bo‘yicha',
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Yangilash',
                    onPressed: reload,
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            if (rows.isEmpty)
              AppSurface(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 28),
                  child: Column(
                    children: [
                      Icon(
                        Icons.notifications_none_rounded,
                        size: 50,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Hozircha kutayotgan mijoz yo‘q',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Mijoz “Kelganda xabar berish”ni bossa, shu yerda chiqadi.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...rows.map((row) {
                final count = _asInt(row['waiting_count']);
                final stock = _asInt(row['stock']);
                final lastRequest = _when(row['last_requested_at']);
                final title = (row['title'] ?? 'Nomsiz kitob').toString();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: AppSurface(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF4E6),
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: const Icon(
                            Icons.menu_book_rounded,
                            color: _orange,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                stock <= 0
                                    ? 'Hozir sotuvda mavjud emas'
                                    : 'Omborda: $stock ta',
                                style: const TextStyle(
                                  color: AppColors.muted,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (lastRequest.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  'Oxirgi so‘rov: $lastRequest',
                                  style: const TextStyle(
                                    color: AppColors.muted,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF4E6),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: const Color(0xFFFFD6A3)),
                          ),
                          child: Text(
                            '$count kishi kutyapti',
                            style: const TextStyle(
                              color: _navy,
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
          ],
        );
      },
    );
  }
}

class _MerchandisingAdminPage extends StatefulWidget {
  const _MerchandisingAdminPage({required this.api});
  final _AdminApi api;

  @override
  State<_MerchandisingAdminPage> createState() =>
      _MerchandisingAdminPageState();
}

class _MerchandisingAdminPageState extends State<_MerchandisingAdminPage> {
  late Future<List<Object>> future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    future = Future.wait<Object>([
      widget.api.merchandisingInsights(),
      widget.api.bundles(),
      widget.api.books(),
    ]);
  }

  List<Map<String, dynamic>> _rows(dynamic value) =>
      ((value as List?) ?? const [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

  Future<void> _openBundleEditor(
    List<Book> books, {
    Map<String, dynamic>? bundle,
  }) async {
    final title =
        TextEditingController(text: (bundle?['title'] ?? '').toString());
    final description =
        TextEditingController(text: (bundle?['description'] ?? '').toString());
    final price = TextEditingController(
      text: ((bundle?['price'] as num?)?.toInt() ?? 0) > 0
          ? (bundle!['price'] as num).toInt().toString()
          : '',
    );
    final selected = <String, int>{};
    for (final raw
        in ((bundle?['items'] as List?) ?? const []).whereType<Map>()) {
      selected[(raw['book_id'] ?? '').toString()] =
          (raw['quantity'] as num?)?.toInt() ?? 1;
    }
    var active = bundle?['is_active'] as bool? ?? true;
    var deliveryIncluded = bundle?['delivery_included'] as bool? ?? false;

    int selectedRegularTotal() {
      var total = 0;
      for (final entry in selected.entries) {
        for (final book in books) {
          if (book.id == entry.key) {
            total += book.price * entry.value;
            break;
          }
        }
      }
      return total;
    }

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text(bundle == null ? 'Yangi kitob seti' : 'Setni tahrirlash'),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: title,
                    decoration: const InputDecoration(labelText: 'Set nomi'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: description,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'Izoh'),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceSoft,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Set narxi',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Tanlangan kitoblar oddiy narxi: ${_won(selectedRegularTotal())}',
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 9),
                        TextField(
                          controller: price,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Mijoz uchun set narxini kiriting',
                            prefixText: '₩ ',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: deliveryIncluded,
                    onChanged: (v) => setLocal(() => deliveryIncluded = v),
                    secondary: const Icon(Icons.local_shipping_outlined),
                    title: const Text(
                      'Pochta set narxiga kiradi',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: Text(
                      deliveryIncluded
                          ? 'Mijoz set narxidan tashqari pochta to‘lamaydi.'
                          : 'Pochta set narxidan alohida hisoblanadi.',
                    ),
                  ),
                                    SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: active,
                    onChanged: (v) => setLocal(() => active = v),
                    title: const Text('Mijozlarga ko‘rsatish'),
                  ),
                  const Divider(),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Set tarkibi',
                        style: TextStyle(fontWeight: FontWeight.w900)),
                  ),
                  ...books.where((b) => b.isActive).map((book) {
                    final qty = selected[book.id] ?? 0;
                    return CheckboxListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      value: qty > 0,
                      title: Text(book.title),
                      subtitle: Text(
                        [
                          _won(book.price),
                          if (qty > 1) '×$qty = ${_won(book.price * qty)}',
                          'ombor ' + book.stock.toString(),
                        ].join(' • '),
                      ),
                      secondary: qty > 0
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  onPressed: qty <= 1
                                      ? null
                                      : () => setLocal(
                                            () => selected[book.id] = qty - 1,
                                          ),
                                  icon: const Icon(Icons.remove_circle_outline),
                                ),
                                Text(qty.toString(),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w900)),
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  onPressed: () => setLocal(
                                    () => selected[book.id] = qty + 1,
                                  ),
                                  icon: const Icon(Icons.add_circle_outline),
                                ),
                              ],
                            )
                          : null,
                      onChanged: (v) => setLocal(() {
                        if (v == true) {
                          selected[book.id] = 1;
                        } else {
                          selected.remove(book.id);
                        }
                      }),
                    );
                  }),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Bekor qilish'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Saqlash'),
            ),
          ],
        ),
      ),
    );

    if (saved != true) {
      title.dispose();
      description.dispose();
      price.dispose();
      return;
    }
    if (title.text.trim().length < 2 || selected.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Set nomi va kitoblarini tanlang.')),
        );
      }
      title.dispose();
      description.dispose();
      price.dispose();
      return;
    }

    final setPrice = int.tryParse(
          price.text.replaceAll(RegExp(r'[^0-9]'), ''),
        ) ??
        0;
    if (setPrice <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Set narxini kiriting.')),
        );
      }
      title.dispose();
      description.dispose();
      price.dispose();
      return;
    }

    final items = <Map<String, dynamic>>[];
    for (final entry in selected.entries) {
      Book? selectedBook;
      for (final candidate in books) {
        if (candidate.id == entry.key) {
          selectedBook = candidate;
          break;
        }
      }
      if (selectedBook == null) continue;
      items.add({'book_id': selectedBook.id, 'quantity': entry.value});
    }

    try {
      final rawId = (bundle?['id'] ?? '').toString().trim();
      await widget.api.saveBundle(
        id: rawId.isEmpty ? null : rawId,
        title: title.text.trim(),
        description: description.text.trim(),
        price: setPrice,
        active: active,
        deliveryIncluded: deliveryIncluded,
        items: items,
      );
      if (mounted) {
        setState(_reload);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kitob seti saqlandi ✅')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Set saqlanmadi: ' + e.toString())),
        );
      }
    } finally {
      title.dispose();
      description.dispose();
      price.dispose();
    }
  }

  Future<void> _deleteBundle(Map<String, dynamic> bundle) async {
    final id = (bundle['id'] ?? '').toString();
    if (id.isEmpty) return;
    final title = (bundle['title'] ?? 'Kitob seti').toString();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Setni o‘chirish'),
        content: Text('“$title” setini butunlay o‘chirasizmi?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Yo‘q'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('O‘chirish'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.api.deleteBundle(id);
      if (!mounted) return;
      setState(_reload);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kitob seti o‘chirildi.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Set o‘chirilmadi: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Savdo imkoniyatlari')),
        body: FutureBuilder<List<Object>>(
          future: future,
          builder: (context, snap) {
            if (!snap.hasData) {
              if (snap.hasError) {
                return Center(
                  child: Text('Xatolik: ' + snap.error.toString()),
                );
              }
              return const Center(child: CircularProgressIndicator());
            }
            final insight =
                Map<String, dynamic>.from(snap.data![0] as Map);
            final bundles = (snap.data![1] as List)
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList();
            final books = (snap.data![2] as List).cast<Book>();
            final preorders = _rows(insight['preorders']);
            final requests = _rows(insight['requests']);
            final misses = _rows(insight['search_misses']);
            final restock = _rows(insight['restock']);
            final bundleSales = _rows(insight['bundle_sales']);
            final bundleSummary = insight['bundle_summary'] is Map
                ? Map<String, dynamic>.from(insight['bundle_summary'] as Map)
                : <String, dynamic>{};

            return RefreshIndicator(
              onRefresh: () async {
                setState(_reload);
                await future;
              },
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  AppSurface(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppSectionHeader(
                          title: 'Kitob setlari',
                          subtitle:
                              'Bir nechta kitobni bitta tayyor to‘plam qilib ko‘rsating',
                          icon: Icons.auto_awesome_mosaic_rounded,
                          trailing: FilledButton.icon(
                            onPressed: () => _openBundleEditor(books),
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('Yangi set'),
                          ),
                        ),
                        const SizedBox(height: 10),
                        if (bundles.isEmpty)
                          const Text('Hozircha set yo‘q.',
                              style: TextStyle(color: AppColors.muted))
                        else
                          ...bundles.map(
                            (b) => ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(
                                  Icons.collections_bookmark_rounded),
                              title: Text(
                                (b['title'] ?? '').toString(),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800),
                              ),
                              subtitle: Text(
                                [
                                  _rows(b['items']).length.toString() +
                                      ' turdagi kitob',
                                  'Oddiy: ${_won((b['regular_total'] as num?)?.toInt() ?? 0)}',
                                  'Set: ${_won((b['price'] as num?)?.toInt() ?? 0)}',
                                  b['delivery_included'] == true
                                      ? 'pochta ichida'
                                      : 'pochta alohida',
                                ].join(' • '),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    b['is_active'] == true
                                        ? Icons.visibility_rounded
                                        : Icons.visibility_off_rounded,
                                  ),
                                  IconButton(
                                    tooltip: 'Setni o‘chirish',
                                    onPressed: () => _deleteBundle(b),
                                    icon: const Icon(
                                      Icons.delete_outline_rounded,
                                      color: AppColors.danger,
                                    ),
                                  ),
                                ],
                              ),
                              onTap: () =>
                                  _openBundleEditor(books, bundle: b),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  AppSurface(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppSectionHeader(
                          title: 'Set savdolari statistikasi',
                          subtitle:
                              'Set narxi, tejash va pochta set ichida yoki alohida hisoblangani',
                          icon: Icons.query_stats_rounded,
                          trailing: AppInfoPill(
                            label:
                                '${bundleSummary['sets_sold'] ?? bundleSales.length} ta set',
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            AppInfoPill(
                              icon: Icons.payments_outlined,
                              label:
                                  'Set savdosi ${_won((bundleSummary['set_revenue'] as num?)?.toInt() ?? 0)}',
                            ),
                            AppInfoPill(
                              icon: Icons.savings_outlined,
                              label:
                                  'Mijoz tejadi ${_won((bundleSummary['set_savings'] as num?)?.toInt() ?? 0)}',
                              foreground: AppColors.success,
                              background: AppColors.successSoft,
                            ),
                            AppInfoPill(
                              icon: Icons.local_shipping_outlined,
                              label:
                                  'Pochta ichida ${bundleSummary['shipping_included_sets'] ?? 0} ta',
                            ),
                            AppInfoPill(
                              icon: Icons.add_road_rounded,
                              label:
                                  'Pochta alohida ${bundleSummary['shipping_separate_sets'] ?? 0} ta',
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        if (bundleSales.isEmpty)
                          const Text(
                            'Hozircha sotilgan set yo‘q.',
                            style: TextStyle(color: AppColors.muted),
                          )
                        else
                          ...bundleSales.take(30).map(
                            (sale) => ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(
                                Icons.collections_bookmark_rounded,
                              ),
                              title: Text(
                                (sale['title'] ?? 'Kitoblar seti').toString(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              subtitle: Text(
                                [
                                  '#${sale['order_number'] ?? ''}',
                                  '${sale['book_count'] ?? 0} ta kitob',
                                  'set ${_won((sale['set_price'] as num?)?.toInt() ?? 0)}',
                                  'tejash ${_won((sale['saving'] as num?)?.toInt() ?? 0)}',
                                  sale['delivery_included'] == true
                                      ? 'pochta ichida'
                                      : 'pochta alohida',
                                  if (sale['delivery_included'] != true)
                                    'pochta ${_won((sale['order_delivery_fee'] as num?)?.toInt() ?? 0)}',
                                ].join(' • '),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _AdminInsightCard(
                    title: 'Pre-order',
                    icon: Icons.event_available_rounded,
                    rows: preorders,
                    empty: 'Hozircha pre-order yo‘q.',
                    line: (r) => [
                      (r['title'] ?? '').toString(),
                      (r['quantity'] ?? 1).toString() + ' dona',
                      (r['customer_name'] ?? 'Mijoz').toString(),
                    ].join(' • '),
                  ),
                  const SizedBox(height: 14),
                  _AdminInsightCard(
                    title: '“Shu kitob kerak” so‘rovlari',
                    icon: Icons.library_add_rounded,
                    rows: requests,
                    empty: 'Hozircha kitob so‘rovi yo‘q.',
                    line: (r) => [
                      (r['title'] ?? '').toString(),
                      if ((r['phone'] ?? '').toString().trim().isNotEmpty)
                        r['phone'].toString(),
                    ].join(' • '),
                  ),
                  const SizedBox(height: 14),
                  _AdminInsightCard(
                    title: 'Qayta olib kelish tavsiyasi',
                    icon: Icons.replay_circle_filled_rounded,
                    rows: restock,
                    empty: 'Hozircha alohida tavsiya yo‘q.',
                    line: (r) => [
                      (r['title'] ?? '').toString(),
                      'ombor ' + (r['stock'] ?? 0).toString(),
                      'kutmoqda ' + (r['waiting'] ?? 0).toString(),
                      '30 kunda ' + (r['sold_30d'] ?? 0).toString() + ' sotildi',
                    ].join(' • '),
                  ),
                  const SizedBox(height: 14),
                  _AdminInsightCard(
                    title: 'Topilmagan qidiruvlar statistikasi',
                    icon: Icons.manage_search_rounded,
                    rows: misses,
                    empty: 'Topilmagan qidiruvlar hali yo‘q.',
                    line: (r) => [
                      (r['query'] ?? '').toString(),
                      (r['count'] ?? 0).toString() + ' marta',
                    ].join(' • '),
                  ),
                ],
              ),
            );
          },
        ),
      );
}

class _AdminInsightCard extends StatelessWidget {
  const _AdminInsightCard({
    required this.title,
    required this.icon,
    required this.rows,
    required this.empty,
    required this.line,
  });
  final String title;
  final IconData icon;
  final List<Map<String, dynamic>> rows;
  final String empty;
  final String Function(Map<String, dynamic>) line;

  @override
  Widget build(BuildContext context) => AppSurface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppSectionHeader(
              title: title,
              icon: icon,
              trailing: AppInfoPill(label: rows.length.toString() + ' ta'),
            ),
            const SizedBox(height: 10),
            if (rows.isEmpty)
              Text(empty, style: const TextStyle(color: AppColors.muted))
            else
              ...rows.take(30).map(
                    (row) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.chevron_right_rounded),
                      title: Text(
                        line(row),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
          ],
        ),
      );
}

class _DiscountAdmin extends StatefulWidget {
  const _DiscountAdmin({required this.api});
  final _AdminApi api;

  @override
  State<_DiscountAdmin> createState() => _DiscountAdminState();
}

class _DiscountAdminState extends State<_DiscountAdmin> {
  final percent = TextEditingController(text: '20');
  bool loading = false;
  bool freeDeliveryForFourPlus = true;
  late DateTime endsAt;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    endsAt = DateTime(now.year, now.month, now.day + 1, 23, 59);
  }

  Future<void> pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: endsAt.isAfter(now) ? endsAt : now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 2, 12, 31),
      helpText: 'Chegirma tugash sanasi',
    );
    if (picked == null || !mounted) return;
    setState(() {
      endsAt = DateTime(
        picked.year,
        picked.month,
        picked.day,
        endsAt.hour,
        endsAt.minute,
      );
    });
  }

  Future<void> pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(endsAt),
      helpText: 'Chegirma tugash vaqti',
    );
    if (picked == null || !mounted) return;
    setState(() {
      endsAt = DateTime(
        endsAt.year,
        endsAt.month,
        endsAt.day,
        picked.hour,
        picked.minute,
      );
    });
  }

  @override
  void dispose() {
    percent.dispose();
    super.dispose();
  }

  Future<void> apply() async {
    final p = int.tryParse(percent.text.trim());
    if (p == null || p < 1 || p > 99) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('1 dan 99 gacha foiz kiriting.')),
      );
      return;
    }
    if (!endsAt.isAfter(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tugash sanasi va soati kelajakda bo‘lsin.')),
      );
      return;
    }
    setState(() => loading = true);
    try {
      await widget.api.applyDiscount(
        p,
        endsAt,
        freeDeliveryForFourPlus: freeDeliveryForFourPlus,
      );
      await context.read<AppState>().refreshBooks();
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(
              SnackBar(
                content: Text(
                  '$p% chegirma ${DateFormat('yyyy.MM.dd HH:mm').format(endsAt)} gacha qo‘llandi ✅',
                ),
              ),
            );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> clear() async {
    setState(() => loading = true);
    try {
      await widget.api.clearDiscounts();
      await context.read<AppState>().refreshBooks();
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Barcha chegirmalar bekor qilindi.')),
        );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        const AppPageHeading(
          title: 'Chegirma boshqaruvi',
          subtitle:
              'Aksiya foizini bir necha soniyada barcha kitoblarga qo‘llang.',
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, c) {
            final wide = c.maxWidth >= 760;
            final editor = AppSurface(
              shadow: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AppSectionHeader(
                    title: 'Yangi aksiya',
                    subtitle: 'Foizni tanlang yoki qo‘lda kiriting',
                    icon: Icons.sell_outlined,
                  ),
                  const SizedBox(height: 15),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [10, 15, 20, 25, 30]
                        .map(
                          (v) => ActionChip(
                            label: Text('$v%'),
                            onPressed: loading
                                ? null
                                : () => setState(() => percent.text = '$v'),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: percent,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Chegirma foizi',
                      prefixIcon: Icon(Icons.percent_rounded),
                      suffixText: '%',
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Chegirma qachon tugaydi?',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: loading ? null : pickDate,
                          icon: const Icon(Icons.calendar_month_rounded),
                          label: Text(DateFormat('yyyy.MM.dd').format(endsAt)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: loading ? null : pickTime,
                          icon: const Icon(Icons.schedule_rounded),
                          label: Text(DateFormat('HH:mm').format(endsAt)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Aynan ${DateFormat('yyyy.MM.dd HH:mm').format(endsAt)} da chegirma avtomatik tugaydi.',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.muted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surfaceSoft,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: SwitchListTile.adaptive(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 4,
                      ),
                      secondary: const Icon(
                        Icons.local_shipping_rounded,
                        color: AppColors.navy,
                      ),
                      title: const Text(
                        '4+ kitobda yetkazib berish bepul',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                      subtitle: const Text(
                        'Bu aksiya chegirma davrida ham amal qilsinmi?',
                      ),
                      value: freeDeliveryForFourPlus,
                      onChanged: loading
                          ? null
                          : (value) => setState(
                                () => freeDeliveryForFourPlus = value,
                              ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    freeDeliveryForFourPlus
                        ? 'Yoqilgan: chegirma davrida ham 4+ kitobda yetkazib berish bepul.'
                        : 'O‘chirilgan: chegirma davrida 4+ kitob uchun ham yetkazib berish ₩4,000.',
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppColors.muted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: loading ? null : apply,
                      icon: const Icon(Icons.campaign_outlined),
                      label: const Text('Chegirmani qo‘llash'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: loading ? null : clear,
                      icon: const Icon(Icons.delete_sweep_outlined),
                      label: const Text('Barcha chegirmalarni bekor qilish'),
                    ),
                  ),
                ],
              ),
            );
            final guide = AppSurface(
              backgroundColor: AppColors.surfaceSoft,
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppSectionHeader(
                    title: 'Aksiya tavsiyasi',
                    subtitle: 'Narxni tushunarli va ishonchli ko‘rsating',
                    icon: Icons.tips_and_updates_outlined,
                  ),
                  SizedBox(height: 14),
                  _DiscountTip(
                    icon: Icons.visibility_outlined,
                    title: 'Eski narx ko‘rinadi',
                    text: 'Chegirma yoqilganda asl narx ustidan chiziq bilan ko‘rsatiladi.',
                  ),
                  SizedBox(height: 10),
                  _DiscountTip(
                    icon: Icons.calculate_outlined,
                    title: 'Yangi narx avtomatik',
                    text: 'Mijozga chegirmadan keyingi yakuniy narx ko‘rsatiladi.',
                  ),
                  SizedBox(height: 10),
                  _DiscountTip(
                    icon: Icons.restart_alt_rounded,
                    title: 'Avtomatik tugaydi',
                    text: 'Belgilangan sana va soatda aksiya o‘zi to‘xtaydi; qo‘lda o‘chirish shart emas.',
                  ),
                ],
              ),
            );
            return wide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: editor),
                      const SizedBox(width: 14),
                      Expanded(child: guide),
                    ],
                  )
                : Column(children: [editor, const SizedBox(height: 14), guide]);
          },
        ),
      ],
    );
  }
}

class _DiscountTip extends StatelessWidget {
  const _DiscountTip({
    required this.icon,
    required this.title,
    required this.text,
  });
  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Icon(icon, size: 19, color: AppColors.navy),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 2),
            Text(
              text,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.muted,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class _SalesAdmin extends StatefulWidget {
  const _SalesAdmin({super.key, required this.api});
  final _AdminApi api;

  @override
  State<_SalesAdmin> createState() => _SalesAdminState();
}

class _SalesAdminState extends State<_SalesAdmin> {
  late Future<List<Map<String, dynamic>>> future;
  String query = '';
  String source = 'all';

  @override
  void initState() {
    super.initState();
    future = widget.api.sales();
  }

  void reload() {
    if (!mounted) return;
    setState(() => future = widget.api.sales());
  }

  Future<void> reloadQuietly() async {
    try {
      final data = await widget.api.sales();
      if (!mounted) return;
      setState(() => future = Future.value(data));
    } catch (_) {
      // 15 soniyalik fon yangilanishida eski ro‘yxat ekranda qoladi.
    }
  }

  String _sourceLabel(String value) {
    switch (value) {
      case 'instagram':
        return 'Instagram';
      case 'telegram':
        return 'Telegram';
      default:
        return 'Ilova';
    }
  }

  IconData _sourceIcon(String value) {
    switch (value) {
      case 'instagram':
        return Icons.camera_alt_outlined;
      case 'telegram':
        return Icons.send_outlined;
      default:
        return Icons.phone_iphone_rounded;
    }
  }

  DateTime? _soldAt(Map<String, dynamic> row) {
    final raw = (row['sold_at'] ?? '').toString();
    return DateTime.tryParse(raw)?.toLocal();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting &&
            snap.data == null) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(
            child: AppSurface(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.cloud_off_rounded,
                    size: 42,
                    color: AppColors.danger,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Sotuv tarixini yuklab bo‘lmadi',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 10),
                  FilledButton.tonalIcon(
                    onPressed: reload,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Qayta urinish'),
                  ),
                ],
              ),
            ),
          );
        }

        final all = snap.data ?? const <Map<String, dynamic>>[];
        final now = DateTime.now();
        final todayCount = all.where((row) {
          final dt = _soldAt(row);
          return dt != null &&
              dt.year == now.year &&
              dt.month == now.month &&
              dt.day == now.day;
        }).length;
        final monthCount = all.where((row) {
          final dt = _soldAt(row);
          return dt != null && dt.year == now.year && dt.month == now.month;
        }).length;

        final q = query.trim().toLowerCase();
        final filtered = all.where((row) {
          final rowSource = (row['source'] ?? 'app').toString();
          final title = (row['title'] ?? 'Kitob').toString();
          final matchesSource = source == 'all' || rowSource == source;
          final matchesQuery = q.isEmpty || title.toLowerCase().contains(q);
          return matchesSource && matchesQuery;
        }).toList();

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppPageHeading(
                    title: 'Sotilgan kitoblar',
                    subtitle: 'Ilova, Telegram va Instagram savdolari bitta tarixda saqlanadi.',
                    trailing: IconButton.filledTonal(
                      onPressed: reload,
                      tooltip: 'Yangilash',
                      icon: const Icon(Icons.refresh_rounded),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      AppInfoPill(
                        icon: Icons.auto_stories_rounded,
                        label: 'Jami ${all.length} ta',
                        foreground: AppColors.navy,
                        background: AppColors.infoSoft,
                        border: AppColors.border,
                      ),
                      AppInfoPill(
                        icon: Icons.today_rounded,
                        label: 'Bugun $todayCount ta',
                        foreground: AppColors.success,
                        background: AppColors.successSoft,
                        border: AppColors.border,
                      ),
                      AppInfoPill(
                        icon: Icons.calendar_month_rounded,
                        label: 'Shu oy $monthCount ta',
                        foreground: AppColors.orange,
                        background: const Color(0xFFFFF3E3),
                        border: AppColors.border,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    onChanged: (value) => setState(() => query = value),
                    decoration: const InputDecoration(
                      hintText: 'Kitob nomi bo‘yicha qidirish...',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final item in const [
                          ('all', 'Barchasi'),
                          ('app', 'Ilova'),
                          ('telegram', 'Telegram'),
                          ('instagram', 'Instagram'),
                        ]) ...[
                          ChoiceChip(
                            label: Text(item.$2),
                            selected: source == item.$1,
                            onSelected: (_) => setState(() => source = item.$1),
                          ),
                          const SizedBox(width: 8),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async => reload(),
                child: filtered.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(18),
                        children: const [
                          SizedBox(height: 80),
                          Center(
                            child: Text(
                              'Hozircha mos sotuv topilmadi.',
                              style: TextStyle(
                                color: AppColors.muted,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      )
                    : ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(18, 4, 18, 28),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final row = filtered[index];
                          final title = (row['title'] ?? 'Kitob').toString();
                          final rowSource = (row['source'] ?? 'app').toString();
                          final dt = _soldAt(row);
                          final date = dt == null
                              ? '—'
                              : DateFormat('dd.MM.yyyy').format(dt);
                          return AppSurface(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 42,
                                  child: Text(
                                    '${index + 1}.',
                                    style: const TextStyle(
                                      color: AppColors.muted,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    '$title ($date)',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.navy,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Tooltip(
                                  message: _sourceLabel(rowSource),
                                  child: Icon(
                                    _sourceIcon(rowSource),
                                    size: 19,
                                    color: AppColors.muted,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CustomersAdmin extends StatefulWidget {
  const _CustomersAdmin({super.key, required this.api});
  final _AdminApi api;

  @override
  State<_CustomersAdmin> createState() => _CustomersAdminState();
}

class _CustomersAdminState extends State<_CustomersAdmin> {
  late Future<(Map<String, dynamic>, List<Map<String, dynamic>>)> future;
  String query = '';

  void reload() {
    if (!mounted) return;
    _reload();
    setState(() {});
  }

  Future<void> reloadQuietly() async {
    try {
      final values = await Future.wait<dynamic>([
        widget.api.userStats(),
        widget.api.customers(),
      ]);
      final data = (
        Map<String, dynamic>.from(values[0] as Map),
        (values[1] as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList(),
      );
      if (!mounted) return;
      setState(() => future = Future.value(data));
    } catch (_) {
      // Keep the current customer list visible during background refresh.
    }
  }

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    future =
        Future.wait<dynamic>([widget.api.userStats(), widget.api.customers()])
            .then(
              (v) => (
                Map<String, dynamic>.from(v[0] as Map),
                (v[1] as List)
                    .map((e) => Map<String, dynamic>.from(e as Map))
                    .toList(),
              ),
            );
  }

  String _date(dynamic value) {
    final d = DateTime.tryParse((value ?? '').toString())?.toLocal();
    if (d == null) return '—';
    return DateFormat('yyyy.MM.dd HH:mm').format(d);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<(Map<String, dynamic>, List<Map<String, dynamic>>)>(
      future: future,
      builder: (context, snapshot) {
        // Faqat birinchi yuklanishda katta spinner ko‘rsatamiz.
        // Har 15 soniyadagi fon yangilanishida mijozlar ro‘yxati ekranda qoladi.
        if (snapshot.connectionState == ConnectionState.waiting &&
            snapshot.data == null) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: FilledButton.icon(
              onPressed: () => setState(_reload),
              icon: const Icon(Icons.refresh_rounded),
              label: Text('Qayta yuklash: ${snapshot.error}'),
            ),
          );
        }
        final stats = snapshot.data?.$1 ?? <String, dynamic>{};
        final all = snapshot.data?.$2 ?? <Map<String, dynamic>>[];
        final q = query.trim().toLowerCase();
        final customers = all.where((c) {
          if (q.isEmpty) return true;
          return (c['full_name'] ?? '').toString().toLowerCase().contains(q) ||
              (c['phone'] ?? '').toString().toLowerCase().contains(q);
        }).toList();

        Widget metric(String label, dynamic value, IconData icon) => Expanded(
          child: AppSurface(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: AppColors.navy, size: 20),
                const SizedBox(height: 10),
                Text(
                  '$value',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: AppColors.navy,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
        );

        return RefreshIndicator(
          onRefresh: () async {
            _reload();
            setState(() {});
            await future;
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 30),
            children: [
              const AppSectionHeader(
                title: 'Mijozlar markazi',
                subtitle: 'Loginlar, faol foydalanuvchilar va xarid tarixi',
                icon: Icons.people_alt_rounded,
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  metric(
                    'Ro‘yxatdan o‘tgan',
                    stats['total_users'] ?? 0,
                    Icons.person_add_alt_1_rounded,
                  ),
                  const SizedBox(width: 10),
                  metric(
                    'Bugun faol',
                    stats['active_today'] ?? 0,
                    Icons.bolt_rounded,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  metric(
                    'Ilova qurilmalari',
                    stats['total_installs'] ?? 0,
                    Icons.phone_iphone_rounded,
                  ),
                  const SizedBox(width: 10),
                  metric(
                    '7 kunda faol',
                    stats['active_7d'] ?? 0,
                    Icons.calendar_view_week_rounded,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              AppSurface(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    const Icon(
                      Icons.receipt_long_rounded,
                      color: AppColors.navy,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Ochiq buyurtmalar: ${stats['open_orders'] ?? 0} • Jo‘natilgan: ${stats['completed_orders'] ?? 0}',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    Text(
                      _won((stats['completed_revenue'] as num?)?.toInt() ?? 0),
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        color: AppColors.success,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                onChanged: (v) => setState(() => query = v),
                decoration: const InputDecoration(
                  hintText: 'Ism yoki telefon bo‘yicha qidirish...',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
              const SizedBox(height: 12),
              if (customers.isEmpty)
                const AppSurface(
                  child: Text('Hozircha ro‘yxatdan o‘tgan mijoz yo‘q.'),
                )
              else
                ...customers.map(
                  (c) => Padding(
                    padding: const EdgeInsets.only(bottom: 9),
                    child: AppSurface(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: AppColors.infoSoft,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.person_rounded,
                              color: AppColors.info,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  (c['full_name'] ?? '')
                                          .toString()
                                          .trim()
                                          .isEmpty
                                      ? 'Nomsiz mijoz'
                                      : c['full_name'].toString(),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  (c['phone'] ?? '—').toString(),
                                  style: const TextStyle(
                                    color: AppColors.muted,
                                  ),
                                ),
                                const SizedBox(height: 7),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 6,
                                  children: [
                                    AppInfoPill(
                                      icon: Icons.shopping_bag_outlined,
                                      label:
                                          '${c['order_count'] ?? 0} buyurtma',
                                    ),
                                    AppInfoPill(
                                      icon: Icons.payments_outlined,
                                      label: _won(
                                        (c['spent'] as num?)?.toInt() ?? 0,
                                      ),
                                      foreground: AppColors.success,
                                      background: AppColors.successSoft,
                                      border: const Color(0xFFCDEAD7),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text(
                                'Oxirgi faollik',
                                style: TextStyle(
                                  color: AppColors.muted,
                                  fontSize: 10.5,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                _date(c['last_seen_at']),
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${c['login_count'] ?? 0} login',
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  color: AppColors.muted,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}


class _AdminAiPage extends StatefulWidget {
  const _AdminAiPage({required this.api});
  final _AdminApi api;
  @override State<_AdminAiPage> createState()=>_AdminAiPageState();
}
class _AdminAiPageState extends State<_AdminAiPage> {
  final q=TextEditingController(); String answer=''; bool loading=false;
  @override void dispose(){q.dispose();super.dispose();}
  Future<void> ask() async {
    final value=q.text.trim(); if(value.isEmpty||loading)return;
    setState((){loading=true;answer='';});
    try { final a=await widget.api.aiAsk(value); if(mounted)setState(()=>answer=a); }
    catch(e){if(mounted)setState(()=>answer='Xatolik: ' + e.toString());}
    finally{if(mounted)setState(()=>loading=false);}
  }
  @override Widget build(BuildContext context)=>ListView(padding:const EdgeInsets.all(16),children:[
    const Text('Muhajeer Admin AI',style:TextStyle(fontSize:24,fontWeight:FontWeight.w900)),
    const SizedBox(height:6),
    const Text('Savdo, ombor, tannarx, foyda, buyurtmalar va internetdagi joriy ma’lumotlarni tahlil qiladi. O‘zi ma’lumotni o‘zgartirmaydi.',style:TextStyle(color:AppColors.muted,height:1.4)),
    const SizedBox(height:14),
    TextField(controller:q,minLines:2,maxLines:5,onSubmitted:(_)=>ask(),decoration:const InputDecoration(hintText:'Masalan: Qaysi kitoblarni qayta olib kelish kerak? Bu oy savdo holati qanday?')),
    const SizedBox(height:10),
    FilledButton.icon(onPressed:loading?null:ask,icon:loading?const SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2)):const Icon(Icons.auto_awesome_rounded),label:Text(loading?'Tahlil qilmoqda...':'AI dan so‘rash')),
    if(answer.isNotEmpty)...[const SizedBox(height:16),AppSurface(padding:const EdgeInsets.all(16),child:SelectableText(answer,style:const TextStyle(fontSize:15.5,height:1.55,fontWeight:FontWeight.w500)))],
  ]);
}
