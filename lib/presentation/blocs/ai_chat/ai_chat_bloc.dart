import 'package:equatable/equatable.dart';
import 'package:fl_ai/domain/usecases/clear_chat_history_usecase.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/usecases/usecase.dart';
import '../../../domain/entities/message_entity.dart';
import '../../../domain/usecases/get_ai_response_usecase.dart';
import '../../../domain/usecases/speak_text_usecase.dart';
import '../../../data/models/message_model.dart';

// These must be part of this file
part 'ai_chat_event.dart';
part 'ai_chat_state.dart';

class AIChatBloc extends Bloc<AIChatEvent, AIChatState> {
  final GetAIResponseUseCase getAIResponse;
  final GetChatHistoryUseCase getChatHistory;
  final ClearChatHistoryUseCase clearChatHistory;
  final SpeakTextUseCase speakText;

  AIChatBloc({
    required this.getAIResponse,
    required this.getChatHistory,
    required this.clearChatHistory,
    required this.speakText,
  }) : super(AIChatInitial()) {
    on<SendMessageEvent>(_onSendMessage);
    on<LoadChatHistoryEvent>(_onLoadChatHistory);
    on<ClearChatHistoryEvent>(_onClearChatHistory);
    on<AddMessageEvent>(_onAddMessage);
  }

  Future<void> _onSendMessage(
    SendMessageEvent event,
    Emitter<AIChatState> emit,
  ) async {
    final currentState = state;
    List<MessageEntity> currentMessages = [];

    if (currentState is AIChatLoaded) {
      currentMessages = currentState.messages;
    }

    // Add user message
    final userMessage = MessageModel.create(
      content: event.message,
      role: MessageRole.user,
    );

    emit(
      AIChatLoaded(messages: [...currentMessages, userMessage], isTyping: true),
    );

    // Get AI response
    final result = await getAIResponse(event.message);

    result.fold((failure) => emit(AIChatError(failure.message)), (aiMessage) {
      // Add AI message
      final updatedMessages = [...currentMessages, userMessage, aiMessage];

      emit(AIChatLoaded(messages: updatedMessages, isTyping: false));

      // Speak response if requested
      if (event.shouldSpeak) {
        speakText(aiMessage.content);
      }
    });
  }

  Future<void> _onLoadChatHistory(
    LoadChatHistoryEvent event,
    Emitter<AIChatState> emit,
  ) async {
    emit(AIChatLoading());

    final result = await getChatHistory(NoParams());

    result.fold(
      (failure) => emit(AIChatError(failure.message)),
      (messages) => emit(AIChatLoaded(messages: messages)),
    );
  }

  Future<void> _onClearChatHistory(
    ClearChatHistoryEvent event,
    Emitter<AIChatState> emit,
  ) async {
    final result = await clearChatHistory(NoParams());

    result.fold(
      (failure) => emit(AIChatError(failure.message)),
      (_) => emit(const AIChatLoaded(messages: [])),
    );
  }

  void _onAddMessage(AddMessageEvent event, Emitter<AIChatState> emit) {
    final currentState = state;
    if (currentState is AIChatLoaded) {
      emit(AIChatLoaded(messages: [...currentState.messages, event.message]));
    }
  }
}
