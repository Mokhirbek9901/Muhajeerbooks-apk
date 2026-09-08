/// Accept Korean local mobile numbers or an explicit international number.
String? normalizeCustomerPhone(String input) {
  final raw = input.trim();
  if (raw.isEmpty || !RegExp(r'^[+0-9() -]+$').hasMatch(raw)) return null;
  final digits = raw.replaceAll(RegExp(r'\D'), '');
  String value;
  if (raw.startsWith('+') && '+'.allMatches(raw).length == 1) {
    value = '+$digits';
  } else if (raw.contains('+')) {
    return null;
  } else if (digits.startsWith('82')) {
    value = '+$digits';
  } else if (digits.startsWith('010')) {
    value = '+82${digits.substring(1)}';
  } else if (digits.startsWith('10')) {
    value = '+82$digits';
  } else {
    return null;
  }
  if (!RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(value)) return null;
  if (value.startsWith('+82') && !RegExp(r'^\+8210\d{8}$').hasMatch(value)) {
    return null;
  }
  return value;
}

const shopOwnerName = 'Mohirbek Ismoilov';
