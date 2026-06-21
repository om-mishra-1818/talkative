import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../providers/chat_provider.dart';
import '../models/chat_model.dart';
import '../../../core/widgets/custom_avatar.dart';
import '../widgets/dynamic_pulse_ring.dart';
import '../widgets/chat_area.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    return Column(
      children: [
        AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text(
            'Contacts',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: TextField(
            controller: _searchController,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: 'Search username...',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Theme.of(context).cardColor.withOpacity(0.5),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value.trim();
              });
            },
          ),
        ),
        Expanded(
          child: _searchQuery.isEmpty
              ? const Center(
                  child: Text('Search for a username to start chatting.'),
                )
              : StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .where('username', isGreaterThanOrEqualTo: _searchQuery)
                      .where(
                        'username',
                        isLessThanOrEqualTo: '$_searchQuery\uf8ff',
                      )
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'Error loading contacts. Please check Firebase rules.\n${snapshot.error}',
                          textAlign: TextAlign.center,
                        ),
                      );
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Center(child: Text('No users found.'));
                    }

                    final users = snapshot.data!.docs
                        .where((doc) => doc.id != currentUserId)
                        .toList();

                    if (users.isEmpty) {
                      return const Center(child: Text('No users found.'));
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.only(
                        left: 16,
                        right: 16,
                        bottom: 100,
                      ),
                      itemCount: users.length,
                      itemBuilder: (context, index) {
                        final userData =
                            users[index].data() as Map<String, dynamic>;
                        final userId = users[index].id;
                        final customStatus = userData['status'] ?? 'Available';
                        final isOnline = userData['isOnline'] == true;
                        
                        final ringStatus = isOnline ? customStatus : 'Offline';
                        
                        final displayName =
                            userData['username'] ??
                            userData['displayName'] ??
                            'Unknown User';
                        final photoUrl =
                            userData['avatarUrl'] ??
                            userData['photoUrl'] ??
                            'https://ui-avatars.com/api/?name=$displayName';

                        return GestureDetector(
                          onTap: () {
                            final chatProvider = context.read<ChatProvider>();
                            final chat = ChatModel(
                              id: userId, // Placeholder until conversation is created
                              otherUserId: userId,
                              name: displayName,
                              avatarUrl: photoUrl,
                              isOnline: isOnline,
                              status: customStatus,
                            );
                            chatProvider.startChatWith(chat);

                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const Scaffold(
                                  body: SafeArea(child: ChatArea()),
                                ),
                              ),
                            );
                          },
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              color: Theme.of(
                                context,
                              ).cardColor.withOpacity(0.1),
                              border: Border.all(
                                color: Theme.of(
                                  context,
                                ).dividerColor.withOpacity(0.1),
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(
                                  sigmaX: 10,
                                  sigmaY: 10,
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Row(
                                    children: [
                                      DynamicPulseRing(
                                        status: ringStatus,
                                        child: CustomAvatar(
                                          imageUrl: photoUrl,
                                          radius: 24,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              displayName,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              customStatus,
                                              style: TextStyle(
                                                color: Colors.grey.shade500,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Icon(
                                        Icons.chat_bubble_outline,
                                        color: Theme.of(context).primaryColor,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
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
