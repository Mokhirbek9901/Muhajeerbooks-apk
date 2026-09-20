/// Volatile admin session only. Never persisted here.
/// Server still verifies the admin code before any paid AI request.
class AdminSession {
  AdminSession._();
  static String? code;
  static bool get active => code?.trim().isNotEmpty == true;
  static void set(String value) => code = value.trim();
  static void clear() => code = null;
}
