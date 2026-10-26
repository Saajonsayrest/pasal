import 'package:pasal_mobile/core/l10n/tr.dart';

/// Nepali (Bikram Sambat, BS) calendar. The API only knows AD dates (YYYY-MM-DD), so the app converts here.
/// Month lengths for BS 2000 to 2090 come from the MIT licensed `nepali-date-converter` package (subeshb1/Nepali-Date).
/// Anchor: BS 2000-01-01 is AD 1943-04-14. Checked: BS 2083-07-01 (Kartik 1) is AD 2026-10-18.
/// Dates outside 2000-2090 throw a [RangeError], so a wrong date is never shown silently.
/// This file matches web/src/lib/bs.ts.
const bsMinYear = 2000;
const bsMaxYear = 2090;

const _days = <int, List<int>>{
  2000: [30, 32, 31, 32, 31, 30, 30, 30, 29, 30, 29, 31],
  2001: [31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
  2002: [31, 31, 32, 32, 31, 30, 30, 29, 30, 29, 30, 30],
  2003: [31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 31],
  2004: [30, 32, 31, 32, 31, 30, 30, 30, 29, 30, 29, 31],
  2005: [31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
  2006: [31, 31, 32, 32, 31, 30, 30, 29, 30, 29, 30, 30],
  2007: [31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 31],
  2008: [31, 31, 31, 32, 31, 31, 29, 30, 30, 29, 29, 31],
  2009: [31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
  2010: [31, 31, 32, 32, 31, 30, 30, 29, 30, 29, 30, 30],
  2011: [31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 31],
  2012: [31, 31, 31, 32, 31, 31, 29, 30, 30, 29, 30, 30],
  2013: [31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
  2014: [31, 31, 32, 32, 31, 30, 30, 29, 30, 29, 30, 30],
  2015: [31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 31],
  2016: [31, 31, 31, 32, 31, 31, 29, 30, 30, 29, 30, 30],
  2017: [31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
  2018: [31, 32, 31, 32, 31, 30, 30, 29, 30, 29, 30, 30],
  2019: [31, 32, 31, 32, 31, 30, 30, 30, 29, 30, 29, 31],
  2020: [31, 31, 31, 32, 31, 31, 30, 29, 30, 29, 30, 30],
  2021: [31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
  2022: [31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 30],
  2023: [31, 32, 31, 32, 31, 30, 30, 30, 29, 30, 29, 31],
  2024: [31, 31, 31, 32, 31, 31, 30, 29, 30, 29, 30, 30],
  2025: [31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
  2026: [31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 31],
  2027: [30, 32, 31, 32, 31, 30, 30, 30, 29, 30, 29, 31],
  2028: [31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
  2029: [31, 31, 32, 31, 32, 30, 30, 29, 30, 29, 30, 30],
  2030: [31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 31],
  2031: [30, 32, 31, 32, 31, 30, 30, 30, 29, 30, 29, 31],
  2032: [31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
  2033: [31, 31, 32, 32, 31, 30, 30, 29, 30, 29, 30, 30],
  2034: [31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 31],
  2035: [30, 32, 31, 32, 31, 31, 29, 30, 30, 29, 29, 31],
  2036: [31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
  2037: [31, 31, 32, 32, 31, 30, 30, 29, 30, 29, 30, 30],
  2038: [31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 31],
  2039: [31, 31, 31, 32, 31, 31, 29, 30, 30, 29, 30, 30],
  2040: [31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
  2041: [31, 31, 32, 32, 31, 30, 30, 29, 30, 29, 30, 30],
  2042: [31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 31],
  2043: [31, 31, 31, 32, 31, 31, 29, 30, 30, 29, 30, 30],
  2044: [31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
  2045: [31, 32, 31, 32, 31, 30, 30, 29, 30, 29, 30, 30],
  2046: [31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 31],
  2047: [31, 31, 31, 32, 31, 31, 30, 29, 30, 29, 30, 30],
  2048: [31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
  2049: [31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 30],
  2050: [31, 32, 31, 32, 31, 30, 30, 30, 29, 30, 29, 31],
  2051: [31, 31, 31, 32, 31, 31, 30, 29, 30, 29, 30, 30],
  2052: [31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
  2053: [31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 30],
  2054: [31, 32, 31, 32, 31, 30, 30, 30, 29, 30, 29, 31],
  2055: [31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
  2056: [31, 31, 32, 31, 32, 30, 30, 29, 30, 29, 30, 30],
  2057: [31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 31],
  2058: [30, 32, 31, 32, 31, 30, 30, 30, 29, 30, 29, 31],
  2059: [31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
  2060: [31, 31, 32, 32, 31, 30, 30, 29, 30, 29, 30, 30],
  2061: [31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 31],
  2062: [30, 32, 31, 32, 31, 31, 29, 30, 29, 30, 29, 31],
  2063: [31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
  2064: [31, 31, 32, 32, 31, 30, 30, 29, 30, 29, 30, 30],
  2065: [31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 31],
  2066: [31, 31, 31, 32, 31, 31, 29, 30, 30, 29, 29, 31],
  2067: [31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
  2068: [31, 31, 32, 32, 31, 30, 30, 29, 30, 29, 30, 30],
  2069: [31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 31],
  2070: [31, 31, 31, 32, 31, 31, 29, 30, 30, 29, 30, 30],
  2071: [31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
  2072: [31, 32, 31, 32, 31, 30, 30, 29, 30, 29, 30, 30],
  2073: [31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 31],
  2074: [31, 31, 31, 32, 31, 31, 30, 29, 30, 29, 30, 30],
  2075: [31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
  2076: [31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 30],
  2077: [31, 32, 31, 32, 31, 30, 30, 30, 29, 30, 29, 31],
  2078: [31, 31, 31, 32, 31, 31, 30, 29, 30, 29, 30, 30],
  2079: [31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
  2080: [31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 30],
  2081: [31, 32, 31, 32, 31, 30, 30, 30, 29, 30, 29, 31],
  2082: [31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
  2083: [31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
  2084: [31, 32, 31, 32, 31, 30, 30, 30, 29, 29, 30, 31],
  2085: [30, 32, 31, 32, 31, 30, 30, 30, 29, 30, 29, 31],
  2086: [31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
  2087: [31, 31, 32, 31, 31, 31, 30, 30, 29, 30, 30, 30],
  2088: [30, 31, 32, 32, 30, 31, 30, 30, 29, 30, 30, 30],
  2089: [30, 32, 31, 32, 31, 30, 30, 30, 29, 30, 30, 30],
  2090: [30, 32, 31, 32, 31, 30, 30, 30, 29, 30, 30, 30],
};

const monthsEn = ['Baisakh', 'Jestha', 'Ashadh', 'Shrawan', 'Bhadra', 'Ashoj', 'Kartik', 'Mangsir', 'Poush', 'Magh', 'Falgun', 'Chaitra'];
const monthsNe = ['बैशाख', 'जेठ', 'असार', 'श्रावण', 'भदौ', 'असोज', 'कात्तिक', 'मंसिर', 'पुष', 'माघ', 'फागुन', 'चैत'];
const _weekdaysEn = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
const _weekdaysNe = ['आइतबार', 'सोमबार', 'मंगलबार', 'बुधबार', 'बिहीबार', 'शुक्रबार', 'शनिबार'];
const _adMonths = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// A Nepali date. [month] is 1 to 12.
class Bs {
  const Bs(this.year, this.month, this.day);
  final int year;
  final int month;
  final int day;

  @override
  bool operator ==(Object other) => other is Bs && other.year == year && other.month == month && other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() => 'Bs($year-$month-$day)';
}

final _anchor = DateTime.utc(1943, 4, 14); // BS 2000-01-01

DateTime _adDate(String ad) {
  final p = ad.substring(0, 10).split('-').map(int.parse).toList();
  return DateTime.utc(p[0], p[1], p[2]);
}

String _adString(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

int daysInBsMonth(int year, int month) {
  final row = _days[year];
  if (row == null || month < 1 || month > 12) throw RangeError('BS date out of range: $year-$month');
  return row[month - 1];
}

/// Gregorian "YYYY-MM-DD" to BS.
Bs adToBs(String ad) {
  var left = _adDate(ad).difference(_anchor).inDays;
  if (left < 0) throw RangeError('AD date before BS $bsMinYear: $ad');
  for (var year = bsMinYear; year <= bsMaxYear; year++) {
    for (var m = 0; m < 12; m++) {
      final len = _days[year]![m];
      if (left < len) return Bs(year, m + 1, left + 1);
      left -= len;
    }
  }
  throw RangeError('AD date after BS $bsMaxYear: $ad');
}

/// BS to Gregorian "YYYY-MM-DD".
String bsToAd(int year, int month, int day) {
  if (day < 1 || day > daysInBsMonth(year, month)) throw RangeError('BS date out of range: $year-$month-$day');
  var days = 0;
  for (var y = bsMinYear; y < year; y++) {
    days += _days[y]!.fold(0, (a, b) => a + b);
  }
  for (var m = 1; m < month; m++) {
    days += daysInBsMonth(year, m);
  }
  return _adString(_anchor.add(Duration(days: days + day - 1)));
}

/// The Nepal calendar date (AD) for a moment. Nepal time is UTC+5:45.
String todayAd([DateTime? now]) => _adString((now ?? DateTime.now()).toUtc().add(const Duration(hours: 5, minutes: 45)));

Bs todayBs([DateTime? now]) => adToBs(todayAd(now));

String addDaysAd(String ad, int days) => _adString(_adDate(ad).add(Duration(days: days)));

/// The Nepal calendar date of a stored UTC time stamp ("2026-10-26T07:26:03+00:00").
String adOfStamp(String iso) => todayAd(DateTime.parse(iso));

/// Whole days from today (Nepal) to an AD date. Negative when it has passed.
int daysUntil(String ad, [DateTime? now]) => _adDate(ad).difference(_adDate(todayAd(now))).inDays;

String monthName(int month, {bool? ne}) => ((ne ?? Lang.ne) ? monthsNe : monthsEn)[month - 1];

/// The label the API stores for a VAT period: "2083-07".
String periodLabel(int year, int month) => '$year-${month.toString().padLeft(2, '0')}';

/// First and last AD day of one BS month.
({String from, String to}) bsMonthRange(int year, int month) =>
    (from: bsToAd(year, month, 1), to: bsToAd(year, month, daysInBsMonth(year, month)));

/// The BS month before (-1) or after (+1).
({int year, int month}) shiftMonth(int year, int month, int by) {
  final index = year * 12 + (month - 1) + by;
  return (year: index ~/ 12, month: index % 12 + 1);
}

/// "Kartik 2083" / "कात्तिक २०८३"
String monthTitle(int year, int month) => digits('${monthName(month)} $year');

/// "Kartik 9, 2083"
String formatBs(String ad) {
  final b = adToBs(ad.substring(0, 10));
  return digits('${monthName(b.month)} ${b.day}, ${b.year}');
}

/// "26 Oct 2026"
String formatAd(String ad) {
  final p = ad.substring(0, 10).split('-').map(int.parse).toList();
  return digits('${p[2]} ${_adMonths[p[1] - 1]} ${p[0]}');
}

String weekday(String ad, {bool? ne}) {
  final idx = _adDate(ad).weekday % 7; // Dart: Monday 1 ... Sunday 7
  return ((ne ?? Lang.ne) ? _weekdaysNe : _weekdaysEn)[idx];
}

String _toAd(String isoOrAd) => isoOrAd.length > 10 ? adOfStamp(isoOrAd) : isoOrAd;

/// Main date text: BS first (or AD first when the setting is off). Pass an AD date or a full ISO date-time.
String formatDate(String isoOrAd) {
  final ad = _toAd(isoOrAd);
  return Lang.bsDates ? formatBs(ad) : formatAd(ad);
}

/// The small second line: the other calendar.
String formatDateSub(String isoOrAd) {
  final ad = _toAd(isoOrAd);
  return Lang.bsDates ? formatAd(ad) : formatBs(ad);
}

/// "10:42 AM" in Nepal time.
String formatTime(String iso) {
  final t = DateTime.parse(iso).toUtc().add(const Duration(hours: 5, minutes: 45));
  final h12 = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final suffix = t.hour < 12 ? 'AM' : 'PM';
  return digits('$h12:${t.minute.toString().padLeft(2, '0')} $suffix');
}
