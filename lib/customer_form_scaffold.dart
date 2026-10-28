import 'package:flutter/material.dart';

/// Customer forms share an explicit dismissal action for iOS number pads,
/// which do not provide a Done key. Tapping empty space also closes input.
class CustomerFormScaffold extends StatelessWidget {
  const CustomerFormScaffold({
    super.key,
    this.appBar,
    this.backgroundColor,
    required this.body,
  });

  final PreferredSizeWidget? appBar;
  final Color? backgroundColor;
  final Widget body;

  static void dismissKeyboard() =>
      FocusManager.instance.primaryFocus?.unfocus();

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: appBar,
    backgroundColor: backgroundColor,
    resizeToAvoidBottomInset: true,
    body: GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: dismissKeyboard,
      child: Column(
        children: [
          Expanded(child: body),
          if (MediaQuery.viewInsetsOf(context).bottom > 0) Material(
            color: Theme.of(context).colorScheme.surface,
            child: SafeArea(
              top: false,
              child: Align(
                heightFactor: 1,
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  key: const ValueKey('dismiss-customer-keyboard'),
                  onPressed: dismissKeyboard,
                  icon: const Icon(Icons.keyboard_hide_outlined),
                  label: const Text('Klaviaturani yopish'),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
