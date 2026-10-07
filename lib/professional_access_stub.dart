import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<bool> verifyProfessionalAccess(String code) async {
  final clean = code.trim();
  if (clean.isEmpty || clean.length > 64) return false;

  const playStoreBuild = bool.fromEnvironment('PLAY_STORE_BUILD');
  final isPlayAndroid =
      defaultTargetPlatform == TargetPlatform.android && playStoreBuild;

  // iOS intentionally keeps its existing behavior until its separate update.
  if (!isPlayAndroid) return clean == '6494';

  final response = await Supabase.instance.client.functions.invoke(
    'customer-rpc',
    body: {
      'name': 'customer_professional_code_verify',
      'params': {'p_code': clean},
    },
  );

  final raw = response.data;
  Map<String, dynamic> envelope = <String, dynamic>{};
  if (raw is Map) {
    envelope = Map<String, dynamic>.from(raw);
  } else if (raw is String && raw.trim().isNotEmpty) {
    final decoded = jsonDecode(raw);
    if (decoded is Map) envelope = Map<String, dynamic>.from(decoded);
  }
  return envelope['ok'] == true && envelope['data'] == true;
}
