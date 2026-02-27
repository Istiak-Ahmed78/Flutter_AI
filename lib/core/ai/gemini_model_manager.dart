// lib/core/ai/gemini_model_manager.dart

import 'package:shared_preferences/shared_preferences.dart';

class GeminiModelManager {
  // ── Model priority list (best → fallback) ────────
  // ✅ Updated: removed deprecated gemini-1.5-flash
  // ✅ Added:   gemini-2.5-flash-lite as last resort
  static const List<String> _models = [
    'gemini-2.5-flash', // 🥇 Best quality (500 RPD free)
    'gemini-2.5-flash-lite', // 🥈 Lighter/faster version
    'gemini-2.0-flash-lite', // 🥉 Last resort fallback
  ];

  static const String _prefKey = 'current_model_index';
  static const String _cooldownPrefix = 'model_cooldown_';

  // ── Get current active model ──────────────────────
  static Future<String> getCurrentModel() async {
    final prefs = await SharedPreferences.getInstance();

    // Find first model that is NOT in cooldown
    for (int i = 0; i < _models.length; i++) {
      final model = _models[i];
      if (!await _isInCooldown(model, prefs)) {
        await prefs.setInt(_prefKey, i);
        print('🤖 [ModelManager] Active model: $model');
        return model;
      }
      print('⏳ [ModelManager] $model is in cooldown — skipping');
    }

    // All models in cooldown — return last one and let it retry
    print('⚠️ [ModelManager] All models in cooldown — using last fallback');
    return _models.last;
  }

  // ── Called when a model hits quota limit ──────────
  static Future<String> onQuotaExceeded(
    String failedModel,
    int retryAfterSeconds,
  ) async {
    final prefs = await SharedPreferences.getInstance();

    // ── Cap unreasonably large retry values ───────────
    // If retry > 600s (10 min), it likely means the model
    // is unavailable on this API key — use 6 hour cooldown
    final effectiveCooldown = retryAfterSeconds > 600
        ? 21600 // 6 hours for unavailable models
        : retryAfterSeconds + 5; // +5s buffer for normal quota

    // ── Set cooldown for the failed model ────────────
    final cooldownUntil = DateTime.now()
        .add(Duration(seconds: effectiveCooldown))
        .millisecondsSinceEpoch;

    await prefs.setInt('$_cooldownPrefix$failedModel', cooldownUntil);
    print(
      '🔴 [ModelManager] $failedModel → cooldown for ${effectiveCooldown}s',
    );

    // ── Find next available model ─────────────────────
    for (final model in _models) {
      if (model != failedModel && !await _isInCooldown(model, prefs)) {
        print('🔀 [ModelManager] Switching: $failedModel → $model');
        return model;
      }
    }

    // All models exhausted
    print('❌ [ModelManager] No available models — all in cooldown');
    return failedModel; // return same, caller will show error
  }

  // ── Check if a model is currently in cooldown ─────
  static Future<bool> _isInCooldown(
    String model,
    SharedPreferences prefs,
  ) async {
    final cooldownUntil = prefs.getInt('$_cooldownPrefix$model') ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;

    if (now < cooldownUntil) {
      final remaining = ((cooldownUntil - now) / 1000).ceil();
      print('⏳ [ModelManager] $model cooldown: ${remaining}s remaining');
      return true;
    }

    return false;
  }

  // ── Get remaining cooldown seconds for a model ────
  static Future<int> getCooldownRemaining(String model) async {
    final prefs = await SharedPreferences.getInstance();
    final cooldownUntil = prefs.getInt('$_cooldownPrefix$model') ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    final remaining = ((cooldownUntil - now) / 1000).ceil();
    return remaining > 0 ? remaining : 0;
  }

  // ── Get status of all models (for debug/UI) ───────
  static Future<Map<String, dynamic>> getAllModelStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final Map<String, dynamic> status = {};

    for (final model in _models) {
      final inCooldown = await _isInCooldown(model, prefs);
      final remaining = await getCooldownRemaining(model);
      status[model] = {
        'available': !inCooldown,
        'cooldown_remaining_seconds': remaining,
      };
    }

    return status;
  }

  // ── Reset all cooldowns (for testing) ─────────────
  static Future<void> resetAllCooldowns() async {
    final prefs = await SharedPreferences.getInstance();
    for (final model in _models) {
      await prefs.remove('$_cooldownPrefix$model');
    }
    // Also clear old model names from previous versions
    await prefs.remove('model_cooldown_gemini-1.5-flash');
    await prefs.remove('model_cooldown_gemini-2.0-flash');
    print('🔄 [ModelManager] All cooldowns reset');
  }

  // ── Parse retry seconds from Gemini error message ─
  static int parseRetrySeconds(String errorMessage) {
    // Gemini error: "Please retry in 49.269972253s"
    final match = RegExp(r'retry in (\d+)').firstMatch(errorMessage);
    return int.tryParse(match?.group(1) ?? '60') ?? 60;
  }

  // ── Check if error means model is unavailable ─────
  // (limit: 0 means not available on this API key)
  static bool isModelUnavailable(String errorMessage) {
    return errorMessage.contains('limit: 0') ||
        errorMessage.contains('not found') ||
        errorMessage.contains('not supported') ||
        errorMessage.contains('PERMISSION_DENIED');
  }
}
