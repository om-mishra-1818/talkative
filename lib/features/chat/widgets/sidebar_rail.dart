import 'package:flutter/material.dart';
import '../../../core/widgets/custom_avatar.dart';
import 'dynamic_pulse_ring.dart';
import '../../../core/providers/theme_provider.dart';
import 'package:provider/provider.dart';
import '../../../core/di/locator.dart';
import '../providers/user_profile_provider.dart';

class SidebarRail extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onIndexChanged;

  const SidebarRail({
    super.key,
    required this.currentIndex,
    required this.onIndexChanged,
  });

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;

    return Container(
      width: 80,
      decoration: BoxDecoration(
        color: isDark
            ? Colors.black.withValues(alpha: 0.2)
            : Colors.white.withValues(alpha: 0.5),
        border: Border(
          right: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.black.withValues(alpha: 0.05),
          ),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 24),
            // Profile Hub
            ListenableBuilder(
              listenable: locator<UserProfileProvider>(),
              builder: (context, _) {
                final profile = locator<UserProfileProvider>().profile;
                if (profile == null) {
                  return const CircularProgressIndicator();
                }
                return DynamicPulseRing(
                  status: profile.status,
                  child: CustomAvatar(
                    imageUrl: locator<UserProfileProvider>().localPhotoBase64 != null
                        ? 'base64:${locator<UserProfileProvider>().localPhotoBase64}'
                        : profile.avatarUrl.isNotEmpty
                            ? profile.avatarUrl
                            : 'https://ui-avatars.com/api/?name=${profile.username}',
                    radius: 24,
                  ),
                );
              },
            ),
            const SizedBox(height: 32),
            // Action Button
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(
                      context,
                    ).primaryColor.withValues(alpha: 0.4),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              padding: const EdgeInsets.all(12),
              child: const Icon(Icons.add, color: Colors.white),
            ),
            const SizedBox(height: 32),
            // Core Navigation Nodes
            Expanded(
              child: Column(
                children: [
                  _buildNavNode(
                    context,
                    Icons.chat_bubble_outline,
                    Icons.chat_bubble,
                    0,
                  ),
                  const SizedBox(height: 16),
                  _buildNavNode(context, Icons.group_outlined, Icons.group, 1),
                  const SizedBox(height: 16),
                  _buildNavNode(
                    context,
                    Icons.contacts_outlined,
                    Icons.contacts,
                    2,
                  ),
                  const SizedBox(height: 16),
                  _buildNavNode(context, Icons.person_outline, Icons.person, 3),
                ],
              ),
            ),
            // Footer Section
            IconButton(
              icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
              onPressed: () => themeProvider.toggleTheme(!isDark),
            ),
            const SizedBox(height: 16),
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              onPressed: () {},
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildNavNode(
    BuildContext context,
    IconData icon,
    IconData activeIcon,
    int index,
  ) {
    final isSelected = currentIndex == index;
    final primaryColor = Theme.of(context).primaryColor;
    return GestureDetector(
      onTap: () => onIndexChanged(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? primaryColor.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(
          isSelected ? activeIcon : icon,
          color: isSelected ? primaryColor : Colors.grey,
        ),
      ),
    );
  }
}
