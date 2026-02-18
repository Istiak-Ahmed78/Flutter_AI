import 'package:dartz/dartz.dart';
import '../../core/errors/failures.dart';
import '../entities/message_entity.dart';

abstract class AIRepository {
  // Speech to Text
  Future<Either<Failure, String>> listenForSpeech();
  Future<Either<Failure, void>> stopListening();
  Stream<bool> get listeningStream;

  // Text to Speech
  Future<Either<Failure, void>> speakText(String text);
  Future<Either<Failure, void>> stopSpeaking();

  // AI Chat
  Future<Either<Failure, MessageEntity>> getAIResponse(String query);
  Future<Either<Failure, List<MessageEntity>>> getChatHistory();
  Future<Either<Failure, void>> clearChatHistory();
}
