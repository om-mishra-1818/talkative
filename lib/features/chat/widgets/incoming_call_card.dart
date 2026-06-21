import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../core/widgets/custom_avatar.dart';
import 'dynamic_pulse_ring.dart';

class IncomingCallCard extends StatelessWidget {
  final String name;
  final String avatarUrl;
  final VoidCallback? onAccept;
  final VoidCallback? onDecline;

  const IncomingCallCard({
    super.key,
    required this.name,
    required this.avatarUrl,
    this.onAccept,
    this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.blueAccent.withValues(alpha: isDark ? 0.2 : 0.1),
            Colors.purpleAccent.withValues(alpha: isDark ? 0.2 : 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.blueAccent.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              children: [
                DynamicPulseRing(
                  status: 'Available',
                  child: CustomAvatar(imageUrl: avatarUrl, radius: 28),
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
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.phone_in_talk,
                            size: 14,
                            color: Colors.blueAccent,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Incoming active call...',
                              style: TextStyle(
                                color: Colors.blueAccent.shade100,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    _buildActionButton(
                      Icons.close,
                      Colors.redAccent,
                      onDecline,
                    ),
                    const SizedBox(width: 12),
                    _buildActionButton(
                      Icons.call,
                      Colors.greenAccent,
                      onAccept,
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

  Widget _buildActionButton(IconData icon, Color color, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.2),
          shape: BoxShape.circle,
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        padding: const EdgeInsets.all(12),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }
}
