import 'package:google_generative_ai/google_generative_ai.dart';
import '../../../core/constants/app_constants.dart';
import '../../models/message_model.dart';

abstract class AIRemoteDataSource {
  Future<String> getAIResponse(String query);
}

class AIRemoteDataSourceImpl implements AIRemoteDataSource {
  late final GenerativeModel _model;
  ChatSession? _chatSession;

  AIRemoteDataSourceImpl() {
    try {
      final apiKey = AppConstants.geminiApiKey;
      if (apiKey.isEmpty) {
        throw Exception(
          'Gemini API key is not configured. Please check your .env file.',
        );
      }

      _model = GenerativeModel(
        model: 'gemini-3-flash-preview',
        apiKey: apiKey,
        generationConfig: GenerationConfig(
          temperature: 0.7,
          maxOutputTokens: 800,
        ),
      );

      print('✅ Gemini model initialized successfully');
    } catch (e) {
      print('❌ Failed to initialize Gemini model: $e');
      rethrow;
    }
  }

  @override
  Future<String> getAIResponse(String query) async {
    try {
      _chatSession ??= _model.startChat();

      final response = await _chatSession!.sendMessage(Content.text(query));

      return response.text ?? 'No response generated';
    } catch (e) {
      throw Exception('AI Response failed: $e');
    }
  }
}
