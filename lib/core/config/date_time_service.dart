import 'dart:convert';
import 'dart:developer' as dev;
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';

import '../api/endpoints.dart';
import '../config/app_config.dart';

/// ---------------------------------------------------------------------------
/// DateTimeService
/// ---------------------------------------------------------------------------
/// Protects the app from wrong system dates caused by:
///   • PC going to sleep and waking up with an old BIOS clock (e.g. year 2002)
///   • User manually setting a wrong date
///   • No RTC battery — clock resets to epoch/factory default
///
/// Strategy
/// ─────────
/// 1. On app start, call the LOCAL backend (/api/system/server-time).
///    The backend returns the PostgreSQL DB time, which is trustworthy because:
///    - It was seeded correctly at install time
///    - It advances monotonically (DB stores transactions with timestamps)
///    No internet is needed — this is a local call.
///
/// 2. Record the anchor: serverAnchorTime + stopwatch elapsed at that moment.
///
/// 3. Every subsequent `DateTimeService.now()` call returns:
///      anchorTime + elapsed since anchor
///    This is immune to system clock changes.
///
/// 4. Safety checks:
///    a. If system date is more than DRIFT_WARN_HOURS behind the trusted time
///       → show a warning banner to the user.
///    b. If the fetched server time is in the past (before earliest plausible
///       date = 2024-01-01), refuse to use it and fall back to system time
///       plus a warning.
///
/// Usage
/// ─────
///   await DateTimeService.instance.init();   // call once in main()
///   DateTime now = DateTimeService.instance.now();
/// ---------------------------------------------------------------------------
class DateTimeService extends ChangeNotifier {
  DateTimeService._();
  static final DateTimeService instance = DateTimeService._();

  // ── Constants ────────────────────────────────────────────────────────────

  /// Earliest date we will ever accept as "valid" from the server.
  static final DateTime _earliestPlausible = DateTime(2024, 1, 1);

  /// If the system clock is more than this many hours BEHIND the trusted
  /// time, warn the user.
  static const int _driftWarnHours = 4;

  // ── State ────────────────────────────────────────────────────────────────
  DateTime? _anchor;           // trusted reference point
  final Stopwatch _sw = Stopwatch();
  bool _initialized = false;
  ClockStatus _status = ClockStatus.unknown;
  String? _warningMessage;

  bool get isInitialized => _initialized;

  /// Current reliable date/time, immune to system clock drift.
  DateTime get now {
    if (_anchor == null) return DateTime.now(); // not yet init — best effort
    return _anchor!.add(_sw.elapsed);
  }

  /// Today's date (midnight local) using trusted time.
  DateTime get today {
    final n = now;
    return DateTime(n.year, n.month, n.day);
  }

  ClockStatus get status => _status;
  String? get warningMessage => _warningMessage;
  bool get hasWarning => _status == ClockStatus.drifted || _status == ClockStatus.fallback;

  // ── Initialization ───────────────────────────────────────────────────────

  /// Call once during app startup (before runApp or in splash screen).
  /// [baseUrl] is optional override; defaults to AppConfig.baseUrl.
  Future<void> init({String? baseUrl}) async {
    try {
      final trusted = await _fetchServerTime(baseUrl: baseUrl);
      if (trusted != null && trusted.isAfter(_earliestPlausible)) {
        _anchor = trusted;
        _sw
          ..reset()
          ..start();

        // Check drift between system clock and trusted time
        final systemNow = DateTime.now();
        final drift = trusted.difference(systemNow);

        if (drift.inHours.abs() > _driftWarnHours) {
          _status = ClockStatus.drifted;
          _warningMessage =
              'System date mismatch detected!\n'
              'System clock: ${_fmt(systemNow)}\n'
              'Trusted date:  ${_fmt(trusted)}\n'
              'The app is using the trusted server date.';
          dev.log('[DateTimeService] DRIFT detected: system=$systemNow trusted=$trusted',
              name: 'DateTimeService');
        } else {
          _status = ClockStatus.synced;
          _warningMessage = null;
        }

        _initialized = true;
        dev.log('[DateTimeService] Anchored to: $trusted (source: server DB)',
            name: 'DateTimeService');
      } else {
        _fallbackToSystem(reason: 'Server returned implausible date: $trusted');
      }
    } catch (e) {
      _fallbackToSystem(reason: 'Could not reach local server: $e');
    }
    notifyListeners();
  }

  /// Re-sync — call this after a long sleep or when user resumes the app.
  Future<void> resync({String? baseUrl}) async => init(baseUrl: baseUrl);

  // ── Private Helpers ──────────────────────────────────────────────────────

  void _fallbackToSystem({required String reason}) {
    // Use system time but warn if it looks suspicious
    final systemNow = DateTime.now();
    _anchor = systemNow;
    _sw
      ..reset()
      ..start();

    if (systemNow.isBefore(_earliestPlausible)) {
      _status = ClockStatus.fallback;
      _warningMessage =
          '⚠ System date looks wrong (${_fmt(systemNow)}).\n'
          'Could not reach local server to verify.\n'
          'Please check your system clock.';
    } else {
      _status = ClockStatus.fallback;
      _warningMessage = 'Could not verify date with server. Using system clock.';
    }

    _initialized = true;
    dev.log('[DateTimeService] FALLBACK to system time. Reason: $reason',
        name: 'DateTimeService');
  }

  Future<DateTime?> _fetchServerTime({String? baseUrl}) async {
    try {
      final base = (baseUrl ?? AppConfig.baseUrl).replaceAll(RegExp(r'/$'), '');
      final url = Uri.parse('$base${ApiEndpoints.serverTime}');
      final response =
          await http.get(url).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['serverTime'] != null) {
          return DateTime.tryParse(data['serverTime'].toString());
        }
      }
    } catch (_) {
      // intentionally swallowed — caller decides what to do
    }
    return null;
  }

  String _fmt(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}-'
      '${dt.month.toString().padLeft(2, '0')}-'
      '${dt.year}  '
      '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}';
}

// ── Supporting enums ────────────────────────────────────────────────────────
enum ClockStatus {
  unknown,   // not yet initialized
  synced,    // server time matches system time (within threshold)
  drifted,   // server time differs significantly — using server time
  fallback,  // could not reach server — using system time (possibly wrong)
}
