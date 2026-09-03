import 'package:intl/intl.dart';

class AppTimeZoneOption {
  final String id;
  final String label;
  final String offsetDisplay;
  final String region;

  const AppTimeZoneOption({
    required this.id,
    required this.label,
    required this.offsetDisplay,
    required this.region,
  });

  String get fullDisplayName => '$label ($offsetDisplay)';
}

class TimeZoneUtils {
  static const String defaultTimeZone = 'Asia/Kolkata';

  static const List<AppTimeZoneOption> supportedTimeZones = [
    // India (Default)
    AppTimeZoneOption(
      id: 'Asia/Kolkata',
      label: 'India Standard Time (IST)',
      offsetDisplay: 'UTC+05:30',
      region: 'India',
    ),
    // USA Time Zones
    AppTimeZoneOption(
      id: 'America/New_York',
      label: 'USA Eastern Time (EST/EDT)',
      offsetDisplay: 'UTC-05:00 / UTC-04:00',
      region: 'USA',
    ),
    AppTimeZoneOption(
      id: 'America/Chicago',
      label: 'USA Central Time (CST/CDT)',
      offsetDisplay: 'UTC-06:00 / UTC-05:00',
      region: 'USA',
    ),
    AppTimeZoneOption(
      id: 'America/Denver',
      label: 'USA Mountain Time (MST/MDT)',
      offsetDisplay: 'UTC-07:00 / UTC-06:00',
      region: 'USA',
    ),
    AppTimeZoneOption(
      id: 'America/Phoenix',
      label: 'USA Arizona Time (MST no DST)',
      offsetDisplay: 'UTC-07:00',
      region: 'USA',
    ),
    AppTimeZoneOption(
      id: 'America/Los_Angeles',
      label: 'USA Pacific Time (PST/PDT)',
      offsetDisplay: 'UTC-08:00 / UTC-07:00',
      region: 'USA',
    ),
    AppTimeZoneOption(
      id: 'America/Anchorage',
      label: 'USA Alaska Time (AKST/AKDT)',
      offsetDisplay: 'UTC-09:00 / UTC-08:00',
      region: 'USA',
    ),
    AppTimeZoneOption(
      id: 'Pacific/Honolulu',
      label: 'USA Hawaii Time (HST)',
      offsetDisplay: 'UTC-10:00',
      region: 'USA',
    ),
    // UTC / Global
    AppTimeZoneOption(
      id: 'UTC',
      label: 'Coordinated Universal Time (UTC)',
      offsetDisplay: 'UTC+00:00',
      region: 'Global',
    ),
    // Europe & UK
    AppTimeZoneOption(
      id: 'Europe/London',
      label: 'UK / London (GMT/BST)',
      offsetDisplay: 'UTC+00:00 / UTC+01:00',
      region: 'Europe',
    ),
    AppTimeZoneOption(
      id: 'Europe/Paris',
      label: 'Central European Time (CET/CEST)',
      offsetDisplay: 'UTC+01:00 / UTC+02:00',
      region: 'Europe',
    ),
    // Middle East
    AppTimeZoneOption(
      id: 'Asia/Dubai',
      label: 'Gulf Standard Time (GST - Dubai/UAE)',
      offsetDisplay: 'UTC+04:00',
      region: 'Middle East',
    ),
    AppTimeZoneOption(
      id: 'Asia/Riyadh',
      label: 'Arabian Standard Time (AST - Saudi Arabia)',
      offsetDisplay: 'UTC+03:00',
      region: 'Middle East',
    ),
    // Asia
    AppTimeZoneOption(
      id: 'Asia/Kathmandu',
      label: 'Nepal Time (NPT)',
      offsetDisplay: 'UTC+05:45',
      region: 'Asia',
    ),
    AppTimeZoneOption(
      id: 'Asia/Dhaka',
      label: 'Bangladesh Standard Time (BST)',
      offsetDisplay: 'UTC+06:00',
      region: 'Asia',
    ),
    AppTimeZoneOption(
      id: 'Asia/Bangkok',
      label: 'Indochina Time (ICT - Thailand)',
      offsetDisplay: 'UTC+07:00',
      region: 'Asia',
    ),
    AppTimeZoneOption(
      id: 'Asia/Singapore',
      label: 'Singapore Standard Time (SGT)',
      offsetDisplay: 'UTC+08:00',
      region: 'Asia',
    ),
    AppTimeZoneOption(
      id: 'Asia/Tokyo',
      label: 'Japan Standard Time (JST)',
      offsetDisplay: 'UTC+09:00',
      region: 'Asia',
    ),
    // Australia & Pacific
    AppTimeZoneOption(
      id: 'Australia/Sydney',
      label: 'Australia Eastern Time (AEST/AEDT)',
      offsetDisplay: 'UTC+10:00 / UTC+11:00',
      region: 'Australia',
    ),
    AppTimeZoneOption(
      id: 'Pacific/Auckland',
      label: 'New Zealand Time (NZST/NZDT)',
      offsetDisplay: 'UTC+12:00 / UTC+13:00',
      region: 'Pacific',
    ),
  ];

