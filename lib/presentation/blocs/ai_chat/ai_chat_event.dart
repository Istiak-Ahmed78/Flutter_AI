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

class LoadChatHistoryEvent extends AIChatEvent {}

class ClearChatHistoryEvent extends AIChatEvent {}

class AddMessageEvent extends AIChatEvent {
  final MessageEntity message;

  const AddMessageEvent(this.message);

  @override
  List<Object> get props => [message];
}
