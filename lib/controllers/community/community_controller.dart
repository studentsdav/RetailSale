import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/api/api_client.dart';
import '../../core/auth/token_storage.dart';
import '../../core/config/app_config.dart';
import '../../models/common/property_info_model.dart';
import '../../models/community/community_models.dart';
import '../inventory/marketplace_controller.dart';
import '../inventory/supplier_controller.dart';
import '../settings/property_info_controller.dart';

class CommunityController extends ChangeNotifier {
  static const String _messagesStorageKey = 'retail_business_community_messages_v1';
  static const String _directChatsStorageKey = 'retail_business_community_direct_chats_v1';
  static const String _readTimestampsStorageKey = 'retail_business_community_read_timestamps_v1';
  static const String _mutedStorageKey = 'retail_business_community_muted_v1';
  static const String _blockedStorageKey = 'retail_business_community_blocked_users_v1';
  static const String _exitedStorageKey = 'retail_business_community_exited_channels_v1';
  static const String _joinedStorageKey = 'retail_business_community_joined_channels_v1';
  static const String _messagingEnabledKey = 'retail_business_community_messaging_enabled_v1';

  final PropertyInfoController _propertyCtrl = PropertyInfoController();
  final MarketplaceController _marketplaceCtrl = MarketplaceController();
  final SupplierController _supplierCtrl = SupplierController();

  PropertyInfo? _currentProperty;
  PropertyInfo? get currentProperty => _currentProperty;

  Map<String, dynamic>? _currentUserMap;
  Map<String, dynamic>? get currentUserMap => _currentUserMap;

  // Master Messaging Enable / Disable Setting
  bool _isMessagingEnabled = true;
  bool get isMessagingEnabled => _isMessagingEnabled;

  // Track if a community or chat screen is actively visible
  bool _isScreenActive = false;
  bool get isScreenActive => _isScreenActive;

  void setScreenActive(bool active) {
    _isScreenActive = active;
    if (!active && _activeConversationId == null) {
      _syncTimer?.cancel();
    } else if (active && !AppConfig.isLocalServer && _isMessagingEnabled) {
      refreshProfile();
      _startSyncTimer();
    }
  }

  // Muted conversation IDs (suppresses notification counts & shows mute icon)
  Set<String> _mutedConvIds = {};
  bool isMuted(String convId) => _mutedConvIds.contains(convId);

  // Blocked merchant IDs / Outlet Codes
  Set<String> _blockedMerchantIds = {};
  bool isBlocked(String? merchantIdOrOutletCode) {
    if (merchantIdOrOutletCode == null) return false;
    final clean = merchantIdOrOutletCode.trim().toLowerCase();
    if (clean.isEmpty) return false;
    return _blockedMerchantIds.any((id) => id.trim().toLowerCase() == clean);
  }

  // Exited channel IDs (User left the community channel)
  Set<String> _exitedChannelIds = {};
  bool isChannelExited(String channelId) => _exitedChannelIds.contains(channelId);

  // Joined channel IDs (Channels from other cities/regions the user joined)
  Set<String> _joinedChannelIds = {};
  bool isChannelJoined(String channelId) => _joinedChannelIds.contains(channelId);

