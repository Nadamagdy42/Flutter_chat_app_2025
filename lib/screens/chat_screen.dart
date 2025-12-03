import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/chat_service.dart';
import '../services/user_service.dart';
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
  final ScrollController scrollController = ScrollController();
  final ChatService chatService = ChatService();

  String get currentUid => FirebaseAuth.instance.currentUser!.uid;

  @override
  void dispose() {
    messageController.dispose();
    scrollController.dispose();
    super.dispose();
  }

  Future<void> sendMessage() async {
    final text = messageController.text.trim();
    if (text.isEmpty) return;

    await chatService.sendMessage(chatId: widget.chatId, senderId: currentUid, text: text);
    messageController.clear();
    scrollToBottom();
  }

  void scrollToBottom() {
    if (!scrollController.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      scrollController.animateTo(
        scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<UserModel?>(
      future: UserService().getUserByUid(widget.otherUserId),
      builder: (context, snap) {
        final otherUserName = snap.data?.username ?? 'Chat';

        return Scaffold(
          appBar: AppBar(title: Text(otherUserName)),
          body: Column(
            children: [
              Expanded(
                child: StreamBuilder<List<MessageModel>>(
                  stream: chatService.messagesStream(widget.chatId),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final messages = snapshot.data ?? [];

                    if (messages.isEmpty) {
                      return const Center(child: Text('No messages yet. Say hi!'));
                    }

                    WidgetsBinding.instance.addPostFrameCallback((_) => scrollToBottom());

                    return ListView.builder(
                      controller: scrollController,
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

              SafeArea(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: messageController,
                          decoration: const InputDecoration(hintText: 'Type a message...'),
                          onSubmitted: (_) => sendMessage(),
                        ),
                      ),
                      IconButton(icon: const Icon(Icons.send), onPressed: sendMessage),
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
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isMe ? Colors.blue[200] : Colors.grey[300],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(text),
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text(
                timeString,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 10),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
