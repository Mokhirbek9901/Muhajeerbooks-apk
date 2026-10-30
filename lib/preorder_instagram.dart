import 'package:flutter/material.dart';

String normalizePreorderInstagram(String value) =>
    value.trim().replaceFirst(RegExp(r'^@'), '');

bool validPreorderInstagram(String value) =>
    RegExp(r'^[A-Za-z0-9._]{1,30}$').hasMatch(normalizePreorderInstagram(value));

class PreorderInstagramField extends StatelessWidget {
  const PreorderInstagramField({super.key, required this.controller, this.enabled = true});
  final TextEditingController controller;
  final bool enabled;
  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    enabled: enabled,
    autocorrect: false,
    enableSuggestions: false,
    textInputAction: TextInputAction.done,
    maxLength: 31,
    decoration: const InputDecoration(
      labelText: 'Instagram username (majburiy)',
      hintText: '@username',
      helperText: 'Kitob kelganda shu Instagram orqali siz bilan bog‘lanamiz.',
      helperMaxLines: 2,
    ),
    validator: (value) => validPreorderInstagram(value ?? '')
        ? null : 'Instagram username kiriting: @username',
  );
}


/// Contact method used for prepaid orders. Older orders remain Instagram.
enum PreorderContactPlatform { instagram, telegram }

String preorderContactName(PreorderContactPlatform platform) =>
    platform == PreorderContactPlatform.telegram ? 'Telegram' : 'Instagram';

String normalizePreorderContact(String value) => normalizePreorderInstagram(value);

bool validPreorderContact(String value, PreorderContactPlatform platform) {
  final username = normalizePreorderContact(value);
  if (platform == PreorderContactPlatform.telegram) {
    return RegExp(r'^[A-Za-z0-9_]{5,32}$').hasMatch(username);
  }
  return validPreorderInstagram(value);
}

class PreorderContactField extends StatelessWidget {
  const PreorderContactField({
    super.key,
    required this.controller,
    required this.platform,
    required this.onPlatformChanged,
    this.enabled = true,
  });

  final TextEditingController controller;
  final PreorderContactPlatform platform;
  final ValueChanged<PreorderContactPlatform> onPlatformChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final name = preorderContactName(platform);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Bog‘lanish uchun (majburiy)',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final choice in PreorderContactPlatform.values)
              ChoiceChip(
                label: Text(preorderContactName(choice)),
                selected: platform == choice,
                onSelected: enabled
                    ? (_) {
                        if (choice != platform) {
                          controller.clear();
                          onPlatformChanged(choice);
                        }
                      }
                    : null,
              ),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          enabled: enabled,
          autocorrect: false,
          enableSuggestions: false,
          textInputAction: TextInputAction.done,
          maxLength: platform == PreorderContactPlatform.telegram ? 33 : 31,
          decoration: InputDecoration(
            labelText: '$name username (majburiy)',
            hintText: '@username',
            helperText: 'Kitob kelganda siz kiritgan $name profilingizga xabar beramiz.\nBuyurtma holatini Profil → Oldindan buyurtmalar bo‘limida kuzatishingiz mumkin.',
            helperMaxLines: 4,
          ),
          validator: (value) => validPreorderContact(value ?? '', platform)
              ? null
              : '$name username kiriting: @username',
        ),
      ],
    );
  }
}
