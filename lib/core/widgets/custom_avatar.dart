import 'package:flutter/material.dart';
import 'dart:convert';

class CustomAvatar extends StatelessWidget {
  final String imageUrl;
  final double radius;

  const CustomAvatar({super.key, required this.imageUrl, this.radius = 20.0});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Theme.of(context).primaryColor.withValues(alpha: 0.2),
      ),
      child: ClipOval(
        child: imageUrl.startsWith('base64:')
            ? Image.memory(
                base64Decode(imageUrl.substring(7)),
                key: ValueKey(imageUrl),
                width: radius * 2,
                height: radius * 2,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Icon(
                    Icons.person,
                    size: radius * 1.2,
                    color: Theme.of(context).primaryColor,
                  );
                },
              )
            : Image.network(
                imageUrl,
                key: ValueKey(imageUrl),
                width: radius * 2,
                height: radius * 2,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Icon(
                    Icons.person,
                    size: radius * 1.2,
                    color: Theme.of(context).primaryColor,
                  );
                },
              ),
      ),
    );
  }
}
