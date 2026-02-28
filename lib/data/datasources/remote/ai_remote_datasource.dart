import 'dart:io';
import 'package:google_generative_ai/google_generative_ai.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/tools/tool_executor.dart';
import '../../../core/tools/tool_registry.dart';
import '../../../core/ai/gemini_model_manager.dart';

// ─────────────────────────────────────────────
// Abstract contract
// ─────────────────────────────────────────────
abstract class AIRemoteDataSource {
  Future<String> getAIResponse(String query);
  Future<String> getAIResponseWithImage(String query, File imageFile); // ✅ NEW
  void resetSession();
}

// ─────────────────────────────────────────────
// Implementation
// ─────────────────────────────────────────────
class AIRemoteDataSourceImpl implements AIRemoteDataSource {
  ChatSession? _chatSession;
  String? _currentModelName;

  // ── Vision-capable models in priority order ──────────────────────
  // gemini-1.5-flash and pro both support image input via inlineData
  static const List<String> _visionModels = [
    'gemini-1.5-flash',
    'gemini-1.5-pro',
    'gemini-2.0-flash',
  ];

  AIRemoteDataSourceImpl();

  // ─────────────────────────────────────────────────────────────────
  // System prompt (same as before)
  // ─────────────────────────────────────────────────────────────────
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

  // ─────────────────────────────────────────────────────────────────
  // Build a text-only model (same as before)
  // ─────────────────────────────────────────────────────────────────
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

