import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:talkative/core/network/supabase_realtime_service.dart';
import 'package:talkative/core/storage/local_db.dart';
import 'package:talkative/features/auth/providers/auth_provider.dart';
import '../domain/entities/message_entity.dart';
import '../../../core/utils/responsive.dart';
import '../providers/chat_provider.dart';
import '../models/media_type.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/custom_avatar.dart';
import '../../../core/di/locator.dart';
import '../providers/user_profile_provider.dart';
import 'dynamic_pulse_ring.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';

class ChatTheme {
  final String name;
  final Color background;
  final Color bubbleMe;
  final Color bubbleOther;
  final List<Color>? gradient;

  const ChatTheme(this.name, this.background, this.bubbleMe, this.bubbleOther, {this.gradient});
}

final List<ChatTheme> _darkThemes = [
  const ChatTheme('Default', Colors.transparent, Colors.transparent, Colors.transparent),
  const ChatTheme('Midnight Nebula', Color(0xFF0D0E15), Color(0xFF6A0DAD), Color(0xFF1F1F3A)),
  const ChatTheme('Cyber Sand', Color(0xFF1C1C1C), Color(0xFFD4AF37), Color(0xFF8B4513)),
  const ChatTheme('Crimson Eclipse', Color(0xFF110000), Color(0xFFDC143C), Color(0xFF3A0000)),
  const ChatTheme('Neon Mint', Color(0xFF0A1A1A), Color(0xFF00FA9A), Color(0xFF008080)),
  const ChatTheme('Vaporwave', Color(0xFF10001C), Color(0xFFFF00FF), Color(0xFF00FFFF)),
  const ChatTheme('Cosmic Void', Colors.transparent, Color(0xFF8A2BE2), Color(0xFF4B0082), gradient: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)]),
  const ChatTheme('Deep Space', Colors.transparent, Color(0xFF00B4DB), Color(0xFF0083B0), gradient: [Color(0xFF000000), Color(0xFF434343)]),
  const ChatTheme('Neon Glow', Colors.transparent, Color(0xFFFF0099), Color(0xFF493240), gradient: [Color(0xFF141E30), Color(0xFF243B55)]),
  const ChatTheme('Abyssal Blue', Colors.transparent, Color(0xFF00B4DB), Color(0xFF0083B0), gradient: [Color(0xFF000428), Color(0xFF004E92)]),
  const ChatTheme('Dark Forest', Colors.transparent, Color(0xFF556B2F), Color(0xFF8FBC8F), gradient: [Color(0xFF134E5E), Color(0xFF71B280)]),
  const ChatTheme('Obsidian Blood', Colors.transparent, Color(0xFFDC143C), Color(0xFF3A0000), gradient: [Color(0xFF430000), Color(0xFF000000)]),
];

final List<ChatTheme> _lightThemes = [
  const ChatTheme('Default', Colors.transparent, Colors.transparent, Colors.transparent),
  const ChatTheme('Rose Water', Color(0xFFFFF0F5), Color(0xFFFF69B4), Color(0xFFFFB6C1)),
  const ChatTheme('Ocean Breeze', Color(0xFFF0F8FF), Color(0xFF1E90FF), Color(0xFF87CEEB)),
  const ChatTheme('Matcha Latte', Color(0xFFF5FFFA), Color(0xFF556B2F), Color(0xFF8FBC8F)),
  const ChatTheme('Peach Sunset', Color(0xFFFFF5EE), Color(0xFFFF7F50), Color(0xFFFFDAB9)),
  const ChatTheme('Lavender Dream', Color(0xFFF8F8FF), Color(0xFF9370DB), Color(0xFFDDA0DD)),
  const ChatTheme('Sunrise', Colors.transparent, Color(0xFFFF512F), Color(0xFFDD2476), gradient: [Color(0xFFFF5F6D), Color(0xFFFFC371)]),
  const ChatTheme('Minty Fresh', Colors.transparent, Color(0xFF00B4DB), Color(0xFF0083B0), gradient: [Color(0xFF56CCF2), Color(0xFF2F80ED)]),
  const ChatTheme('Cotton Candy', Colors.transparent, Color(0xFFFF6A88), Color(0xFFFF99AC), gradient: [Color(0xFFFFAFBD), Color(0xFFFFC3A0)]),
  const ChatTheme('Mango Pulse', Colors.transparent, Color(0xFFFF7F50), Color(0xFFFFDAB9), gradient: [Color(0xFFF2994A), Color(0xFFF2C94C)]),
  const ChatTheme('Cool Sky', Colors.transparent, Color(0xFF1E90FF), Color(0xFF87CEEB), gradient: [Color(0xFF2980B9), Color(0xFF6DD5FA)]),
  const ChatTheme('Cherry Blossom', Colors.transparent, Color(0xFFFF69B4), Color(0xFFFFB6C1), gradient: [Color(0xFFFF9A9E), Color(0xFFFECFEF)]),
];

