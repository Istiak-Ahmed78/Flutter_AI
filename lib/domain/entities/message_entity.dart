import 'package:equatable/equatable.dart';

enum MessageRole { user, assistant, system }

class MessageEntity extends Equatable {
  final String id;
  final String content;
  final MessageRole role;
  final DateTime timestamp;

  const MessageEntity({
    required this.id,
    required this.content,
    required this.role,
    required this.timestamp,
  });

  @override
  List<Object?> get props => [id, content, role, timestamp];
}
