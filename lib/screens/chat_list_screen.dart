import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/chat_metadata_service.dart';
import '../services/user_service.dart';
import '../models/chat_model.dart';
import '../models/user_model.dart';
import 'chat_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final _searchController = TextEditingController();
  final String uid = FirebaseAuth.instance.currentUser!.uid;

  Stream<QuerySnapshot<Map<String, dynamic>>>? _searchStream;

  void _searchUsers(String query) {
    if (query.trim().isEmpty) {
      setState(() => _searchStream = null);
      return;
    }

    setState(() {
      _searchStream = FirebaseFirestore.instance
          .collection('users')
          .orderBy('username')
          .startAt([query.toLowerCase()])
          .endAt(['${query.toLowerCase()}\uf8ff'])
          .snapshots();
    });
  }

  Future<void> _startChat(String receiverId) async {
    if (receiverId == uid) return; // Prevent chatting with yourself

    final existing = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('chats')
        .where('participants', arrayContains: receiverId)
        .limit(1)
        .get();

    String chatId;

    if (existing.docs.isNotEmpty) {
      chatId = existing.docs.first.id;
    } else {
      chatId = await ChatMetadataService().createChat(uid, receiverId);
    }

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          chatId: chatId,
          otherUserId: receiverId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Chats"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (!mounted) return;
              Navigator.pushNamedAndRemoveUntil(context, '/', (_) => false);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: "Search username...",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: _searchUsers,
            ),
          ),

          Expanded(
            child: _searchStream == null
                ? _buildRecentChats()
                : _buildSearchResults(),
          ),
        ],
      ),
    );
  }

  /// SEARCH RESULTS
  Widget _buildSearchResults() {
    return StreamBuilder<QuerySnapshot>(
      stream: _searchStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final users = snapshot.data!.docs
            .where((doc) => doc.id != uid)
            .toList();

        if (users.isEmpty) {
          return const Center(child: Text("No users found"));
        }

        return ListView.builder(
          itemCount: users.length,
          itemBuilder: (_, i) {
            final data = users[i].data() as Map<String, dynamic>;
            return ListTile(
              title: Text(data['username']),
              subtitle: Text(data['email'] ?? ''),
              onTap: () => _confirmChat(users[i].id, data['username']),
            );
          },
        );
      },
    );
  }

  void _confirmChat(String id, String username) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Start Chat"),
        content: Text("Chat with $username?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _startChat(id);
            },
            child: const Text("Start"),
          ),
        ],
      ),
    );
  }

  /// RECENT CHATS UI
  Widget _buildRecentChats() {
    return StreamBuilder<QuerySnapshot>(
      stream: ChatMetadataService().chatsStream(uid),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.data!.docs.isEmpty) {
          return const Center(child: Text("You have no recent chats"));
        }

        final docs = snapshot.data!.docs;

        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final chatId = docs[i].id;
            final chatModel =
                ChatModel.fromMap(docs[i].data() as Map<String, dynamic>,
                    id: chatId);

            final otherUserId =
                chatModel.participants.firstWhere((id) => id != uid);

            return FutureBuilder<UserModel?>(
              future: UserService().getUserByUid(otherUserId),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const ListTile(title: Text("Loading user..."));
                }

                final user = snap.data!;
                return ListTile(
                  title: Text(user.username),
                  subtitle: Text(
                      chatModel.lastMessage.isEmpty
                          ? "Say hello 👋"
                          : chatModel.lastMessage),
                  onTap: () => _startChat(otherUserId),
                );
              },
            );
          },
        );
      },
    );
  }
}
