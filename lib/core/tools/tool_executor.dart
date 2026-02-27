// lib/core/tools/tool_executor.dart

import 'dart:convert';
import 'package:fl_ai/core/constants/app_constants.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:torch_light/torch_light.dart';
import 'package:url_launcher/url_launcher.dart';

class ToolExecutor {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  // ── Initialize notifications once at app start ──
  static Future<void> init() async {
    tz.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings();

    await _notifications.initialize(
      settings: const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
      onDidReceiveNotificationResponse: (response) {},
    );
  }

  // ── Main dispatcher ──────────────────────────────
  static Future<Map<String, dynamic>> execute(
    String toolName,
    Map<String, dynamic> args,
  ) async {
    print('🔧 Executing tool: $toolName with args: $args');

    switch (toolName) {
      case 'get_weather':
        return await _getWeather(args['location'] as String);

      case 'set_alarm':
        return await _setAlarm(
          args['time'] as String,
          args['label'] as String? ?? 'Alarm',
        );

      case 'make_call':
        return await _makeCall(args['contact_name'] as String);

      case 'toggle_flashlight':
        return await _toggleFlashlight(args['state'] as String);

      case 'open_web_search':
        return await _openWebSearch(args['query'] as String);

      default:
        return {'success': false, 'error': 'Unknown tool: $toolName'};
    }
  }

