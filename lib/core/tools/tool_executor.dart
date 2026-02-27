// lib/core/tools/tool_executor.dart

import 'dart:convert';
import 'package:fl_ai/core/constants/app_constants.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart'; // ✅ NEW
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

      case 'get_time': // ✅ NEW
        return _getTime();

      case 'get_date': // ✅ NEW
        return _getDate();

      default:
        return {'success': false, 'error': 'Unknown tool: $toolName'};
    }
  }

  // ── 🌤️ WEATHER ───────────────────────────────────
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
  static Future<Map<String, dynamic>> _makeCall(String contactName) async {
    try {
      print('📞 [Call] Starting call to: "$contactName"');

      // ── Step 1: Check permanent denial first ─────
      final contactsStatus = await Permission.contacts.status;
      final phoneStatus = await Permission.phone.status;

      print('📞 [Call] Contacts permission: $contactsStatus');
      print('📞 [Call] Phone permission   : $phoneStatus');

      if (contactsStatus.isPermanentlyDenied) {
        print('❌ [Call] Contacts permanently denied → opening settings');
        await openAppSettings();
        return {
          'success': false,
          'error':
              'Contacts permission permanently denied. '
              'Please enable it in Settings.',
        };
      }

      if (phoneStatus.isPermanentlyDenied) {
        print('❌ [Call] Phone permanently denied → opening settings');
        await openAppSettings();
        return {
          'success': false,
          'error':
              'Phone permission permanently denied. '
              'Please enable it in Settings.',
        };
      }

      // ── Step 2: Request permissions SEPARATELY ────
      // Request contacts permission first
      if (!contactsStatus.isGranted) {
        print('📞 [Call] Requesting contacts permission...');
        final contactsResult = await Permission.contacts.request();
        print('📞 [Call] Contacts result: $contactsResult');

        if (!contactsResult.isGranted) {
          print('❌ [Call] Contacts permission denied');
          return {
            'success': false,
            'error':
                'Contacts permission denied. '
                'Please allow contacts access to make calls.',
          };
        }
      }

      // Request phone permission separately
      if (!phoneStatus.isGranted) {
        print('📞 [Call] Requesting phone permission...');
        final phoneResult = await Permission.phone.request();
        print('📞 [Call] Phone result: $phoneResult');

        if (!phoneResult.isGranted) {
          print('❌ [Call] Phone permission denied');
          return {
            'success': false,
            'error':
                'Phone call permission denied. '
                'Please allow phone access to make calls.',
          };
        }
      }

      print('✅ [Call] Both permissions granted');

      // ── Step 3: Load contacts ─────────────────────
      final contacts = await FlutterContacts.getContacts(withProperties: true);
      print('📞 [Call] Total contacts loaded: ${contacts.length}');

      if (contacts.isEmpty) {
        return {'success': false, 'error': 'No contacts found on this device.'};
      }

      // ── Step 4: Find best match ───────────────────
      Contact? match;

      // Exact match first (case-insensitive)
      try {
        match = contacts.firstWhere(
          (c) =>
              c.displayName.toLowerCase().trim() ==
              contactName.toLowerCase().trim(),
        );
        print('✅ [Call] Exact match: ${match.displayName}');
      } catch (_) {
        match = null;
      }

      // Partial match if no exact match
      if (match == null || match.id.isEmpty) {
        try {
          match = contacts.firstWhere(
            (c) => c.displayName.toLowerCase().contains(
              contactName.toLowerCase().trim(),
            ),
          );
          print('✅ [Call] Partial match: ${match.displayName}');
        } catch (_) {
          match = null;
        }
      }

      // ── Step 5: Validate match ────────────────────
      if (match == null || match.id.isEmpty) {
        print('❌ [Call] No contact found for "$contactName"');
        return {
          'success': false,
          'error':
              'No contact named "$contactName" found. '
              'Please check the name and try again.',
        };
      }

      if (match.phones.isEmpty) {
        print('❌ [Call] No phone number for: ${match.displayName}');
        return {
          'success': false,
          'error': '${match.displayName} has no phone number saved.',
        };
      }

      // ── Step 6: Dial ──────────────────────────────
      final rawNumber = match.phones.first.number;
      final phoneNumber = rawNumber.replaceAll(RegExp(r'[\s\-\(\)]'), '');
      final uri = Uri.parse('tel:$phoneNumber');

      print('📞 [Call] Dialing: ${match.displayName} → $phoneNumber');

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
        print('✅ [Call] Call launched successfully');
        return {
          'success': true,
          'message': 'Calling ${match.displayName}',
          'contact': match.displayName,
          'number': phoneNumber,
        };
      }

      print('❌ [Call] Cannot launch dialer');
      return {
        'success': false,
        'error': 'Cannot open the phone dialer on this device.',
      };
    } catch (e) {
      print('❌ [Call] Unexpected error: $e');
      return {
        'success': false,
        'error': 'Failed to make call: ${e.toString()}',
      };
    }
  }

  // ── 🔦 FLASHLIGHT ─────────────────────────────────
  static Future<Map<String, dynamic>> _toggleFlashlight(String state) async {
    try {
      final turnOn = state.toLowerCase() == 'on';

      final hasTorch = await TorchLight.isTorchAvailable();
      if (!hasTorch) {
        print('❌ [Flashlight] No torch on this device');
        return {'success': false, 'error': 'This device has no flashlight'};
      }

      if (turnOn) {
        await TorchLight.enableTorch();
        print('✅ [Flashlight] Turned ON');
      } else {
        await TorchLight.disableTorch();
        print('✅ [Flashlight] Turned OFF');
      }

      return {'success': true, 'state': state};
    } on EnableTorchExistentUserException catch (_) {
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
  static Future<Map<String, dynamic>> _openWebSearch(String query) async {
    try {
      final uri = Uri.https('www.google.com', '/search', {'q': query});
      print('🌐 [Search] Launching: $uri');

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        print('✅ [Search] Opened: $query');
        return {'success': true, 'query': query};
      }

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

  // ── 🕐 TIME ───────────────────────────────────────  ✅ NEW
  static Map<String, dynamic> _getTime() {
    try {
      final now = DateTime.now();
      final time12h = DateFormat('hh:mm:ss a').format(now); // 09:45:30 PM
      final time24h = DateFormat('HH:mm:ss').format(now); // 21:45:30
      final timezone = now.timeZoneName; // BDT / UTC+6
      final offsetHours = now.timeZoneOffset.inHours;
      final offsetMins = now.timeZoneOffset.inMinutes.abs() % 60;
      final offsetStr =
          'UTC${offsetHours >= 0 ? '+' : ''}$offsetHours'
          '${offsetMins > 0 ? ':$offsetMins' : ''}';

      print('✅ [Time] $time12h ($timezone / $offsetStr)');

      return {
        'success': true,
        'time_12h': time12h, // "09:45:30 PM"
        'time_24h': time24h, // "21:45:30"
        'timezone': timezone, // "BDT"
        'utc_offset': offsetStr, // "UTC+6"
        'timestamp': now.millisecondsSinceEpoch,
      };
    } catch (e) {
      print('❌ [Time] Error: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  // ── 📅 DATE ───────────────────────────────────────  ✅ NEW
  static Map<String, dynamic> _getDate() {
    try {
      final now = DateTime.now();
      final dateFull = DateFormat(
        'EEEE, MMMM d, y',
      ).format(now); // Friday, February 28, 2026
      final dateShort = DateFormat('dd/MM/yyyy').format(now); // 28/02/2026
      final dateIso = DateFormat('yyyy-MM-dd').format(now); // 2026-02-28
      final dayOfWeek = DateFormat('EEEE').format(now); // Friday
      final month = DateFormat('MMMM').format(now); // February

      print('✅ [Date] $dateFull');

      return {
        'success': true,
        'date_full': dateFull, // "Friday, February 28, 2026"
        'date_short': dateShort, // "28/02/2026"
        'date_iso': dateIso, // "2026-02-28"
        'day_of_week': dayOfWeek, // "Friday"
        'month': month, // "February"
        'day': now.day, // 28
        'year': now.year, // 2026
      };
    } catch (e) {
      print('❌ [Date] Error: $e');
      return {'success': false, 'error': e.toString()};
    }
  }
}
