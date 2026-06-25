import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:talkative/core/network/supabase_realtime_service.dart';
import 'package:talkative/core/storage/local_db.dart';
import 'package:talkative/features/chat/providers/user_profile_provider.dart';
import '../models/chat_model.dart';
import '../models/media_type.dart';
import '../../../core/di/locator.dart';
import '../domain/entities/message_entity.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';

class ChatProvider with ChangeNotifier {
  final SupabaseRealtimeService _realtimeService = locator<SupabaseRealtimeService>();
  SupabaseClient get _supabase => locator<SupabaseRealtimeService>().client;

  List<ChatModel> _chats = [];
  ChatModel? _activeChat;
  String _searchQuery = '';
  List<ChatModel> _searchResults = [];
  String _chatFilter = 'All';

  RealtimeChannel? _chatsSubscription;
  StreamSubscription<AuthState>? _authSubscription;
  
  final Map<String, Map<String, dynamic>> _userCache = {};

  ChatProvider() {
    _authSubscription = _supabase.auth.onAuthStateChange.listen((data) {
      final Session? session = data.session;
      _chatsSubscription?.unsubscribe();
      _chats = [];
      _activeChat = null;
      _searchResults = [];
      _searchQuery = '';
      _userCache.clear();
      _historyExhausted.clear();
      _realtimeService.leaveCurrentChat();
      notifyListeners();

      if (session?.user != null) {
        _initChats(session!.user!.id);
        _realtimeService.initGlobalListener(session.user!.id);
      }
    });
  }

  static String directRoomId(String userA, String userB) {
    final ids = [userA, userB]..sort();
    return 'direct_${ids[0]}_${ids[1]}';
  }

  ValueNotifier<List<String>> get presentUsers => _realtimeService.presentUsers;

  String get chatFilter => _chatFilter;

  void setChatFilter(String filter) {
    _chatFilter = filter;
    notifyListeners();
  }

  List<ChatModel> get chats {
    List<ChatModel> result = _chats;

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      final local = result
          .where(
            (c) =>
                c.name.toLowerCase().contains(q) || c.phoneNumber.contains(q),
          )
          .toList();
      final global = _searchResults
          .where((c) => !local.any((l) => l.otherUserId == c.otherUserId))
          .toList();
      result = [...local, ...global];
    }

    if (_chatFilter == 'Unread') {
      result = result.where((c) => c.unreadCount > 0).toList();
    } else if (_chatFilter == 'Files') {
      result = result
          .where(
            (c) =>
                c.mediaType == MediaType.audio ||
                c.mediaType == MediaType.video,
          )
          .toList();
    } else if (_chatFilter == 'Links') {
      result = result.where((c) => c.lastMessage.contains('http')).toList();
    }

    if (_searchQuery.isEmpty) {
      result = result
          .where((c) => c.lastMessage.isNotEmpty || c.time != null)
          .toList();
    }

    result.sort((a, b) {
      if (a.time == null && b.time == null) return 0;
      if (a.time == null) return 1;
      if (b.time == null) return -1;
      return b.time!.compareTo(a.time!);
    });

