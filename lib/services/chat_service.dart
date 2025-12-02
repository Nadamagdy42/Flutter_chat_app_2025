import 'dart:async';

import 'package:firebase_database/firebase_database.dart';

import '../models/message_model.dart';

/// Service that manages sending and receiving chat messages using
/// Firebase Realtime Database.
///
/// Realtime Database path convention used:
///   /messages/{chatId}/{messageId}
///
/// Message node fields:
///   - senderId: String
///   - text: String
///   - timestamp: int (millisecondsSinceEpoch)
class ChatService {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  /// Send a message to a chat.
  ///
  /// Writes a message under `/messages/{chatId}/{messageId}`. This method
  /// does not update any Firestore chat metadata (lastMessage/lastUpdatedAt).
  /// Another service or teammate should handle Firestore updates.
  Future<void> sendMessage({
    required String chatId,
    required String senderId,
    required String text,
  }) async {
    try {
      final messagesRef = _db.child('messages').child(chatId);
      final newRef = messagesRef.push();
      final messageId = newRef.key;
      if (messageId == null) {
        throw Exception('Failed to generate message id');
      }

      final message = MessageModel(
        id: messageId,
        chatId: chatId,
        senderId: senderId,
        text: text,
        timestamp: DateTime.now(),
      );

      await newRef.set(message.toMap());

      // TODO: Update Firestore chat metadata (lastMessage, lastUpdatedAt).
      // This service intentionally does not touch Firestore to keep concerns separated.
    } catch (e) {
      throw Exception('ChatService.sendMessage failed: $e');
    }
  }

  /// Returns a stream of messages for the given `chatId` ordered by timestamp
  /// ascending.
  ///
  /// Usage (UI):
  /// ```dart
  /// StreamBuilder<List<MessageModel>>(
  ///   stream: chatService.messagesStream(chatId),
  ///   builder: (context, snapshot) { ... }
  /// )
  /// ```
  Stream<List<MessageModel>> messagesStream(String chatId) {
    final ref = _db.child('messages').child(chatId);

    return ref.orderByChild('timestamp').onValue.map((event) {
      final snapshot = event.snapshot;
      if (!snapshot.exists) return <MessageModel>[];

      final messages = snapshot.children.map((child) {
        final key = child.key ?? '';
        final dynamic val = child.value;
        if (val is Map) {
          final map = Map<String, dynamic>.from(val.map((k, v) => MapEntry(k.toString(), v)));
          return MessageModel.fromMap(map, id: key, chatId: chatId);
        }
        return null;
      }).whereType<MessageModel>().toList();

      messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      return messages;
    }).handleError((error) {
      // Convert any stream error into a more helpful message for debugging.
      throw Exception('ChatService.messagesStream error: $error');
    });
  }
}

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
