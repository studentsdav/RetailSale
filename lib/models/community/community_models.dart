/// Chat Message Model with support for real merchant profiles, mentions, and timed deletion.
class ChatMessage {
  final String id;
  final String conversationId;
  final String senderId; // Merchant Mobile / GSTIN / OutletCode
  final String senderName; // Real Business / Property Name
  final String senderTradeName;
  final String senderCity;
  final String senderGstin;
  final String senderPhone;
  final String content;
  final DateTime createdAt;
  final bool isDeletedForEveryone;
  final List<String> deletedForUserIds; // 'Delete for me' participant IDs
  final List<String> mentionedHandles; // @BusinessName mentions
  final ChatAttachment? attachment;

  ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.senderName,
    this.senderTradeName = '',
    this.senderCity = '',
    this.senderGstin = '',
    this.senderPhone = '',
    required this.content,
    required this.createdAt,
    this.isDeletedForEveryone = false,
    this.deletedForUserIds = const [],
    this.mentionedHandles = const [],
    this.attachment,
  });

  /// Check if the message is deleted for a specific merchant/user
  bool isDeletedFor(String userId) => deletedForUserIds.contains(userId);

  /// Message can only be "Deleted for Everyone" within 1 hour of sending
  bool get canDeleteForEveryone {
    if (isDeletedForEveryone) return false;
    final diff = DateTime.now().difference(createdAt);
    return diff.inMinutes < 60;
  }

  /// Remaining minutes for "Delete for Everyone"
  int get remainingRevokeMinutes {
    final diff = DateTime.now().difference(createdAt);
    final remaining = 60 - diff.inMinutes;
    return remaining > 0 ? remaining : 0;
  }

  /// Message can be edited within 1 hour of sending
  bool get canEdit {
    if (isDeletedForEveryone) return false;
    final diff = DateTime.now().difference(createdAt);
    return diff.inMinutes < 60;
  }

  /// Remaining minutes for "Edit Message"
  int get remainingEditMinutes {
    final diff = DateTime.now().difference(createdAt);
    final remaining = 60 - diff.inMinutes;
    return remaining > 0 ? remaining : 0;
  }

  ChatMessage copyWith({
    String? id,
    String? conversationId,
    String? senderId,
    String? senderName,
    String? senderTradeName,
    String? senderCity,
    String? senderGstin,
    String? senderPhone,
    String? content,
    DateTime? createdAt,
    bool? isDeletedForEveryone,
    List<String>? deletedForUserIds,
    List<String>? mentionedHandles,
    ChatAttachment? attachment,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      senderTradeName: senderTradeName ?? this.senderTradeName,
      senderCity: senderCity ?? this.senderCity,
      senderGstin: senderGstin ?? this.senderGstin,
      senderPhone: senderPhone ?? this.senderPhone,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      isDeletedForEveryone: isDeletedForEveryone ?? this.isDeletedForEveryone,
      deletedForUserIds: deletedForUserIds ?? this.deletedForUserIds,
      mentionedHandles: mentionedHandles ?? this.mentionedHandles,
      attachment: attachment ?? this.attachment,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'conversation_id': conversationId,
      'sender_id': senderId,
      'sender_name': senderName,
      'sender_trade_name': senderTradeName,
      'sender_city': senderCity,
      'sender_gstin': senderGstin,
      'sender_phone': senderPhone,
      'content': content,
      'created_at': createdAt.toUtc().toIso8601String(),
      'is_deleted_for_everyone': isDeletedForEveryone,
      'deleted_for_user_ids': deletedForUserIds,
      'mentioned_handles': mentionedHandles,
      'attachment': attachment?.toJson(),
    };
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id']?.toString() ?? '',
      conversationId: json['conversation_id']?.toString() ?? '',
      senderId: json['sender_id']?.toString() ?? '',
      senderName: json['sender_name']?.toString() ?? 'Merchant',
      senderTradeName: json['sender_trade_name']?.toString() ?? '',
      senderCity: json['sender_city']?.toString() ?? '',
      senderGstin: json['sender_gstin']?.toString() ?? '',
      senderPhone: json['sender_phone']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      createdAt: _parseLocalTime(json['created_at']),
      isDeletedForEveryone: json['is_deleted_for_everyone'] == true ||
          json['is_deleted_for_everyone'] == 1 ||
          json['is_deleted_for_everyone'] == 't' ||
          json['is_deleted_for_everyone'] == 'true',
      deletedForUserIds: List<String>.from(json['deleted_for_user_ids'] ?? []),
      mentionedHandles: List<String>.from(json['mentioned_handles'] ?? []),
      attachment: json['attachment'] != null ? ChatAttachment.fromJson(json['attachment']) : null,
    );
  }
}

DateTime _parseLocalTime(dynamic raw) {
  if (raw == null) return DateTime.now();
  if (raw is DateTime) return raw.toLocal();
  final str = raw.toString().trim();
  if (str.isEmpty) return DateTime.now();

  try {
    if (str.endsWith('Z') || RegExp(r'[+-]\d\d:?\d\d$').hasMatch(str)) {
      return DateTime.parse(str).toLocal();
    }
    final iso = str.replaceAll(' ', 'T');
    return DateTime.parse('${iso}Z').toLocal();
  } catch (_) {
    try {
      return DateTime.parse(str).toLocal();
    } catch (_) {
      return DateTime.now();
    }
  }
}