  // ─────────────────────────────────────────────────────────────────
  // ✅ NEW: Build a vision model (no tools — image + text only)
  // Tools are NOT passed here because Gemini vision calls are
  // one-shot generateContent(), not agentic chat sessions.
  // ─────────────────────────────────────────────────────────────────
  GenerativeModel _buildVisionModel(String modelName) {
    final apiKey = AppConstants.geminiApiKey;

    if (apiKey.isEmpty) {
      throw Exception('Gemini API key is empty. Check AppConstants.');
    }

    return GenerativeModel(
      model: modelName,
      apiKey: apiKey,
      // ⚠️ No tools here — vision is pure describe/analyze
      systemInstruction: Content.system(
        _buildSystemPrompt() +
            '\n\nYou are also a visual AI. '
                'When given an image, describe and analyze it clearly. '
                'Answer the user\'s question about what you see in the image.',
      ),
      generationConfig: GenerationConfig(
        temperature: 0.7,
        maxOutputTokens: 1000,
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // Get or create chat session
  // ─────────────────────────────────────────────────────────────────
  Future<ChatSession> _getOrCreateSession(String modelName) async {
    if (_chatSession == null || _currentModelName != modelName) {
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
  // Text-only AI response (unchanged from your original)
  // ─────────────────────────────────────────────────────────────────
  @override
  Future<String> getAIResponse(String query) async {
    print('👤 User query: $query');

    const maxModelSwitches = 3;
    int modelAttempts = 0;

    while (modelAttempts < maxModelSwitches) {
      final modelName = await GeminiModelManager.getCurrentModel();

      try {
        final session = await _getOrCreateSession(modelName);

        var response = await session.sendMessage(Content.text(query));

        int loopCount = 0;
        const maxLoops = 5;

        while (response.functionCalls.isNotEmpty && loopCount < maxLoops) {
          loopCount++;
          print('🔄 Agent loop iteration: $loopCount');

          for (final functionCall in response.functionCalls) {
            print('🔧 Tool requested : ${functionCall.name}');
            print('📦 Arguments      : ${functionCall.args}');

            final toolResult = await ToolExecutor.execute(
              functionCall.name,
              functionCall.args,
            );

            print('✅ Tool result: $toolResult');

            response = await session.sendMessage(
              Content.functionResponse(functionCall.name, toolResult),
            );
          }
        }

        if (loopCount >= maxLoops) {
          print('⚠️ Max loop limit reached ($maxLoops).');
        }

        final finalText = response.text;
        if (finalText == null || finalText.trim().isEmpty) {
          return 'Action completed successfully.';
        }

        print('🤖 Gemini response: $finalText');
        return finalText;
      } on GenerativeAIException catch (e) {
        print('❌ GenerativeAI error: ${e.message}');

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
            print('❌ [AutoSwitch] All models exhausted');
            return '⚠️ All AI models are currently busy. '
                'Please try again in a minute!';
          }
          print('🔀 [AutoSwitch] Switching: $modelName → $nextModel');
          modelAttempts++;
          continue;
        }

        if (e.message.contains('not found')) {
          print('💡 HINT: Model "$modelName" is wrong or deprecated.');
          await GeminiModelManager.onQuotaExceeded(modelName, 21600);
          modelAttempts++;
          continue;
        }

        if (e.message.contains('thought_signature')) {
          print('💡 HINT: thought_signature bug — switching model');
          await GeminiModelManager.onQuotaExceeded(modelName, 21600);
          modelAttempts++;
          continue;
        }

        throw Exception('Gemini API error: ${e.message}');
      } catch (e) {
        print('❌ Unexpected error: $e');
        throw Exception('Failed to get AI response: $e');
      }
    }

    return '⚠️ Service temporarily unavailable. Please try again shortly.';
  }

  // ─────────────────────────────────────────────────────────────────
  // ✅ NEW: Image + Text AI response
  //
  // How it works:
  //   1. Read image bytes from File
  //   2. Build a Content with [TextPart, DataPart] — multimodal
  //   3. Call generateContent() (one-shot, not chat session)
  //   4. Return Gemini's description/analysis
  //
  // Ref: google_generative_ai SDK — Content.multi([TextPart, DataPart])
  // ─────────────────────────────────────────────────────────────────
  @override
  Future<String> getAIResponseWithImage(String query, File imageFile) async {
    print('📷 Image query: $query');
    print('📁 Image path : ${imageFile.path}');

    const maxModelSwitches = 3;
    int modelAttempts = 0;

    // Try vision models in order
    int visionModelIndex = 0;

    while (modelAttempts < maxModelSwitches &&
        visionModelIndex < _visionModels.length) {
      final modelName = _visionModels[visionModelIndex];

      try {
        // ── Step 1: Read image bytes ─────────────────────────────
        final imageBytes = await imageFile.readAsBytes();
        print('🖼️  Image loaded: ${imageBytes.lengthInBytes} bytes');

        // ── Step 2: Detect MIME type from extension ──────────────
        final mimeType = _getMimeType(imageFile.path);
        print('📄 MIME type: $mimeType');

        // ── Step 3: Build multimodal Content ────────────────────
        // TextPart = user's question
        // DataPart = raw image bytes with MIME type
        final content = Content.multi([
          TextPart(query),
          DataPart(mimeType, imageBytes),
        ]);

        // ── Step 4: Build vision model & call generateContent ────
        final model = _buildVisionModel(modelName);
        print('🤖 Sending to vision model: $modelName');

        final response = await model.generateContent([content]);

        // ── Step 5: Extract text response ────────────────────────
        final finalText = response.text;
        if (finalText == null || finalText.trim().isEmpty) {
          return 'I can see the image but could not generate a response.';
        }

        print('🤖 Vision response: $finalText');
        return finalText;
      } on GenerativeAIException catch (e) {
        print('❌ Vision model error ($modelName): ${e.message}');

        if (_isQuotaError(e.message)) {
          print('⚠️ Quota hit on vision model $modelName — trying next...');
          visionModelIndex++;
          modelAttempts++;
          continue;
        }

        if (e.message.contains('not found') ||
            e.message.contains('thought_signature')) {
          print('💡 Vision model issue — trying next model');
          visionModelIndex++;
          modelAttempts++;
          continue;
        }

        // ── Image too large or unsupported format ────────────────
        if (e.message.contains('image') ||
            e.message.contains('INVALID_ARGUMENT')) {
          print('❌ Image rejected by API: ${e.message}');
          return '⚠️ Could not process this image. '
              'Please try again with a clearer photo.';
        }

        throw Exception('Vision API error: ${e.message}');
      } catch (e) {
        print('❌ Unexpected vision error: $e');
        throw Exception('Failed to analyze image: $e');
      }
    }

    return '⚠️ Vision service temporarily unavailable. '
        'Please try again shortly.';
  }

  // ─────────────────────────────────────────────────────────────────
  // ✅ Helper: Detect MIME type from file extension
  // Gemini supports: image/jpeg, image/png, image/webp, image/heic
  // ─────────────────────────────────────────────────────────────────
  String _getMimeType(String filePath) {
    final ext = filePath.split('.').last.toLowerCase();
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'heic':
        return 'image/heic';
      case 'heif':
        return 'image/heif';
      default:
        // Camera always saves as .jpg — safe default
        return 'image/jpeg';
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // Detect quota / rate limit errors
  // ─────────────────────────────────────────────────────────────────
  bool _isQuotaError(String error) {
    return error.contains('quota') ||
        error.contains('rate') ||
        error.contains('429') ||
        error.contains('RESOURCE_EXHAUSTED') ||
        error.contains('exceeded');
  }

  // ─────────────────────────────────────────────────────────────────
  // Reset session
  // ─────────────────────────────────────────────────────────────────
  @override
  void resetSession() {
    _chatSession = null;
    _currentModelName = null;
    print('🔄 Chat session reset');
  }
}
