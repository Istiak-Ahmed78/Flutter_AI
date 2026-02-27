import 'package:google_generative_ai/google_generative_ai.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/tools/tool_executor.dart';
import '../../../core/tools/tool_registry.dart';

// ─────────────────────────────────────────────
// Abstract contract
// ─────────────────────────────────────────────
abstract class AIRemoteDataSource {
  Future<String> getAIResponse(String query);
  void resetSession();
}

// ─────────────────────────────────────────────
// Implementation
// ─────────────────────────────────────────────
class AIRemoteDataSourceImpl implements AIRemoteDataSource {
  late final GenerativeModel _model;
  ChatSession? _chatSession;

  // ── FREE MODEL NAMES (Updated Sept 2025) ─────────────────────────────
  //
  //  Google changed naming convention — old date-suffix names are DEAD:
  //  ❌ gemini-2.5-flash-preview-05-20   → 404 Not Found
  //  ❌ gemini-3-flash-preview            → thought_signature bug
  //
  //  Use stable aliases instead — always points to latest version:
  //  ✅ gemini-2.5-flash                  → BEST FREE (tool calling works)
  //  ✅ gemini-2.5-flash-lite             → Fast backup
  //  ✅ gemini-2.0-flash                  → Reliable fallback
  //  ✅ gemini-1.5-flash                  → Most stable fallback
  //
  //  Source: https://ai.google.dev/gemini-api/docs/models
  // ─────────────────────────────────────────────────────────────────────

  // ✅ PRIMARY — Best free model with working tool calling
  static const String _modelName = 'gemini-2.5-flash';

  // 💡 FALLBACK ORDER (if primary fails, try next):
  // static const String _modelName = 'gemini-2.5-flash-lite';
  // static const String _modelName = 'gemini-2.0-flash';
  // static const String _modelName = 'gemini-1.5-flash';

  static const String _systemPrompt = '''
You are a helpful AI voice assistant built into a Flutter app.
You can perform real device actions like:
- Checking weather
- Setting alarms and reminders
- Making phone calls
- Toggling the flashlight
- Opening web searches

When the user asks you to perform an action, use the appropriate tool.
Always respond in a friendly, concise, conversational tone.
If a tool call succeeds, confirm it naturally to the user.
If a tool call fails, apologize and explain what went wrong.
''';

  AIRemoteDataSourceImpl() {
    _initModel();
  }

  // ── Initialize Gemini model ───────────────────
  void _initModel() {
    try {
      final apiKey = AppConstants.geminiApiKey;

      if (apiKey.isEmpty) {
        throw Exception('Gemini API key is empty. Check AppConstants.');
      }

      _model = GenerativeModel(
        model: _modelName, // ✅ Updated stable alias
        apiKey: apiKey,
        tools: ToolRegistry.getTools(),
        systemInstruction: Content.system(_systemPrompt),
        generationConfig: GenerationConfig(
          temperature: 0.7,
          maxOutputTokens: 800,
        ),
      );

      print('✅ Gemini initialized: $_modelName');
    } catch (e) {
      print('❌ Failed to initialize Gemini: $e');
      rethrow;
    }
  }

  // ── Get or create chat session ────────────────
  ChatSession _getOrCreateSession() {
    _chatSession ??= _model.startChat();
    return _chatSession!;
  }

  // ─────────────────────────────────────────────
  // Core: Send message + agentic tool loop
  // ─────────────────────────────────────────────
  @override
  Future<String> getAIResponse(String query) async {
    try {
      final session = _getOrCreateSession();
      print('👤 User query: $query');

      // Step 1: Send user message
      var response = await session.sendMessage(Content.text(query));

      // Step 2: Agentic loop — handle tool calls
      int loopCount = 0;
      const maxLoops = 5;

      while (response.functionCalls.isNotEmpty && loopCount < maxLoops) {
        loopCount++;
        print('🔄 Agent loop iteration: $loopCount');

        for (final functionCall in response.functionCalls) {
          print('🔧 Tool requested : ${functionCall.name}');
          print('📦 Arguments      : ${functionCall.args}');

          // Step 3: Execute tool on device
          final toolResult = await ToolExecutor.execute(
            functionCall.name,
            functionCall.args,
          );

          print('✅ Tool result: $toolResult');

          // Step 4: Send result back to Gemini
          response = await session.sendMessage(
            Content.functionResponse(functionCall.name, toolResult),
          );
        }
      }

      if (loopCount >= maxLoops) {
        print('⚠️ Max loop limit reached ($maxLoops).');
      }

      // Step 5: Return final text
      final finalText = response.text;
      if (finalText == null || finalText.trim().isEmpty) {
        return 'Action completed successfully.';
      }

      print('🤖 Gemini response: $finalText');
      return finalText;
    } on GenerativeAIException catch (e) {
      print('❌ GenerativeAI error: ${e.message}');

      // ── Helpful model-specific error hints ────
      if (e.message.contains('not found')) {
        print('💡 HINT: Model name is wrong or deprecated.');
        print(
          '💡 Valid free models: gemini-2.5-flash, gemini-2.0-flash, gemini-1.5-flash',
        );
        print('💡 Check: https://ai.google.dev/gemini-api/docs/models');
      }
      if (e.message.contains('thought_signature')) {
        print(
          '💡 HINT: This model requires thought_signature — not supported in Dart SDK',
        );
        print('💡 Switch to: gemini-2.5-flash');
      }

      throw Exception('Gemini API error: ${e.message}');
    } catch (e) {
      print('❌ Unexpected error: $e');
      throw Exception('Failed to get AI response: $e');
    }
  }

  // ── Reset session ─────────────────────────────
  @override
  void resetSession() {
    _chatSession = null;
    print('🔄 Chat session reset');
  }
}
