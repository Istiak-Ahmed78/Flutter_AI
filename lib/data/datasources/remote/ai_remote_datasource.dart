// lib/data/datasources/remote/ai_remote_datasource.dart

import 'package:google_generative_ai/google_generative_ai.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/tools/tool_executor.dart';
import '../../../core/tools/tool_registry.dart';
import '../../../core/ai/gemini_model_manager.dart'; // ✅ NEW

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
  // ── No longer a fixed model — managed dynamically ✅
  ChatSession? _chatSession;
  String? _currentModelName; // ✅ NEW — tracks active model

  // ── Replace the static _systemPrompt with this method ──

  // ❌ DELETE this line:
  // static const String _systemPrompt = ''' ... ''';

  // ✅ ADD this method instead:
  static String _buildSystemPrompt() {
    final now = DateTime.now();

    final weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    final months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    final weekday = weekdays[now.weekday - 1];
    final month = months[now.month - 1];
    final day = now.day;
    final year = now.year;
    final hour12 = now.hour == 0
        ? 12
        : now.hour > 12
        ? now.hour - 12
        : now.hour;
    final minute = now.minute.toString().padLeft(2, '0');
    final amPm = now.hour < 12 ? 'AM' : 'PM';

    final dateTimeStr = '$weekday, $month $day, $year at $hour12:$minute $amPm';

    return '''
You are a helpful AI voice assistant built into a Flutter app.

📅 Current date and time: $dateTimeStr

You can perform real device actions like:
- Checking weather
- Setting alarms and reminders
- Making phone calls
- Toggling the flashlight
- Opening web searches
- Telling the current time and date

When the user asks you to perform an action, use the appropriate tool.
Always respond in a friendly, concise, conversational tone.
If a tool call succeeds, confirm it naturally to the user.
If a tool call fails, apologize and explain what went wrong.
When asked for the time or date, use the current date and time provided above.
''';
  }

  AIRemoteDataSourceImpl();

  // ── Build a model instance for any model name ─────────────────────
  GenerativeModel _buildModel(String modelName) {
    final apiKey = AppConstants.geminiApiKey;

    if (apiKey.isEmpty) {
      throw Exception('Gemini API key is empty. Check AppConstants.');
    }

    return GenerativeModel(
      model: modelName,
      apiKey: apiKey,
      tools: ToolRegistry.getTools(),
      systemInstruction: Content.system(_buildSystemPrompt()),
      generationConfig: GenerationConfig(
        temperature: 0.7,
        maxOutputTokens: 800,
      ),
    );
  }

  // ── Get or create chat session ────────────────────────────────────
  // Resets session if model has switched
  Future<ChatSession> _getOrCreateSession(String modelName) async {
    if (_chatSession == null || _currentModelName != modelName) {
      // ── Model switched or first run — create fresh session ────────
      if (_currentModelName != null && _currentModelName != modelName) {
        print('🔀 [Session] Model changed: $_currentModelName → $modelName');
        print('🔄 [Session] Starting fresh chat session');
      }
      _currentModelName = modelName;
      _chatSession = _buildModel(modelName).startChat();
      print('✅ [Session] New session started with: $modelName');
    }
    return _chatSession!;
  }

  // ─────────────────────────────────────────────────────────────────
  // Core: Send message + agentic tool loop + auto model switching ✅
  // ─────────────────────────────────────────────────────────────────
  @override
  Future<String> getAIResponse(String query) async {
    print('👤 User query: $query');

    const maxModelSwitches = 3; // max times we can switch model per query
    int modelAttempts = 0;

    while (modelAttempts < maxModelSwitches) {
      // ── Step 1: Get current best available model ───────────────────
      final modelName = await GeminiModelManager.getCurrentModel();

      try {
        final session = await _getOrCreateSession(modelName);

        // ── Step 2: Send user message ──────────────────────────────
        var response = await session.sendMessage(Content.text(query));

        // ── Step 3: Agentic loop — handle tool calls ───────────────
        int loopCount = 0;
        const maxLoops = 5;

        while (response.functionCalls.isNotEmpty && loopCount < maxLoops) {
          loopCount++;
          print('🔄 Agent loop iteration: $loopCount');

          for (final functionCall in response.functionCalls) {
            print('🔧 Tool requested : ${functionCall.name}');
            print('📦 Arguments      : ${functionCall.args}');

            // ── Step 4: Execute tool on device ─────────────────────
            final toolResult = await ToolExecutor.execute(
              functionCall.name,
              functionCall.args,
            );

            print('✅ Tool result: $toolResult');

            // ── Step 5: Send result back to Gemini ─────────────────
            response = await session.sendMessage(
              Content.functionResponse(functionCall.name, toolResult),
            );
          }
        }

        if (loopCount >= maxLoops) {
          print('⚠️ Max loop limit reached ($maxLoops).');
        }

        // ── Step 6: Return final text ──────────────────────────────
        final finalText = response.text;
        if (finalText == null || finalText.trim().isEmpty) {
          return 'Action completed successfully.';
        }

        print('🤖 Gemini response: $finalText');
        return finalText;
      } on GenerativeAIException catch (e) {
        print('❌ GenerativeAI error: ${e.message}');

        // ── Quota / Rate limit → switch model ─────────────────────
        if (_isQuotaError(e.message)) {
          final retrySeconds = GeminiModelManager.parseRetrySeconds(e.message);

          print(
            '⚠️ [AutoSwitch] Quota hit on $modelName '
            '(retry in ${retrySeconds}s) — switching model...',
          );

          final nextModel = await GeminiModelManager.onQuotaExceeded(
            modelName,
            retrySeconds,
          );

          if (nextModel == modelName) {
            // All models exhausted
            print('❌ [AutoSwitch] All models exhausted');
            return '⚠️ All AI models are currently busy. '
                'Please try again in a minute!';
          }

          print('🔀 [AutoSwitch] Switching: $modelName → $nextModel');
          modelAttempts++;
          continue; // ✅ Retry immediately with new model
        }

        // ── Model not found / deprecated ──────────────────────────
        if (e.message.contains('not found')) {
          print('💡 HINT: Model "$modelName" is wrong or deprecated.');
          print('💡 Marking as unavailable and switching...');

          // Treat as long cooldown (6 hours)
          await GeminiModelManager.onQuotaExceeded(modelName, 21600);
          modelAttempts++;
          continue;
        }

        // ── thought_signature bug ──────────────────────────────────
        if (e.message.contains('thought_signature')) {
          print('💡 HINT: thought_signature bug — switching model');
          await GeminiModelManager.onQuotaExceeded(modelName, 21600);
          modelAttempts++;
          continue;
        }

        // ── Other Gemini errors — don't retry ─────────────────────
        throw Exception('Gemini API error: ${e.message}');
      } catch (e) {
        print('❌ Unexpected error: $e');
        throw Exception('Failed to get AI response: $e');
      }
    }

    // All model switch attempts used up
    return '⚠️ Service temporarily unavailable. Please try again shortly.';
  }

  // ── Detect quota / rate limit errors ──────────────────────────────
  bool _isQuotaError(String error) {
    return error.contains('quota') ||
        error.contains('rate') ||
        error.contains('429') ||
        error.contains('RESOURCE_EXHAUSTED') ||
        error.contains('exceeded');
  }

  // ── Reset session ──────────────────────────────────────────────────
  @override
  void resetSession() {
    _chatSession = null;
    _currentModelName = null;
    print('🔄 Chat session reset');
  }
}
