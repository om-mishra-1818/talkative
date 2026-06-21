import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/chat_provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/theme_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/widgets/custom_avatar.dart';

class Sidebar extends StatelessWidget {
  const Sidebar({super.key});

  @override
  Widget build(BuildContext context) {
    final chatProvider = context.watch<ChatProvider>();
    final authProvider = context.watch<AuthProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          right: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Profile & Actions Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.surfaceDark
                    : AppColors.backgroundLight,
              ),
              child: Row(
                children: [
                  CustomAvatar(
                    radius: 20,
                    imageUrl:
                        'https://ui-avatars.com/api/?name=${authProvider.username ?? "User"}&background=random',
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(
                      themeProvider.isDarkMode
                          ? Icons.light_mode
                          : Icons.dark_mode,
                    ),
                    onPressed: () =>
                        themeProvider.toggleTheme(!themeProvider.isDarkMode),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chat),
                    onPressed: () =>
                        context.read<ChatProvider>().createNewChat(),
                  ),
                  IconButton(
                    icon: const Icon(Icons.more_vert),
                    onPressed: () => context.read<AuthProvider>().logout(),
                  ),
                ],
              ),
            ),

            // Search Bar
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                onChanged: (val) =>
                    context.read<ChatProvider>().setSearchQuery(val),
                decoration: InputDecoration(
                  hintText: 'Search or start new chat',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: isDark ? AppColors.backgroundDark : Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),

            const Divider(height: 1),

            // Chat List / Search Results
            Expanded(
              child:
                  chatProvider.searchQuery.isNotEmpty &&
                      chatProvider.searchResults.isNotEmpty
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16.0,
                            vertical: 8.0,
                          ),
                          child: Text(
                            'Global Results',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                        ),
                        Expanded(
                          child: ListView.builder(
                            itemCount: chatProvider.searchResults.length,
                            itemBuilder: (context, index) {
                              final user = chatProvider.searchResults[index];
                              return ListTile(
                                leading: CustomAvatar(
                                  radius: 24,
                                  imageUrl: user.avatarUrl,
                                ),
                                title: Text(
                                  user.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: const Text('Tap to start chatting'),
                                onTap: () {
                                  context.read<ChatProvider>().startChatWith(
                                    user,
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      itemCount: chatProvider.chats.length,
                      itemBuilder: (context, index) {
                        final chat = chatProvider.chats[index];
                        final isActive = chatProvider.activeChat?.id == chat.id;

                        return ListTile(
                          tileColor: isActive
                              ? (isDark
                                    ? AppColors.dividerDark
                                    : AppColors.dividerLight)
                              : null,
                          leading: Stack(
                            children: [
                              CustomAvatar(
                                radius: 24,
                                imageUrl: chat.avatarUrl,
                              ),
                              if (chat.isOnline)
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: AppColors.online,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.surface,
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          title: Text(
                            chat.name,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: const Text(
                            'Tap to view messages',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: null,
                          onTap: () {
                            context.read<ChatProvider>().setActiveChat(chat);
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