  static AppTimeZoneOption getTimeZoneInfo(String? tzId) {
    final search = tzId?.trim() ?? defaultTimeZone;
    return supportedTimeZones.firstWhere(
      (element) => element.id.toLowerCase() == search.toLowerCase(),
      orElse: () => supportedTimeZones.firstWhere(
        (element) => element.id == defaultTimeZone,
      ),
    );
  }

  /// Calculates UTC offset duration for a given timezone ID and UTC date.
  static Duration getTimeZoneOffset(String? tzId, [DateTime? date]) {
    final searchId = tzId?.trim() ?? defaultTimeZone;
    final utc = (date ?? DateTime.now()).toUtc();

    switch (searchId) {
      case 'Asia/Kolkata':
        return const Duration(hours: 5, minutes: 30);
      case 'Asia/Kathmandu':
        return const Duration(hours: 5, minutes: 45);
      case 'Asia/Dhaka':
        return const Duration(hours: 6);
      case 'Asia/Dubai':
        return const Duration(hours: 4);
      case 'Asia/Riyadh':
        return const Duration(hours: 3);
      case 'Asia/Bangkok':
        return const Duration(hours: 7);
      case 'Asia/Singapore':
        return const Duration(hours: 8);
      case 'Asia/Tokyo':
        return const Duration(hours: 9);
      case 'UTC':
        return Duration.zero;
      case 'America/New_York':
        return _isUsaDst(utc) ? const Duration(hours: -4) : const Duration(hours: -5);
      case 'America/Chicago':
        return _isUsaDst(utc) ? const Duration(hours: -5) : const Duration(hours: -6);
      case 'America/Denver':
        return _isUsaDst(utc) ? const Duration(hours: -6) : const Duration(hours: -7);
      case 'America/Phoenix':
        return const Duration(hours: -7);
      case 'America/Los_Angeles':
        return _isUsaDst(utc) ? const Duration(hours: -7) : const Duration(hours: -8);
      case 'America/Anchorage':
        return _isUsaDst(utc) ? const Duration(hours: -8) : const Duration(hours: -9);
      case 'Pacific/Honolulu':
        return const Duration(hours: -10);
      case 'Europe/London':
        return _isEuropeDst(utc) ? const Duration(hours: 1) : Duration.zero;
      case 'Europe/Paris':
        return _isEuropeDst(utc) ? const Duration(hours: 2) : const Duration(hours: 1);
      case 'Australia/Sydney':
        return _isAustraliaDst(utc) ? const Duration(hours: 11) : const Duration(hours: 10);
      case 'Pacific/Auckland':
        return _isAustraliaDst(utc) ? const Duration(hours: 13) : const Duration(hours: 12);
      default:
        final customOffset = _parseCustomOffset(searchId);
        if (customOffset != null) return customOffset;
        return const Duration(hours: 5, minutes: 30);
    }
  }

  /// Converts any [DateTime] (local or UTC) to the specified timezone's wall-clock time.
  static DateTime convertToTimeZone(DateTime dt, String? tzId) {
    final utc = dt.toUtc();
    final offset = getTimeZoneOffset(tzId, utc);
    final tzDate = utc.add(offset);
    return DateTime(
      tzDate.year,
      tzDate.month,
      tzDate.day,
      tzDate.hour,
      tzDate.minute,
      tzDate.second,
      tzDate.millisecond,
      tzDate.microsecond,
    );
  }

