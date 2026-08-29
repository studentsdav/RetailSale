import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';
import '../../models/notes/user_note_model.dart';
import '../settings/notification_services.dart';

class UserNotesController extends ChangeNotifier {
  bool loading = false;
  List<UserNote> notes = [];
  String currentSection = 'notes'; // 'notes', 'archive', 'trash'
  Timer? _reminderTimer;

  UserNotesController() {
    _startReminderListener();
  }

  void _startReminderListener() {
    _reminderTimer?.cancel();
    _checkAndTriggerReminders();
    _reminderTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _checkAndTriggerReminders();
    });
  }

  DateTime _getReminderTargetDateTime(UserNote note, DateTime now) {
    DateTime baseDate = note.reminderDate ?? now;
    int hour = 9;
    int minute = 0;

    if (note.reminderTime != null && note.reminderTime!.trim().isNotEmpty) {
      final timeStr = note.reminderTime!.trim().toUpperCase();
      final match12 = RegExp(r'^(\d{1,2}):(\d{2})\s*(AM|PM)$').firstMatch(timeStr);
      if (match12 != null) {
        int h = int.parse(match12.group(1)!);
        int m = int.parse(match12.group(2)!);
        String ampm = match12.group(3)!;
        if (ampm == 'PM' && h < 12) h += 12;
        if (ampm == 'AM' && h == 12) h = 0;
        hour = h;
        minute = m;
      } else {
        final match24 = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(timeStr);
        if (match24 != null) {
          hour = int.parse(match24.group(1)!);
          minute = int.parse(match24.group(2)!);
        }
      }
    }

    return DateTime(baseDate.year, baseDate.month, baseDate.day, hour, minute);
  }

  Future<void> _checkAndTriggerReminders() async {
    if (notes.isEmpty) return;
    final now = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    bool shouldNotifyListeners = false;

    for (final note in notes) {
      if (note.isCompleted || note.isArchived || note.isTrashed || note.reminderType == 'NONE') {
        continue;
      }

      final targetDT = _getReminderTargetDateTime(note, now);

      if (now.isAfter(targetDT) || now.isAtSameMomentAs(targetDT)) {
        String occKey = 'note_reminder_${note.id}_${targetDT.millisecondsSinceEpoch}';

        if (prefs.getBool(occKey) != true) {
          await prefs.setBool(occKey, true);

          final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
          final dateLabel = '${targetDT.day} ${months[targetDT.month - 1]}, ${note.reminderTime ?? "09:00 AM"}';
          final notifTitle = note.title.isNotEmpty ? '📌 Sticky Note: ${note.title} ($dateLabel)' : '📌 Sticky Note Reminder ($dateLabel)';
          final notifBody = note.content.isNotEmpty ? note.content : 'Scheduled reminder reached.';

          await NotificationService.show(note.id, notifTitle, notifBody, uniqueKey: occKey);
        }

        // Reschedule or clear reminder
        if (note.reminderType == 'SPECIFIC_DATE') {
          try {
            await ApiClient.put('${ApiEndpoints.userNotes}/${note.id}', {
              'reminder_type': 'NONE',
              'reminder_date': null,
              'reminder_time': null,
            });
          } catch (e) {
            debugPrint('[CLEAR TRIGGERED REMINDER ERROR]: $e');
          }
          note.reminderType = 'NONE';
          note.reminderDate = null;
          note.reminderTime = null;
          shouldNotifyListeners = true;
        } else {
          // Recurring: DAILY, WEEKLY, MONTHLY, YEARLY
          DateTime nextDT = targetDT;
          while (nextDT.isBefore(now) || nextDT.isAtSameMomentAs(now)) {
            if (note.reminderType == 'DAILY') {
              nextDT = nextDT.add(const Duration(days: 1));
            } else if (note.reminderType == 'WEEKLY') {
              nextDT = nextDT.add(const Duration(days: 7));
            } else if (note.reminderType == 'MONTHLY') {
              int y = nextDT.year;
              int m = nextDT.month + 1;
              if (m > 12) {
                m = 1;
                y += 1;
              }
              int maxDays = DateTime(y, m + 1, 0).day;
              int d = nextDT.day > maxDays ? maxDays : nextDT.day;
              nextDT = DateTime(y, m, d, nextDT.hour, nextDT.minute);
            } else if (note.reminderType == 'YEARLY') {
              nextDT = DateTime(nextDT.year + 1, nextDT.month, nextDT.day, nextDT.hour, nextDT.minute);
            } else {
              break;
            }
          }

          note.reminderDate = nextDT;
          shouldNotifyListeners = true;
          try {
            await ApiClient.put('${ApiEndpoints.userNotes}/${note.id}', {
              'reminder_date': nextDT.toUtc().toIso8601String(),
            });
          } catch (e) {
            debugPrint('[UPDATE RECURRING REMINDER DATE ERROR]: $e');
          }
        }
      }
    }

    if (shouldNotifyListeners) {
      _safeNotify();
    }
  }

  void _safeNotify() {
    if (WidgetsBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        notifyListeners();
      });
    } else {
      notifyListeners();
    }
  }

  int get activeRemindersCount {
    return notes.where((n) => !n.isCompleted && !n.isArchived && !n.isTrashed && n.reminderType != 'NONE').length;
  }

  Future<void> loadNotes({String query = '', String? section}) async {
    if (section != null) {
      currentSection = section;
    }
    loading = true;
    _safeNotify();

    try {
      final res = await ApiClient.get('${ApiEndpoints.userNotes}?q=$query&section=$currentSection');
      if (res != null && res['success'] == true && res['data'] is List) {
        notes = (res['data'] as List).map((e) => UserNote.fromJson(e)).toList();
        _checkAndTriggerReminders();
      }
    } catch (e) {
      debugPrint('[USER NOTES CONTROLLER LOAD ERROR]: $e');
    } finally {
      loading = false;
      _safeNotify();
    }
  }

  Future<UserNote?> createNote(UserNote payload) async {
    loading = true;
    _safeNotify();

    try {
      final res = await ApiClient.post(ApiEndpoints.userNotes, payload.toJson());
      if (res != null && res['success'] == true && res['data'] != null) {
        final created = UserNote.fromJson(res['data']);
        await loadNotes();
        return created;
      }
    } catch (e) {
      debugPrint('[USER NOTES CREATE ERROR]: $e');
    } finally {
      loading = false;
      _safeNotify();
    }
    return null;
  }

  Future<UserNote?> copyNote(int id) async {
    loading = true;
    _safeNotify();

    try {
      final res = await ApiClient.post('${ApiEndpoints.userNotes}/$id/copy', {});
      if (res != null && res['success'] == true && res['data'] != null) {
        final copied = UserNote.fromJson(res['data']);
        await loadNotes();
        return copied;
      }
    } catch (e) {
      debugPrint('[USER NOTES COPY ERROR]: $e');
    } finally {
      loading = false;
      _safeNotify();
    }
    return null;
  }

  Future<bool> updateNote(int id, UserNote payload) async {
    loading = true;
    _safeNotify();

    try {
      final res = await ApiClient.put('${ApiEndpoints.userNotes}/$id', payload.toJson());
      if (res != null && res['success'] == true) {
        await loadNotes();
        return true;
      }
    } catch (e) {
      debugPrint('[USER NOTES UPDATE ERROR]: $e');
    } finally {
      loading = false;
      _safeNotify();
    }
    return false;
  }

  Future<bool> toggleArchive(int id) async {
    loading = true;
    _safeNotify();

    try {
      final res = await ApiClient.put('${ApiEndpoints.userNotes}/$id/archive', {});
      if (res != null && res['success'] == true) {
        await loadNotes();
        return true;
      }
    } catch (e) {
      debugPrint('[USER NOTES ARCHIVE ERROR]: $e');
    } finally {
      loading = false;
      _safeNotify();
    }
    return false;
  }

  Future<bool> moveToTrash(int id) async {
    loading = true;
    _safeNotify();

    try {
      final res = await ApiClient.put('${ApiEndpoints.userNotes}/$id/trash', {});
      if (res != null && res['success'] == true) {
        await loadNotes();
        return true;
      }
    } catch (e) {
      debugPrint('[USER NOTES TRASH ERROR]: $e');
    } finally {
      loading = false;
      _safeNotify();
    }
    return false;
  }

  Future<bool> restoreNote(int id) async {
    loading = true;
    _safeNotify();

    try {
      final res = await ApiClient.put('${ApiEndpoints.userNotes}/$id/restore', {});
      if (res != null && res['success'] == true) {
        await loadNotes();
        return true;
      }
    } catch (e) {
      debugPrint('[USER NOTES RESTORE ERROR]: $e');
    } finally {
      loading = false;
      _safeNotify();
    }
    return false;
  }

  Future<bool> permanentDelete(int id) async {
    loading = true;
    _safeNotify();

    try {
      final res = await ApiClient.delete('${ApiEndpoints.userNotes}/$id/permanent');
      if (res != null && res['success'] == true) {
        await loadNotes();
        return true;
      }
    } catch (e) {
      debugPrint('[USER NOTES PERMANENT DELETE ERROR]: $e');
    } finally {
      loading = false;
      _safeNotify();
    }
    return false;
  }

  Future<bool> emptyTrash() async {
    loading = true;
    _safeNotify();

    try {
      final res = await ApiClient.delete('${ApiEndpoints.userNotes}/trash/empty');
      if (res != null && res['success'] == true) {
        await loadNotes();
        return true;
      }
    } catch (e) {
      debugPrint('[USER NOTES EMPTY TRASH ERROR]: $e');
    } finally {
      loading = false;
      _safeNotify();
    }
    return false;
  }

  @override
  void dispose() {
    _reminderTimer?.cancel();
    super.dispose();
  }
}
