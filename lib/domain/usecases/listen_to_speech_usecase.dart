import 'package:dartz/dartz.dart';
import '../../core/errors/failures.dart';
import '../../core/usecases/usecase.dart';
import '../repositories/ai_repository.dart';

class ListenToSpeechUseCase implements UseCase<String, NoParams> {
  final AIRepository repository;

  ListenToSpeechUseCase(this.repository);

  @override
  Future<Either<Failure, String>> call(NoParams params) async {
    return await repository.listenForSpeech();
  }
}

class StopListeningUseCase implements UseCase<void, NoParams> {
  final AIRepository repository;

  StopListeningUseCase(this.repository);

  @override
  Future<Either<Failure, void>> call(NoParams params) async {
    return await repository.stopListening();
  }
}
