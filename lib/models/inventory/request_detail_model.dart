import 'request_item_model.dart';

class RequestDetail {
  final int id;
  final String requestNo;
  final String department;
  final DateTime requestDate;
  final String status;
  final List<RequestItemnew> items;

  RequestDetail({
    required this.id,
    required this.requestNo,
    required this.department,
    required this.requestDate,
    required this.status,
    required this.items,
  });

  factory RequestDetail.fromJson(Map<String, dynamic> json) {
    return RequestDetail(
      id: json['id'],
      requestNo: json['request_no'],
      department: json['department'],
      requestDate: DateTime.parse(json['request_date']),
      status: json['status'] ?? '',
      items: (json['items'] as List)
          .map((e) => RequestItemnew.fromJson(e))
          .toList(),
    );
  }
}
