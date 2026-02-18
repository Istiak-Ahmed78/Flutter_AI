part of 'ai_chat_bloc.dart';

abstract class AIChatState extends Equatable {
  const AIChatState();

  @override
  List<Object> get props => [];
}

class AIChatInitial extends AIChatState {}

class AIChatLoading extends AIChatState {}

class AIChatLoaded extends AIChatState {
  final List<MessageEntity> messages;
  final bool isTyping;

  const AIChatLoaded({required this.messages, this.isTyping = false});

  @override
  List<Object> get props => [messages, isTyping];
}

class AIChatError extends AIChatState {
  final String message;

  const AIChatError(this.message);

  @override
  List<Object> get props => [message];
}