/// Chat Attachment (Product SKU, Purchase Order, or Invoice Card)
class ChatAttachment {
  final String type; // 'PRODUCT', 'PURCHASE_ORDER', 'IMAGE'
  final String id;
  final String title;
  final String subtitle;
  final double price;
  final String? imageUrl;
  final Map<String, dynamic>? metadata;

  ChatAttachment({
    required this.type,
    required this.id,
    required this.title,
    this.subtitle = '',
    this.price = 0.0,
    this.imageUrl,
    this.metadata,
  });

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'id': id,
      'title': title,
      'subtitle': subtitle,
      'price': price,
      'image_url': imageUrl,
      'metadata': metadata,
    };
  }

  factory ChatAttachment.fromJson(Map<String, dynamic> json) {
    return ChatAttachment(
      type: json['type']?.toString() ?? 'PRODUCT',
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      subtitle: json['subtitle']?.toString() ?? '',
      price: double.tryParse(json['price']?.toString() ?? '0.0') ?? 0.0,
      imageUrl: json['image_url']?.toString(),
      metadata: json['metadata'] != null ? Map<String, dynamic>.from(json['metadata']) : null,
    );
  }
}

/// Chat Conversation or Regional Community Channel
class ChatConversation {
  final String id;
  final String title;
  final String description;
  final String regionCity;
  final String regionState;
  final bool isDirect; // false = Regional Community Channel, true = Private 1-on-1 Direct Chat
  final String? creatorMerchantId;
  final String? creatorMerchantName;
  final String? creatorMerchantGstin;
  final String? creatorMerchantPhone;
  final String? creatorMerchantCity;
  final String? directRecipientId;
  final String? directRecipientName;
  final String? directRecipientGstin;
  final String? directRecipientPhone;
  final String? directRecipientCity;
  final ChatMessage? lastMessage;
  final int unreadCount;
  final DateTime updatedAt;

  ChatConversation({
    required this.id,
    required this.title,
    this.description = '',
    required this.regionCity,
    this.regionState = '',
    this.isDirect = false,
    this.creatorMerchantId,
    this.creatorMerchantName,
    this.creatorMerchantGstin,
    this.creatorMerchantPhone,
    this.creatorMerchantCity,
    this.directRecipientId,
    this.directRecipientName,
    this.directRecipientGstin,
    this.directRecipientPhone,
    this.directRecipientCity,
    this.lastMessage,
    this.unreadCount = 0,
    required this.updatedAt,
  });

  /// Dynamic title resolution from perspective of the current merchant (WhatsApp User A vs User B perspective)
  String getDisplayTitle(String myMerchantId, String myMerchantName) {
    if (!isDirect) {
      return title;
    }
    final cleanMyId = myMerchantId.trim().toLowerCase();
    final cleanMyName = myMerchantName.trim().toLowerCase();

    final recName = (directRecipientName ?? '').trim();
    final creatorName = (creatorMerchantName ?? '').trim();
    final recId = (directRecipientId ?? '').trim().toLowerCase();
    final creatorId = (creatorMerchantId ?? '').trim().toLowerCase();
    final cleanTitle = title.replaceAll(RegExp(r'^#\s*'), '').trim();

    // 1. If I am the creator, counterpart is recipient
    if (cleanMyId.isNotEmpty && (cleanMyId == creatorId || (creatorName.isNotEmpty && cleanMyName == creatorName.toLowerCase()))) {
      if (recName.isNotEmpty) return recName;
    }

    // 2. If I am the recipient, counterpart is creator
    if (cleanMyId.isNotEmpty && (cleanMyId == recId || (recName.isNotEmpty && cleanMyName == recName.toLowerCase()))) {
      if (creatorName.isNotEmpty) return creatorName;
    }

    // 3. Fallback matching
    if (recName.isNotEmpty &&
        recName.toLowerCase() != cleanMyName &&
        recId != cleanMyId) {
      return recName;
    }

    if (creatorName.isNotEmpty &&
        creatorName.toLowerCase() != cleanMyName &&
        creatorId != cleanMyId) {
      return creatorName;
    }

    if (lastMessage != null &&
        lastMessage!.senderName.trim().isNotEmpty &&
        lastMessage!.senderName.trim().toLowerCase() != cleanMyName &&
        lastMessage!.senderId.trim().toLowerCase() != cleanMyId) {
      return lastMessage!.senderName.trim();
    }

    if (cleanTitle.isNotEmpty &&
        cleanTitle.toLowerCase() != cleanMyName &&
        cleanTitle.toLowerCase() != cleanMyId) {
      return cleanTitle;
    }

    return 'Business Partner';
  }

