class UserNote {
  final int id;
  final int outletId;
  final int? userId;
  final String title;
  final String content;
  final String colorHex;
  final bool isPinned;
  final bool isCompleted;
  final bool isArchived;
  final bool isTrashed;
  final DateTime? deletedAt;
  String reminderType; // NONE, SPECIFIC_DATE, DAILY, WEEKLY, MONTHLY, YEARLY
  DateTime? reminderDate;
  String? reminderTime;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  UserNote({
    required this.id,
    required this.outletId,
    this.userId,
    required this.title,
    this.content = '',
    this.colorHex = '#FEF08A',
    this.isPinned = false,
    this.isCompleted = false,
    this.isArchived = false,
    this.isTrashed = false,
    this.deletedAt,
    this.reminderType = 'NONE',
    this.reminderDate,
    this.reminderTime,
    this.createdAt,
    this.updatedAt,
  });

  factory UserNote.fromJson(Map<String, dynamic> json) {
    return UserNote(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      outletId: json['outlet_id'] is int ? json['outlet_id'] : int.tryParse(json['outlet_id']?.toString() ?? '0') ?? 0,
      userId: json['user_id'] is int ? json['user_id'] : int.tryParse(json['user_id']?.toString() ?? '0'),
      title: json['title'] ?? 'Untitled Note',
      content: json['content'] ?? '',
      colorHex: json['color_hex'] ?? '#FEF08A',
      isPinned: json['is_pinned'] == true || json['is_pinned']?.toString() == 'true',
      isCompleted: json['is_completed'] == true || json['is_completed']?.toString() == 'true',
      isArchived: json['is_archived'] == true || json['is_archived']?.toString() == 'true',
      isTrashed: json['is_trashed'] == true || json['is_trashed']?.toString() == 'true',
      deletedAt: json['deleted_at'] != null ? DateTime.tryParse(json['deleted_at'].toString()) : null,
      reminderType: json['reminder_type'] ?? 'NONE',
      reminderDate: json['reminder_date'] != null ? DateTime.tryParse(json['reminder_date'].toString())?.toLocal() : null,
      reminderTime: json['reminder_time']?.toString(),
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'].toString()) : null,
      updatedAt: json['updatedAt'] != null ? DateTime.tryParse(json['updatedAt'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'outlet_id': outletId,
      'user_id': userId,
      'title': title,
      'content': content,
      'color_hex': colorHex,
      'is_pinned': isPinned,
      'is_completed': isCompleted,
      'is_archived': isArchived,
      'is_trashed': isTrashed,
      'reminder_type': reminderType,
      'reminder_date': reminderDate?.toUtc().toIso8601String(),
      'reminder_time': reminderTime,
    };
  }
}
