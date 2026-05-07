import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';
import '../../models/inventory/supplier_bill_model.dart';
import '../../models/inventory/supplier_model.dart';

class SupplierBillController extends ChangeNotifier {
  bool loading = false;
  List<Supplier> suppliers = [];

  List<SupplierBill> bills = [];
  double totalPurchase = 0;
  double totalPaid = 0;
  double totalUnpaid = 0;

  DateTime fromDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime toDate = DateTime.now();

  String? supplierId;
  String? status;
  String? suppliername;

  Future<void> load() async {
    loading = true;

    final res = await ApiClient.get(
      '${ApiEndpoints.supplierBills}'
      '?fromDate=${DateFormat('yyyy-MM-dd').format(fromDate)}'
      '&toDate=${DateFormat('yyyy-MM-dd').format(toDate)}'
      '&supplierId=${supplierId ?? ''}'
      '&status=${status ?? ''}',
    );

    bills = (res['data'] as List).map((e) => SupplierBill.fromJson(e)).toList();

    totalPurchase = (res['summary']['totalPurchase'] ?? 0).toDouble();
    totalPaid = (res['summary']['totalPaid'] ?? 0).toDouble();
    totalUnpaid = (res['summary']['totalUnpaid'] ?? 0).toDouble();
    // suppliername = (res['summary']['supplierid']['name'] ?? "");
    loading = false;
    notifyListeners();
  }

  Future<void> loadSuppliers() async {
    final res = await ApiClient.get(ApiEndpoints.suppliers);

    suppliers = (res['data'] as List).map((e) => Supplier.fromJson(e)).toList();

    notifyListeners();
  }

  Future<void> init() async {
    await loadSuppliers();
    await load();
  }

  Future<void> payBill({
    required int billId,
    required double amount,
    required String paymentMode,
    String? referenceNo,
    DateTime? paymentDate,
    String note = '',
  }) async {
    await ApiClient.post(
      ApiEndpoints.paySupplierBill,
      {
        "bill_id": billId,
        "amount": amount,
        "payment_mode": paymentMode,
        "reference_no": referenceNo,
        "payment_date": paymentDate == null
            ? null
            : DateFormat('yyyy-MM-dd').format(paymentDate),
        "note": note,
      },
    );

    await load(); // reload after payment
  }
}
