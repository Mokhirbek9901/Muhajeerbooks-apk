/// Pure, testable iOS update comparisons.
/// A release is public only after its marketing version and optional build
/// number have been verified against the App Store production track.
int compareIosMarketingVersions(String left, String right) {
  List<int> parts(String value) {
    final clean = value.trim().split(RegExp(r'[-+]')).first;
    return clean.split('.').map((p) => int.tryParse(p) ?? 0).toList();
  }

  final a = parts(left);
  final b = parts(right);
  final count = a.length > b.length ? a.length : b.length;
  for (var i = 0; i < count; i++) {
    final x = i < a.length ? a[i] : 0;
    final y = i < b.length ? b[i] : 0;
    if (x > y) return 1;
    if (x < y) return -1;
  }
  return 0;
}

bool iosPublishedUpdateAvailable({
  required String installedVersion,
  required int installedBuild,
  required String publishedVersion,
  required int publishedBuild,
}) {
  if (installedVersion.trim().isEmpty || publishedVersion.trim().isEmpty) {
    return false;
  }
  final versionOrder = compareIosMarketingVersions(
    publishedVersion, installedVersion);
  if (versionOrder > 0) return true;
  if (versionOrder < 0) return false;
  // Same marketing version: TestFlight may have a newer build than the
  // current App Store release. Never direct a tester to downgrade.
  return publishedBuild > 0 &&
      installedBuild > 0 &&
      publishedBuild > installedBuild;
}
