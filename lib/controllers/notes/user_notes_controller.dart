import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:intl/intl.dart';
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
    _reminderTimer = Timer.periodic(const Duration(seconds: 25), (_) {
      _checkAndTriggerReminders();
    });
  }

  Future<void> _checkAndTriggerReminders() async {
    if (notes.isEmpty) return;
    final now = DateTime.now();
    final prefs = await SharedPreferences.getInstance();

    for (final note in notes) {
      if (note.isCompleted || note.isArchived || note.isTrashed || note.reminderType == 'NONE') {
        continue;
      }

      bool shouldTrigger = false;
      String dateStr = '${now.year}_${now.month}_${now.day}';
      String dayKey = 'note_reminder_${note.id}_$dateStr';
      String specificKey = 'note_reminder_${note.id}_${note.reminderDate?.millisecondsSinceEpoch}';

      if (prefs.getBool(dayKey) == true || prefs.getBool(specificKey) == true) {
        continue;
      }

      if (note.reminderType == 'SPECIFIC_DATE' && note.reminderDate != null) {
        if (now.isAfter(note.reminderDate!) || now.isAtSameMomentAs(note.reminderDate!)) {
          if (now.difference(note.reminderDate!).inMinutes.abs() <= 60) {
            shouldTrigger = true;
          }
        }
      } else if (note.reminderTime != null) {
        if (note.reminderDate != null) {
          final startMidnight = DateTime(note.reminderDate!.year, note.reminderDate!.month, note.reminderDate!.day);
          final todayMidnight = DateTime(now.year, now.month, now.day);
          if (todayMidnight.isBefore(startMidnight)) {
            continue;
          }
        }

        final currentHM = DateFormat('HH:mm').format(now);
        final current12HM = DateFormat('hh:mm a').format(now).toUpperCase();
        final reminderStr = note.reminderTime!.trim().toUpperCase();

        if (reminderStr == currentHM || reminderStr == current12HM) {
          shouldTrigger = true;
        }
      }

      if (shouldTrigger) {
        await prefs.setBool(dayKey, true);
        if (note.reminderDate != null) {
          await prefs.setBool(specificKey, true);
        }

        final notifTitle = note.title.isNotEmpty ? '📌 Sticky Note: ${note.title}' : '📌 Sticky Note Reminder';
        final notifBody = note.content.isNotEmpty ? note.content : 'Scheduled reminder reached.';

        await NotificationService.show(note.id, notifTitle, notifBody);

        try {
          await ApiClient.post('/api/notifications', {
            'title': notifTitle,
            'message': notifBody,
            'module': 'STICKY_NOTES',
            'type': 'INFO',
            'entity_id': note.id,
          });
        } catch (e) {
          debugPrint('[STICKY NOTE NOTIFICATION SAVE ERROR]: $e');
        }

        if (note.reminderType == 'SPECIFIC_DATE') {
          try {
            await ApiClient.put('${ApiEndpoints.userNotes}/${note.id}', {
              'reminder_type': 'NONE',
              'reminder_date': null,
              'reminder_time': null,
            });
            note.reminderType = 'NONE';
            note.reminderDate = null;
            note.reminderTime = null;
            _safeNotify();
          } catch (e) {
            debugPrint('[CLEAR TRIGGERED REMINDER ERROR]: $e');
          }
        }
      }
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