  /// Dynamic GSTIN display for the other party
  String getDisplayGstin(String myMerchantId, String? myGst) {
    final cleanMyId = myMerchantId.trim().toLowerCase();
    final cleanMyGst = (myGst ?? '').trim().toLowerCase();

    final recGst = (directRecipientGstin ?? '').trim();
    final creatorGst = (creatorMerchantGstin ?? '').trim();
    final recId = (directRecipientId ?? '').trim().toLowerCase();
    final creatorId = (creatorMerchantId ?? '').trim().toLowerCase();

    if (cleanMyId.isNotEmpty && cleanMyId == creatorId) {
      if (recGst.isNotEmpty) return recGst;
    }

    if (cleanMyId.isNotEmpty && cleanMyId == recId) {
      if (creatorGst.isNotEmpty) return creatorGst;
    }

    if (recGst.isNotEmpty && recGst.toLowerCase() != cleanMyGst) {
      return recGst;
    }
    if (creatorGst.isNotEmpty && creatorGst.toLowerCase() != cleanMyGst) {
      return creatorGst;
    }

    return 'Registered';
  }


  ChatConversation copyWith({
    String? id,
    String? title,
    String? description,
    String? regionCity,
    String? regionState,
    bool? isDirect,
    String? creatorMerchantId,
    String? creatorMerchantName,
    String? creatorMerchantGstin,
    String? creatorMerchantPhone,
    String? creatorMerchantCity,
    String? directRecipientId,
    String? directRecipientName,
    String? directRecipientGstin,
    String? directRecipientPhone,
    String? directRecipientCity,
    ChatMessage? lastMessage,
    int? unreadCount,
    DateTime? updatedAt,
  }) {
    return ChatConversation(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      regionCity: regionCity ?? this.regionCity,
      regionState: regionState ?? this.regionState,
      isDirect: isDirect ?? this.isDirect,
      creatorMerchantId: creatorMerchantId ?? this.creatorMerchantId,
      creatorMerchantName: creatorMerchantName ?? this.creatorMerchantName,
      creatorMerchantGstin: creatorMerchantGstin ?? this.creatorMerchantGstin,
      creatorMerchantPhone: creatorMerchantPhone ?? this.creatorMerchantPhone,
      creatorMerchantCity: creatorMerchantCity ?? this.creatorMerchantCity,
      directRecipientId: directRecipientId ?? this.directRecipientId,
      directRecipientName: directRecipientName ?? this.directRecipientName,
      directRecipientGstin: directRecipientGstin ?? this.directRecipientGstin,
      directRecipientPhone: directRecipientPhone ?? this.directRecipientPhone,
      directRecipientCity: directRecipientCity ?? this.directRecipientCity,
      lastMessage: lastMessage ?? this.lastMessage,
      unreadCount: unreadCount ?? this.unreadCount,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'region_city': regionCity,
      'region_state': regionState,
      'is_direct': isDirect,
      'creator_merchant_id': creatorMerchantId,
      'creator_merchant_name': creatorMerchantName,
      'creator_merchant_gstin': creatorMerchantGstin,
      'creator_merchant_phone': creatorMerchantPhone,
      'creator_merchant_city': creatorMerchantCity,
      'direct_recipient_id': directRecipientId,
      'direct_recipient_name': directRecipientName,
      'direct_recipient_gstin': directRecipientGstin,
      'direct_recipient_phone': directRecipientPhone,
      'direct_recipient_city': directRecipientCity,
      'last_message': lastMessage?.toJson(),
      'unread_count': unreadCount,
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }

  factory ChatConversation.fromJson(Map<String, dynamic> json) {
    return ChatConversation(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Community Channel',
      description: json['description']?.toString() ?? '',
      regionCity: json['region_city']?.toString() ?? '',
      regionState: json['region_state']?.toString() ?? '',
      isDirect: json['is_direct'] == true,
      creatorMerchantId: json['creator_merchant_id']?.toString(),
      creatorMerchantName: json['creator_merchant_name']?.toString(),
      creatorMerchantGstin: json['creator_merchant_gstin']?.toString(),
      creatorMerchantPhone: json['creator_merchant_phone']?.toString(),
      creatorMerchantCity: json['creator_merchant_city']?.toString(),
      directRecipientId: json['direct_recipient_id']?.toString(),
      directRecipientName: json['direct_recipient_name']?.toString(),
      directRecipientGstin: json['direct_recipient_gstin']?.toString(),
      directRecipientPhone: json['direct_recipient_phone']?.toString(),
      directRecipientCity: json['direct_recipient_city']?.toString(),
      lastMessage: json['last_message'] != null ? ChatMessage.fromJson(json['last_message']) : null,
      unreadCount: int.tryParse(json['unread_count']?.toString() ?? '0') ?? 0,
      updatedAt: _parseLocalTime(json['updated_at']),
    );
  }
}

/// Real Merchant Mention Target (for WhatsApp style @ popup)
class MerchantMention {
  final String handle; // e.g. "FamalthTechnologies"
  final String businessName;
  final String legalName;
  final String gstin;
  final String city;
  final String phone;
  final String id;

  MerchantMention({
    required this.handle,
    required this.businessName,
    this.legalName = '',
    this.gstin = '',
    this.city = '',
    this.phone = '',
    required this.id,
  });
}
