// core/call_status_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:phone_state_background/phone_state_background.dart';
import 'recorder.dart';
import 'websocket_service.dart';

class CallStatusService {
  final WebSocketService webSocketService;
  final CallRecorder recorder;

  CallStatusService(this.webSocketService, this.recorder);

  Future<void> handleEvent(PhoneStateBackgroundEvent event, String number, int duration) async {
    final prefs = await SharedPreferences.getInstance();
    String status;

    switch (event) {
      case PhoneStateBackgroundEvent.incomingstart:
        status = 'IncomingStart';
        break;
      case PhoneStateBackgroundEvent.incomingmissed:
        status = 'Missed';
        break;
      case PhoneStateBackgroundEvent.incomingreceived:
        status = 'Answered';
        break;
      case PhoneStateBackgroundEvent.incomingend:
        status = 'Ended';
        break;
      case PhoneStateBackgroundEvent.outgoingstart:
        status = 'ANSWERED';
        await recorder.startRecording();
        break;
      case PhoneStateBackgroundEvent.outgoingend:
        status = 'HANGUP';
        await recorder.stopRecording();
        break;
    }

    if (!(prefs.getBool("was_dialed_from_app") ?? false)) return;

    final payload = await _buildPayload(status, number, duration);

    await http.post(
      Uri.parse('https://devwebrtc.parahittech.com/webrtc_api/call_status.php'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );

    prefs.setBool("was_dialed_from_app", false);

    webSocketService.send(payload);
  }

  Future<Map<String, dynamic>> _buildPayload(String status, String number, int duration) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String threeDigits(int n) => n.toString().padLeft(3, '0');
    String rid = '${now.year}${twoDigits(now.month)}${twoDigits(now.day)}${twoDigits(now.hour)}${twoDigits(now.minute)}${twoDigits(now.second)}${threeDigits(now.millisecond)}';

    return {
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
      'rid': prefs.getString('RecordID'),
    };
  }
}
