import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMetadataService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Stream chats where the user is a participant
  Stream<QuerySnapshot> chatsStream(String uid) {
    return _db
        .collection('chats')
        .where('participants', arrayContains: uid)
        // MUST MATCH YOUR INDEX EXACTLY
        .orderBy('lastUpdatedAt', descending: true) 
        .snapshots();
  }

  /// Create a chat between 2 users if not exists
  Future<String> createChat(String uid, String otherUid) async {
    var chatDoc = await _db.collection('chats').add({
      'participants': [uid, otherUid],
      'lastMessage': "",
      // FIX: Writes 'lastUpdatedAt' to match the index
      'lastUpdatedAt': FieldValue.serverTimestamp(), 
      'createdAt': FieldValue.serverTimestamp(),
    });

    return chatDoc.id;
  }

  /// Update chat metadata (after sending message)
  Future<void> updateChatMetadata({
    required String chatId,
    required String lastMessage,
    required List<String> participants,
  }) async {
    await _db.collection('chats').doc(chatId).update({
      'lastMessage': lastMessage,
      'participants': participants,
      // FIX: Updates 'lastUpdatedAt' to match the index
      'lastUpdatedAt': FieldValue.serverTimestamp(), 
    });
  }
}