  /// Returns current wall-clock date and time in the specified timezone.
  static DateTime nowInTimeZone(String? tzId, [DateTime? baseTime]) {
    final dt = baseTime ?? DateTime.now();
    return convertToTimeZone(dt, tzId);
  }

  /// Formats a [DateTime] in the specified timezone.
  static String formatInTimeZone(
    DateTime dt,
    String? tzId, {
    String pattern = 'dd-MMM-yyyy hh:mm a',
  }) {
    final converted = convertToTimeZone(dt, tzId);
    return DateFormat(pattern).format(converted);
  }

  /// Formats current time in specified timezone.
  static String formatNowInTimeZone(
    String? tzId, {
    String pattern = 'dd-MMM-yyyy hh:mm a',
  }) {
    return formatInTimeZone(DateTime.now(), tzId, pattern: pattern);
  }

  // ── DST Helper Calculations ─────────────────────────────────────────────

  /// USA Daylight Saving Time: 2nd Sunday in March (07:00 UTC) to 1st Sunday in Nov (06:00 UTC)
  static bool _isUsaDst(DateTime utc) {
    final year = utc.year;
    final marchSecondSun = _nthSunday(year, 3, 2);
    final marchDstStart = DateTime.utc(year, 3, marchSecondSun.day, 7);

    final novFirstSun = _nthSunday(year, 11, 1);
    final novDstEnd = DateTime.utc(year, 11, novFirstSun.day, 6);

    return utc.isAfter(marchDstStart) && utc.isBefore(novDstEnd);
  }

  /// Europe Daylight Saving Time: Last Sunday in March (01:00 UTC) to Last Sunday in October (01:00 UTC)
  static bool _isEuropeDst(DateTime utc) {
    final year = utc.year;
    final marchLastSun = _lastSunday(year, 3);
    final marchDstStart = DateTime.utc(year, 3, marchLastSun.day, 1);

    final octLastSun = _lastSunday(year, 10);
    final octDstEnd = DateTime.utc(year, 10, octLastSun.day, 1);

    return utc.isAfter(marchDstStart) && utc.isBefore(octDstEnd);
  }

  /// Australia Daylight Saving Time: 1st Sunday in October to 1st Sunday in April
  static bool _isAustraliaDst(DateTime utc) {
    final year = utc.year;
    final octFirstSun = _nthSunday(year, 10, 1);
    final octDstStart = DateTime.utc(year, 10, octFirstSun.day, 16);

    final aprFirstSun = _nthSunday(year, 4, 1);
    final aprDstEnd = DateTime.utc(year, 4, aprFirstSun.day, 16);

    return utc.isAfter(octDstStart) || utc.isBefore(aprDstEnd);
  }

  static DateTime _nthSunday(int year, int month, int n) {
    int count = 0;
    for (int day = 1; day <= 31; day++) {
      final dt = DateTime.utc(year, month, day);
      if (dt.month != month) break;
      if (dt.weekday == DateTime.sunday) {
        count++;
        if (count == n) return dt;
      }
    }
    return DateTime.utc(year, month, 1);
  }

  static DateTime _lastSunday(int year, int month) {
    final lastDay = DateTime.utc(year, month + 1, 0).day;
    for (int day = lastDay; day >= 1; day--) {
      final dt = DateTime.utc(year, month, day);
      if (dt.weekday == DateTime.sunday) return dt;
    }
    return DateTime.utc(year, month, lastDay);
  }

  static Duration? _parseCustomOffset(String str) {
    final reg = RegExp(r'^([+-])?(\d{1,2}):?(\d{2})?$');
    final match = reg.firstMatch(str.trim());
    if (match != null) {
      final sign = match.group(1) == '-' ? -1 : 1;
      final hours = int.tryParse(match.group(2) ?? '0') ?? 0;
      final mins = int.tryParse(match.group(3) ?? '0') ?? 0;
      return Duration(minutes: sign * (hours * 60 + mins));
    }
    return null;
  }
}
