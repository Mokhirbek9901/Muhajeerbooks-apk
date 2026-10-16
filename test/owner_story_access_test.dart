import 'package:flutter_test/flutter_test.dart';
import 'package:muhajeerbooks/app_state.dart';
import 'package:muhajeerbooks/owner_story_access.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('phone numbers normalize across domestic and country-code forms', () {
    expect(OwnerStoryAccess.normalizePhone('010-1111-2222'), '01011112222');
    expect(OwnerStoryAccess.normalizePhone('+82 10 1111 2222'), '01011112222');
    expect(OwnerStoryAccess.normalizePhone('821011112222'), '01011112222');
  });

  test('profile names normalize without ignoring changed identity', () {
    expect(OwnerStoryAccess.normalizeName('  Example   Owner '), 'example owner');
    expect(OwnerStoryAccess.normalizeName('Different Person'),
        isNot(OwnerStoryAccess.normalizeName('Example Owner')));
  });

  test('ordinary customers can never access Story without admin proof', () {
    final state = AppState(backendConfigured: false);
    state.savedCustomer = const {
      'name': 'Example Owner', 'phone': '01011112222', 'address': '',
    };
    OwnerStoryAccess.instance.lock();
    expect(OwnerStoryAccess.instance.allowedFor(state), isFalse);
    state.dispose();
  });
}
