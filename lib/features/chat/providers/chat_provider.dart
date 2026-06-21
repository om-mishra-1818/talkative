import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:talkative/core/network/supabase_realtime_service.dart';
import 'package:talkative/core/storage/local_db.dart';
import 'package:talkative/features/chat/providers/user_profile_provider.dart';
import '../models/chat_model.dart';
import '../models/media_type.dart';
import '../../../core/di/locator.dart';
import '../domain/entities/message_entity.dart';
import 'package:flutter/foundation.dart';

import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';

class ChatProvider with ChangeNotifier {
  FirebaseFirestore? get _firestore {
    try {
      return FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }

  final SupabaseRealtimeService _realtimeService =
      locator<SupabaseRealtimeService>();

  List<ChatModel> _chats = [];
  ChatModel? _activeChat;
  String _searchQuery = '';
  List<ChatModel> _searchResults = [];
  String _chatFilter = 'All';

  StreamSubscription? _chatsSubscription;
  StreamSubscription? _authSubscription;

  // Cache of fetched user profiles, keyed by userId. The chats snapshot fires
  // on every lastMessage/unreadCount change, but user profiles rarely change —
  // caching them turns a per-message N+1 fetch storm into a one-time load.
  final Map<String, Map<String, dynamic>> _userCache = {};

  ChatProvider() {
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      _chatsSubscription?.cancel();
      _chats = [];
      _activeChat = null;
      _searchResults = [];
      _searchQuery = '';
      _userCache.clear();
      _historyExhausted.clear();
      _realtimeService.leaveCurrentChat();
      notifyListeners();

      if (user != null) {
        _listenToChats(user.uid);
        _realtimeService.initGlobalListener(user.uid);
      }
    });
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

    // Filter out empty chats (where no messages have been sent) unless we are searching
    if (_searchQuery.isEmpty) {
      result = result
          .where((c) => c.lastMessage.isNotEmpty || c.time != null)
          .toList();
    }

    // Sort by latest message time
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

