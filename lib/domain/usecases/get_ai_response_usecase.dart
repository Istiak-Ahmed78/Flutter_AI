import 'dart:io'; // ✅ NEW
import 'package:dartz/dartz.dart';
import '../../core/errors/failures.dart';
import '../../core/usecases/usecase.dart';
import '../entities/message_entity.dart';
import '../repositories/ai_repository.dart';

class GetAIResponseUseCase implements UseCase<MessageEntity, String> {
  final AIRepository repository;

  GetAIResponseUseCase(this.repository);

  // ── Text-only call (unchanged) ─────────────────────────────────
  @override
  Future<Either<Failure, MessageEntity>> call(String query) async {
    return await repository.getAIResponse(query);
  }

  // ✅ NEW: Image + text call
  // Used by AIChatBloc when camera captures a photo
  Future<Either<Failure, MessageEntity>> callWithImage(
    String query,
    File imageFile,
  ) async {
    return await repository.getAIResponseWithImage(query, imageFile);
  }
}

// ── GetChatHistoryUseCase (unchanged) ──────────────────────────────
class GetChatHistoryUseCase implements UseCase<List<MessageEntity>, NoParams> {
  final AIRepository repository;

  GetChatHistoryUseCase(this.repository);

  @override
  Future<Either<Failure, List<MessageEntity>>> call(NoParams params) async {
    return await repository.getChatHistory();
  }
}