    return result;
  }

  List<ChatModel> get searchResults => _searchResults;
  String get searchQuery => _searchQuery;
  ChatModel? get activeChat => _activeChat;

  Future<void> _fetchAndProcessChats(String currentUserId) async {
    try {
      final data = await _supabase
          .from('chats')
          .select()
          .contains('users', [currentUserId]);
          
      final List<Map<String, dynamic>> docs = List<Map<String, dynamic>>.from(data);

      final missingIds = <String>{};
      for (var doc in docs) {
        final users = List<String>.from(doc['users'] ?? []);
        final otherUserId = users.firstWhere(
          (id) => id != currentUserId,
          orElse: () => currentUserId,
        );
        if (!_userCache.containsKey(otherUserId)) {
          missingIds.add(otherUserId);
        }
      }

      if (missingIds.isNotEmpty) {
        try {
          final fetched = await _supabase
              .from('users')
              .select()
              .inFilter('id', missingIds.toList());
              
          for (final userDoc in fetched) {
            _userCache[userDoc['id']] = userDoc;
          }
        } catch (e) {
          debugPrint('Error fetching user data for chats: $e');
        }
      }

      final List<ChatModel> loadedChats = [];
      for (var doc in docs) {
        final users = List<String>.from(doc['users'] ?? []);
        final otherUserId = users.firstWhere(
          (id) => id != currentUserId,
          orElse: () => currentUserId,
        );
        final userData = _userCache[otherUserId];
        if (userData == null) continue;
        
        final unreadCountMap = doc['unread_count'] as Map<String, dynamic>? ?? {};
        final unreadCount = unreadCountMap[currentUserId] ?? 0;

        loadedChats.add(
          ChatModel(
            id: doc['id'],
            otherUserId: otherUserId,
            name: userData['username'] ?? 'Unknown',
            avatarUrl: userData['avatarUrl'] ?? '',
            isOnline: userData['isOnline'] ?? false,
            status:
                userData['status'] ??
                (userData['isOnline'] == true ? 'Available' : 'Offline'),
            phoneNumber: userData['phoneNumber'] ?? '',
            lastMessage: doc['lastMessage'] ?? '',
            mediaType: MediaTypeExt.fromString(
              doc['lastMessageType'] ?? 'text',
            ),
            time: doc['lastMessageTime'] != null ? DateTime.parse(doc['lastMessageTime']).toLocal() : null,
            unreadCount: unreadCount,
            hasActiveCall: doc['hasActiveCall'] ?? false,
          ),
        );
      }
      _chats = loadedChats;
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching chats: $e');
    }
  }

  void _initChats(String currentUserId) {
    _fetchAndProcessChats(currentUserId);

    _chatsSubscription = _supabase
        .channel('public:chats')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'chats',
          callback: (payload) {
            // Realtime doesn't easily filter by array contains, but RLS protects it.
            // When we receive an event, we'll just re-fetch the chats.
            _fetchAndProcessChats(currentUserId);
          },
        )
        .subscribe();
  }

  void setActiveChat(ChatModel chat) async {
    _activeChat = chat;
    if (chat.id.isNotEmpty) {
      final currentUserId = _supabase.auth.currentUser?.id;
      _realtimeService.subscribeToChat(chat.id, currentUserId ?? '');

      if (currentUserId != null) {
        try {
          final data = await _supabase.from('chats').select('unread_count').eq('id', chat.id).single();
          final unreadCountMap = Map<String, dynamic>.from(data['unread_count'] ?? {});
          unreadCountMap[currentUserId] = 0;
          await _supabase.from('chats').update({'unread_count': unreadCountMap}).eq('id', chat.id);
        } catch (e) {
          debugPrint('Error clearing unread count: $e');
        }
      }
    }
    notifyListeners();
  }

  Future<void> searchUsers(String query) async {
    _searchQuery = query;
    if (query.isEmpty) {
      _searchResults = [];
      notifyListeners();
      return;
    }

    final currentUserId = _supabase.auth.currentUser?.id;

    try {
      final snapshot = await _supabase
          .from('users')
          .select()
          .neq('id', currentUserId ?? '');

      _searchResults = snapshot
          .where((doc) {
            final username = (doc['username'] as String?)?.toLowerCase() ?? '';
            final phone = (doc['phoneNumber'] as String?)?.toLowerCase() ?? '';
            return username.contains(query.toLowerCase()) || phone.contains(query.toLowerCase());
          })
          .map((doc) {
            return ChatModel(
              id: '', // Not a chat yet
              otherUserId: doc['id'],
              name: doc['username'] ?? 'Unknown',
              avatarUrl: doc['avatarUrl'] ?? '',
              isOnline: doc['isOnline'] ?? false,
              status: doc['status'] ?? 'Offline',
              phoneNumber: doc['phoneNumber'] ?? '',
            );
          })
          .toList();
    } catch (e) {
      debugPrint('Error searching users: $e');
    }

    notifyListeners();
  }

  Timer? _searchDebounce;

  void setSearchQuery(String query) {
    _searchQuery = query;
    _searchDebounce?.cancel();
    if (query.isEmpty) {
      _searchResults = [];
      notifyListeners();
      return;
    }
    _searchDebounce = Timer(
      const Duration(milliseconds: 350),
      () => searchUsers(query),
    );
  }

  Future<void> startChatWith(ChatModel user) async {
    final currentUserId = _supabase.auth.currentUser?.id;
    if (currentUserId == null) return;

    final existingChatIndex = _chats.indexWhere(
      (c) => c.otherUserId == user.otherUserId,
    );
    if (existingChatIndex != -1) {
      setActiveChat(_chats[existingChatIndex]);
    } else {
      try {
        final chatDocList = await _supabase.from('chats').insert({
          'users': [currentUserId, user.otherUserId],
        }).select();
        
        if (chatDocList.isNotEmpty) {
          final chatDoc = chatDocList.first;
          final newChat = ChatModel(
            id: chatDoc['id'],
            otherUserId: user.otherUserId,
            name: user.name,
            avatarUrl: user.avatarUrl,
            isOnline: user.isOnline,
            status: user.status,
            phoneNumber: user.phoneNumber,
          );
          _chats.insert(0, newChat);
          setActiveChat(newChat);
        }
      } catch (e) {
        debugPrint('Error creating chat: $e');
      }
    }

    _searchQuery = '';
    _searchResults = [];
    notifyListeners();
  }

  void sendMessage(
    String text, {
    String volume = 'normal',
    MediaType mediaType = MediaType.text,
  }) async {
    if (_activeChat == null || text.trim().isEmpty) return;
    final currentUserId = _supabase.auth.currentUser?.id;
    if (currentUserId == null) return;

    final chatId = _activeChat!.id;
    if (chatId.isEmpty) return;

    final otherUserId = _activeChat!.otherUserId;

    final isBlocked = _activeChat!.isBlocked ?? false;

    final message = MessageEntity()
      ..messageId = DateTime.now().millisecondsSinceEpoch.toString()
      ..chatId = chatId
      ..text = text
      ..senderId = currentUserId
      ..timestamp = DateTime.now()
      ..textVolume = volume
      ..mediaType = mediaType.name
      ..isSynced = false;

    await locator<LocalDb>().saveMessage(message);

    if (isBlocked) return;

    final bool didSync = await locator<SupabaseRealtimeService>()
        .sendMessageToSupabase(message);
    if (didSync) {
      message.isSynced = true;
      await locator<LocalDb>().updateMessage(message);
      await locator<SupabaseRealtimeService>().broadcastMessage(
        otherUserId,
        message,
      );
    }

    try {
      final chatData = await _supabase.from('chats').select('unread_count').eq('id', chatId).single();
      final unreadCountMap = Map<String, dynamic>.from(chatData['unread_count'] ?? {});
      unreadCountMap[otherUserId] = (unreadCountMap[otherUserId] as int? ?? 0) + 1;
      
      await _supabase.from('chats').update({
        'lastMessage': text,
        'lastMessageTime': DateTime.now().toUtc().toIso8601String(),
        'lastMessageType': mediaType.name,
        'unread_count': unreadCountMap,
      }).eq('id', chatId);
    } catch (e) {
      debugPrint('Error updating chat metadata: $e');
    }
  }

  void editMessage(MessageEntity message, String newText) async {
    message.text = newText;
    message.isEdited = true;

    await locator<LocalDb>().updateMessage(message);

    if (_activeChat != null) {
      await locator<SupabaseRealtimeService>().broadcastMessage(
        _activeChat!.otherUserId,
        message,
      );
    }
  }

  void deleteMessage(MessageEntity message) async {
    await locator<LocalDb>().deleteMessage(message.messageId);

    message.text = '[DELETED]';
    await locator<SupabaseRealtimeService>().broadcastMessage(
      _activeChat!.otherUserId,
      message,
    );

    try {
      final lastMsg = await locator<LocalDb>().getLastMessageForChat(message.chatId);

      if (lastMsg != null) {
        await _supabase.from('chats').update({
          'lastMessage': lastMsg.text,
          'lastMessageType': lastMsg.mediaType,
        }).eq('id', message.chatId);
      } else {
        await _supabase.from('chats').update({
          'lastMessage': '',
          'lastMessageType': 'text',
        }).eq('id', message.chatId);
      }
    } catch (e) {}
  }

  Future<void> toggleBlockStatus() async {
    if (_activeChat == null) return;

    final currentStatus = _activeChat!.isBlocked ?? false;
    final newStatus = !currentStatus;

    _activeChat = _activeChat!.copyWith(isBlocked: newStatus);
    notifyListeners();

    try {
      await _supabase.from('chats').update({
        'is_blocked': newStatus,
      }).eq('id', _activeChat!.id);
    } catch (e) {}
  }

  Future<void> markMessagesAsRead(List<MessageEntity> unreadMessages) async {
    if (unreadMessages.isEmpty) return;
    for (var msg in unreadMessages) {
      msg.isRead = true;
    }
    await locator<LocalDb>().saveMessages(unreadMessages);
    final ids = unreadMessages.map((m) => m.messageId).toList();
    await locator<SupabaseRealtimeService>().markMessagesAsReadInSupabase(ids);
  }

  bool _isLoadingHistory = false;
  bool get isLoadingHistory => _isLoadingHistory;

  final Set<String> _historyExhausted = {};

  bool get isActiveHistoryExhausted {
    final id = _activeChat?.id;
    return id != null && _historyExhausted.contains(id);
  }

  Future<void> loadOlderMessages() async {
    final chat = _activeChat;
    if (chat == null || chat.id.isEmpty) return;
    if (_isLoadingHistory || _historyExhausted.contains(chat.id)) return;

    final oldest = await locator<LocalDb>().getOldestMessageForChat(chat.id);
    if (oldest == null) return;

    _isLoadingHistory = true;
    notifyListeners();
    try {
      final newCount = await locator<SupabaseRealtimeService>()
          .fetchOlderMessages(chat.id, before: oldest.timestamp);
      if (newCount == 0) {
        _historyExhausted.add(chat.id);
      }
    } finally {
      _isLoadingHistory = false;
      notifyListeners();
    }
  }

  Stream<List<MessageEntity>> getActiveChatMessages() {
    if (_activeChat == null || _activeChat!.id.isEmpty) {
      return Stream.value([]);
    }
    return locator<LocalDb>().watchMessagesForChat(_activeChat!.id);
  }

  void sendTypingEvent(bool isTyping) {
    if (_activeChat == null) return;
    
    final profileProvider = locator<UserProfileProvider>();
    final isTypingAllowed = profileProvider.profile?.typingIndicators ?? true;
    if (!isTypingAllowed) return;

    final currentUserId = _supabase.auth.currentUser?.id;
    if (currentUserId == null) return;
    
    locator<SupabaseRealtimeService>().sendTypingEvent(_activeChat!.id, currentUserId, isTyping);
  }

  void createNewChat() {
    _activeChat = null;
    _realtimeService.leaveCurrentChat();
    notifyListeners();
  }

  void clearActiveChat() {
    _activeChat = null;
    _realtimeService.leaveCurrentChat();
    notifyListeners();
  }

  void answerCall(ChatModel chat) async {
    try {
      await _supabase.from('chats').update({'hasActiveCall': false}).eq('id', chat.id);
    } catch (e) {}
  }

  void declineCall(ChatModel chat) async {
    try {
      await _supabase.from('chats').update({'hasActiveCall': false}).eq('id', chat.id);
    } catch (e) {}
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _chatsSubscription?.unsubscribe();
    _searchDebounce?.cancel();
    super.dispose();
  }
}
