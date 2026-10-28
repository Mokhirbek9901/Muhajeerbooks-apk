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
