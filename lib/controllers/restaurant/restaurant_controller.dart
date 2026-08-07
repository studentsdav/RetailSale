import 'package:flutter/material.dart';
import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';

class RestaurantController extends ChangeNotifier {
  bool loading = false;

  List<dynamic> floors = [];
  List<dynamic> diningAreas = [];
  List<dynamic> tableTypes = [];
  List<dynamic> tables = [];
  List<dynamic> printers = [];
  List<dynamic> kitchenStations = [];
  List<dynamic> reservations = [];
  List<dynamic> activeKots = [];
  List<dynamic> challans = [];
  List<dynamic> recurringExpensesList = [];

  Map<String, dynamic>? emailConfig;
  List<dynamic> emailTemplates = [];

  // General Loading Setter
  void setLoading(bool val) {
    loading = val;
    notifyListeners();
  }

  // ==========================================
  // FLOORS CRUD
  // ==========================================
  Future<void> loadFloors() async {
    loading = true;
    notifyListeners();
    try {
      final res = await ApiClient.get(ApiEndpoints.restaurantFloors);
      if (res['success'] == true) {
        floors = res['data'] ?? [];
      }
    } catch (e) {
      debugPrint('Error loading floors: $e');
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<bool> saveFloor(Map<String, dynamic> data) async {
    loading = true;
    notifyListeners();
    try {
      final isNew = data['id'] == null;
      final url = isNew 
          ? ApiEndpoints.restaurantFloors 
          : '${ApiEndpoints.restaurantFloors}/${data['id']}';
      
      final res = isNew 
          ? await ApiClient.post(url, data)
          : await ApiClient.put(url, data);
      
      await loadFloors();
      return res['success'] == true;
    } catch (e) {
      debugPrint('Error saving floor: $e');
      return false;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<bool> deleteFloor(int id) async {
    loading = true;
    notifyListeners();
    try {
      final res = await ApiClient.delete('${ApiEndpoints.restaurantFloors}/$id');
      await loadFloors();
      return res['success'] == true;
    } catch (e) {
      debugPrint('Error deleting floor: $e');
      return false;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  // ==========================================
  // DINING AREAS CRUD
  // ==========================================
  Future<void> loadDiningAreas() async {
    loading = true;
    notifyListeners();
    try {
      final res = await ApiClient.get(ApiEndpoints.restaurantDiningAreas);
      if (res['success'] == true) {
        diningAreas = res['data'] ?? [];
      }
    } catch (e) {
      debugPrint('Error loading dining areas: $e');
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<bool> saveDiningArea(Map<String, dynamic> data) async {
    loading = true;
    notifyListeners();
    try {
      final isNew = data['id'] == null;
      final url = isNew 
          ? ApiEndpoints.restaurantDiningAreas 
          : '${ApiEndpoints.restaurantDiningAreas}/${data['id']}';
      
      final res = isNew 
          ? await ApiClient.post(url, data)
          : await ApiClient.put(url, data);
      
      await loadDiningAreas();
      return res['success'] == true;
    } catch (e) {
      debugPrint('Error saving dining area: $e');
      return false;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<bool> deleteDiningArea(int id) async {
    loading = true;
    notifyListeners();
    try {
      final res = await ApiClient.delete('${ApiEndpoints.restaurantDiningAreas}/$id');
      await loadDiningAreas();
      return res['success'] == true;
    } catch (e) {
      debugPrint('Error deleting dining area: $e');
      return false;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  // ==========================================
  // TABLE TYPES CRUD
  // ==========================================
  Future<void> loadTableTypes() async {
    loading = true;
    notifyListeners();
    try {
      final res = await ApiClient.get(ApiEndpoints.restaurantTableTypes);
      if (res['success'] == true) {
        tableTypes = res['data'] ?? [];
      }
    } catch (e) {
      debugPrint('Error loading table types: $e');
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<bool> saveTableType(Map<String, dynamic> data) async {
    loading = true;
    notifyListeners();
    try {
      final isNew = data['id'] == null;
      final url = isNew 
          ? ApiEndpoints.restaurantTableTypes 
          : '${ApiEndpoints.restaurantTableTypes}/${data['id']}';
      
      final res = isNew 
          ? await ApiClient.post(url, data)
          : await ApiClient.put(url, data);
      
      await loadTableTypes();
      return res['success'] == true;
    } catch (e) {
      debugPrint('Error saving table type: $e');
      return false;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<bool> deleteTableType(int id) async {
    loading = true;
    notifyListeners();
    try {
      final res = await ApiClient.delete('${ApiEndpoints.restaurantTableTypes}/$id');
      await loadTableTypes();
      return res['success'] == true;
    } catch (e) {
      debugPrint('Error deleting table type: $e');
      return false;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  // ==========================================
  // TABLES CRUD & ACTIONS
  // ==========================================
  Future<void> loadTables() async {
    loading = true;
    notifyListeners();
    try {
      final res = await ApiClient.get(ApiEndpoints.restaurantTables);
      if (res['success'] == true) {
        tables = res['data'] ?? [];
      }
    } catch (e) {
      debugPrint('Error loading tables: $e');
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<bool> saveTable(Map<String, dynamic> data) async {
    loading = true;
    notifyListeners();
    try {
      final isNew = data['id'] == null;
      final url = isNew 
          ? ApiEndpoints.restaurantTables 
          : '${ApiEndpoints.restaurantTables}/${data['id']}';
      
      final res = isNew 
          ? await ApiClient.post(url, data)
          : await ApiClient.put(url, data);
      
      await loadTables();
      return res['success'] == true;
    } catch (e) {
      debugPrint('Error saving table: $e');
      return false;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<bool> deleteTable(int id) async {
    loading = true;
    notifyListeners();
    try {
      final res = await ApiClient.delete('${ApiEndpoints.restaurantTables}/$id');
      await loadTables();
      return res['success'] == true;
    } catch (e) {
      debugPrint('Error deleting table: $e');
      return false;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<bool> updateTableStatus(int id, String status, {int? guestCount, int? waiterId, int? captainId, int? activeSaleId}) async {
    try {
      final res = await ApiClient.put('${ApiEndpoints.restaurantTables}/$id/status', {
        'status': status,
        if (guestCount != null) 'guest_count': guestCount,
        if (waiterId != null) 'waiter_id': waiterId,
        if (captainId != null) 'captain_id': captainId,
        if (activeSaleId != null) 'active_sale_id': activeSaleId,
      });
      await loadTables();
      return res['success'] == true;
    } catch (e) {
      debugPrint('Error updating table status: $e');
      return false;
    }
  }

  Future<bool> transferTable(int sourceId, int targetId) async {
    loading = true;
    notifyListeners();
    try {
      final res = await ApiClient.post('${ApiEndpoints.restaurantTables}/transfer', {
        'source_table_id': sourceId,
        'target_table_id': targetId
      });
      await loadTables();
      return res['success'] == true;
    } catch (e) {
      debugPrint('Error transferring table: $e');
      return false;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<bool> mergeTables(int mainTableId, int mergeTableId) async {
    loading = true;
    notifyListeners();
    try {
      final res = await ApiClient.post('${ApiEndpoints.restaurantTables}/merge', {
        'main_table_id': mainTableId,
        'table_to_merge_id': mergeTableId
      });
      await loadTables();
      return res['success'] == true;
    } catch (e) {
      debugPrint('Error merging tables: $e');
      return false;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  // ==========================================
  // PRINTERS CRUD
  // ==========================================
  Future<void> loadPrinters() async {
    loading = true;
    notifyListeners();
    try {
      final res = await ApiClient.get(ApiEndpoints.restaurantPrinters);
      if (res['success'] == true) {
        printers = res['data'] ?? [];
      }
    } catch (e) {
      debugPrint('Error loading printers: $e');
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<bool> savePrinter(Map<String, dynamic> data) async {
    loading = true;
    notifyListeners();
    try {
      final isNew = data['id'] == null;
      final url = isNew 
          ? ApiEndpoints.restaurantPrinters 
          : '${ApiEndpoints.restaurantPrinters}/${data['id']}';
      
      final res = isNew 
          ? await ApiClient.post(url, data)
          : await ApiClient.put(url, data);
      
      await loadPrinters();
      return res['success'] == true;
    } catch (e) {
      debugPrint('Error saving printer: $e');
      return false;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<bool> deletePrinter(int id) async {
    loading = true;
    notifyListeners();
    try {
      final res = await ApiClient.delete('${ApiEndpoints.restaurantPrinters}/$id');
      await loadPrinters();
      return res['success'] == true;
    } catch (e) {
      debugPrint('Error deleting printer: $e');
      return false;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  // ==========================================
  // KITCHEN STATIONS CRUD
  // ==========================================
  Future<void> loadKitchenStations() async {
    loading = true;
    notifyListeners();
    try {
      final res = await ApiClient.get(ApiEndpoints.restaurantKitchenStations);
      if (res['success'] == true) {
        kitchenStations = res['data'] ?? [];
      }
    } catch (e) {
      debugPrint('Error loading kitchen stations: $e');
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<bool> saveKitchenStation(Map<String, dynamic> data) async {
    loading = true;
    notifyListeners();
    try {
      final isNew = data['id'] == null;
      final url = isNew 
          ? ApiEndpoints.restaurantKitchenStations 
          : '${ApiEndpoints.restaurantKitchenStations}/${data['id']}';
      
      final res = isNew 
          ? await ApiClient.post(url, data)
          : await ApiClient.put(url, data);
      
      await loadKitchenStations();
      return res['success'] == true;
    } catch (e) {
      debugPrint('Error saving kitchen station: $e');
      return false;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<bool> deleteKitchenStation(int id) async {
    loading = true;
    notifyListeners();
    try {
      final res = await ApiClient.delete('${ApiEndpoints.restaurantKitchenStations}/$id');
      await loadKitchenStations();
      return res['success'] == true;
    } catch (e) {
      debugPrint('Error deleting kitchen station: $e');
      return false;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  // ==========================================
  // RESERVATIONS CRUD
  // ==========================================
  Future<void> loadReservations() async {
    loading = true;
    notifyListeners();
    try {
      final res = await ApiClient.get(ApiEndpoints.restaurantReservations);
      if (res['success'] == true) {
        reservations = res['data'] ?? [];
      }
    } catch (e) {
      debugPrint('Error loading reservations: $e');
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<bool> saveReservation(Map<String, dynamic> data) async {
    loading = true;
    notifyListeners();
    try {
      final res = await ApiClient.post(ApiEndpoints.restaurantReservations, data);
      await loadReservations();
      await loadTables();
      return res['success'] == true;
    } catch (e) {
      debugPrint('Error saving reservation: $e');
      return false;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<bool> updateReservationStatus(int id, String status) async {
    try {
      final res = await ApiClient.put('${ApiEndpoints.restaurantReservations}/$id/status', {'status': status});
      await loadReservations();
      await loadTables();
      return res['success'] == true;
    } catch (e) {
      debugPrint('Error updating reservation status: $e');
      return false;
    }
  }

  // ==========================================
  // SMTP EMAIL SETTINGS CRUD
  // ==========================================
  Future<void> loadEmailConfig() async {
    loading = true;
    notifyListeners();
    try {
      final res = await ApiClient.get(ApiEndpoints.emailConfigurations);
      if (res['success'] == true) {
        emailConfig = res['data'];
      }
    } catch (e) {
      debugPrint('Error loading email configurations: $e');
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<bool> saveEmailConfig(Map<String, dynamic> data) async {
    loading = true;
    notifyListeners();
    try {
      final res = await ApiClient.post(ApiEndpoints.emailConfigurations, data);
      emailConfig = res['data'];
      return res['success'] == true;
    } catch (e) {
      debugPrint('Error saving email config: $e');
      return false;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<bool> sendTestEmail(String email) async {
    try {
      final res = await ApiClient.post('${ApiEndpoints.emailConfigurations}/test', {'to_email': email});
      return res['success'] == true;
    } catch (e) {
      debugPrint('Error sending test email: $e');
      return false;
    }
  }

  Future<void> loadTemplates() async {
    try {
      final res = await ApiClient.get(ApiEndpoints.emailTemplates);
      if (res['success'] == true) {
        emailTemplates = res['data'] ?? [];
      }
    } catch (e) {
      debugPrint('Error loading email templates: $e');
    }
  }

  Future<bool> saveTemplate(Map<String, dynamic> data) async {
    try {
      final res = await ApiClient.post(ApiEndpoints.emailTemplates, data);
      await loadTemplates();
      return res['success'] == true;
    } catch (e) {
      debugPrint('Error saving template: $e');
      return false;
    }
  }

  // ==========================================
  // RECURRING EXPENSES CRUD
  // ==========================================
  Future<void> loadRecurringExpenses() async {
    loading = true;
    notifyListeners();
    try {
      final res = await ApiClient.get(ApiEndpoints.recurringExpenses);
      if (res['success'] == true) {
        recurringExpensesList = res['data'] ?? [];
      }
    } catch (e) {
      debugPrint('Error loading recurring expenses: $e');
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<bool> saveRecurringExpense(Map<String, dynamic> data) async {
    loading = true;
    notifyListeners();
    try {
      final isNew = data['id'] == null;
      final url = isNew 
          ? ApiEndpoints.recurringExpenses 
          : '${ApiEndpoints.recurringExpenses}/${data['id']}';
      
      final res = isNew 
          ? await ApiClient.post(url, data)
          : await ApiClient.put(url, data);
      
      await loadRecurringExpenses();
      return res['success'] == true;
    } catch (e) {
      debugPrint('Error saving recurring expense: $e');
      return false;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<bool> deleteRecurringExpense(int id) async {
    loading = true;
    notifyListeners();
    try {
      final res = await ApiClient.delete('${ApiEndpoints.recurringExpenses}/$id');
      await loadRecurringExpenses();
      return res['success'] == true;
    } catch (e) {
      debugPrint('Error deleting recurring expense: $e');
      return false;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  // ==========================================
  // DELIVERY CHALLAN CRUD
  // ==========================================
  Future<void> loadChallans() async {
    loading = true;
    notifyListeners();
    try {
      final res = await ApiClient.get(ApiEndpoints.restaurantChallans);
      if (res['success'] == true) {
        challans = res['data'] ?? [];
      }
    } catch (e) {
      debugPrint('Error loading challans: $e');
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<bool> saveChallan(Map<String, dynamic> data) async {
    loading = true;
    notifyListeners();
    try {
      final res = await ApiClient.post(ApiEndpoints.restaurantChallans, data);
      await loadChallans();
      return res['success'] == true;
    } catch (e) {
      debugPrint('Error saving challan: $e');
      return false;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<bool> updateChallanStatus(int id, String status) async {
    try {
      final res = await ApiClient.put('${ApiEndpoints.restaurantChallans}/$id/status', {'status': status});
      await loadChallans();
      return res['success'] == true;
    } catch (e) {
      debugPrint('Error updating challan status: $e');
      return false;
    }
  }
}
