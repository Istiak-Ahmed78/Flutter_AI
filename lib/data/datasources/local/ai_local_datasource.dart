import '../../models/message_model.dart';

abstract class AILocalDataSource {
  Future<List<MessageModel>> getChatHistory();
  Future<void> saveMessage(MessageModel message);
  Future<void> clearChatHistory();
}

class AILocalDataSourceImpl implements AILocalDataSource {
  final List<MessageModel> _messages = [];

  @override
  Future<List<MessageModel>> getChatHistory() async {
    return _messages;
  }

  @override
  Future<void> saveMessage(MessageModel message) async {
    _messages.add(message);
  }

  @override
  Future<void> clearChatHistory() async {
    _messages.clear();
  }
}
