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

  test('published App Store 2.5.24 forces 2.5.23 but not current 2.5.24', () {
    expect(iosPublishedUpdateAvailable(
      installedVersion: '2.5.23', installedBuild: 17003,
      publishedVersion: '2.5.24', publishedBuild: 0), isTrue);
    expect(iosPublishedUpdateAvailable(
      installedVersion: '2.5.24', installedBuild: 30008,
      publishedVersion: '2.5.24', publishedBuild: 0), isFalse);
    expect(iosPublishedUpdateAvailable(
      installedVersion: '2.5.25', installedBuild: 30011,
      publishedVersion: '2.5.24', publishedBuild: 0), isFalse);
  });

  test('release version numeric segments, not lexicographical', () {
    expect(compareIosMarketingVersions('2.5.10', '2.5.9'), 1);
    expect(compareIosMarketingVersions('2.5.22', '2.5.22+2144'), 0);
  });
  test('verified public 2.5.23 prompts old 2.5.22 installs', () {
    expect(iosPublishedUpdateAvailable(
      installedVersion: '2.5.22', installedBuild: 2144,
      publishedVersion: '2.5.23', publishedBuild: 17003), isTrue);
  });

  test('up-to-date public release does not prompt itself', () {
    expect(iosPublishedUpdateAvailable(
      installedVersion: '2.5.23', installedBuild: 17003,
      publishedVersion: '2.5.23', publishedBuild: 17003), isFalse);
  });

  test('higher TestFlight never gets sent to an older public release', () {
    expect(iosPublishedUpdateAvailable(
      installedVersion: '2.5.24', installedBuild: 30004,
      publishedVersion: '2.5.23', publishedBuild: 17003), isFalse);
  });

  test('App Store 2.5.24 shows update to installed public 2.5.23', () {
    expect(iosPublishedUpdateAvailable(
      installedVersion: '2.5.23', installedBuild: 17003,
      publishedVersion: '2.5.24', publishedBuild: 30008), isTrue);
  });

  test('public 2.5.24 does not ask same build to update', () {
    expect(iosPublishedUpdateAvailable(
      installedVersion: '2.5.24', installedBuild: 30008,
      publishedVersion: '2.5.24', publishedBuild: 30008), isFalse);
  });


}