  // ── 🌤️ WEATHER ───────────────────────────────────
  // ✅ No changes needed — already working
  static Future<Map<String, dynamic>> _getWeather(String location) async {
    try {
      final apiKey = AppConstants.openWeatherApiKey;
      final url =
          'https://api.openweathermap.org/data/2.5/weather'
          '?q=$location&appid=$apiKey&units=metric';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'location': data['name'],
          'temperature': data['main']['temp'],
          'feels_like': data['main']['feels_like'],
          'condition': data['weather'][0]['description'],
          'humidity': data['main']['humidity'],
        };
      } else {
        return {'success': false, 'error': 'Weather API error'};
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // ── ⏰ ALARM ──────────────────────────────────────
  // ✅ No changes needed — already working
  static Future<Map<String, dynamic>> _setAlarm(
    String time,
    String label,
  ) async {
    try {
      await Permission.notification.request();

      final parts = time.split(':');
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);

      final now = DateTime.now();
      var alarmTime = DateTime(now.year, now.month, now.day, hour, minute);

      if (alarmTime.isBefore(now)) {
        alarmTime = alarmTime.add(const Duration(days: 1));
      }

      final tzAlarmTime = tz.TZDateTime.from(alarmTime, tz.local);

      await _notifications.zonedSchedule(
        id: alarmTime.millisecondsSinceEpoch ~/ 1000,
        title: '⏰ $label',
        body: 'Your alarm is ringing!',
        scheduledDate: tzAlarmTime,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'alarm_channel',
            'Alarms',
            channelDescription: 'Alarm notifications',
            importance: Importance.max,
            priority: Priority.high,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );

      return {
        'success': true,
        'scheduled_at': alarmTime.toIso8601String(),
        'label': label,
      };
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // ── 📞 CALL ───────────────────────────────────────
  // ✅ FIXED — handle permanently denied permission
  static Future<Map<String, dynamic>> _makeCall(String contactName) async {
    try {
      // ── Step 1: Check if permanently denied ──────
      final status = await Permission.contacts.status;
      print('📞 [Call] Permission status: $status');

      if (status.isPermanentlyDenied) {
        // Can't show dialog again — must redirect to Settings
        print('❌ [Call] Permanently denied → opening app settings');
        await openAppSettings();
        return {
          'success': false,
          'error':
              'Contacts permission permanently denied. '
              'Please enable it in Settings.',
        };
      }

      // ── Step 2: Request permission ────────────────
      if (!await FlutterContacts.requestPermission()) {
        return {'success': false, 'error': 'Contacts permission denied'};
      }

      // ── Step 3: Search contacts ───────────────────
      final contacts = await FlutterContacts.getContacts(withProperties: true);
      print('📞 [Call] Total contacts: ${contacts.length}');

      final match = contacts.firstWhere(
        (c) => c.displayName.toLowerCase().contains(contactName.toLowerCase()),
        orElse: () => Contact(),
      );

      if (match.phones.isEmpty) {
        print('❌ [Call] No number found for "$contactName"');
        return {
          'success': false,
          'error': 'No contact named "$contactName" found.',
        };
      }

      // ── Step 4: Dial ──────────────────────────────
      final phoneNumber = match.phones.first.number;
      final uri = Uri.parse('tel:$phoneNumber');

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
        print('✅ [Call] Calling ${match.displayName} → $phoneNumber');
        return {
          'success': true,
          'contact': match.displayName,
          'number': phoneNumber,
        };
      }

      return {'success': false, 'error': 'Cannot launch dialer'};
    } catch (e) {
      print('❌ [Call] Error: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  // ── 🔦 FLASHLIGHT ─────────────────────────────────
  // ✅ FIXED — replaced MethodChannel with torch_light package
  static Future<Map<String, dynamic>> _toggleFlashlight(String state) async {
    try {
      final turnOn = state.toLowerCase() == 'on';

      // ── Check torch availability first ────────────
      final hasTorch = await TorchLight.isTorchAvailable();
      if (!hasTorch) {
        print('❌ [Flashlight] No torch on this device');
        return {'success': false, 'error': 'This device has no flashlight'};
      }

      // ── Toggle ────────────────────────────────────
      if (turnOn) {
        await TorchLight.enableTorch();
        print('✅ [Flashlight] Turned ON');
      } else {
        await TorchLight.disableTorch();
        print('✅ [Flashlight] Turned OFF');
      }

      return {'success': true, 'state': state};
    } on EnableTorchExistentUserException catch (_) {
      // Camera is currently in use by another app
      print('❌ [Flashlight] Camera in use — cannot enable torch');
      return {'success': false, 'error': 'Camera is in use by another app'};
    } on EnableTorchNotAvailableException catch (_) {
      print('❌ [Flashlight] Torch not available on this device');
      return {'success': false, 'error': 'Torch not available'};
    } on EnableTorchException catch (e) {
      print('❌ [Flashlight] Enable error: $e');
      return {'success': false, 'error': 'Could not enable flashlight'};
    } on DisableTorchExistentUserException catch (_) {
      print('❌ [Flashlight] Camera in use — cannot disable torch');
      return {'success': false, 'error': 'Camera is in use by another app'};
    } on DisableTorchNotAvailableException catch (_) {
      print('❌ [Flashlight] Torch not available on this device');
      return {'success': false, 'error': 'Torch not available'};
    } on DisableTorchException catch (e) {
      print('❌ [Flashlight] Disable error: $e');
      return {'success': false, 'error': 'Could not disable flashlight'};
    } catch (e) {
      print('❌ [Flashlight] Unexpected: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  // ── 🌐 WEB SEARCH ─────────────────────────────────
  // ✅ FIXED — Uri.https() builder + platformDefault fallback
  static Future<Map<String, dynamic>> _openWebSearch(String query) async {
    try {
      // ✅ Uri.https() handles encoding automatically — no manual encode needed
      final uri = Uri.https('www.google.com', '/search', {'q': query});
      print('🌐 [Search] Launching: $uri');

      // ✅ Try externalApplication first
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        print('✅ [Search] Opened: $query');
        return {'success': true, 'query': query};
      }

      // ✅ Fallback to platformDefault (lets OS decide)
      final fallback = await launchUrl(uri, mode: LaunchMode.platformDefault);
      if (fallback) {
        print('✅ [Search] Opened via fallback: $query');
        return {'success': true, 'query': query};
      }

      print('❌ [Search] Cannot open browser');
      return {'success': false, 'error': 'Cannot open browser'};
    } catch (e) {
      print('❌ [Search] Error: $e');
      return {'success': false, 'error': e.toString()};
    }
  }
}