class ChatArea extends StatefulWidget {
  const ChatArea({super.key});

  @override
  State<ChatArea> createState() => _ChatAreaState();
}

class _ChatAreaState extends State<ChatArea> {
  final _scrollController = ScrollController();
  final _textController = TextEditingController();
  final _focusNode = FocusNode();

  bool _isFocused = false;
  double _dragOffset = 0;
  String _currentVolume = 'normal'; // 'normal', 'shout', 'whisper'

  bool _showEmojiPicker = false;
  bool _isRecording = false;
  late final AudioRecorder _audioRecorder;
  MessageEntity? _editingMessage;

  bool _isSearching = false;
  String _searchQuery = '';
  final _searchController = TextEditingController();

  ChatTheme _currentTheme = const ChatTheme('Default', Colors.transparent, Colors.transparent, Colors.transparent);
  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _currentlyPlayingPath;
  Timer? _typingTimer;

  // The local Isar watch stream must be created ONCE per active chat, not on
  // every build(). Re-creating it in build() resets the StreamBuilder to
  // `waiting` on every notifyListeners(), so freshly-written messages never
  // get a chance to render. We cache it and only rebuild it when the chat id
  // actually changes.
  String? _streamChatId;
  Stream<List<MessageEntity>>? _messagesStream;

  // Scroll/pagination bookkeeping (see _onScroll and the messages builder).
  int _prevMessageCount = 0;
  String? _prevFirstMsgId;
  bool _isFirstMessageLoad = true;
  double? _historyAnchorExtent;

  Stream<List<MessageEntity>> _messagesStreamFor(ChatProvider provider) {
    final String id = provider.activeChat?.id ?? '';
    if (id != _streamChatId || _messagesStream == null) {
      _streamChatId = id;
      _messagesStream = provider.getActiveChatMessages();
      // Reset scroll state so a newly-opened chat starts pinned to the bottom.
      _prevMessageCount = 0;
      _prevFirstMsgId = null;
      _isFirstMessageLoad = true;
      _historyAnchorExtent = null;
    }
    return _messagesStream!;
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    // Oldest messages sit at the top; when the user nears it, pull an older
    // page. The provider self-throttles (ignores calls while loading or once
    // history is exhausted), so calling on every scroll tick is safe.
    if (pos.pixels <= pos.minScrollExtent + 200) {
      final provider = context.read<ChatProvider>();
      if (provider.isLoadingHistory) return;
      // Remember the current extent so we can keep the viewport anchored once
      // the older messages prepend and grow the list upward.
      _historyAnchorExtent ??= pos.maxScrollExtent;
      provider.loadOlderMessages();
    }
  }

