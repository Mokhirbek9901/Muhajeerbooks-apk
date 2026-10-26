/// Calendar fields for the store's Asia/Seoul business day (UTC+09:00).
/// Use only for calendar filters and formatting, never for elapsed durations.
DateTime koreaTime(DateTime instant) =>
    instant.toUtc().add(const Duration(hours: 9));
DateTime koreaNow() => koreaTime(DateTime.now());
bool sameKoreaDay(DateTime a, DateTime b) {
  final x = koreaTime(a), y = koreaTime(b);
  return x.year == y.year && x.month == y.month && x.day == y.day;
}
