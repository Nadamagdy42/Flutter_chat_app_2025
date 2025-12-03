import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Ensure these imports are correct for your project
import '../services/chat_service.dart';
import '../services/user_service.dart';
import '../services/chat_metadata_service.dart'; 
import '../models/message_model.dart';
import '../models/user_model.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  final String otherUserId;

  const ChatScreen({super.key, required this.chatId, required this.otherUserId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController messageController = TextEditingController();
  final ChatService chatService = ChatService();

  String get currentUid => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void dispose() {
    messageController.dispose();
    super.dispose();
  }

  Future<void> sendMessage() async {
    final text = messageController.text.trim();
    if (text.isEmpty) return;

    messageController.clear(); 

    // 1. Send the message
    await chatService.sendMessage(chatId: widget.chatId, senderId: currentUid, text: text);

    // 2. Update the Chat List "Last Message"
    await ChatMetadataService().updateChatMetadata(
      chatId: widget.chatId,
      lastMessage: text,
      participants: [currentUid, widget.otherUserId],
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<UserModel?>(
      future: UserService().getUserByUid(widget.otherUserId),
      builder: (context, snap) {
        final otherUserName = snap.data?.username ?? 'Chat';

        return Scaffold(
          appBar: AppBar(
            title: Row(
              children: [
                const CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.white24,
                  child: Icon(Icons.person, size: 20, color: Colors.white),
                ),
                const SizedBox(width: 10),
                Text(otherUserName, style: const TextStyle(fontSize: 18)),
              ],
            ),
            backgroundColor: Colors.deepPurple,
            foregroundColor: Colors.white,
          ),
          
          backgroundColor: Colors.grey[100], 

          body: Column(
            children: [
              Expanded(
                child: StreamBuilder<List<MessageModel>>(
                  stream: chatService.messagesStream(widget.chatId),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    // --- FIX IS HERE ---
                    // We reverse the list so Newest is at Index 0
                    // This makes it work perfectly with reverse: true
                    final messages = (snapshot.data ?? []).reversed.toList();

                    if (messages.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.waving_hand, size: 50, color: Colors.deepPurple.withOpacity(0.5)),
                            const SizedBox(height: 10),
                            Text(
                              'No messages yet.\nSay hi to $otherUserName!',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      reverse: true, // Keeps keyboard behavior smooth
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final message = messages[index];
                        final isMe = message.senderId == currentUid;
                        return _MessageBubble(
                          text: message.text,
                          isMe: isMe,
                          timestamp: message.timestamp,
                        );
                      },
                    );
                  },
                ),
              ),

              // INPUT AREA
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 10.0),
                color: Colors.white,
                child: SafeArea(
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: TextField(
                            controller: messageController,
                            decoration: const InputDecoration(
                              hintText: 'Type a message...',
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                            onSubmitted: (_) => sendMessage(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      CircleAvatar(
                        backgroundColor: Colors.deepPurple,
                        radius: 24,
                        child: IconButton(
                          icon: const Icon(Icons.send, color: Colors.white, size: 20),
                          onPressed: sendMessage,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final String text;
  final bool isMe;
  final DateTime timestamp;

  const _MessageBubble({required this.text, required this.isMe, required this.timestamp});

  @override
  Widget build(BuildContext context) {
    final timeString = '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isMe ? Colors.deepPurple : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: isMe ? const Radius.circular(16) : Radius.zero,
            bottomRight: isMe ? Radius.zero : const Radius.circular(16),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 2,
              offset: const Offset(0, 1),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              text,
              style: TextStyle(
                color: isMe ? Colors.white : Colors.black87,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              timeString,
              style: TextStyle(
                color: isMe ? Colors.white70 : Colors.grey[500],
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
