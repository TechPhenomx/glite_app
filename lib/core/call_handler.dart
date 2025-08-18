// lib/core/call_handler.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:glite/core/websocket_service.dart';
import 'package:glite/core/ws_api_service.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:phone_state_background/phone_state_background.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Singleton WebSocket instance
final webSocket = WebSocketService();
final FlutterSoundRecorder backgroundRecorder = FlutterSoundRecorder();
bool _isRecorderInitialized = false;

// Send call status to API
Future<void> sendCallStatusToAPI(
    String status,
    String number,
    int duration,
    String rid,
    ) async {
  final prefs = await SharedPreferences.getInstance();
  final now = DateTime.now();

  final payload = {
    'call_status': status,
    'phone_number': number,
    'duration': duration,
    'timestamp': now.toIso8601String(),
    'userId': prefs.getString('USER_ID'),
    'ClientID': prefs.getString('ClientID'),
    'CampaignName': prefs.getString('CampaignName'),
    'Campaign_Type': prefs.getString('Campaign_Type'),
    'login_id': prefs.getString('LoginHourID'),
    'UserMode': prefs.getString('UserMode'),
    'user_login_id': prefs.getString('user_login_id'),
    'rid': rid,
  };

  try {
    await http.post(
      Uri.parse('https://devwebrtc.parahittech.com/webrtc_api/call_status.php'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );
    print('✅ Call event sent: $status');
  } catch (e) {
    print("❌ API Error: $e");
  }
}

// Phone state background callback handler
@pragma('vm:entry-point')
Future<void> phoneStateBackgroundCallbackHandler(
    PhoneStateBackgroundEvent event,
    String number,
    int duration,
    ) async {
  final prefs = await SharedPreferences.getInstance();
  String? expectedNumber = prefs.getString('call_number');
  String? callRid = prefs.getString('call_rid');

  String cleanExpected = expectedNumber?.replaceAll(RegExp(r'[^0-9+]'), '') ?? '';
  String cleanIncoming = number.replaceAll(RegExp(r'[^0-9+]'), '');

  if (cleanIncoming.isEmpty && expectedNumber != null) {
    cleanIncoming = expectedNumber.replaceAll(RegExp(r'[^0-9+]'), '');
  }

  if (cleanExpected.isEmpty || callRid == null || cleanExpected != cleanIncoming) {
    print("Skipping event: Not app-initiated. number=$number");
    return;
  }

  switch (event) {
    case PhoneStateBackgroundEvent.outgoingstart:
      print("📞 Outgoing call started");
      await sendCallStatusToAPI('ANSWERED', expectedNumber!, duration, callRid);
      await WsApiService.sendCallEventToWs(
        status: 'ONCALL',
        number: expectedNumber,
        duration: duration,
        rid: callRid,
      );
      await startRecordingSafely();
      break;

    case PhoneStateBackgroundEvent.outgoingend:
      print("📴 Outgoing call ended");
      await sendCallStatusToAPI('HANGUP', number, duration, callRid);
      await WsApiService.sendCallEventToWs(
        status: 'HANGUP',
        number: number,
        duration: duration,
        rid: callRid,
      );
      await stopCallRecording();
      await prefs.remove('call_rid');
      await prefs.remove('call_number');
      break;

    default:
      return;
  }
}

// Request storage permission (handle Android 11+)
Future<bool> requestStoragePermission() async {
  if (Platform.isAndroid && (await _getAndroidSDKInt()) >= 30) {
    var status = await Permission.manageExternalStorage.status;
    if (!status.isGranted) {
      var result = await Permission.manageExternalStorage.request();
      if (!result.isGranted) {
        print("⚠ Storage permission denied.");
        await openAppSettings();
        return false;
      }
    }
  } else {
    var status = await Permission.storage.status;
    if (!status.isGranted) {
      var result = await Permission.storage.request();
      if (!result.isGranted) {
        print("⚠ Storage permission denied.");
        await openAppSettings();
        return false;
      }
    }
  }
  return true;
}

// Request microphone permission
Future<bool> requestMicrophonePermission() async {
  var status = await Permission.microphone.status;
  if (!status.isGranted) {
    var result = await Permission.microphone.request();
    if (!result.isGranted) {
      print("⚠ Microphone permission denied");
      return false;
    }
  }
  return true;
}

// Request all permissions needed before recording
Future<bool> requestAllPermissions() async {
  bool micGranted = await requestMicrophonePermission();
  if (!micGranted) return false;

  bool storageGranted = await requestStoragePermission();
  if (!storageGranted) return false;

  return true;
}

// Initialize recorder (no permission request here; done before call)
Future<void> initRecorder() async {
  if (!_isRecorderInitialized) {
    await backgroundRecorder.openRecorder();
    _isRecorderInitialized = true;
    print("🎤 Recorder initialized");
  }
}

// Start recording safely with permissions and fallback codec
Future<void> startRecordingSafely() async {
  try {
    bool permitted = await requestAllPermissions();
    if (!permitted) {
      print("⚠ Permissions not granted, aborting recording");
      return;
    }

    if (!_isRecorderInitialized) await initRecorder();

    Directory? baseDir = Platform.isAndroid
        ? await getExternalStorageDirectory()
        : await getApplicationDocumentsDirectory();
    baseDir ??= await getApplicationDocumentsDirectory();

    String recordingsFolderPath = '${baseDir.path}/CallRecordings';
    final recordingsDir = Directory(recordingsFolderPath);
    if (!await recordingsDir.exists()) {
      await recordingsDir.create(recursive: true);
      print("📁 Created folder: $recordingsFolderPath");
    }

    String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    String wavPath = '$recordingsFolderPath/call_$timestamp.wav';

    try {
      // Try WAV with microphone input
      await backgroundRecorder.startRecorder(
        toFile: wavPath,
        codec: Codec.pcm16WAV,
        audioSource: AudioSource.microphone,
      );
      print('🎙 Recording started (WAV): $wavPath');
    } catch (e) {
      print("⚠ WAV not supported, switching to AAC fallback: $e");
      String aacPath = '$recordingsFolderPath/call_$timestamp.aac';
      await backgroundRecorder.startRecorder(
        toFile: aacPath,
        codec: Codec.aacADTS,
        audioSource: AudioSource.microphone,
      );
      print('🎙 Recording started (AAC fallback): $aacPath');
    }
  } catch (e) {
    print("❌ Error starting recording: $e");
  }
}

// Stop recording and close recorder
Future<String?> stopCallRecording() async {
  try {
    if (backgroundRecorder.isRecording) {
      final path = await backgroundRecorder.stopRecorder();
      await backgroundRecorder.closeRecorder();
      _isRecorderInitialized = false;
      print("✅ Recording stopped: $path");
      return path;
    }
  } catch (e, stacktrace) {
    print("❌ Error stopping recording: $e");
    print(stacktrace);
  }
  return null;
}

// Get Android SDK version
Future<int> _getAndroidSDKInt() async {
  if (!Platform.isAndroid) return 0;
  try {
    final versionString = Platform.version;
    final match = RegExp(r'SDK_INT\s*=\s*(\d+)').firstMatch(versionString);
    if (match != null) return int.parse(match.group(1)!);
  } catch (_) {}
  return 0;
}
