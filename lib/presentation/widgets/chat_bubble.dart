import 'package:flutter/material.dart';
import '../../domain/entities/message_entity.dart';

class ChatBubble extends StatelessWidget {
  final MessageEntity message;

  const ChatBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == MessageRole.user;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          if (!isUser) _buildAvatar(Icons.smart_toy, Colors.deepPurple),
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isUser ? Colors.deepPurple : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                message.content,
                style: TextStyle(color: isUser ? Colors.white : Colors.black87),
              ),
            ),
          ),
          if (isUser) _buildAvatar(Icons.person, Colors.deepPurple.shade100),
        ],
      ),
    );
  }

  Widget _buildAvatar(IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      child: CircleAvatar(
        backgroundColor: color,
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }
}
