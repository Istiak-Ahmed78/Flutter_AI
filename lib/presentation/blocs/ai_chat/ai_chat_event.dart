part of 'ai_chat_bloc.dart';

abstract class AIChatEvent extends Equatable {
  const AIChatEvent();

  @override
  List<Object> get props => [];
}

class SendMessageEvent extends AIChatEvent {
  final String message;
  final bool shouldSpeak;

  const SendMessageEvent({required this.message, this.shouldSpeak = true});

  @override
  List<Object> get props => [message, shouldSpeak];
}

// ✅ NEW: Send message with image
class SendMessageWithImageEvent extends AIChatEvent {
  final String message;
  final File imageFile;
  final bool shouldSpeak;

  const SendMessageWithImageEvent({
    required this.message,
    required this.imageFile,
    this.shouldSpeak = true,
  });

  @override
  List<Object> get props => [message, imageFile, shouldSpeak];
}

class LoadChatHistoryEvent extends AIChatEvent {}

class ClearChatHistoryEvent extends AIChatEvent {}

class AddMessageEvent extends AIChatEvent {
  final MessageEntity message;

  const AddMessageEvent(this.message);

  @override
  List<Object> get props => [message];
}
