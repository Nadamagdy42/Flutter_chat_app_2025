import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
//This file is responsible for displaying the user's recent chats and providing a search bar
// to find other users registered in the system. It plays a critical role in the chat application
// because it acts as the central hub where the user begins every conversation. The ChatListScreen
// is stateful because it manages the search text and dynamically switches between search mode
// and recent chats mode.
// Ensure these imports match your actual file names
import '../services/chat_metadata_service.dart';
import '../services/user_service.dart';
import '../services/chat_service.dart';
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
  final FocusNode _searchFocus = FocusNode();
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
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 96,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text('Chats', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            SizedBox(height: 4),
            Text('Your conversations', style: TextStyle(fontSize: 12, color: Colors.white70)),
          ],
        ),
        leadingWidth: 72,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12, top: 12, bottom: 12),
          child: GestureDetector(
            onTap: () async {
              // placeholder for profile/settings
              await showDialog(context: context, builder: (_) => AlertDialog(title: const Text('Profile'), content: const Text('Profile screen placeholder'), actions: [TextButton(onPressed: Navigator.of(context).pop, child: const Text('Close'))]));
            },
            child: CircleAvatar(
              radius: 20,
              backgroundColor: Colors.white24,
              child: const Icon(Icons.person, color: Colors.white),
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            },
          ),
          const SizedBox(width: 6),
        ],
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [Color(0xFF6A11CB), Color(0xFF2575FC)], begin: Alignment.topLeft, end: Alignment.bottomRight),
          ),
        ),
      ),
      // No floating action button — search is available via the search field.
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: TextField(
              focusNode: _searchFocus,
              controller: _searchController,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: "Search username...",
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(icon: const Icon(Icons.clear), onPressed: () { _searchController.clear(); _searchUsers(''); })
                    : null,
              ),
              onChanged: (v) {
                _searchUsers(v);
                setState(() {});
              },
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
  // The search results builder and recent chats builder both use StreamBuilder or FutureBuilder, ensuring the

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
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0,4))]),
                  child: Column(
                    children: const [
                      Icon(Icons.chat_bubble_outline, size: 60, color: Colors.deepPurple),
                      SizedBox(height: 8),
                      Text("No chats yet.", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(onPressed: () => _searchFocus.requestFocus(), icon: const Icon(Icons.search), label: const Text('Find someone to chat')),              
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

                // Use a stream for unread counts and render a richer row
                return StreamBuilder<int>(
                  stream: ChatService().unreadCountStream(chatId, uid),
                  builder: (context, unreadSnap) {
                    final unread = unreadSnap.data ?? 0;

                    return InkWell(
                      onTap: () => _startChat(otherUserId),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0,2))],
                        ),
                        child: Row(
                          children: [
                            // Avatar
                            CircleAvatar(
                              radius: 26,
                              backgroundColor: Colors.deepPurple.shade50,
                              child: Text(
                                displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                                style: const TextStyle(color: Colors.deepPurple, fontWeight: FontWeight.bold, fontSize: 18),
                              ),
                            ),
                            const SizedBox(width: 12),

                            // Name + last message
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(displayName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                                  const SizedBox(height: 4),
                                  Text(
                                    chatModel.lastMessage.isEmpty ? 'Say hello 👋' : chatModel.lastMessage,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(color: chatModel.lastMessage.isEmpty ? Colors.blue : Colors.grey[600], fontSize: 14, fontStyle: chatModel.lastMessage.isEmpty ? FontStyle.italic : FontStyle.normal),
                                  ),
                                ],
                              ),
                            ),

                            // Time + unread badge
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(_formatDate(data['lastUpdatedAt']), style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                const SizedBox(height: 8),
                                if (unread > 0)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.deepPurple,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Text(
                                      unread > 99 ? '99+' : unread.toString(),
                                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
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
