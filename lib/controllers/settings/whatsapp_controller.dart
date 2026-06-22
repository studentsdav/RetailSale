import 'package:flutter/material.dart';
import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';

class WhatsAppController extends ChangeNotifier {
  bool loading = false;
  Map<String, dynamic>? config;
  List<dynamic> templates = [];
  List<dynamic> campaigns = [];
  List<dynamic> logs = [];
  List<dynamic> audience = [];
  Map<String, dynamic>? billingDashboard;

  void _setLoading(bool val) {
    loading = val;
    notifyListeners();
  }

  Future<void> getConfig() async {
    _setLoading(true);
    try {
      final res = await ApiClient.get(ApiEndpoints.whatsappConfig);
      if (res['success'] == true) {
        config = res['data'];
      }
    } catch (e) {
      debugPrint('[WHATSAPP CONTROLLER] Fetch config error: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> saveConfig(Map<String, dynamic> data) async {
    _setLoading(true);
    try {
      await ApiClient.post(ApiEndpoints.whatsappConfig, data);
      await getConfig();
    } catch (e) {
      debugPrint('[WHATSAPP CONTROLLER] Save config error: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> testConnection(String phoneId, String token, String testNumber) async {
    _setLoading(true);
    try {
      await ApiClient.post('${ApiEndpoints.whatsappConfig}/test', {
        'phone_number_id': phoneId,
        'token': token,
        'test_number': testNumber,
      });
    } catch (e) {
      debugPrint('[WHATSAPP CONTROLLER] Test connection error: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> getTemplates() async {
    _setLoading(true);
    try {
      final res = await ApiClient.get(ApiEndpoints.whatsappTemplates);
      if (res['success'] == true) {
        templates = res['data'] ?? [];
      }
    } catch (e) {
      debugPrint('[WHATSAPP CONTROLLER] Fetch templates error: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> syncTemplates() async {
    _setLoading(true);
    try {
      await ApiClient.post('${ApiEndpoints.whatsappTemplates}/sync', {});
      await getTemplates();
    } catch (e) {
      debugPrint('[WHATSAPP CONTROLLER] Sync templates error: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> createTemplate(Map<String, dynamic> data) async {
    _setLoading(true);
    try {
      await ApiClient.post(ApiEndpoints.whatsappTemplates, data);
      await getTemplates();
    } catch (e) {
      debugPrint('[WHATSAPP CONTROLLER] Create template error: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> toggleDefaultInvoiceTemplate(int templateId) async {
    _setLoading(true);
    try {
      await ApiClient.post('${ApiEndpoints.whatsappTemplates}/toggle-default', {
        'template_id': templateId,
      });
      await getTemplates();
    } catch (e) {
      debugPrint('[WHATSAPP CONTROLLER] Toggle default invoice template error: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> getCampaigns() async {
    _setLoading(true);
    try {
      final res = await ApiClient.get(ApiEndpoints.whatsappCampaigns);
      if (res['success'] == true) {
        campaigns = res['data'] ?? [];
      }
    } catch (e) {
      debugPrint('[WHATSAPP CONTROLLER] Fetch campaigns error: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> launchCampaign(String name, int templateId, List<Map<String, dynamic>> recipients) async {
    _setLoading(true);
    try {
      await ApiClient.post(ApiEndpoints.whatsappCampaigns, {
        'campaign_name': name,
        'template_id': templateId,
        'recipients': recipients,
      });
      await getCampaigns();
    } catch (e) {
      debugPrint('[WHATSAPP CONTROLLER] Launch campaign error: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> getLogs() async {
    _setLoading(true);
    try {
      final res = await ApiClient.get(ApiEndpoints.whatsappLogs);
      if (res['success'] == true) {
        logs = res['data'] ?? [];
      }
    } catch (e) {
      debugPrint('[WHATSAPP CONTROLLER] Fetch logs error: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> getAudience() async {
    _setLoading(true);
    try {
      final res = await ApiClient.get(ApiEndpoints.whatsappAudience);
      if (res['success'] == true) {
        audience = res['data'] ?? [];
      }
    } catch (e) {
      debugPrint('[WHATSAPP CONTROLLER] Fetch audience error: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> getBillingDashboard() async {
    _setLoading(true);
    try {
      final res = await ApiClient.get(ApiEndpoints.whatsappBilling);
      if (res['success'] == true) {
        billingDashboard = res['data'];
      }
    } catch (e) {
      debugPrint('[WHATSAPP CONTROLLER] Fetch billing dashboard error: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }
}
