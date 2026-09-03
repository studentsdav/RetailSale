class BankAccountModel {
  final int id;
  final int outletId;
  final String bankName;
  final String accountName;
  final String accountNumber;
  final String? ifscCode;
  final String? branchName;
  final String accountType;
  final double openingBalance;
  final double currentBalance;
  final bool isActive;
  final bool isPrimary;

  BankAccountModel({
    required this.id,
    required this.outletId,
    required this.bankName,
    required this.accountName,
    required this.accountNumber,
    this.ifscCode,
    this.branchName,
    required this.accountType,
    required this.openingBalance,
    required this.currentBalance,
    required this.isActive,
    this.isPrimary = false,
  });

  factory BankAccountModel.fromJson(Map<String, dynamic> json) {
    return BankAccountModel(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      outletId: json['outlet_id'] is int
          ? json['outlet_id']
          : int.parse(json['outlet_id'].toString()),
      bankName: json['bank_name'] ?? '',
      accountName: json['account_name'] ?? '',
      accountNumber: json['account_number'] ?? '',
      ifscCode: json['ifsc_code'],
      branchName: json['branch_name'],
      accountType: json['account_type'] ?? 'CURRENT',
      openingBalance:
          double.tryParse(json['opening_balance']?.toString() ?? '0') ?? 0.0,
      currentBalance:
          double.tryParse(json['current_balance']?.toString() ?? '0') ?? 0.0,
      isActive: json['is_active'] ?? true,
      isPrimary: json['is_primary'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'outlet_id': outletId,
      'bank_name': bankName,
      'account_name': accountName,
      'account_number': accountNumber,
      'ifsc_code': ifscCode,
      'branch_name': branchName,
      'account_type': accountType,
      'opening_balance': openingBalance,
      'current_balance': currentBalance,
      'is_active': isActive,
      'is_primary': isPrimary,
    };
  }
}
