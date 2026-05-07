import '../inventory/request_item_model.dart';

class RequestReport {
  final int id;
  final String requestNo;
  final DateTime requestDate;
  final String department;
  final String status;
  final String approvalStatus;
  final DateTime? approvedAt;
  final DateTime? rejectedAt;
  final String rejectionReason;
  final double totalQty;
  final double totalAmount;
  final List<RequestItemReport> items;

  RequestReport({
    required this.id,
    required this.requestNo,
    required this.requestDate,
    required this.department,
    required this.status,
    required this.approvalStatus,
    required this.approvedAt,
    required this.rejectedAt,
    required this.rejectionReason,
    required this.totalQty,
    required this.totalAmount,
    required this.items,
  });

  factory RequestReport.fromJson(Map<String, dynamic> json) {
    return RequestReport(
      id: json['id'],
      requestNo: json['request_no'] ?? '',
      requestDate: DateTime.parse(json['request_date']),
      department: json['department'] ?? '',
      status: json['status'] ?? '',
      approvalStatus: json['approval_status'] ?? 'PENDING',
      approvedAt: json['approved_at'] == null
          ? null
          : DateTime.tryParse(json['approved_at'].toString()),
      rejectedAt: json['rejected_at'] == null
          ? null
          : DateTime.tryParse(json['rejected_at'].toString()),
      rejectionReason: json['rejection_reason'] ?? '',
      totalQty: double.parse(json['total_qty'].toString()),
      totalAmount: double.parse(json['total_amount'].toString()),
      items: (json['items'] as List)
          .map((e) => RequestItemReport.fromJson(e))
          .toList(),
    );
  }
}
