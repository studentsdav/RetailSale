import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';
import '../../models/inventory/purchase_order_model.dart';

class PurchaseOrderController {
  /// CREATE PO
  Future<void> create(PurchaseOrder po) async {
    await ApiClient.post(
      ApiEndpoints.purchaseOrders,
      po.toJson(),
    );
  }

  /// LIST PO
  Future<List<dynamic>> list() async {
    final res = await ApiClient.get(ApiEndpoints.purchaseOrders);
    return res['data'];
  }

  /// GET PO BY ID
  Future<dynamic> getById(int id) async {
    final res = await ApiClient.get('${ApiEndpoints.purchaseOrders}/$id');
    return res['data'];
  }

  /// UPDATE PO (ONLY IF OPEN)
  Future<void> update(int id, Map<String, dynamic> payload) async {
    await ApiClient.put(
      '${ApiEndpoints.purchaseOrders}/$id',
      payload,
    );
  }

  /// CLOSE PO
  Future<void> close(int id) async {
    await ApiClient.post(
      '${ApiEndpoints.purchaseOrders}/$id/close',
      {},
    );
  }

  Future<void> cancel(int id) async {
    await ApiClient.post(
      '${ApiEndpoints.purchaseOrders}/$id/cancel',
      {},
    );
  }
}