  Future<void> refreshProfile() async {
    try {
      _currentUserMap = await TokenStorage.getUser();
      await _propertyCtrl.load();
      _currentProperty = _propertyCtrl.data;

      if (!AppConfig.isLocalServer && _isMessagingEnabled) {
        await fetchPlatformOutlets();

        if (_currentUserMap != null) {
          final currentId = (_currentUserMap!['outlet_id'] ?? _currentUserMap!['outletId'])?.toString();
          if (currentId != null) {
            final matched = _platformOutlets.firstWhere(
              (o) => (o['id'] ?? o['outlet_id'] ?? o['outlet_code'])?.toString() == currentId,
              orElse: () => {},
            );
            if (matched['outlet_code'] != null && matched['outlet_code'].toString().isNotEmpty) {
              _currentUserMap!['outlet_code'] = matched['outlet_code'];
            }
          }
        }

        await fetchBlockedMerchants();
        await fetchRemoteConversations();
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error refreshing community profile: $e');
    }
  }

  String get currentMerchantId {
    // Globally unique Outlet Code (acts as unique merchant username / routing ID)
    final code = _currentUserMap?['outlet_code']?.toString().trim();
    if (code != null && code.isNotEmpty) return code;

    final id = (_currentUserMap?['outlet_id'] ?? _currentUserMap?['outletId'])?.toString().trim();
    if (id != null && id.isNotEmpty) {
      final matched = _platformOutlets.firstWhere(
        (o) => (o['id'] ?? o['outlet_id'])?.toString() == id,
        orElse: () => {},
      );
      if (matched['outlet_code'] != null && matched['outlet_code'].toString().isNotEmpty) {
        return matched['outlet_code'].toString();
      }
      if (id == '1') return 'OUTLET202604212159';
      if (id == '6') return 'OUTLET202609302244';
      if (id == '2') return 'OUTLET202605102056';
      return id;
    }
    return 'OUTLET202604212159';
  }

  String get currentMerchantName {
    // 1. Registered name in Property Info takes highest priority
    final propName = _currentProperty?.propertyName.trim();
    if (propName != null && propName.isNotEmpty) return propName;

    final legalName = _currentProperty?.legalName.trim();
    if (legalName != null && legalName.isNotEmpty) return legalName;

    final userPropName = _currentUserMap?['property_name']?.toString().trim();
    if (userPropName != null && userPropName.isNotEmpty) return userPropName;

    // 2. Outlet Name fallback if Property Info is empty
    final outletName = _currentUserMap?['outlet_name']?.toString().trim();
    if (outletName != null && outletName.isNotEmpty) return outletName;

    final name = _currentUserMap?['name']?.toString().trim();
    if (name != null && name.isNotEmpty && name.toLowerCase() != 'admin' && name.toLowerCase() != 'cashier') return name;

    if (currentMerchantId == '2') return 'Downtown Mart';

    return 'Famalth Technologies';
  }

  String get currentGstin {
    // 1. Registered GSTIN in Property Info takes highest priority
    final propGst = _currentProperty?.gstNo.trim();
    if (propGst != null && propGst.isNotEmpty) return propGst;

    final taxId = (_currentUserMap?['tax_id'] ?? _currentUserMap?['gstin'])?.toString().trim();
    if (taxId != null && taxId.isNotEmpty) return taxId;

    if (currentMerchantId == '2') {
      return 'GSTIN45454544';
    }
    return 'GSTIN';
  }

  String get currentCity =>
      _currentProperty?.city.isNotEmpty == true ? _currentProperty!.city : 'New York';

  String get currentState =>
      _currentProperty?.state.isNotEmpty == true ? _currentProperty!.state : '';

  List<ChatConversation> _channels = [];
  List<ChatConversation> get channels => _channels;

  List<ChatConversation> _directChats = [];
  List<ChatConversation> get directChats => _directChats;

  final Map<String, List<ChatMessage>> _messagesByConv = {};
  final Map<String, int> _lastReadTimestampByConv = {};

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  int _unreadMentionsCount = 0;
  int get unreadMentionsCount => _unreadMentionsCount;

  ChatMessage? _latestMention;
  ChatMessage? get latestMention => _latestMention;

  String? _activeConversationId;
  String? get activeConversationId => _activeConversationId;

  List<Map<String, dynamic>> _platformOutlets = [];
  List<Map<String, dynamic>> get platformOutlets => _platformOutlets;

  /// Calculate unread message count for a specific conversation (only counts messages from other merchants)
  int getUnreadCount(String convId) {
    if (!_isMessagingEnabled) return 0;
    if (_activeConversationId == convId) return 0;
    if (isMuted(convId)) return 0;

    final lastRead = _lastReadTimestampByConv[convId] ?? 0;
    final cleanMyId = currentMerchantId.trim().toLowerCase();
    final cleanMyName = currentMerchantName.trim().toLowerCase();

    // Check if counterpart is blocked in direct chat
    final conv = _directChats.cast<ChatConversation?>().firstWhere((c) => c?.id == convId, orElse: () => null) ??
                 _channels.cast<ChatConversation?>().firstWhere((c) => c?.id == convId, orElse: () => null);

    if (conv != null && conv.isDirect) {
      final otherId = conv.creatorMerchantId == currentMerchantId ? conv.directRecipientId : conv.creatorMerchantId;
      if (otherId != null && isBlocked(otherId)) return 0;
    }

    // 1. Check in-memory cached messages for this conversation
    final msgs = _messagesByConv[convId];
    if (msgs != null && msgs.isNotEmpty) {
      final unreadList = msgs.where((m) {
        final senderId = m.senderId.trim().toLowerCase();
        final senderName = m.senderName.trim().toLowerCase();
        final isMe = (cleanMyId.isNotEmpty && senderId == cleanMyId) ||
                     (cleanMyName.isNotEmpty && senderName == cleanMyName);
        return !isMe &&
               !isBlocked(m.senderId) &&
               !m.isDeletedFor(currentMerchantId) &&
               m.createdAt.millisecondsSinceEpoch > lastRead;
      }).toList();

      if (unreadList.isNotEmpty) {
        return unreadList.length;
      }
    }

    // 2. Check conversation metadata and last message from server
    if (conv != null && conv.lastMessage != null) {
      final lastMsg = conv.lastMessage!;
      final senderId = lastMsg.senderId.trim().toLowerCase();
      final senderName = lastMsg.senderName.trim().toLowerCase();
      final isMe = (cleanMyId.isNotEmpty && senderId == cleanMyId) ||
                   (cleanMyName.isNotEmpty && senderName == cleanMyName);

      if (!isMe && !isBlocked(lastMsg.senderId) && lastMsg.createdAt.millisecondsSinceEpoch > lastRead) {
        return conv.unreadCount > 0 ? conv.unreadCount : 1;
      }
    } else if (conv != null && conv.unreadCount > 0) {
      return conv.unreadCount;
    }

    return 0;
  }

  /// Total unread messages across channels and direct messages
  int get totalUnreadCount {
    if (!_isMessagingEnabled) return 0;
    int total = _unreadMentionsCount;
    for (var c in _directChats) {
      if (!isMuted(c.id)) {
        total += getUnreadCount(c.id);
      }
    }
    for (var c in _channels) {
      if (!isMuted(c.id)) {
        total += getUnreadCount(c.id);
      }
    }
    return total;
  }

  /// Total unread messages specifically from direct chats (Vendors/Suppliers/Outlets)
  int get vendorUnreadCount {
    if (!_isMessagingEnabled) return 0;
    int total = 0;
    for (var c in _directChats) {
      if (!isMuted(c.id)) {
        total += getUnreadCount(c.id);
      }
    }
    return total;
  }

  /// Master switch to enable/disable all community messaging features
  Future<void> setMessagingEnabled(bool enabled) async {
    _isMessagingEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_messagingEnabledKey, enabled);

    if (!enabled) {
      _syncTimer?.cancel();
    } else {
      _startSyncTimer();
      await fetchRemoteConversations();
    }
    notifyListeners();
  }

  /// Toggle Mute for a conversation
  Future<void> toggleMuteConversation(String convId) async {
    if (_mutedConvIds.contains(convId)) {
      _mutedConvIds.remove(convId);
    } else {
      _mutedConvIds.add(convId);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_mutedStorageKey, _mutedConvIds.toList());
    notifyListeners();
  }

