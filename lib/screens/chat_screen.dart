<<<<<<< HEAD
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/chat_metadata_service.dart';
import '../services/message_service.dart';
import '../services/user_service.dart';
import '../models/user_model.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  final String otherUserId;

  ChatScreen({required this.chatId, required this.otherUserId});
=======
import 'package:flutter/material.dart';
import '../services/chat_service.dart';
import '../models/message_model.dart';
// those 2 imports in lines 2,3 are not added yet
// These will point to your teammates' files later.
// For now they may be red, that's okay until they add them.
import '../services/chat_service.dart';
import '../models/message_model.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  final String currentUserId;
  final String otherUserName;

  const ChatScreen({
    super.key,
    required this.chatId,
    required this.currentUserId,
    required this.otherUserName,
  });
>>>>>>> 65cb4ea0fb7fc6e6439c1de2b240066c67079481

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
<<<<<<< HEAD
  final _messageController = TextEditingController();
  final String currentUid = FirebaseAuth.instance.currentUser!.uid;
  final _scrollController = ScrollController();

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
=======
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // This assumes Role 1 will create a ChatService class.
  final ChatService _chatService = ChatService();

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
>>>>>>> 65cb4ea0fb7fc6e6439c1de2b240066c67079481
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
<<<<<<< HEAD
    _messageController.clear();

    if (text.isEmpty) return;

    await MessageService().sendMessage(
      chatId: widget.chatId,
      senderId: currentUid,
      text: text,
    );

    await ChatMetadataService().updateChatMetadata(
      chatId: widget.chatId,
      lastMessage: text,
      participants: [currentUid, widget.otherUserId],
    );

    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<UserModel?>(
      future: UserService().getUserByUid(widget.otherUserId),
      builder: (context, snap) {
        if (!snap.hasData) {
          return Scaffold(
            appBar: AppBar(title: const Text("Chat")),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        final user = snap.data!;

        return Scaffold(
          appBar: AppBar(title: Text(user.username)),
          body: Column(
            children: [
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: MessageService().messagesStream(widget.chatId),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Center(
                        child: Text(
                          "Say hi 👋",
                          style: TextStyle(fontSize: 16),
                        ),
                      );
                    }

                    final messages = snapshot.data!.docs;

                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _scrollToBottom();
                    });

                    return ListView.builder(
                      controller: _scrollController,
                      itemCount: messages.length,
                      itemBuilder: (_, i) {
                        final data = messages[i].data() as Map<String, dynamic>;
                        final isMe = data['senderId'] == currentUid;

                        return Align(
                          alignment: isMe
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.symmetric(
                                vertical: 4, horizontal: 12),
                            decoration: BoxDecoration(
                              color: isMe
                                  ? Colors.blue.shade300
                                  : Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              data['text'] ?? '',
                              style: TextStyle(
                                color: isMe ? Colors.white : Colors.black,
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),

              // INPUT FIELD
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  border: const Border(top: BorderSide(color: Colors.black12)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        decoration: const InputDecoration(
                          hintText: "Type a message...",
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.send, color: Colors.blue),
                      onPressed: _sendMessage,
                    )
                  ],
                ),
              ),
            ],
          ),
        );
      },
=======
    if (text.isEmpty) return;

    // Call Role 1's function. They will decide the exact signature.
    await _chatService.sendMessage(
      widget.chatId,
      widget.currentUserId,
      text,
      // TODO: add extra parameters here if your team defines any.
    );

    _messageController.clear();
    _scrollToBottom();
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.otherUserName),
      ),
      body: Column(
        children: [
          // ===== MESSAGES LIST =====
          Expanded(
            child: StreamBuilder<List<MessageModel>>(
              // Again, this assumes Role 1 exposes this stream.
              stream: _chatService.messagesStream(widget.chatId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final messages = snapshot.data ?? [];

                if (messages.isEmpty) {
                  return const Center(
                    child: Text('No messages yet. Say hi!'),
                  );
                }

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _scrollToBottom();
                });

                return ListView.builder(
                  controller: _scrollController,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];

                    // These field names will be adjusted when you see MessageModel.
                    final bool isMe =
                        message.senderId == widget.currentUserId;

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

          // ===== INPUT AREA =====
          SafeArea(
            child: Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: const InputDecoration(
                        hintText: 'Type a message...',
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: _sendMessage,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final String text;
  final bool isMe;
  final dynamic timestamp;

  const _MessageBubble({
    required this.text,
    required this.isMe,
    this.timestamp,
  });

  @override
  Widget build(BuildContext context) {
    final String timeString =
    timestamp == null ? '' : timestamp.toString();

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
          crossAxisAlignment:
          isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(text),
            if (timeString.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(
                  timeString,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(fontSize: 10),
                ),
              ),
          ],
        ),
      ),
>>>>>>> 65cb4ea0fb7fc6e6439c1de2b240066c67079481
    );
  }
}
