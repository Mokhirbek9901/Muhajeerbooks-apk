import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

Future<bool> verifyProfessionalAccess(String code) async {
  final clean = code.trim();
  if (clean.isEmpty || clean.length > 64) return false;

  final response = await Supabase.instance.client.functions.invoke(
    'admin-rpc',
    body: {
      'name': 'admin_verify',
      'params': {'p_secret': clean},
    },
  );

  final raw = response.data;
  Map<String, dynamic> envelope = <String, dynamic>{};
  if (raw is Map) {
    envelope = Map<String, dynamic>.from(raw);
  } else if (raw is String && raw.trim().isNotEmpty) {
    final decoded = jsonDecode(raw);
    if (decoded is Map) {
      envelope = Map<String, dynamic>.from(decoded);
    }
  }

  return envelope['ok'] == true && envelope['data'] == true;
}
