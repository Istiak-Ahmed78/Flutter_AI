import 'package:dartz/dartz.dart';
import '../../core/errors/failures.dart';
import '../../core/usecases/usecase.dart';
import '../repositories/ai_repository.dart';

class SpeakTextUseCase implements UseCase<void, String> {
  final AIRepository repository;

  SpeakTextUseCase(this.repository);

  @override
  Future<Either<Failure, void>> call(String text) async {
    return await repository.speakText(text);
  }
}

class StopSpeakingUseCase implements UseCase<void, NoParams> {
  final AIRepository repository;

  StopSpeakingUseCase(this.repository);

  @override
  Future<Either<Failure, void>> call(NoParams params) async {
    return await repository.stopSpeaking();
  }
}
