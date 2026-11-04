import 'package:flutter/material.dart';

/// A compact warning for the PRIVATE admin order list only.
///
/// Never add this to shared order models, customer widgets or push payloads.
/// The actual text remains stored behind the admin-only notes endpoint.
class AdminOrderPrivateNoteBadge extends StatelessWidget {
  const AdminOrderPrivateNoteBadge({
    super.key,
    required this.note,
  });

  final String note;

  @override
  Widget build(BuildContext context) {
    final value = note.trim();
    if (value.isEmpty) return const SizedBox.shrink();

    return Tooltip(
      message: value,
      child: Semantics(
        label: 'Faqat admin uchun izoh: $value',
        child: Container(
          key: const Key('admin_private_note_header_badge'),
          constraints: const BoxConstraints(minHeight: 24),
          decoration: BoxDecoration(
            color: const Color(0xFFD9252E),
            borderRadius: BorderRadius.circular(50),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.warning_rounded,
                size: 14,
                color: Colors.white,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  value,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
