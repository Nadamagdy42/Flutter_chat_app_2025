import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

// Ensure these imports match your actual file names
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
  // Get current user ID safely
  final String uid = FirebaseAuth.instance.currentUser?.uid ?? '';

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
    if (receiverId == uid) return; 

    // --- FIX: Check GLOBAL 'chats' collection ---
    // We check if there are any chats where I am a participant
    final existing = await FirebaseFirestore.instance
        .collection('chats') 
        .where('participants', arrayContains: uid)
        .get();

    String? existingChatId;
    
    // Filter locally to find the chat that ALSO contains the receiver
    for (var doc in existing.docs) {
      List<dynamic> participants = doc['participants'];
      if (participants.contains(receiverId)) {
        existingChatId = doc.id;
        break;
      }
    }

    String chatId;
    if (existingChatId != null) {
      // Found it! Re-use this ID.
      chatId = existingChatId;
    } else {
      // Not found, create a new one.
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
              // AuthGate in main.dart will handle the navigation automatically
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
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

          // Main Content
          Expanded(
            child: _searchStream == null
                ? _buildRecentChats() // Show My Chats
                : _buildSearchResults(), // Show Search Results
          ),
        ],
      ),
    );
  }

  // --- 1. SEARCH RESULTS UI ---
  Widget _buildSearchResults() {
    return StreamBuilder<QuerySnapshot>(
      stream: _searchStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) return const Center(child: Text("Search Error"));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

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
              leading: const CircleAvatar(child: Icon(Icons.person)),
              title: Text(data['username'] ?? 'No Name'),
              subtitle: Text(data['email'] ?? ''),
              onTap: () => _confirmChat(users[i].id, data['username']),
            );
          },
        );
      },
    );
  }

  // --- 2. RECENT CHATS UI ---
  Widget _buildRecentChats() {
    if (uid.isEmpty) return const Center(child: Text("Error: User not found"));

    return StreamBuilder<QuerySnapshot>(
      stream: ChatMetadataService().chatsStream(uid),
      builder: (context, snapshot) {
        
        if (snapshot.hasError) {
          return Center(
            child: Text("Error loading chats:\n${snapshot.error}", 
              style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.chat_bubble_outline, size: 60, color: Colors.grey),
                SizedBox(height: 10),
                Text("No chats yet. Search for a user!"),
              ],
            ),
          );
        }

        final docs = snapshot.data!.docs;

        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final data = docs[i].data() as Map<String, dynamic>;
            final chatId = docs[i].id;
            
            // Safety check
            if (!data.containsKey('participants')) return const SizedBox();

            final chatModel = ChatModel.fromMap(data, id: chatId);

            final otherUserId = chatModel.participants.firstWhere(
              (id) => id != uid, 
              orElse: () => 'Unknown',
            );

            return FutureBuilder<UserModel?>(
              future: UserService().getUserByUid(otherUserId),
              builder: (context, userSnap) {
                String displayName = "Loading...";
                if (userSnap.hasData && userSnap.data != null) {
                  displayName = userSnap.data!.username;
                }

                return ListTile(
                  // 1. BETTER AVATAR: Shows the first letter of their name with a color
                  leading: CircleAvatar(
                    backgroundColor: Colors.deepPurple.shade100,
                    child: Text(
                      displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                      style: const TextStyle(color: Colors.deepPurple, fontWeight: FontWeight.bold),
                    ),
                  ),
                  
                  // 2. BOLD TITLE: Makes the name pop
                  title: Text(
                    displayName,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  
                  // 3. CLEAN SUBTITLE: Shows last message or "Say hello" placeholder
                  subtitle: Text(
                    chatModel.lastMessage.isEmpty ? "Say hello 👋" : chatModel.lastMessage,
                    maxLines: 1, 
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: chatModel.lastMessage.isEmpty ? Colors.blue : Colors.grey[600],
                      fontStyle: chatModel.lastMessage.isEmpty ? FontStyle.italic : FontStyle.normal,
                    ),
                  ),
                  
                  // 4. TIMESTAMP: Shows the date on the right side
                  trailing: Text(
                    _formatDate(data['lastUpdatedAt']), 
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  
                  onTap: () => _startChat(otherUserId),
                );
              },
            );
          },
        );
      },
    );
  }

  /// Helper to format Firestore timestamps into readable time
  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return "";
    if (timestamp is Timestamp) {
      DateTime date = timestamp.toDate();
      DateTime now = DateTime.now();
      
      // If it's today, show time (e.g., "10:30 AM")
      if (now.year == date.year && now.month == date.month && now.day == date.day) {
        String period = date.hour >= 12 ? "PM" : "AM";
        int hour = date.hour > 12 ? date.hour - 12 : date.hour;
        if (hour == 0) hour = 12;
        return "$hour:${date.minute.toString().padLeft(2, '0')} $period";
      }
      
      // If it's older, show the date (e.g., "12/05")
      return "${date.day}/${date.month}";
    }
    return "";
  }
}
/*
  Chat List Screen – Firebase Firestore Chat App

  🔹 Purpose:
     - Display all existing chats for the currently logged-in user.
     - Provide a search bar to find other registered users and start new chats.

  🔹 How Chats Work:
     - A chat document is created in Firestore under `chats/` when two users start a conversation.
     - Each chat contains:
          • participants → [uid1, uid2]
          • lastMessage → preview text in list
          • updatedAt → sorted by latest chat activity

  🔹 Real-Time Updates:
     - We listen to chats where arrayContains = current user ID
     - Any new message updates "lastMessage" and "updatedAt"
     - Chat list refreshes automatically without manual reload

  🔹 Search System:
     - Searches inside `users/` collection
     - Prevents chatting with yourself
     - If a chat already exists → open it
     - If no chat exists → create a new chat in Firestore

  🔹 Navigation:
     - Tapping a chat item opens ChatScreen with:
          • chatId
          • target user info

  Summary:
  This file manages the UI and logic for recent chats and starting new conversations.
*/
