class MessageModel {
  final String id;
  final String chatId;
  final String senderId;
  final String text;
  final DateTime timestamp;

  const MessageModel({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.text,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'text': text,
      'timestamp': timestamp.millisecondsSinceEpoch,
    };
  }

  factory MessageModel.fromMap(Map<String, dynamic> map,
      {required String id, required String chatId}) {
    final ts = map['timestamp'];
    DateTime timestamp;
    if (ts is int) {
      timestamp = DateTime.fromMillisecondsSinceEpoch(ts);
    } else if (ts is String) {
      timestamp = DateTime.fromMillisecondsSinceEpoch(int.tryParse(ts) ?? 0);
    } else {
      timestamp = DateTime.fromMillisecondsSinceEpoch(0);
    }

    return MessageModel(
      id: id,
      chatId: chatId,
      senderId: map['senderId'] as String? ?? '',
      text: map['text'] as String? ?? '',
      timestamp: timestamp,
    );
  }

  MessageModel copyWith({
    String? text,
    DateTime? timestamp,
  }) {
    return MessageModel(
      id: id,
      chatId: chatId,
      senderId: senderId,
      text: text ?? this.text,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}
