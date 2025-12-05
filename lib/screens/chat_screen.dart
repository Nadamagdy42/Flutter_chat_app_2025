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

        // Build scaffold with gradient background and messages list
        final scaffold = Scaffold(
          appBar: AppBar(
            toolbarHeight: 72,
            title: Row(
              children: [
                const CircleAvatar(radius: 18, backgroundColor: Colors.white24, child: Icon(Icons.person, size: 20, color: Colors.white)),
                const SizedBox(width: 10),
                Expanded(child: Text(otherUserName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600))),
              ],
            ),
            backgroundColor: Colors.transparent,
            elevation: 0,
            flexibleSpace: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [Color(0xFF6A11CB), Color(0xFF2575FC)], begin: Alignment.topLeft, end: Alignment.bottomRight),
              ),
            ),
          ),
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [Color(0xFFF6F8FB), Color.fromARGB(255, 128, 128, 128)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
            ),
            child: Column(
              children: [
                Expanded(
                  child: StreamBuilder<List<MessageModel>>(
                    stream: chatService.messagesStream(widget.chatId),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (snapshot.hasData) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          chatService.markMessagesRead(chatId: widget.chatId, userId: currentUid);
                        });
                      }

                      final messages = (snapshot.data ?? []).reversed.toList();

                      if (messages.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.waving_hand, size: 50, color: Colors.deepPurple.withOpacity(0.5)),
                              const SizedBox(height: 10),
                              Text('No messages yet.\nSay hi to $otherUserName!', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600])),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        reverse: true,
                        itemCount: messages.length,
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                        itemBuilder: (context, index) {
                          final message = messages[index];
                          final isMe = message.senderId == currentUid;
                          return _MessageBubble(text: message.text, isMe: isMe, timestamp: message.timestamp, read: message.read);
                        },
                      );
                    },
                  ),
                ),

                // Composer
                Container(
                  padding: const EdgeInsets.all(12),
                  color: Colors.transparent,
                  child: SafeArea(
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0,3))]),
                            child: Row(children: [Expanded(child: TextField(controller: messageController, decoration: const InputDecoration(hintText: 'Type a message...', border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 12)), onSubmitted: (_) => sendMessage()),),]),
                          ),
                        ),
                        const SizedBox(width: 8),
                        CircleAvatar(radius: 24, backgroundColor: Colors.deepPurple, child: IconButton(icon: const Icon(Icons.send, color: Colors.white, size: 20), onPressed: sendMessage)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );

        return scaffold;
      },
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final String text;
  final bool isMe;
  final DateTime timestamp;
  final bool read;

  const _MessageBubble({required this.text, required this.isMe, required this.timestamp, this.read = false});

  @override
  Widget build(BuildContext context) {
    final timeString = '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        decoration: BoxDecoration(
          gradient: isMe
              ? const LinearGradient(colors: [Color(0xFF6A11CB), Color(0xFF2575FC)])
              : null,
          color: isMe ? null : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: isMe ? const Radius.circular(16) : const Radius.circular(6),
            bottomRight: isMe ? const Radius.circular(6) : const Radius.circular(16),
          ),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))],
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
            const SizedBox(height: 6),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  timeString,
                  style: TextStyle(
                    color: isMe ? Colors.white70 : Colors.grey[500],
                    fontSize: 11,
                  ),
                ),
                const SizedBox(width: 6),
                if (isMe)
                  Icon(
                    read ? Icons.done_all : Icons.check,
                    size: 16,
                    color: read ? Colors.lightBlueAccent : Colors.white70,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