  void _listenToChats(String currentUserId) {
    if (_firestore == null) return;

    _chatsSubscription = _firestore!
        .collection('chats')
        .where('users', arrayContains: currentUserId)
        .snapshots()
        .listen(
          (snapshot) async {
            // Step 1: resolve the "other user" for each chat and fetch only the
            // profiles we don't already have cached — in parallel, not in a
            // sequential await loop. Repeat snapshot fires (every message) now
            // do zero network reads once profiles are warm.
            final missingIds = <String>{};
            for (var doc in snapshot.docs) {
              final users = List<String>.from(doc.data()['users'] ?? []);
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
                final fetched = await Future.wait(
                  missingIds.map(
                    (id) =>
                        _firestore!.collection('users').doc(id).get(),
                  ),
                );
                for (final userDoc in fetched) {
                  if (userDoc.exists) {
                    _userCache[userDoc.id] = userDoc.data()!;
                  }
                }
              } catch (e) {
                debugPrint('Error fetching user data for chats: $e');
              }
            }

            // Step 2: build the chat list purely from the snapshot + cache.
            final List<ChatModel> loadedChats = [];
            for (var doc in snapshot.docs) {
              final data = doc.data();
              final users = List<String>.from(data['users'] ?? []);
              final otherUserId = users.firstWhere(
                (id) => id != currentUserId,
                orElse: () => currentUserId,
              );
              final userData = _userCache[otherUserId];
              if (userData == null) continue;

              loadedChats.add(
                ChatModel(
                  id: doc.id,
                  otherUserId: otherUserId,
                  name: userData['username'] ?? 'Unknown',
                  avatarUrl: userData['avatarUrl'] ?? '',
                  isOnline: userData['isOnline'] ?? false,
                  status:
                      userData['status'] ??
                      (userData['isOnline'] == true ? 'Available' : 'Offline'),
                  phoneNumber: userData['phoneNumber'] ?? '',
                  lastMessage: data['lastMessage'] ?? '',
                  mediaType: MediaTypeExt.fromString(
                    data['lastMessageType'] ?? 'text',
                  ),
                  time: (data['lastMessageTime'] as Timestamp?)?.toDate(),
                  unreadCount: data['unreadCount_$currentUserId'] ?? 0,
                  hasActiveCall: data['hasActiveCall'] ?? false,
                ),
              );
            }
            _chats = loadedChats;
            notifyListeners();
          },
          onError: (error) {
            debugPrint('Error listening to chats: $error');
          },
        );
  }

  void setActiveChat(ChatModel chat) {
    _activeChat = chat;
    if (chat.id.isNotEmpty) {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      _realtimeService.subscribeToChat(chat.id, currentUserId ?? '');

      // Clear unread count when opening the chat
      if (_firestore != null && currentUserId != null) {
        _firestore!
            .collection('chats')
            .doc(chat.id)
            .update({'unreadCount_$currentUserId': 0})
            .catchError((_) {});
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

    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    if (_firestore == null) return;
    final snapshot = await _firestore!.collection('users').get();

    _searchResults = snapshot.docs
        .where((doc) {
          final data = doc.data();
          final username = (data['username'] as String?)?.toLowerCase() ?? '';
          final phone = (data['phoneNumber'] as String?)?.toLowerCase() ?? '';
          return doc.id != currentUserId &&
              (username.contains(query.toLowerCase()) ||
                  phone.contains(query.toLowerCase()));
        })
        .map((doc) {
          final data = doc.data();
          return ChatModel(
            id: '', // Not a chat yet
            otherUserId: doc.id,
            name: data['username'] ?? 'Unknown',
            avatarUrl: data['avatarUrl'] ?? '',
            isOnline: data['isOnline'] ?? false,
            status: data['status'] ?? 'Offline',
            phoneNumber: data['phoneNumber'] ?? '',
          );
        })
        .toList();

    notifyListeners();
  }

  Timer? _searchDebounce;

  void setSearchQuery(String query) {
    // Debounce: a full-collection user query per keystroke is what hammers the
    // network while typing. Wait until the user pauses (350ms) before firing.
    _searchQuery = query; // keep UI filter responsive immediately
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
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null || _firestore == null) return;

    final existingChatIndex = _chats.indexWhere(
      (c) => c.otherUserId == user.otherUserId,
    );
    if (existingChatIndex != -1) {
      setActiveChat(_chats[existingChatIndex]);
    } else {
      final chatDoc = await _firestore!.collection('chats').add({
        'users': [currentUserId, user.otherUserId],
        'createdAt': FieldValue.serverTimestamp(),
      });

      final newChat = ChatModel(
        id: chatDoc.id,
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
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return;

    final chatId = _activeChat!.id;
    if (chatId.isEmpty) return;

    // Soft-Blocking System
    final isBlocked = _activeChat!.isBlocked ?? false;

    final message = MessageEntity()
      ..messageId = DateTime.now().millisecondsSinceEpoch.toString()
      ..chatId = chatId
      ..text = text
      ..senderId = currentUserId
      ..timestamp = DateTime.now()
      ..textVolume = volume
      ..mediaType = mediaType.name
      // Optimistic: assume pending until the server confirms the insert.
      ..isSynced = false;

    // STEP 1A/1B: Write to local Isar immediately. The Chat screen's
    // StreamBuilder is bound to watchMessagesForChat(), so this single write
    // makes the sender's bubble appear instantly — no network involved.
    await locator<LocalDb>().saveMessage(message);

    if (isBlocked) {
      // System intercepts and freezes the payload. The message stays trapped
      // locally as pending (isSynced == false) and is never broadcast.
      return;
    }

    // STEP 1C: Fire the payload at Supabase in the background. On success we
    // flip the local row to synced; on failure it stays pending/failed and
    // remains visible on screen rather than being cleared.
    final bool didSync = await locator<SupabaseRealtimeService>()
        .sendMessageToSupabase(message);
    if (didSync && !message.isSynced) {
      message.isSynced = true;
      await locator<LocalDb>().updateMessage(message);
    }

    // Optional: Update Firestore chat metadata for unread counts
    if (_firestore != null) {
      final chatRef = _firestore!.collection('chats').doc(chatId);
      chatRef
          .update({
            'lastMessage': text,
            'lastMessageTime': FieldValue.serverTimestamp(),
            'lastMessageType': mediaType.name,
            'unreadCount_${_activeChat!.otherUserId}': FieldValue.increment(1),
          })
          .catchError((_) {});
    }
  }

  void editMessage(MessageEntity message, String newText) async {
    message.text = newText;
    message.isEdited = true;

    // Update locally
    await locator<LocalDb>().updateMessage(message);

    // Broadcast update
    // In a real app, you might send a specific "edit" event package.
    // For now, broadcasting the same message ID will overwrite it on the receiver's local DB
    // if we implement the receiver to use `put` with the same ID.
    await locator<SupabaseRealtimeService>().broadcastMessage(
      message.chatId,
      message,
    );
  }

  void deleteMessage(MessageEntity message) async {
    // Delete locally
    await locator<LocalDb>().deleteMessage(message.messageId);

    // Broadcast deletion (Using text = '[DELETED]')
    message.text = '[DELETED]';
    await locator<SupabaseRealtimeService>().broadcastMessage(
      _activeChat!.otherUserId,
      message,
    );

    if (_firestore != null) {
      final lastMsg = await locator<LocalDb>().getLastMessageForChat(
        message.chatId,
      );
      final chatRef = _firestore!.collection('chats').doc(message.chatId);

      if (lastMsg != null) {
        chatRef
            .update({
              'lastMessage': lastMsg.text,
              'lastMessageType': lastMsg.mediaType,
            })
            .catchError((_) {});
      } else {
        chatRef
            .update({'lastMessage': '', 'lastMessageType': 'text'})
            .catchError((_) {});
      }
    }
  }

  Future<void> toggleBlockStatus() async {
    if (_activeChat == null || _firestore == null) return;

    final currentStatus = _activeChat!.isBlocked ?? false;
    final newStatus = !currentStatus;

    // Update locally / active chat
    _activeChat = _activeChat!.copyWith(isBlocked: newStatus);
    notifyListeners();

    // Update in Firestore globally
    await _firestore!.collection('chats').doc(_activeChat!.id).update({
      'is_blocked': newStatus,
    });
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

  // --- Older-history pagination (lazy, scroll-up triggered) ---
  bool _isLoadingHistory = false;
  bool get isLoadingHistory => _isLoadingHistory;

  // Chats whose history has been fully backfilled — stop requesting more.
  final Set<String> _historyExhausted = {};

  bool get isActiveHistoryExhausted {
    final id = _activeChat?.id;
    return id != null && _historyExhausted.contains(id);
  }

  /// Pulls one page of older messages for the active chat from Supabase into
  /// local Isar. Safe to call repeatedly: it no-ops while a load is in flight
  /// or once a chat's history is exhausted, so the UI can call it freely on
  /// scroll without flooding the network.
  Future<void> loadOlderMessages() async {
    final chat = _activeChat;
    if (chat == null || chat.id.isEmpty) return;
    if (_isLoadingHistory || _historyExhausted.contains(chat.id)) return;

    // Anchor on the oldest message we already have. If we have none yet, the
    // live stream is still populating — let it, rather than double-fetching.
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
    // Zero-cost local database stream
    return locator<LocalDb>().watchMessagesForChat(_activeChat!.id);
  }

  void sendTypingEvent(bool isTyping) {
    if (_activeChat == null) return;
    
    // Check if my own typing indicator setting is ON
    final profileProvider = locator<UserProfileProvider>();
    final isTypingAllowed = profileProvider.profile?.typingIndicators ?? true;
    if (!isTypingAllowed) return;

    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
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
    if (_firestore == null) return;
    await _firestore!.collection('chats').doc(chat.id).update({
      'hasActiveCall': false,
    });
  }

  void declineCall(ChatModel chat) async {
    if (_firestore == null) return;
    await _firestore!.collection('chats').doc(chat.id).update({
      'hasActiveCall': false,
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _chatsSubscription?.cancel();
    _searchDebounce?.cancel();
    super.dispose();
  }
}
