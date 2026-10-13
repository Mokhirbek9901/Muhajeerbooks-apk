import 'package:flutter_test/flutter_test.dart';
import 'package:muhajeerbooks/storefront_navigation.dart';

void main() {
  group('Home tab scroll restoration', () {
    test('returning to Home from another tab preserves scroll', () {
      for (final previousTab in [1, 2, 3, 4]) {
        expect(shouldScrollHomeToTop(previousTab, 0), isFalse,
            reason: 'First tap from tab $previousTab restores old position');
      }
    });

    test('tapping Home again while already there scrolls to top', () {
      expect(shouldScrollHomeToTop(0, 0), isTrue);
    });

    test('selecting a different destination never triggers Home scroll', () {
      for (final currentTab in [0, 1, 2, 3, 4]) {
        for (final tappedTab in [1, 2, 3, 4]) {
          expect(shouldScrollHomeToTop(currentTab, tappedTab), isFalse);
        }
      }
    });

    test('two consecutive Home taps have distinct actions', () {
      var activeTab = 4; // From Profile
      final firstTap = shouldScrollHomeToTop(activeTab, 0);
      activeTab = 0;
      final secondTap = shouldScrollHomeToTop(activeTab, 0);
      expect([firstTap, secondTap], [false, true]);
    });
  });
}