  /// Block a merchant / user
  Future<void> blockMerchant(String merchantIdOrOutletCode) async {
    final cleanId = merchantIdOrOutletCode.trim();
    if (cleanId.isEmpty) return;

    _blockedMerchantIds.add(cleanId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_blockedStorageKey, _blockedMerchantIds.toList());
    notifyListeners();

    try {
      await ApiClient.post('/api/community/merchants/block', {
        'user_id': currentMerchantId,
        'blocked_user_id': cleanId,
      });
    } catch (e) {
      debugPrint('Error blocking merchant on server: $e');
    }
  }

  /// Unblock a merchant / user
  Future<void> unblockMerchant(String merchantIdOrOutletCode) async {
    final cleanId = merchantIdOrOutletCode.trim();
    if (cleanId.isEmpty) return;

    _blockedMerchantIds.removeWhere((id) => id.trim().toLowerCase() == cleanId.toLowerCase());
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_blockedStorageKey, _blockedMerchantIds.toList());
    notifyListeners();

    try {
      await ApiClient.post('/api/community/merchants/unblock', {
        'user_id': currentMerchantId,
        'blocked_user_id': cleanId,
      });
    } catch (e) {
      debugPrint('Error unblocking merchant on server: $e');
    }
  }

  /// Exit / Leave a regional community channel
  Future<bool> exitChannel(String channelId) async {
    final cleanId = channelId.trim();
    if (cleanId.isEmpty) return false;

    _exitedChannelIds.add(cleanId);
    _joinedChannelIds.remove(cleanId);
    _channels.removeWhere((c) => c.id == cleanId);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_exitedStorageKey, _exitedChannelIds.toList());
    await prefs.setStringList(_joinedStorageKey, _joinedChannelIds.toList());
    await _saveLocal();
    notifyListeners();

    try {
      await ApiClient.post('/api/community/channels/exit', {
        'channel_id': cleanId,
        'user_id': currentMerchantId,
      });
    } catch (e) {
      debugPrint('Error exiting channel on server: $e');
    }
    return true;
  }

  /// Fetch blocked users from backend
  Future<void> fetchBlockedMerchants() async {
    if (AppConfig.isLocalServer) return;
    try {
      final res = await ApiClient.get('/api/community/merchants/blocked?user_id=$currentMerchantId');
      if (res['success'] == true && res['data'] is List) {
        final List<dynamic> list = res['data'];
        for (var item in list) {
          final bId = (item['blocked_user_id'] ?? item['blockedUserId'] ?? item['user_id'])?.toString();
          if (bId != null && bId.isNotEmpty) {
            _blockedMerchantIds.add(bId.trim());
          }
        }
        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList(_blockedStorageKey, _blockedMerchantIds.toList());
      }
    } catch (e) {
      debugPrint('Error fetching blocked merchants: $e');
    }
  }

  void markConversationAsRead(String conversationId) {
    _lastReadTimestampByConv[conversationId] = DateTime.now().millisecondsSinceEpoch;
    _saveLocal();
    notifyListeners();
  }

  void setActiveConversation(String? id) {
    _activeConversationId = id;
    if (id != null) {
      _lastReadTimestampByConv[id] = DateTime.now().millisecondsSinceEpoch;
      _saveLocal();
      if (!AppConfig.isLocalServer && _isMessagingEnabled) {
        fetchRemoteMessages();
        _startSyncTimer();
      }
    } else {
      if (!_isScreenActive) {
        _syncTimer?.cancel();
      }
    }
    notifyListeners();
  }

  void clearMentions() {
    _unreadMentionsCount = 0;
    _latestMention = null;
    notifyListeners();
  }

  Timer? _syncTimer;

  void _startSyncTimer() {
    _syncTimer?.cancel();
    if (AppConfig.isLocalServer || !_isMessagingEnabled) return;
    if (!_isScreenActive && _activeConversationId == null) return;

    _syncTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (AppConfig.isLocalServer || !_isMessagingEnabled) {
        _syncTimer?.cancel();
        return;
      }
      if (_activeConversationId != null) {
        fetchRemoteMessages();
      } else if (_isScreenActive) {
        fetchRemoteConversations();
      } else {
        _syncTimer?.cancel();
      }
    });
  }

  CommunityController() {
    init();
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    super.dispose();
  }

  /// Initialize real merchant profile and load local channels
  Future<void> init() async {
    _isLoading = true;
    notifyListeners();

    try {
      _currentUserMap = await TokenStorage.getUser();
      await _propertyCtrl.load();
      _currentProperty = _propertyCtrl.data;
      await _loadLocalConversationsAndMessages();
      // Note: Remote network sync is only triggered when Community/Chat screen is active
    } catch (e) {
      debugPrint('Error initializing community controller: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Count of community channels created by the current merchant outlet
  int get myCreatedCommunitiesCount {
    final myId = currentMerchantId.trim().toLowerCase();
    final myName = currentMerchantName.trim().toLowerCase();
    return _channels.where((c) {
      if (c.isDirect) return false;
      final cId = (c.creatorMerchantId ?? '').trim().toLowerCase();
      final cName = (c.creatorMerchantName ?? '').trim().toLowerCase();
      return (myId.isNotEmpty && cId == myId) || (myName.isNotEmpty && cName == myName);
    }).length;
  }

  /// Create a new Real Business Community Channel in the Database
  Future<ChatConversation?> createNewCommunityChannel({
    required String title,
    required String description,
    String? regionCity,
    String? regionState,
  }) async {
    if (myCreatedCommunitiesCount >= 5) {
      throw Exception('Community creation limit reached (maximum 5 communities per outlet).');
    }

    final cleanCity = regionCity?.trim().isNotEmpty == true ? regionCity!.trim() : currentCity;
    final cleanState = regionState?.trim().isNotEmpty == true ? regionState!.trim() : currentState;
    final cleanTitle = title.trim();

    if (cleanTitle.isEmpty) return null;

    final citySlug = cleanCity.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');
    final channelSlug = cleanTitle.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');
    final generatedId = 'channel_${citySlug}_${channelSlug}_${DateTime.now().millisecondsSinceEpoch % 100000}';

    final newChannel = ChatConversation(
      id: generatedId,
      title: cleanTitle.startsWith('#') ? cleanTitle : '# $cleanTitle',
      description: description.trim(),
      regionCity: cleanCity,
      regionState: cleanState,
      isDirect: false,
      creatorMerchantId: currentMerchantId,
      creatorMerchantName: currentMerchantName,
      creatorMerchantGstin: currentGstin,
      creatorMerchantPhone: _currentProperty?.mobile ?? '',
      creatorMerchantCity: currentCity,
      updatedAt: DateTime.now(),
    );

    // Optimistic local add
    final existingIdx = _channels.indexWhere((c) => c.id == newChannel.id);
    if (existingIdx >= 0) {
      _channels[existingIdx] = newChannel;
    } else {
      _channels.insert(0, newChannel);
    }
    await _saveLocal();
    notifyListeners();

    // Persist to real backend DB
    try {
      final res = await ApiClient.post('/api/community/conversations', {
        'id': newChannel.id,
        'title': newChannel.title,
        'description': newChannel.description,
        'region_city': newChannel.regionCity,
        'region_state': newChannel.regionState,
        'is_direct': false,
        'creator_merchant_id': currentMerchantId,
        'creator_merchant_name': currentMerchantName,
        'creator_merchant_gstin': currentGstin,
        'creator_merchant_phone': _currentProperty?.mobile ?? '',
        'creator_merchant_city': currentCity,
      });

      if (res['success'] == true && res['data'] != null) {
        final serverChannel = ChatConversation.fromJson(res['data']);
        final idx = _channels.indexWhere((c) => c.id == serverChannel.id);
        if (idx >= 0) {
          _channels[idx] = serverChannel;
        }
        await _saveLocal();
        notifyListeners();
        return serverChannel;
      }
    } catch (e) {
      debugPrint('Error syncing created channel to backend: $e');
      rethrow;
    }

    return newChannel;
  }

  /// Discover public communities across regions from the database
  Future<List<ChatConversation>> discoverPublicChannels({String query = '', String state = ''}) async {
    try {
      final res = await ApiClient.get(
        '/api/community/conversations/discover?q=${Uri.encodeComponent(query)}&state=${Uri.encodeComponent(state)}',
      );
      if (res['success'] == true && res['data'] is List) {
        final list = (res['data'] as List).map((e) => ChatConversation.fromJson(e)).toList();
        return list.where((c) => !_exitedChannelIds.contains(c.id)).toList();
      }
    } catch (e) {
      debugPrint('Error discovering public channels: $e');
    }
    return [];
  }

  /// Join an existing public community channel
  Future<void> joinCommunityChannel(ChatConversation channel) async {
    _exitedChannelIds.remove(channel.id);
    _joinedChannelIds.add(channel.id);
    final existingIdx = _channels.indexWhere((c) => c.id == channel.id);
    if (existingIdx >= 0) {
      _channels[existingIdx] = channel;
    } else {
      _channels.add(channel);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_exitedStorageKey, _exitedChannelIds.toList());
    await prefs.setStringList(_joinedStorageKey, _joinedChannelIds.toList());
    await _saveLocal();
    notifyListeners();

    try {
      await ApiClient.post('/api/community/channels/join', {
        'channel_id': channel.id,
        'user_id': currentMerchantId,
      });
    } catch (e) {
      debugPrint('Error syncing joined channel to backend: $e');
    }
  }

  /// Get visible messages for a conversation (chronologically sorted)
  List<ChatMessage> getMessages(String conversationId) {
    final Set<String> matchingConvIds = {conversationId};

    // If it's a direct conversation, also gather messages from counterpart aliases
    if (conversationId.startsWith('direct_')) {
      final conv = _directChats.cast<ChatConversation?>().firstWhere((c) => c?.id == conversationId, orElse: () => null);
      if (conv != null) {
        final counterpartCode = conv.creatorMerchantId == currentMerchantId ? conv.directRecipientId : conv.creatorMerchantId;
        final counterpartName = conv.getDisplayTitle(currentMerchantId, currentMerchantName).trim().toLowerCase();

        for (var c in _directChats) {
          final cCounterpart = c.creatorMerchantId == currentMerchantId ? c.directRecipientId : c.creatorMerchantId;
          final cName = c.getDisplayTitle(currentMerchantId, currentMerchantName).trim().toLowerCase();

          if ((counterpartCode != null && counterpartCode.isNotEmpty && cCounterpart == counterpartCode) ||
              (counterpartName.isNotEmpty && cName == counterpartName)) {
            matchingConvIds.add(c.id);
          }
        }
      }
    }

    final Map<String, ChatMessage> uniqueMessages = {};
    for (var cid in matchingConvIds) {
      final list = _messagesByConv[cid] ?? [];
      for (var m in list) {
        if (!m.isDeletedFor(currentMerchantId) && !isBlocked(m.senderId)) {
          uniqueMessages[m.id] = m;
        }
      }
    }

    final visible = uniqueMessages.values.toList();
    visible.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return visible;
  }

  /// Load local persistent storage
  Future<void> _loadLocalConversationsAndMessages() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Messaging enabled
      _isMessagingEnabled = prefs.getBool(_messagingEnabledKey) ?? true;

      // Muted convs
      final mutedList = prefs.getStringList(_mutedStorageKey);
      if (mutedList != null) {
        _mutedConvIds = mutedList.toSet();
      }

      // Blocked users
      final blockedList = prefs.getStringList(_blockedStorageKey);
      if (blockedList != null) {
        _blockedMerchantIds = blockedList.toSet();
      }

      // Exited channels
      final exitedList = prefs.getStringList(_exitedStorageKey);
      if (exitedList != null) {
        _exitedChannelIds = exitedList.toSet();
      }

      // Joined channels
      final joinedList = prefs.getStringList(_joinedStorageKey);
      if (joinedList != null) {
        _joinedChannelIds = joinedList.toSet();
      }

      // 1. Direct chats
      final directJson = prefs.getString(_directChatsStorageKey);
      if (directJson != null && directJson.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(directJson);
        _directChats = decoded.map((e) => ChatConversation.fromJson(e)).toList();
      }

      // 2. Messages
      final msgJson = prefs.getString(_messagesStorageKey);
      if (msgJson != null && msgJson.isNotEmpty) {
        final Map<String, dynamic> decoded = jsonDecode(msgJson);
        decoded.forEach((convId, msgsList) {
          if (msgsList is List) {
            final list = msgsList.map((m) => ChatMessage.fromJson(m)).toList();
            list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
            _messagesByConv[convId] = list;
          }
        });
      }
      // 3. Read timestamps
      final readJson = prefs.getString(_readTimestampsStorageKey);
      if (readJson != null && readJson.isNotEmpty) {
        final Map<String, dynamic> decoded = jsonDecode(readJson);
        decoded.forEach((convId, ts) {
          if (ts is int) {
            _lastReadTimestampByConv[convId] = ts;
          }
        });
      }
    } catch (e) {
      debugPrint('Error reading local community messages: $e');
    }
  }

  /// Save local persistent storage
  Future<void> _saveLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Direct chats
      final directList = _directChats.map((c) => c.toJson()).toList();
      await prefs.setString(_directChatsStorageKey, jsonEncode(directList));

      // Messages map
      final Map<String, dynamic> msgMap = {};
      _messagesByConv.forEach((k, v) {
        msgMap[k] = v.map((m) => m.toJson()).toList();
      });
      await prefs.setString(_messagesStorageKey, jsonEncode(msgMap));

      // Read timestamps
      await prefs.setString(_readTimestampsStorageKey, jsonEncode(_lastReadTimestampByConv));
    } catch (e) {
      debugPrint('Error saving community messages: $e');
    }
  }

  /// Open or create a 1-on-1 direct private chat with a real merchant using unique outlet_code
  ChatConversation getOrCreateDirectChat({
    required String recipientId,
    required String recipientName,
    String? recipientGstin,
    String? recipientPhone,
    String? recipientCity,
  }) {
    // 1. Resolve recipient to their unique outlet_code
    String targetOutletCode = recipientId.trim();
    final match = _platformOutlets.firstWhere(
      (o) => (o['id'] ?? o['outlet_id'] ?? o['outlet_code'])?.toString().trim() == targetOutletCode ||
             (o['business_name'] ?? o['outlet_name'])?.toString().trim().toLowerCase() == recipientName.trim().toLowerCase(),
      orElse: () => {},
    );
    if (match['outlet_code'] != null && match['outlet_code'].toString().isNotEmpty) {
      targetOutletCode = match['outlet_code'].toString();
    }

    final cleanMyCode = currentMerchantId.trim();
    final cleanRecCode = targetOutletCode;

    // 2. Generate deterministic direct chat ID using sorted unique outlet codes
    final codes = [cleanMyCode, cleanRecCode]..sort();
    final directId = 'direct_${codes.first}_${codes.last}';

    // 3. Check if conversation already exists in memory
    final cleanRecName = recipientName.trim().toLowerCase();
    final existingIndex = _directChats.indexWhere((c) {
      if (c.id == directId) return true;
      final cCreator = (c.creatorMerchantId ?? '').trim().toLowerCase();
      final cRec = (c.directRecipientId ?? '').trim().toLowerCase();
      final cTitle = c.getDisplayTitle(currentMerchantId, currentMerchantName).trim().toLowerCase();
      final myCode = cleanMyCode.toLowerCase();
      final recCode = cleanRecCode.toLowerCase();

      final matchesParticipants = (cCreator == recCode && cRec == myCode) ||
          (cCreator == myCode && cRec == recCode);
      final matchesTitle = cTitle.isNotEmpty && (cTitle == cleanRecName);
      return matchesParticipants || matchesTitle;
    });
    if (existingIndex >= 0) {
      return _directChats[existingIndex];
    }

    final newDirectChat = ChatConversation(
      id: directId,
      title: recipientName,
      description: 'Private 1-on-1 business chat',
      regionCity: recipientCity ?? currentCity,
      isDirect: true,
      creatorMerchantId: cleanMyCode,
      creatorMerchantName: currentMerchantName,
      creatorMerchantGstin: currentGstin,
      creatorMerchantPhone: _currentProperty?.mobile ?? '',
      creatorMerchantCity: currentCity,
      directRecipientId: cleanRecCode,
      directRecipientName: recipientName,
      directRecipientGstin: recipientGstin ?? '',
      directRecipientPhone: recipientPhone ?? '',
      directRecipientCity: recipientCity ?? currentCity,
      updatedAt: DateTime.now(),
    );

    _directChats.insert(0, newDirectChat);
    _saveLocal();
    notifyListeners();

    try {
      ApiClient.post('/api/community/conversations', {
        'id': newDirectChat.id,
        'title': newDirectChat.title,
        'description': newDirectChat.description,
        'region_city': newDirectChat.regionCity,
        'region_state': newDirectChat.regionState,
        'is_direct': true,
        'creator_merchant_id': newDirectChat.creatorMerchantId,
        'creator_merchant_name': newDirectChat.creatorMerchantName,
        'creator_merchant_gstin': newDirectChat.creatorMerchantGstin,
        'creator_merchant_phone': newDirectChat.creatorMerchantPhone,
        'creator_merchant_city': newDirectChat.creatorMerchantCity,
        'direct_recipient_id': newDirectChat.directRecipientId,
        'direct_recipient_name': newDirectChat.directRecipientName,
        'direct_recipient_gstin': newDirectChat.directRecipientGstin,
        'direct_recipient_phone': newDirectChat.directRecipientPhone,
        'direct_recipient_city': newDirectChat.directRecipientCity,
      }).catchError((_) {});
    } catch (_) {}

    return newDirectChat;
  }

  /// Send a real message to a conversation or channel
  Future<bool> sendMessage({
    required String conversationId,
    required String content,
    ChatAttachment? attachment,
  }) async {
    final text = content.trim();
    if (text.isEmpty && attachment == null) return false;

    // Parse real @mentions (e.g. @FamalthTechnologies or @SupplierName)
    final mentionRegex = RegExp(r'@([a-zA-Z0-9_-]+)');
    final matches = mentionRegex.allMatches(text);
    final List<String> mentions = matches.map((m) => m.group(1)!).toList();

    final msgId = 'msg_${DateTime.now().millisecondsSinceEpoch}_${currentMerchantId.hashCode.abs()}';

    final newMessage = ChatMessage(
      id: msgId,
      conversationId: conversationId,
      senderId: currentMerchantId,
      senderName: currentMerchantName,
      senderTradeName: _currentProperty?.legalName ?? '',
      senderCity: currentCity,
      senderGstin: currentGstin,
      senderPhone: _currentProperty?.mobile ?? '',
      content: text,
      createdAt: DateTime.now().toLocal(),
      isDeletedForEveryone: false,
      deletedForUserIds: [],
      mentionedHandles: mentions,
      attachment: attachment,
    );

    // Optimistic local add with chronological sorting
    final convList = _messagesByConv.putIfAbsent(conversationId, () => []);
    convList.add(newMessage);
    convList.sort((a, b) => a.createdAt.compareTo(b.createdAt));

    // Update conversation last message & timestamp
    _updateConversationLastMessage(conversationId, newMessage);
    await _saveLocal();
    notifyListeners();

    // Silent remote sync
    try {
      final body = newMessage.toJson();
      await ApiClient.post('/api/community/messages', body);
    } catch (_) {
      // Offline fallback: Message remains safely stored in local state & preferences
    }

    return true;
  }

  /// Edit Message (Restricted to within 1 Hour of sending for own messages)
  Future<bool> editMessage(ChatMessage message, String newContent) async {
    final cleanMyId = currentMerchantId.trim().toLowerCase();
    final senderId = message.senderId.trim().toLowerCase();
    if (cleanMyId.isNotEmpty && senderId.isNotEmpty && cleanMyId != senderId && cleanMyId != message.senderName.trim().toLowerCase()) {
      throw Exception('You can only edit your own messages.');
    }

    final diff = DateTime.now().difference(message.createdAt);
    if (diff.inMinutes >= 60) {
      throw Exception('Messages older than 1 hour cannot be edited.');
    }

    final list = _messagesByConv[message.conversationId];
    if (list == null) return false;

    final index = list.indexWhere((m) => m.id == message.id);
    if (index >= 0) {
      list[index] = list[index].copyWith(
        content: newContent,
      );
      await _saveLocal();
      notifyListeners();

      try {
        await ApiClient.post('/api/community/messages/edit', {
          'message_id': message.id,
          'conversation_id': message.conversationId,
          'sender_id': currentMerchantId,
          'content': newContent,
        });
      } catch (_) {}
      return true;
    }
    return false;
  }

  /// Delete Message for Everyone (Restricted to within 1 Hour of sending)
  Future<bool> deleteForEveryone(ChatMessage message) async {
    final cleanMyId = currentMerchantId.trim().toLowerCase();
    final senderId = message.senderId.trim().toLowerCase();
    if (cleanMyId.isNotEmpty && senderId.isNotEmpty && cleanMyId != senderId && cleanMyId != message.senderName.trim().toLowerCase()) {
      throw Exception('You can only delete your own messages for everyone.');
    }

    final diff = DateTime.now().difference(message.createdAt);
    if (diff.inMinutes >= 60) {
      throw Exception('Messages older than 1 hour cannot be deleted for everyone.');
    }

    final list = _messagesByConv[message.conversationId];
    if (list == null) return false;

    final index = list.indexWhere((m) => m.id == message.id);
    if (index >= 0) {
      list[index] = list[index].copyWith(
        isDeletedForEveryone: true,
        content: '🚫 This message was deleted',
        attachment: null,
      );
      await _saveLocal();
      notifyListeners();

      try {
        await ApiClient.post('/api/community/messages/delete-for-everyone', {
          'message_id': message.id,
          'conversation_id': message.conversationId,
          'sender_id': currentMerchantId,
        });
      } catch (_) {}
      return true;
    }
    return false;
  }

  /// Delete Message for Me (Allowed anytime, hides locally on self-side only)
  Future<bool> deleteForMe(ChatMessage message) async {
    final list = _messagesByConv[message.conversationId];
    if (list == null) return false;

    final index = list.indexWhere((m) => m.id == message.id);
    if (index >= 0) {
      final existingDeletedUsers = List<String>.from(list[index].deletedForUserIds);
      if (!existingDeletedUsers.contains(currentMerchantId)) {
        existingDeletedUsers.add(currentMerchantId);
      }

      list[index] = list[index].copyWith(deletedForUserIds: existingDeletedUsers);
      await _saveLocal();
      notifyListeners();

      try {
        await ApiClient.post('/api/community/messages/delete-for-me', {
          'message_id': message.id,
          'user_id': currentMerchantId,
        });
      } catch (_) {}
      return true;
    }
    return false;
  }

  /// Clear all messages in a conversation (both local cache and database for the current merchant)
  Future<bool> clearChat(String conversationId) async {
    // 1. Gather all matching alias conversation IDs if direct
    final Set<String> matchingConvIds = {conversationId};
    if (conversationId.startsWith('direct_')) {
      final conv = _directChats.cast<ChatConversation?>().firstWhere((c) => c?.id == conversationId, orElse: () => null);
      if (conv != null) {
        final counterpartCode = conv.creatorMerchantId == currentMerchantId ? conv.directRecipientId : conv.creatorMerchantId;
        final counterpartName = conv.getDisplayTitle(currentMerchantId, currentMerchantName).trim().toLowerCase();

        for (var c in _directChats) {
          final cCounterpart = c.creatorMerchantId == currentMerchantId ? c.directRecipientId : c.creatorMerchantId;
          final cName = c.getDisplayTitle(currentMerchantId, currentMerchantName).trim().toLowerCase();

          if ((counterpartCode != null && counterpartCode.isNotEmpty && cCounterpart == counterpartCode) ||
              (counterpartName.isNotEmpty && cName == counterpartName)) {
            matchingConvIds.add(c.id);
          }
        }
      }
    }

    // 2. Mark all messages in local memory as deleted for current user
    for (var cid in matchingConvIds) {
      final list = _messagesByConv[cid];
      if (list != null) {
        for (int i = 0; i < list.length; i++) {
          final existingDeleted = List<String>.from(list[i].deletedForUserIds);
          if (!existingDeleted.contains(currentMerchantId)) {
            existingDeleted.add(currentMerchantId);
          }
          list[i] = list[i].copyWith(deletedForUserIds: existingDeleted);
        }
      }
    }

    // 3. Clear last message in conversation
    final cIdx = _channels.indexWhere((c) => matchingConvIds.contains(c.id));
    if (cIdx >= 0) {
      _channels[cIdx] = _channels[cIdx].copyWith(lastMessage: null);
    }
    final dIdx = _directChats.indexWhere((c) => matchingConvIds.contains(c.id));
    if (dIdx >= 0) {
      _directChats[dIdx] = _directChats[dIdx].copyWith(lastMessage: null);
    }

    await _saveLocal();
    notifyListeners();

    // 4. Send clear request to backend
    try {
      await ApiClient.post('/api/community/conversations/clear', {
        'conversation_id': conversationId,
        'user_id': currentMerchantId,
      });
    } catch (e) {
      debugPrint('Error clearing chat on backend: $e');
    }

    return true;
  }

  /// Search real merchants in region for WhatsApp style @mentions
  List<MerchantMention> searchMentions(String query) {
    final cleanQuery = query.toLowerCase().replaceAll('@', '').trim();
    final List<MerchantMention> results = [];
    final Set<String> seenIds = {};

    // 1. Add vendors from Marketplace
    for (var v in _marketplaceCtrl.vendors) {
      if (seenIds.contains(v.id)) continue;
      final handle = v.businessName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
      if (cleanQuery.isEmpty ||
          v.businessName.toLowerCase().contains(cleanQuery) ||
          handle.toLowerCase().contains(cleanQuery) ||
          v.city.toLowerCase().contains(cleanQuery)) {
        results.add(
          MerchantMention(
            id: v.id,
            handle: handle.isNotEmpty ? handle : 'Vendor_${v.id}',
            businessName: v.businessName,
            legalName: v.tradeName,
            gstin: v.gstin,
            city: v.city,
            phone: v.phone,
          ),
        );
        seenIds.add(v.id);
      }
    }

    // 2. Add real suppliers from SupplierController
    for (var s in _supplierCtrl.list) {
      final idStr = s.id.toString();
      if (seenIds.contains(idStr)) continue;
      final handle = s.supplierName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
      final location = s.state ?? s.address;
      if (cleanQuery.isEmpty ||
          s.supplierName.toLowerCase().contains(cleanQuery) ||
          handle.toLowerCase().contains(cleanQuery) ||
          location.toLowerCase().contains(cleanQuery)) {
        results.add(
          MerchantMention(
            id: idStr,
            handle: handle.isNotEmpty ? handle : 'Supplier_$idStr',
            businessName: s.supplierName,
            legalName: s.supplierName,
            gstin: s.gstin ?? '',
            city: location,
            phone: s.phone,
          ),
        );
        seenIds.add(idStr);
      }
    }

    // 3. Add platform outlets (Famalth Technologies, other outlets)
    for (var o in _platformOutlets) {
      final idStr = (o['id'] ?? o['outlet_id'] ?? '').toString();
      if (seenIds.contains(idStr) || idStr == currentMerchantId) continue;
      final bName = (o['business_name'] ?? o['outlet_name'] ?? 'Outlet $idStr').toString();
      final handle = bName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
      final location = (o['city'] ?? o['state'] ?? '').toString();
      final gstin = (o['gstin'] ?? '').toString();
      final phone = (o['phone'] ?? '').toString();

      if (cleanQuery.isEmpty ||
          bName.toLowerCase().contains(cleanQuery) ||
          handle.toLowerCase().contains(cleanQuery) ||
          location.toLowerCase().contains(cleanQuery) ||
          gstin.toLowerCase().contains(cleanQuery)) {
        results.add(
          MerchantMention(
            id: idStr,
            handle: handle.isNotEmpty ? handle : 'Outlet_$idStr',
            businessName: bName,
            legalName: (o['trade_name'] ?? bName).toString(),
            gstin: gstin,
            city: location,
            phone: phone,
          ),
        );
        seenIds.add(idStr);
      }
    }

    return results;
  }

  /// Fetch registered business outlets from database (optionally filtered by city or query)
  Future<void> fetchPlatformOutlets({String? city, String? query, int limit = 30, int offset = 0}) async {
    if (AppConfig.isLocalServer) return;
    try {
      final queryParams = <String>[];
      final targetCity = city ?? (query != null && query.trim().isNotEmpty ? null : currentCity);
      if (targetCity != null && targetCity.trim().isNotEmpty) {
        queryParams.add('city=${Uri.encodeComponent(targetCity.trim())}');
      }
      if (query != null && query.trim().isNotEmpty) {
        queryParams.add('q=${Uri.encodeComponent(query.trim())}');
      }
      if (currentMerchantId.isNotEmpty) {
        queryParams.add('merchant_id=${Uri.encodeComponent(currentMerchantId)}');
      }
      queryParams.add('limit=$limit');
      queryParams.add('offset=$offset');
      final queryString = queryParams.isNotEmpty ? '?${queryParams.join('&')}' : '';
      final res = await ApiClient.get('/api/community/merchants$queryString');
      if (res['success'] == true && res['data'] is List) {
        _platformOutlets = List<Map<String, dynamic>>.from(
          (res['data'] as List).map((e) => Map<String, dynamic>.from(e)),
        );
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error fetching platform outlets: $e');
    }
  }

  void _updateConversationLastMessage(String convId, ChatMessage msg) {
    // Check in channels
    final cIdx = _channels.indexWhere((c) => c.id == convId);
    if (cIdx >= 0) {
      _channels[cIdx] = _channels[cIdx].copyWith(
        lastMessage: msg,
        updatedAt: DateTime.now(),
      );
    }
    // Check in direct chats
    final dIdx = _directChats.indexWhere((c) => c.id == convId);
    if (dIdx >= 0) {
      _directChats[dIdx] = _directChats[dIdx].copyWith(
        lastMessage: msg,
        updatedAt: DateTime.now(),
      );
    }
  }

  /// Sync real conversations & channels from database
  Future<void> fetchRemoteConversations() async {
    if (AppConfig.isLocalServer || !_isMessagingEnabled) return;
    try {
      final res = await ApiClient.get(
        '/api/community/conversations?city=${Uri.encodeComponent(currentCity)}&merchant_id=$currentMerchantId',
      );
      if (res['success'] == true && res['data'] is List) {
        final List<dynamic> remoteList = res['data'];
        final List<ChatConversation> fetchedChannels = [];
        final List<ChatConversation> fetchedDirects = [];

        for (var raw in remoteList) {
          final conv = ChatConversation.fromJson(raw);
          if (_exitedChannelIds.contains(conv.id)) continue;

          if (conv.isDirect) {
            fetchedDirects.add(conv);
          } else {
            fetchedChannels.add(conv);
          }
        }

        if (fetchedChannels.isNotEmpty) {
          _channels = fetchedChannels;
        }
        if (fetchedDirects.isNotEmpty) {
          // Deduplicate direct chats by counterpart title so only ONE clean thread exists
          final seenTitles = <String>{};
          final dedupedDirects = <ChatConversation>[];
          for (var c in fetchedDirects) {
            final titleKey = c.getDisplayTitle(currentMerchantId, currentMerchantName).trim().toLowerCase();
            if (seenTitles.contains(titleKey)) continue;
            seenTitles.add(titleKey);
            dedupedDirects.add(c);
          }
          _directChats = dedupedDirects;
        }

        await _saveLocal();
        notifyListeners();
      }
    } catch (_) {
      // Offline fallback
    }
  }

  /// Sync messages with remote backend for the active conversation
  Future<void> fetchRemoteMessages() async {
    if (AppConfig.isLocalServer || !_isMessagingEnabled) return;
    if (_activeConversationId == null) {
      if (_isScreenActive) {
        await fetchRemoteConversations();
      }
      return;
    }

    try {
      final path =
          '/api/community/messages?conversation_id=${Uri.encodeComponent(_activeConversationId!)}&merchant_id=$currentMerchantId';

      final res = await ApiClient.get(path);
      if (res['success'] == true && res['data'] is List) {
        final List<dynamic> remoteList = res['data'];
        bool changed = false;

        final myHandle = currentMerchantName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toLowerCase();
        final myPhone = _currentProperty?.mobile ?? '';

        for (var raw in remoteList) {
          final msg = ChatMessage.fromJson(raw);
          if (isBlocked(msg.senderId)) continue;

          final convList = _messagesByConv.putIfAbsent(msg.conversationId, () => []);
          final existingIdx = convList.indexWhere((m) => m.id == msg.id);

          if (existingIdx >= 0) {
            if (convList[existingIdx].isDeletedForEveryone != msg.isDeletedForEveryone ||
                convList[existingIdx].content != msg.content) {
              convList[existingIdx] = msg;
              changed = true;
            }
          } else {
            convList.add(msg);
            _updateConversationLastMessage(msg.conversationId, msg);
            changed = true;

            if (_activeConversationId != null && _activeConversationId != msg.conversationId) {
              final activeConvList = _messagesByConv.putIfAbsent(_activeConversationId!, () => []);
              if (!activeConvList.any((m) => m.id == msg.id)) {
                activeConvList.add(msg);
              }
            }

            // Check if another merchant mentioned me
            if (msg.senderId != currentMerchantId && !isMuted(msg.conversationId)) {
              final isMentioned = msg.mentionedHandles.any((h) =>
                  h.toLowerCase() == myHandle ||
                  (myPhone.isNotEmpty && h.contains(myPhone)));
              if (isMentioned) {
                _unreadMentionsCount++;
                _latestMention = msg;
              }
            }
          }
        }

        if (changed) {
          final activeList = _messagesByConv[_activeConversationId];
          activeList?.sort((a, b) => a.createdAt.compareTo(b.createdAt));
          await _saveLocal();
          notifyListeners();
        }
      }
    } catch (_) {
      // Silent error handler
    }
  }
}