  @override
  void initState() {
    super.initState();
    _loadSavedTheme();
    _audioRecorder = AudioRecorder();
    _scrollController.addListener(_onScroll);
    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        setState(() {
          _isFocused = true;
          _showEmojiPicker = false; // Hide emoji picker when keyboard opens
        });
      } else {
        setState(() {
          _isFocused = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _textController.dispose();
    _focusNode.dispose();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    _typingTimer?.cancel();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _jumpToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    }
  }

  // Decides how the viewport should react when the message list size changes,
  // based on the unfiltered live count. Three cases:
  //  - first load of a chat  → jump straight to the latest message
  //  - older history prepended (anchor set) → hold position (shift down by the
  //    amount the content grew) so the user stays where they were reading
  //  - a new message at the bottom → follow it only if already near the bottom
  void _handleMessageListGrowth(List<MessageEntity> messages, bool exhausted) {
    final int count = messages.length;
    final String? firstId =
        messages.isEmpty ? null : messages.first.messageId;
    final bool grew = count > _prevMessageCount;
    final bool topChanged = firstId != _prevFirstMsgId;
    final bool wasFirstLoad = _isFirstMessageLoad;
    _prevMessageCount = count;
    _prevFirstMsgId = firstId;

    if (count > 0 && wasFirstLoad) {
      _isFirstMessageLoad = false;
      WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToBottom());
      return;
    }

    if (!grew) {
      // No new rows arrived. If history is now exhausted, drop any anchor we
      // captured on scroll so a future incoming message isn't mistaken for a
      // prepend. While a load is still pending, keep the anchor.
      if (exhausted) _historyAnchorExtent = null;
      return;
    }

    final double? anchor = _historyAnchorExtent;
    _historyAnchorExtent = null;

    if (anchor != null && topChanged) {
      // Older history prepended: hold the reading position by shifting down by
      // however much the content above grew.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scrollController.hasClients) return;
        final double delta =
            _scrollController.position.maxScrollExtent - anchor;
        if (delta > 0) {
          _scrollController.jumpTo(_scrollController.position.pixels + delta);
        }
      });
    } else {
      // New message at the bottom: follow it only if already near the bottom.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scrollController.hasClients) return;
        final pos = _scrollController.position;
        if (pos.maxScrollExtent - pos.pixels < 300) {
          _scrollToBottom();
        }
      });
    }
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      _dragOffset -= details.delta.dy;
      if (_dragOffset > 50) {
        _currentVolume = 'shout';
      } else if (_dragOffset < -50) {
        _currentVolume = 'whisper';
      } else {
        _currentVolume = 'normal';
      }
    });
  }

  void _onPanEnd(DragEndDetails details) {
    final text = _textController.text;
    if (text.trim().isNotEmpty) {
      context.read<ChatProvider>().sendMessage(text, volume: _currentVolume);
      _textController.clear();
    }
    setState(() {
      _dragOffset = 0;
      _currentVolume = 'normal';
    });
  }

  Future<void> _startRecording(LongPressStartDetails details) async {
    if (await _audioRecorder.hasPermission()) {
      setState(() => _isRecording = true);
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _audioRecorder.start(const RecordConfig(), path: path);
    }
  }

  Future<void> _stopRecording(LongPressEndDetails details) async {
    setState(() => _isRecording = false);
    final path = await _audioRecorder.stop();
    if (path != null) {
      context.read<ChatProvider>().sendMessage(path, mediaType: MediaType.audio);
    }
  }

  Future<void> _loadSavedTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final savedThemeName = prefs.getString('selected_chat_theme');
    if (savedThemeName != null) {
      final allThemes = [..._darkThemes, ..._lightThemes];
      final matchedTheme = allThemes.firstWhere((t) => t.name == savedThemeName, orElse: () => allThemes[0]);
      if (mounted) {
        setState(() {
          _currentTheme = matchedTheme;
        });
      }
    }
  }

  Future<void> _saveTheme(ChatTheme theme) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_chat_theme', theme.name);
  }

  @override
  Widget build(BuildContext context) {
    final chatProvider = context.watch<ChatProvider>();
    final activeChat = chatProvider.activeChat;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (activeChat == null) {
      return Container(
        color: _currentTheme.name != 'Default' 
            ? _currentTheme.background 
            : (isDark ? AppColors.chatBackgroundDark : AppColors.chatBackgroundLight),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.chat_bubble_outline,
                size: 80,
                color: Theme.of(context).disabledColor,
              ),
              const SizedBox(height: 16),
              Text(
                'Select a chat to start messaging',
                style: TextStyle(
                  color: Theme.of(context).disabledColor,
                  fontSize: 18,
                ),
              ),
            ],
          ).animate().fadeIn(duration: 500.ms),
        ),
      );
    }

    Widget content = Column(
      children: [
        // Header
        Stack(
          children: [
            ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: (isDark ? Colors.black : Colors.white).withValues(alpha: 0.2),
                    border: Border(
                      bottom: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                    ),
                  ),
              child: _isSearching ? Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () {
                      setState(() {
                        _isSearching = false;
                        _searchQuery = '';
                        _searchController.clear();
                      });
                    },
                  ),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      autofocus: true,
                      decoration: const InputDecoration(
                        hintText: 'Search in chat...',
                        border: InputBorder.none,
                      ),
                      onChanged: (val) {
                        setState(() {
                          _searchQuery = val.toLowerCase();
                        });
                      },
                    ),
                  ),
                ],
              ) : Row(
                children: [
                  if (Responsive.isMobile(context))
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () {
                        context.read<ChatProvider>().clearActiveChat();
                        if (Navigator.canPop(context)) {
                          Navigator.pop(context);
                        }
                      },
                    ),
                  DynamicPulseRing(
                    status: activeChat.status,
                    child: CustomAvatar(
                      radius: 20,
                      imageUrl: activeChat.avatarUrl,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          activeChat.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        ValueListenableBuilder<List<String>>(
                          valueListenable: chatProvider.presentUsers,
                          builder: (context, users, child) {
                            return ValueListenableBuilder<String?>(
                              valueListenable: locator<SupabaseRealtimeService>().typingUserId,
                              builder: (context, typingUserId, child) {
                                if (typingUserId == activeChat.otherUserId) {
                                  return Text('Typing...', style: TextStyle(color: Theme.of(context).primaryColor, fontSize: 12, fontStyle: FontStyle.italic));
                                }
                                final bothInChat = users.contains(activeChat.otherUserId);
                                if (bothInChat) {
                                  return Container(
                                    margin: const EdgeInsets.only(top: 2),
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                                    ),
                                    child: Text('Both in chat', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                                  );
                                }
                                return const SizedBox.shrink();
                              },
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  IconButton(icon: const Icon(Icons.call), onPressed: () {}),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert),
                    onSelected: (value) async {
                      if (value == 'search') {
                        setState(() {
                          _isSearching = true;
                        });
                      } else if (value == 'theme') {
                        showModalBottomSheet(
                          context: context,
                          backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
                          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                          builder: (context) {
                            final themes = isDark ? _darkThemes : _lightThemes;
                            return SafeArea(
                              child: SingleChildScrollView(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Padding(
                                      padding: EdgeInsets.all(16.0),
                                      child: Text('Premium Themes', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                    ),
                                    ...themes.map((theme) => ListTile(
                                      leading: Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: theme.gradient == null 
                                              ? (theme.name == 'Default' ? Colors.grey : theme.background)
                                              : null,
                                          gradient: theme.gradient != null 
                                              ? LinearGradient(colors: theme.gradient!)
                                              : null,
                                        ),
                                      ),
                                      title: Text(theme.name),
                                      trailing: _currentTheme.name == theme.name ? const Icon(Icons.check, color: Colors.green) : null,
                                      onTap: () {
                                        setState(() => _currentTheme = theme);
                                        _saveTheme(theme);
                                        Navigator.pop(context);
                                      },
                                    )),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      } else if (value == 'block') {
                        final isCurrentlyBlocked = activeChat.isBlocked;
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            backgroundColor: (isDark ? AppColors.surfaceDark : Colors.white).withValues(alpha:0.9),
                            title: Text(isCurrentlyBlocked ? 'Unblock User?' : 'Block User?'),
                            content: Text(isCurrentlyBlocked 
                              ? 'Are you sure you want to unblock this user?' 
                              : 'Are you sure you want to block this user?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('No'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: Text('Yes', style: TextStyle(color: isCurrentlyBlocked ? Colors.green : Colors.red)),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          await context.read<ChatProvider>().toggleBlockStatus();
                        }
                      } else if (value == 'clear') {
                        await locator<LocalDb>().clearChat(activeChat.id);
                      }
                    },
                    itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                      const PopupMenuItem<String>(
                        value: 'search',
                        child: ListTile(
                          leading: Icon(Icons.search),
                          title: Text('Search in Chat'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      const PopupMenuItem<String>(
                        value: 'theme',
                        child: ListTile(
                          leading: Icon(Icons.palette),
                          title: Text('Theme'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      PopupMenuItem<String>(
                        value: 'block',
                        child: ListTile(
                          leading: Icon(activeChat.isBlocked ? Icons.check_circle : Icons.block, color: activeChat.isBlocked ? Colors.green : Colors.red),
                          title: Text(activeChat.isBlocked ? 'Unblock User' : 'Block User', style: TextStyle(color: activeChat.isBlocked ? Colors.green : Colors.red)),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      const PopupMenuItem<String>(
                        value: 'clear',
                        child: ListTile(
                          leading: Icon(Icons.delete_outline),
                          title: Text('Clear Chat'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
             ),
            ),
           ),
            Positioned.fill(
              child: ClipRect(
                child: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _textController,
                  builder: (context, textValue, child) {
                    return TweenAnimationBuilder<double>(
                      tween: Tween(
                        begin: 0.0,
                        end:
                            (_isFocused &&
                                MediaQuery.of(context).viewInsets.bottom > 0)
                            ? 1.0
                            : 0.0,
                      ),
                      duration: const Duration(milliseconds: 300),
                      builder: (context, value, child) {
                        if (value == 0.0) return const SizedBox.shrink();
                        return BackdropFilter(
                          filter: ImageFilter.blur(
                            sigmaX: 5 * value,
                            sigmaY: 5 * value,
                          ),
                          child: Container(
                            color: (isDark ? Colors.black : Colors.white)
                                .withValues(alpha: 0.4 * value),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),

        // Messages Stream
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: _currentTheme.gradient == null && _currentTheme.name != 'Default'
                  ? _currentTheme.background
                  : null,
              gradient: _currentTheme.gradient != null
                  ? LinearGradient(
                      colors: _currentTheme.gradient!,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
            ),
            child: StreamBuilder<List<MessageEntity>>(
              stream: _messagesStreamFor(chatProvider),
              builder: (context, snapshot) {
              // Only show the spinner on the very first frame before Isar has
              // emitted anything. Once we have data (even an empty list) we
              // render the list so live writes appear instantly.
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              var rawMessages = List<MessageEntity>.from(snapshot.data ?? []);
              rawMessages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
              var messages = rawMessages;

              final currentUserId = context.read<AuthProvider>().currentUserId;
              final unreadMessages = rawMessages.where((m) => m.senderId != currentUserId && !m.isRead).toList();
              if (unreadMessages.isNotEmpty) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  context.read<ChatProvider>().markMessagesAsRead(unreadMessages);
                });
              }

              if (_searchQuery.isNotEmpty) {
                messages = messages
                    .where((m) => m.text.toLowerCase().contains(_searchQuery))
                    .toList();
              } else {
                // Manage scroll position against the real list only — never
                // while a search filter is temporarily shrinking it.
                _handleMessageListGrowth(
                  rawMessages,
                  chatProvider.isActiveHistoryExhausted,
                );
              }

              final messageList = ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final msg = messages[index];
                  final isMe =
                      msg.senderId ==
                      context.read<AuthProvider>().currentUserId;

                  // Intent-Based Bubble Clusters
                  bool isFirstInCluster = true;
                  bool isLastInCluster = true;

                  if (index > 0) {
                    final prevMsg = messages[index - 1];
                    if (prevMsg.senderId == msg.senderId &&
                        msg.timestamp.difference(prevMsg.timestamp).inSeconds <
                            60) {
                      isFirstInCluster = false;
                    }
                  }
                  if (index < messages.length - 1) {
                    final nextMsg = messages[index + 1];
                    if (nextMsg.senderId == msg.senderId &&
                        nextMsg.timestamp.difference(msg.timestamp).inSeconds <
                            60) {
                      isLastInCluster = false;
                    }
                  }

                  double fontSize = 15;
                  double alpha = 1.0;
                  if (msg.textVolume == 'shout') {
                    fontSize = 22;
                  } else if (msg.textVolume == 'whisper') {
                    fontSize = 12;
                    alpha = 0.6;
                  }

                  final bubble = Align(
                    alignment: isMe
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Opacity(
                      opacity: alpha,
                      child: Container(
                                key: ValueKey('${msg.messageId}_${msg.text}_${msg.isEdited}'),
                                margin: EdgeInsets.only(
                                  bottom: isLastInCluster ? 16 : 4,
                                  top: isFirstInCluster ? 8 : 0,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: isMe
                                      ? (_currentTheme.name != 'Default'
                                          ? _currentTheme.bubbleMe
                                          : (isDark
                                              ? AppColors.chatBubbleUserDark
                                              : AppColors.chatBubbleUserLight))
                                      : (_currentTheme.name != 'Default'
                                          ? _currentTheme.bubbleOther
                                          : (isDark
                                              ? AppColors.chatBubbleBotDark
                                              : AppColors.chatBubbleBotLight)),
                                  borderRadius: BorderRadius.circular(16)
                                      .copyWith(
                                        topLeft: Radius.circular(
                                          isMe || !isFirstInCluster ? 16 : 0,
                                        ),
                                        topRight: Radius.circular(
                                          !isMe || !isFirstInCluster ? 16 : 0,
                                        ),
                                        bottomLeft: Radius.circular(
                                          isMe || !isLastInCluster ? 16 : 0,
                                        ),
                                        bottomRight: Radius.circular(
                                          !isMe || !isLastInCluster ? 16 : 0,
                                        ),
                                      ),
                                  boxShadow: [
                                    if (isLastInCluster)
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.05),
                                        blurRadius: 2,
                                        offset: const Offset(0, 1),
                                      ),
                                  ],
                                ),
                                constraints: BoxConstraints(
                                  maxWidth:
                                      MediaQuery.of(context).size.width * 0.75,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (msg.mediaType == 'audio')
                                          IconButton(
                                            icon: Icon(
                                              _currentlyPlayingPath == msg.text ? Icons.stop : Icons.play_arrow,
                                              color: isDark ? Colors.white : Colors.black87,
                                            ),
                                            onPressed: () async {
                                              if (_currentlyPlayingPath == msg.text) {
                                                await _audioPlayer.stop();
                                                setState(() => _currentlyPlayingPath = null);
                                              } else {
                                                await _audioPlayer.stop();
                                                setState(() => _currentlyPlayingPath = msg.text);
                                                await _audioPlayer.play(DeviceFileSource(msg.text));
                                                _audioPlayer.onPlayerComplete.listen((_) {
                                                  if (mounted) {
                                                    setState(() => _currentlyPlayingPath = null);
                                                  }
                                                });
                                              }
                                            },
                                          )
                                        else
                                          Flexible(
                                            child: Text(
                                              msg.text,
                                              style: TextStyle(
                                                color: isDark
                                                    ? Colors.white
                                                    : Colors.black87,
                                                fontSize: fontSize,
                                              ),
                                            ),
                                          ),
                                        if (msg.isEdited && msg.mediaType != 'audio')
                                          Padding(
                                            padding: const EdgeInsets.only(left: 4.0),
                                            child: Text(
                                              '(edited)',
                                              style: TextStyle(
                                                color: isDark ? Colors.white54 : Colors.black54,
                                                fontSize: 10,
                                                fontStyle: FontStyle.italic,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    if (isLastInCluster) ...[
                                      const SizedBox(height: 4),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            DateFormat(
                                              'HH:mm',
                                            ).format(msg.timestamp),
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: (isDark
                                                  ? Colors.white54
                                                  : Colors.black54),
                                            ),
                                          ),
                                          if (isMe) ...[
                                            const SizedBox(width: 4),
                                            Icon(
                                              // Pending/failed push → clock,
                                              // server-confirmed → double check.
                                              !msg.isSynced
                                                  ? Icons.access_time
                                                  : (msg.isRead ? Icons.done_all : Icons.check),
                                              size: 14,
                                              color: !msg.isSynced
                                                  ? (isDark ? Colors.white54 : Colors.blueGrey)
                                                  : (msg.isRead ? Colors.blue : (isDark ? Colors.white54 : Colors.blueGrey)),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              )
                              .animate()
                              .slideX(
                                begin: isMe ? 0.2 : -0.2,
                                duration: 200.ms,
                                curve: Curves.easeOut,
                              )
                              .fadeIn(),
                    ),
                  );

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2.0),
                    child: Row(
                      mainAxisAlignment: isMe
                          ? MainAxisAlignment.end
                          : MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (!isMe && isLastInCluster)
                          Padding(
                            padding: const EdgeInsets.only(
                              right: 8.0,
                              bottom: 12,
                            ),
                            child: CustomAvatar(
                              radius: 12,
                              imageUrl: activeChat.avatarUrl,
                            ),
                          )
                        else if (!isMe)
                          const SizedBox(width: 32),
                        Expanded(
                          child: GestureDetector(
                            onLongPressStart: isMe ? (details) {
                              final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
                              final position = details.globalPosition;
                              showMenu(
                                context: context,
                                position: RelativeRect.fromRect(
                                  position & const Size(40, 40),
                                  Offset.zero & overlay.size,
                                ),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                color: isDark ? AppColors.surfaceDark.withValues(alpha: 0.95) : Colors.white.withValues(alpha: 0.95),
                                items: [
                                  PopupMenuItem(
                                    value: 'edit',
                                    child: Row(
                                      children: const [
                                        Icon(Icons.edit, size: 20),
                                        SizedBox(width: 8),
                                        Text('Edit Message', style: TextStyle(fontWeight: FontWeight.w500)),
                                      ],
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Row(
                                      children: const [
                                        Icon(Icons.delete, color: Colors.red, size: 20),
                                        SizedBox(width: 8),
                                        Text('Delete Message', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w500)),
                                      ],
                                    ),
                                  ),
                                ],
                              ).then((value) {
                                if (value == 'edit') {
                                  setState(() {
                                    _editingMessage = msg;
                                    _textController.text = msg.text;
                                    FocusScope.of(context).requestFocus(_focusNode);
                                  });
                                } else if (value == 'delete') {
                                  context.read<ChatProvider>().deleteMessage(msg);
                                }
                              });
                            } : null,
                            child: bubble,
                          ),
                        ),
                        if (isMe && isLastInCluster)
                          ListenableBuilder(
                            listenable: locator<UserProfileProvider>(),
                            builder: (context, _) {
                              final profile =
                                  locator<UserProfileProvider>().profile;
                              return Padding(
                                padding: const EdgeInsets.only(
                                  left: 8.0,
                                  bottom: 12,
                                ),
                                child: CustomAvatar(
                                  radius: 12,
                                  imageUrl:
                                      locator<UserProfileProvider>()
                                              .localPhotoBase64 !=
                                          null
                                      ? 'base64:${locator<UserProfileProvider>().localPhotoBase64}'
                                      : profile?.avatarUrl.isNotEmpty == true
                                      ? profile!.avatarUrl
                                      : 'https://ui-avatars.com/api/?name=${profile?.username ?? 'Me'}',
                                ),
                              );
                            },
                          )
                        else if (isMe)
                          const SizedBox(width: 32),
                      ],
                    ),
                  );
                },
              );

              return Stack(
                children: [
                  messageList,
                  if (chatProvider.isLoadingHistory)
                    Positioned(
                      top: 8,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: (isDark ? Colors.black : Colors.white)
                                .withValues(alpha: 0.6),
                            shape: BoxShape.circle,
                          ),
                          child: const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          ),
        ),
      ],
    );

    return Container(
      color: isDark ? AppColors.chatBackgroundDark : AppColors.chatBackgroundLight,
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  content,

            // Editing Banner
            if (_editingMessage != null)
              Positioned(
                left: 0,
                right: 0,
                bottom: 60, // approximate height of input bar
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: Theme.of(context).primaryColor.withOpacity(0.9),
                  child: Row(
                    children: [
                      const Icon(Icons.edit, color: Colors.white, size: 16),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Editing Message',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white, size: 16),
                        onPressed: () {
                          setState(() {
                            _editingMessage = null;
                            _textController.clear();
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),

            // Isolated Input Node
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    decoration: BoxDecoration(
                      color: (isDark ? Colors.black : Colors.white).withValues(alpha: 0.2),
                      border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.15))),
                    ),
                    child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.attach_file),
                      onPressed: () async {
                        final picker = ImagePicker();
                        final file = await picker.pickImage(source: ImageSource.gallery);
                        if (file != null) {
                          // In a real implementation: context.read<ChatProvider>().sendMedia(File(file.path));
                          // For now, we just log it or pass it safely.
                        }
                      },
                    ),
                    IconButton(
                      icon: Icon(
                        _showEmojiPicker ? Icons.keyboard : Icons.emoji_emotions_outlined,
                      ),
                      onPressed: () {
                        setState(() {
                          _showEmojiPicker = !_showEmojiPicker;
                        });
                        if (_showEmojiPicker) {
                          FocusScope.of(context).unfocus();
                        } else {
                          FocusScope.of(context).requestFocus(_focusNode);
                        }
                      },
                    ),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.backgroundDark
                              : Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color:
                                _isFocused &&
                                    MediaQuery.of(context).viewInsets.bottom > 0
                                ? Theme.of(context).primaryColor
                                : Colors.transparent,
                          ),
                        ),
                        child: TextField(
                          controller: _textController,
                          focusNode: _focusNode,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: const InputDecoration(
                            hintText: 'Type a message',
                            border: InputBorder.none,
                          ),
                          onChanged: (val) {
                            final chatProvider = context.read<ChatProvider>();
                            chatProvider.sendTypingEvent(true);
                            _typingTimer?.cancel();
                            _typingTimer = Timer(const Duration(seconds: 2), () {
                              if (mounted) {
                                chatProvider.sendTypingEvent(false);
                              }
                            });
                          },
                          onSubmitted: (val) {
                            if (val.trim().isNotEmpty) {
                              _typingTimer?.cancel();
                              context.read<ChatProvider>().sendTypingEvent(false);
                              if (_editingMessage != null) {
                                // TODO: Edit logic
                                context.read<ChatProvider>().editMessage(_editingMessage!, val);
                                setState(() => _editingMessage = null);
                              } else {
                                context.read<ChatProvider>().sendMessage(val);
                              }
                              _textController.clear();
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _textController,
                      builder: (context, value, child) {
                        final hasText = value.text.trim().isNotEmpty;

                        return GestureDetector(
                          onTap: hasText
                              ? () {
                                  _typingTimer?.cancel();
                                  context.read<ChatProvider>().sendTypingEvent(false);
                                  
                                  if (_editingMessage != null) {
                                    context.read<ChatProvider>().editMessage(
                                      _editingMessage!,
                                      _textController.text,
                                    );
                                    setState(() => _editingMessage = null);
                                  } else {
                                    context.read<ChatProvider>().sendMessage(
                                      _textController.text,
                                      volume: _currentVolume,
                                    );
                                  }
                                  _textController.clear();
                                  setState(() {
                                    _dragOffset = 0;
                                    _currentVolume = 'normal';
                                  });
                                }
                              : null,
                          onPanUpdate: hasText ? _onPanUpdate : null,
                          onPanEnd: hasText ? _onPanEnd : null,
                          onLongPressStart: hasText ? null : _startRecording,
                          onLongPressEnd: hasText ? null : _stopRecording,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: EdgeInsets.all(
                              _currentVolume == 'shout'
                                  ? 16
                                  : (_currentVolume == 'whisper' ? 8 : 12),
                            ),
                            decoration: BoxDecoration(
                              color: _currentVolume == 'shout'
                                  ? Colors.redAccent
                                  : (_currentVolume == 'whisper'
                                        ? Colors.blueAccent
                                        : Theme.of(context).primaryColor),
                              shape: BoxShape.circle,
                              boxShadow: [
                                if (_dragOffset != 0)
                                  BoxShadow(
                                    color: Theme.of(
                                      context,
                                    ).primaryColor.withOpacity(0.5),
                                    blurRadius: 10,
                                    spreadRadius: 2,
                                  ),
                              ],
                            ),
                            child: Icon(
                              hasText ? Icons.send : Icons.mic,
                              color: Colors.white,
                              size: _currentVolume == 'shout'
                                  ? 28
                                  : (_currentVolume == 'whisper' ? 16 : 24),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
             ),
            ),
           ),
            if (_showEmojiPicker)
              Positioned(
                left: 0,
                right: 0,
                bottom: 60,
                child: SizedBox(
                  height: 250,
                  child: EmojiPicker(
                    textEditingController: _textController,
                    onEmojiSelected: (category, emoji) {},
                    config: Config(
                      height: 250,
                      checkPlatformCompatibility: false,
                      emojiViewConfig: EmojiViewConfig(
                        backgroundColor: isDark
                            ? AppColors.backgroundDark
                            : AppColors.backgroundLight,
                      ),
                    ),
                  ),
                ),
              ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
