import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/chat_provider.dart';
import '../widgets/sidebar_rail.dart';
import '../widgets/zen_drawer.dart';
import '../widgets/glass_bottom_nav.dart';
import '../widgets/omni_search_hub.dart';
import '../widgets/chat_card.dart';
import '../widgets/incoming_call_card.dart';
import '../widgets/chat_area.dart';
import 'groups_screen.dart';
import 'contacts_screen.dart';
import 'profile_settings_screen.dart';
import 'package:flutter/services.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  DateTime? _lastPressedAt;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) async {
            if (didPop) return;

            if (_currentIndex != 0) {
              setState(() {
                _currentIndex = 0;
              });
              return;
            }

            final now = DateTime.now();
            if (_lastPressedAt == null ||
                now.difference(_lastPressedAt!) > const Duration(seconds: 2)) {
              _lastPressedAt = now;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Press back again to exit'),
                  duration: Duration(seconds: 2),
                ),
              );
              return;
            }

            await SystemNavigator.pop();
          },
          child: Scaffold(
            drawer: isMobile ? ZenDrawer(
            currentIndex: _currentIndex,
            onIndexChanged: (idx) => setState(() => _currentIndex = idx),
          ) : null,
          body: Row(
            children: [
              if (!isMobile)
                SidebarRail(
                  currentIndex: _currentIndex,
                  onIndexChanged: (idx) => setState(() => _currentIndex = idx),
                ),
              Expanded(
                child: Stack(
                  children: [
                    _buildBody(isMobile),
                    if (isMobile)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: GlassBottomNav(
                          currentIndex: _currentIndex,
                          onIndexChanged: (idx) =>
                              setState(() => _currentIndex = idx),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        );
      },
    );
  }

  Widget _buildBody(bool isMobile) {
    if (_currentIndex == 1) return const GroupsScreen();
    if (_currentIndex == 2) return const ContactsScreen();
    if (_currentIndex == 3) return const ProfileSettingsScreen();

    return Column(
      children: [
        // Top Bar
        AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset('assets/talkative.jpeg', height: 32, width: 32, fit: BoxFit.cover),
              ),
              const SizedBox(width: 12),
              Text(
                'Talkative',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                  letterSpacing: -0.5,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
          leading: isMobile
              ? Builder(
                  builder: (ctx) => IconButton(
                    icon: const Icon(Icons.menu),
                    onPressed: () => Scaffold.of(ctx).openDrawer(),
                  ),
                )
              : null,
          actions: [
            IconButton(
              icon: const Icon(Icons.notifications_outlined),
              onPressed: () {},
            ),
          ],
        ),
        // Omni Search Hub
        const OmniSearchHub(),
        const SizedBox(height: 16),

        // Homepage Body (Feed)
        Expanded(
          child: Consumer<ChatProvider>(
            builder: (context, chatProvider, child) {
              final chats = chatProvider.chats;
              if (chats.isEmpty) {
                return Center(
                  child: Text(
                    'No conversations found.',
                    style: TextStyle(color: Colors.grey.shade500),
                  ),
                );
              }

              return ListView.builder(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  bottom: isMobile ? 100 : 16,
                ),
                itemCount: chats.length,
                itemBuilder: (context, index) {
                  final chat = chats[index];

                  // Formatting time
                  String timeStr = '';
                  if (chat.time != null) {
                    final now = DateTime.now();
                    final diff = now.difference(chat.time!);
                    if (diff.inMinutes < 1) {
                      timeStr = 'Just now';
                    } else if (diff.inHours < 24) {
                      final h = chat.time!.hour;
                      final m = chat.time!.minute.toString().padLeft(2, '0');
                      timeStr =
                          '${h > 12 ? h - 12 : (h == 0 ? 12 : h)}:$m ${h >= 12 ? 'PM' : 'AM'}';
                    } else {
                      timeStr = '${diff.inDays}d ago';
                    }
                  }

                  if (chat.hasActiveCall) {
                    return IncomingCallCard(
                      name: chat.name,
                      avatarUrl: chat.avatarUrl,
                      onAccept: () => chatProvider.answerCall(chat),
                      onDecline: () => chatProvider.declineCall(chat),
                    );
                  }

                  return GestureDetector(
                    onTap: () {
                      chatProvider.startChatWith(chat);
                      if (isMobile) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const Scaffold(
                              body: SafeArea(child: ChatArea()),
                            ),
                          ),
                        );
                      }
                    },
                    child: ChatCard(
                      name: chat.name,
                      avatarUrl: chat.avatarUrl,
                      lastMessage: chat.lastMessage,
                      mediaType: chat.mediaType,
                      time: timeStr,
                      unreadCount: chat.unreadCount,
                      isOnline: chat.isOnline,
                      status: chat.status,
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
