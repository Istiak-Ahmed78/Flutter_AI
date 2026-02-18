import 'package:dartz/dartz.dart';
import '../../core/errors/failures.dart';
import '../../core/usecases/usecase.dart';
import '../repositories/ai_repository.dart';

class ClearChatHistoryUseCase implements UseCase<void, NoParams> {
  final AIRepository repository;

  ClearChatHistoryUseCase(this.repository);

  @override
  Future<Either<Failure, void>> call(NoParams params) async {
    return await repository.clearChatHistory();
  }
}
