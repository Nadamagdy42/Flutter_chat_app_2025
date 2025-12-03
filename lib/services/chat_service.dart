class ChatService {
  Stream<List<dynamic>> messagesStream(String chatId) {
    // Temporary empty stream — your teammates will replace it
    return const Stream.empty();
  }

  Future<void> sendMessage(String chatId, String userId, String text) async {
    // Temporary placeholder — Role 1 will replace this
    return;
  }
}
<<<<<<< HEAD

/*
UI integration notes:

- To display messages in a chat screen, use `messagesStream(chatId)` with a
  `StreamBuilder<List<MessageModel>>`. The snapshot data will be an ordered
  list of `MessageModel` objects.

- To send a message from the UI (for example when the user taps send):
  ```dart
  await chatService.sendMessage(chatId: chatId, senderId: uid, text: text);
  ```

This service is intentionally UI-agnostic and focuses on Realtime Database
operations only. Firestore chat document updates (chat metadata) should be
handled elsewhere.
*/
=======
>>>>>>> 65cb4ea0fb7fc6e6439c1de2b240066c67079481
