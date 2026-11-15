// Calendar days as 'YYYY-MM-DD' keys. All day arithmetic is done in UTC so
// daylight-saving changes can never skip or repeat a day.

String _two(int n) => n.toString().padLeft(2, '0');

/// The calendar day of [d] (its own year/month/day fields).
String dateKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${_two(d.month)}-${_two(d.day)}';

final RegExp _keyPattern = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');

DateTime parseDateKey(String key) {
  final m = _keyPattern.firstMatch(key);
  if (m == null) throw FormatException('bad date: $key');
  final d = DateTime.utc(
    int.parse(m.group(1)!),
    int.parse(m.group(2)!),
    int.parse(m.group(3)!),
  );
  if (dateKey(d) != key) throw FormatException('bad date: $key');
  return d;
}

String previousDay(String key) =>
    dateKey(parseDateKey(key).subtract(const Duration(days: 1)));

/// Whole days from [from] to [to] (negative when [to] is earlier).
int daysBetween(String from, String to) =>
    parseDateKey(to).difference(parseDateKey(from)).inDays;

/// Daily puzzle #1.
const String dailyEpoch = '2026-11-15';

int dailyNumber(String key) => daysBetween(dailyEpoch, key) + 1;

const List<String> _weekdays = [
  'الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد',
];
const List<String> _months = [
  'كانون الثاني', 'شباط', 'آذار', 'نيسان', 'أيار', 'حزيران',
  'تموز', 'آب', 'أيلول', 'تشرين الأول', 'تشرين الثاني', 'كانون الأول',
];

/// «الأحد 15 تشرين الثاني 2026»
String formatArabicDate(String key) {
  final d = parseDateKey(key);
  return '${_weekdays[d.weekday - 1]} ${d.day} ${_months[d.month - 1]} ${d.year}';
}
