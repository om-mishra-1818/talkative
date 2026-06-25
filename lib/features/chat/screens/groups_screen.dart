import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import '../providers/chat_provider.dart';
import '../models/chat_model.dart';
import '../../../core/widgets/custom_avatar.dart';

class GroupsScreen extends StatelessWidget {
  const GroupsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return const Center(child: Text('Not logged in'));

    return Column(
      children: [
        AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text(
            'My Groups',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
        ),
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: Supabase.instance.client
                .from('groups')
                .select()
                .contains('members', [user.id]),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Error loading groups: ${snapshot.error}',
                    style: TextStyle(color: Colors.grey.shade500),
                  ),
                );
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return Center(
                  child: Text(
                    'No groups joined yet.',
                    style: TextStyle(color: Colors.grey.shade500),
                  ),
                );
              }

              final docs = snapshot.data!;
              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final group = docs[index];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    leading: CustomAvatar(
                      imageUrl:
                          group['groupImageUrl'] ??
                          'https://ui-avatars.com/api/?name=${group['name'] ?? 'G'}',
                      radius: 24,
                    ),
                    title: Text(
                      group['name'] ?? 'Unnamed Group',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      '${(group['members'] as List).length} members',
                    ),
                    onTap: () {
                      // Navigate to group chat
                    },
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
