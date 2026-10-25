import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muhajeerbooks/store_ui.dart' show shouldShowFixedCatalogSidebar;

void main() {
  test('iPad landscape uses all width even if desktop threshold is crossed', () {
    for (final width in <double>[1024, 1112, 1180, 1194, 1366, 1600, 2048]) {
      expect(shouldShowFixedCatalogSidebar(
        platform:TargetPlatform.iOS,width:width,isWeb:false),isFalse);
      expect(shouldShowFixedCatalogSidebar(
        platform:TargetPlatform.iOS,width:width,isWeb:true),isFalse);
    }
  });

  test('desktop retains its wide-screen sidebar', () {
    expect(shouldShowFixedCatalogSidebar(
      platform:TargetPlatform.macOS,width:1800,isWeb:true),isTrue);
    expect(shouldShowFixedCatalogSidebar(
      platform:TargetPlatform.macOS,width:1440,isWeb:true),isFalse);
    expect(shouldShowFixedCatalogSidebar(
      platform:TargetPlatform.windows,width:1300,isWeb:false),isTrue);
  });
}
