import '../../domain/entities/message_entity.dart';

class MessageModel extends MessageEntity {
  const MessageModel({
    required super.id,
    required super.content,
    required super.role,
    required super.timestamp,
  });

  factory MessageModel.fromEntity(MessageEntity entity) {
    return MessageModel(
      id: entity.id,
      content: entity.content,
      role: entity.role,
      timestamp: entity.timestamp,
    );
  }

  factory MessageModel.create({
    required String content,
    required MessageRole role,
  }) {
    return MessageModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: content,
      role: role,
      timestamp: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'role': role.toString(),
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      id: json['id'],
      content: json['content'],
      role: MessageRole.values.firstWhere((e) => e.toString() == json['role']),
      timestamp: DateTime.parse(json['timestamp']),
    );
  }
}
