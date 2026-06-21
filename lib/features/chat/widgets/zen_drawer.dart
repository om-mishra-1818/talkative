import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../core/widgets/custom_avatar.dart';
import 'dynamic_pulse_ring.dart';
import '../../../core/providers/theme_provider.dart';
import 'package:provider/provider.dart';
import '../../../core/di/locator.dart';
import '../providers/user_profile_provider.dart';

class ZenDrawer extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onIndexChanged;

  const ZenDrawer({
    super.key,
    required this.currentIndex,
    required this.onIndexChanged,
  });

  @override
  State<ZenDrawer> createState() => _ZenDrawerState();
}

class _ZenDrawerState extends State<ZenDrawer> {
  bool _showTyping = true;
  bool _hidePresence = false;

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final profileProvider = locator<UserProfileProvider>();
    final isDark = themeProvider.isDarkMode;

    return Drawer(
      backgroundColor: Colors.transparent,
      child: ListenableBuilder(
        listenable: profileProvider,
        builder: (context, _) {
          final profile = profileProvider.profile;
          return ClipRRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.7)
                    : Colors.white.withValues(alpha: 0.8),
                child: SafeArea(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Profile Hub
                      Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            DynamicPulseRing(
                              status: profile?.isOnlineVisible == false ? 'Offline' : (profile?.status ?? 'Available'),
                              child: CustomAvatar(
                                imageUrl: profileProvider.localPhotoBase64 != null
                                    ? 'base64:${profileProvider.localPhotoBase64}'
                                    : profile?.avatarUrl ?? 'https://ui-avatars.com/api/?name=User&background=random',
                                radius: 32,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              profile?.username ?? 'John Doe',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).primaryColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Theme.of(
                                    context,
                                  ).primaryColor.withValues(alpha: 0.5),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.circle,
                                    color: Theme.of(context).primaryColor,
                                    size: 10,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    profile?.isOnlineVisible == false ? 'Invisible' : (profile?.status ?? 'Available'),
                                    style: TextStyle(
                                      color: Theme.of(context).primaryColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    Icons.arrow_drop_down,
                                    color: Theme.of(context).primaryColor,
                                    size: 16,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),

                      Expanded(
                        child: ListView(
                          padding: EdgeInsets.zero,
                          children: [
                            const Padding(
                              padding: EdgeInsets.all(16.0),
                              child: Text(
                                'NAVIGATION',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                            _buildDrawerItem(
                              Icons.chat_bubble,
                              'Chats',
                              widget.currentIndex == 0,
                              context,
                              0,
                            ),
                            _buildDrawerItem(
                              Icons.group, 
                              'Groups', 
                              widget.currentIndex == 1, 
                              context,
                              1,
                            ),
                            _buildDrawerItem(
                              Icons.contacts,
                              'Contacts',
                              widget.currentIndex == 2,
                              context,
                              2,
                            ),
                            _buildDrawerItem(
                              Icons.person,
                              'Profile',
                              widget.currentIndex == 3,
                              context,
                              3,
                            ),

                            const Padding(
                              padding: EdgeInsets.all(16.0),
                              child: Text(
                                'GRANULAR VISIBILITY',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                            SwitchListTile(
                              title: const Text(
                                'Show Typing Indicators',
                                style: TextStyle(fontSize: 14),
                              ),
                              subtitle: const Text(
                                'Let others see when you type',
                                style: TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                              value: profile?.typingIndicators ?? true,
                              activeColor: Theme.of(context).primaryColor,
                              onChanged: (val) {
                                if (profile != null) {
                                  profileProvider.updateProfile(profile.copyWith(typingIndicators: val));
                                }
                              },
                            ),
                            SwitchListTile(
                              title: const Text(
                                'Hide Presence Status',
                                style: TextStyle(fontSize: 14),
                              ),
                              subtitle: const Text(
                                'Appear offline to all contacts',
                                style: TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                              value: !(profile?.isOnlineVisible ?? true),
                              activeColor: Theme.of(context).primaryColor,
                              onChanged: (val) {
                                if (profile != null) {
                                  profileProvider.updateProfile(profile.copyWith(isOnlineVisible: !val));
                                }
                              },
                            ),
                          ],
                        ),
                      ),

                      const Divider(height: 1),
                      // Footer
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            IconButton(
                              icon: Icon(
                                isDark ? Icons.light_mode : Icons.dark_mode,
                              ),
                              onPressed: () => themeProvider.toggleTheme(!isDark),
                            ),
                            IconButton(
                              icon: const Icon(Icons.settings),
                              onPressed: () {},
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }
      ),
    );
  }

  Widget _buildDrawerItem(
    IconData icon,
    String title,
    bool isSelected,
    BuildContext context,
    int index,
  ) {
    final primaryColor = Theme.of(context).primaryColor;
    return ListTile(
      leading: Icon(icon, color: isSelected ? primaryColor : Colors.grey),
      title: Text(
        title,
        style: TextStyle(
          color: isSelected ? primaryColor : null,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      tileColor: isSelected ? primaryColor.withValues(alpha: 0.1) : null,
      contentPadding: const EdgeInsets.symmetric(horizontal: 32),
      onTap: () {
        widget.onIndexChanged(index);
        Navigator.pop(context); // Close the drawer
      },
    );
  }
}
