import '../../data/data_export.dart';
import '../../utils/utils.dart';

/// A rate found for a conversion: one unit is worth [rate] units of the
/// target currency, published (or typed in) on [date] by [source].
typedef RateQuote = ({double rate, DateTime date, RateSource source});

/// Every exchange rate of the database, for converting amounts between
/// currencies on a given day.
///
/// The rate of a day is the last one published on or before it (no rates
/// on weekends and holidays); before the first one, the first one. The
/// downloaded rates are converted through their source's pivot (HUF for
/// the MNB, EUR for the ECB), so any two of their currencies can be
/// converted. A manual rate (typed in for a pair, either way round) goes
/// before the downloaded one of the same day or before; if the chosen
/// source has none, the other source is used.
class RateBook {
  const RateBook.empty() : _series = const {}, manual = const [];

  RateBook(Iterable<ExchangeRate> rates)
    : _series = {},
      manual = [
        for (final rate in rates)
          if (rate.source == RateSource.manual) rate,
      ]..sort((a, b) => b.date.compareTo(a.date)) {
    for (final rate in rates) {
      _series
          .putIfAbsent((rate.source, rate.currency, rate.base), () => [])
          .add((rate.date, rate.rate));
    }
    for (final series in _series.values) {
      series.sort((a, b) => a.$1.compareTo(b.$1));
    }
  }

  /// The rates of a source, currency and base, the oldest first.
  final Map<(RateSource, Currency, Currency), List<(DateTime, double)>> _series;

  /// The rates typed in, the newest first.
  final List<ExchangeRate> manual;

  bool get isEmpty => _series.isEmpty;

  /// How many units of [to] one unit of [from] is worth on [date], by
  /// [source]; null if there is no rate for it.
  RateQuote? quote(
    Currency from,
    Currency to,
    DateTime date,
    RateSource source,
  ) {
    if (from == to) return (rate: 1, date: date, source: source);
    final manual = _manual(from, to, date);
    if (source == RateSource.manual) return manual;
    final downloaded = this.downloaded(from, to, date, source);
    if (manual != null &&
        (downloaded == null || !_closer(downloaded, manual, date))) {
      return manual;
    }
    return downloaded;
  }

  /// Like [quote], but only the downloaded rates: of [source] (the other
  /// source if it has none; the MNB's for manual).
  RateQuote? downloaded(
    Currency from,
    Currency to,
    DateTime date,
    RateSource source,
  ) {
    if (from == to) return (rate: 1, date: date, source: source);
    final first = source == RateSource.ecb ? RateSource.ecb : RateSource.mnb;
    return _downloaded(from, to, date, first) ??
        _downloaded(
          from,
          to,
          date,
          first == RateSource.mnb ? RateSource.ecb : RateSource.mnb,
        );
  }

  /// The rate of [source] alone for [date] as the tax rules take it: the
  /// last one published on or before the day (none after it, none of
  /// another source). Null if there is none, or the downloaded ones end
  /// more than [officialGap] days before the day (not downloaded yet).
  RateQuote? official(
    Currency from,
    Currency to,
    DateTime date,
    RateSource source,
  ) {
    if (from == to) return (rate: 1, date: date, source: source);
    final pivot = source.pivot;
    if (pivot == null) return null;
    final a = from == pivot ? null : _published((source, from, pivot), date);
    final b = to == pivot ? null : _published((source, to, pivot), date);
    if ((from != pivot && a == null) || (to != pivot && b == null)) {
      return null;
    }
    final days = [?a?.$1, ?b?.$1]..sort();
    return (
      rate: (a?.$2 ?? 1) / (b?.$2 ?? 1),
      date: days.first,
      source: source,
    );
  }

  /// The longest gap between two published rates (holidays and a weekend).
  static const int officialGap = 7;

  (DateTime, double)? _published(
    (RateSource, Currency, Currency) key,
    DateTime date,
  ) {
    final series = _series[key];
    if (series == null || series.isEmpty) return null;
    final day = DateTime(date.year, date.month, date.day);
    final found = _on(key, day)!;
    if (found.$1.isAfter(day)) return null;
    // The last one: the day may be past the downloaded ones.
    if (found.$1 == series.last.$1 &&
        day.difference(found.$1).inDays > officialGap) {
      return null;
    }
    return found;
  }

  RateQuote? _manual(Currency from, Currency to, DateTime date) {
    final direct = _on((RateSource.manual, from, to), date);
    final inverse = _on((RateSource.manual, to, from), date);
    final a = direct == null
        ? null
        : (rate: direct.$2, date: direct.$1, source: RateSource.manual);
    final b = inverse == null
        ? null
        : (rate: 1 / inverse.$2, date: inverse.$1, source: RateSource.manual);
    if (a == null) return b;
    if (b == null) return a;
    return _closer(b, a, date) ? b : a;
  }

  RateQuote? _downloaded(
    Currency from,
    Currency to,
    DateTime date,
    RateSource source,
  ) {
    final pivot = source.pivot!;
    final a = from == pivot ? null : _on((source, from, pivot), date);
    final b = to == pivot ? null : _on((source, to, pivot), date);
    if ((from != pivot && a == null) || (to != pivot && b == null)) {
      return null;
    }
    final rate = (a?.$2 ?? 1) / (b?.$2 ?? 1);
    // The farther of the two days.
    final days = [?a?.$1, ?b?.$1];
    days.sort((x, y) => _distance(x, date).compareTo(_distance(y, date)));
    return (rate: rate, date: days.last, source: source);
  }

  /// The series' rate for [date]: the last one on or before it, or the
  /// first one after it.
  (DateTime, double)? _on((RateSource, Currency, Currency) key, DateTime date) {
    final series = _series[key];
    if (series == null || series.isEmpty) return null;
    final day = DateTime(date.year, date.month, date.day);
    // The first one after the day.
    var low = 0;
    var high = series.length;
    while (low < high) {
      final mid = (low + high) ~/ 2;
      if (series[mid].$1.isAfter(day)) {
        high = mid;
      } else {
        low = mid + 1;
      }
    }
    return low == 0 ? series.first : series[low - 1];
  }

  /// Whether [a] is a better rate for [date] than [b]: one of the day or
  /// before goes before one after it; of two before it the later, of two
  /// after it the earlier.
  static bool _closer(RateQuote a, RateQuote b, DateTime date) =>
      _distance(a.date, date) < _distance(b.date, date);

  /// Days before [date] count from 0 up, days after it after every day
  /// before it.
  static int _distance(DateTime day, DateTime date) {
    final days = DateTime.utc(
      date.year,
      date.month,
      date.day,
    ).difference(DateTime.utc(day.year, day.month, day.day)).inDays;
    return days >= 0 ? days : 1000000 - days;
  }
}
