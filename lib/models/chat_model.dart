class ChatModel {
  final String id;
  final List<String> participants;
  final String lastMessage;
  final DateTime? lastUpdatedAt;

  const ChatModel({
    required this.id,
    required this.participants,
    required this.lastMessage,
    this.lastUpdatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'participants': participants,
      'lastMessage': lastMessage,
      'lastUpdatedAt': lastUpdatedAt?.millisecondsSinceEpoch,
    };
  }

  factory ChatModel.fromMap(Map<String, dynamic> map, {required String id}) {
    final participantsDynamic = map['participants'] as List<dynamic>?;
    final participants = participantsDynamic != null
        ? participantsDynamic.map((e) => e.toString()).toList()
        : <String>[];

    final lastUpdatedMillis = map['lastUpdatedAt'];
    DateTime? lastUpdated;
    if (lastUpdatedMillis is int) {
      lastUpdated = DateTime.fromMillisecondsSinceEpoch(lastUpdatedMillis);
    }

    return ChatModel(
      id: id,
      participants: participants,
      lastMessage: map['lastMessage'] as String? ?? '',
      lastUpdatedAt: lastUpdated,
    );
  }

  ChatModel copyWith({
    List<String>? participants,
    String? lastMessage,
    DateTime? lastUpdatedAt,
  }) {
    return ChatModel(
      id: id,
      participants: participants ?? this.participants,
      lastMessage: lastMessage ?? this.lastMessage,
      lastUpdatedAt: lastUpdatedAt ?? this.lastUpdatedAt,
    );
  }
}