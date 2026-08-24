import 'package:flutter/material.dart';
import '../../services/night_audit_service.dart';

class NightAuditController extends ChangeNotifier {
  bool isLoading = false;
  bool isExecuting = false;

  Map<String, dynamic>? currentBusinessDay;
  Map<String, dynamic>? validationData;
  List<dynamic> historyList = [];
  int historyTotal = 0;

  // Denominations counter
  final Map<String, int> denominations = {
    '2000': 0,
    '500': 0,
    '200': 0,
    '100': 0,
    '50': 0,
    '20': 0,
    '10': 0,
    'coins': 0,
  };

  double get physicalCashTotal {
    double total = 0;
    denominations.forEach((key, count) {
      if (key == 'coins') {
        total += count * 1.0;
      } else {
        total += (double.tryParse(key) ?? 0) * count;
      }
    });
    return total;
  }

  String auditNotes = '';
  Map<String, dynamic>? lastRunResult;

  Future<void> fetchStatus() async {
    isLoading = true;
    notifyListeners();

    try {
      final res = await NightAuditService.getStatus();
      if (res['success'] == true && res['data'] != null) {
        currentBusinessDay = res['data']['currentBusinessDay'];
        validationData = res['data']['validation'];
      }
    } catch (e) {
      debugPrint('NightAuditController fetchStatus error: $e');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> runValidation() async {
    isLoading = true;
    notifyListeners();

    try {
      final res = await NightAuditService.validate();
      if (res['success'] == true) {
        validationData = res['data'];
      }
    } catch (e) {
      debugPrint('NightAuditController runValidation error: $e');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void updateDenomination(String key, int count) {
    if (denominations.containsKey(key)) {
      denominations[key] = count >= 0 ? count : 0;
      notifyListeners();
    }
  }

  void clearDenominations() {
    denominations.updateAll((key, value) => 0);
    notifyListeners();
  }

  Future<bool> executeAudit({bool forceRun = false}) async {
    isExecuting = true;
    notifyListeners();

    try {
      final res = await NightAuditService.executeAudit(
        physicalCash: physicalCashTotal,
        denominations: denominations,
        forceRun: forceRun,
        notes: auditNotes,
      );

      if (res['success'] == true) {
        lastRunResult = res;
        await fetchStatus();
        await fetchHistory();
        isExecuting = false;
        notifyListeners();
        return true;
      } else {
        lastRunResult = res;
        isExecuting = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      debugPrint('NightAuditController executeAudit error: $e');
      isExecuting = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> fetchHistory() async {
    try {
      final res = await NightAuditService.getHistory();
      if (res['success'] == true) {
        historyList = res['data'] ?? [];
        historyTotal = res['total'] ?? 0;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('NightAuditController fetchHistory error: $e');
    }
  }
}
