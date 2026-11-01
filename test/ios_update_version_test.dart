import 'package:flutter_test/flutter_test.dart';
import 'package:muhajeerbooks/ios_update_version.dart';

void main() {
  test('older public marketing version sees update', () {
    expect(iosPublishedUpdateAvailable(
      installedVersion: '2.5.21', installedBuild: 2118,
      publishedVersion: '2.5.22', publishedBuild: 2144), isTrue);
  });

  test('same marketing, lower installed build sees update', () {
    expect(iosPublishedUpdateAvailable(
      installedVersion: '2.5.22', installedBuild: 2143,
      publishedVersion: '2.5.22', publishedBuild: 2144), isTrue);
  });

  test('same exact public release does not show update', () {
    expect(iosPublishedUpdateAvailable(
      installedVersion: '2.5.22', installedBuild: 2144,
      publishedVersion: '2.5.22', publishedBuild: 2144), isFalse);
  });

  test('newer TestFlight 2146 is never forced to App Store 2144', () {
    expect(iosPublishedUpdateAvailable(
      installedVersion: '2.5.22', installedBuild: 2146,
      publishedVersion: '2.5.22', publishedBuild: 2144), isFalse);
  });

  test('missing published build does not fake same-version updates', () {
    expect(iosPublishedUpdateAvailable(
      installedVersion: '2.5.22', installedBuild: 2143,
      publishedVersion: '2.5.22', publishedBuild: 0), isFalse);
  });

  test('newer marketing takes precedence over published build', () {
    expect(iosPublishedUpdateAvailable(
      installedVersion: '2.5.23', installedBuild: 2143,
      publishedVersion: '2.5.22', publishedBuild: 9999), isFalse);
  });

  test('release version numeric segments, not lexicographical', () {
    expect(compareIosMarketingVersions('2.5.10', '2.5.9'), 1);
    expect(compareIosMarketingVersions('2.5.22', '2.5.22+2144'), 0);
  });
}
