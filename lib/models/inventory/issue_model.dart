import 'issue_item_model.dart';

class Issue {
  final String issueNo;
  final DateTime issueDate;
  final String department;
  final String? indentNo;
  final String issueType;
  final String? openRequestNo;
  final List<IssueItem> items;

  Issue({
    required this.issueNo,
    required this.issueDate,
    required this.department,
    required this.issueType,
    this.indentNo,
    this.openRequestNo,
    required this.items,
  });

  Map<String, dynamic> toJson() {
    return {
      'header': {
        'issue_no': issueNo,
        'issue_date': issueDate.toIso8601String(),
        'department': department,
        'indent_no': indentNo,
        'issue_type': issueType,
        'open_request_no': openRequestNo,
      },
      'items': items.map((e) => e.toJson()).toList(),
    };
  }
}
