import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../core/widgets/custom_avatar.dart';
import 'dynamic_pulse_ring.dart';
import '../models/media_type.dart';

class ChatCard extends StatelessWidget {
  final String name;
  final String avatarUrl;
  final String lastMessage;
  final MediaType mediaType;
  final String time;
  final int unreadCount;
  final bool isOnline;
  final String status;

  const ChatCard({
    super.key,
    required this.name,
    required this.avatarUrl,
    required this.lastMessage,
    this.mediaType = MediaType.text,
    required this.time,
    this.unreadCount = 0,
    this.isOnline = false,
    this.status = 'Offline',
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.white.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.black.withValues(alpha: 0.05),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Stack(
                  children: [
                    DynamicPulseRing(
                      status: isOnline ? status : 'Offline',
                      child: CustomAvatar(imageUrl: avatarUrl, radius: 24),
                    ),
                    if (isOnline)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: Colors.greenAccent,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isDark ? Colors.black : Colors.white,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      _buildMediaSnippet(context),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      time,
                      style: TextStyle(
                        fontSize: 12,
                        color: unreadCount > 0 ? primaryColor : Colors.grey,
                        fontWeight: unreadCount > 0
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (unreadCount > 0)
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: primaryColor,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: primaryColor.withValues(alpha: 0.4),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Text(
                          unreadCount.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMediaSnippet(BuildContext context) {
    if (mediaType == MediaType.audio) {
      return Row(
        children: [
          Icon(Icons.mic, size: 14, color: Theme.of(context).primaryColor),
          const SizedBox(width: 4),
          Expanded(
            child: Row(
              children: List.generate(
                15,
                (index) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 1),
                  width: 3,
                  height: (index % 3 == 0) ? 12 : ((index % 2 == 0) ? 8 : 4),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).primaryColor.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    } else if (mediaType == MediaType.video) {
      return Row(
        children: [
          const Icon(Icons.videocam, size: 14, color: Colors.blueAccent),
          const SizedBox(width: 4),
          Text(
            'Video message',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      );
    }
    return Text(
      lastMessage,
      style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
