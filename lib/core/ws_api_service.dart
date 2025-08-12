// ws_api_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WsApiService {
  static Future<void> sendCallEventToWs({
    required String status,
    required String number,
    required int duration,
    required String rid,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      String cleanedNumber = number.replaceAll(RegExp(r'\D'), ''); // Remove non-digits
      if (cleanedNumber.length > 10) {
        cleanedNumber = cleanedNumber.substring(cleanedNumber.length - 10);
      }
      final payload = {
        "type": "agentstatus",
        "status": status,
        "line2": "",
        "phone2": "",
        "phone": cleanedNumber,
        "client_id": prefs.getString('ClientID') ?? "",
        "exten": prefs.getString('SIP_ID') ?? "",
        "campaign": prefs.getString('CampaignName') ?? "",
        "agent": prefs.getString('USER_ID') ?? "",
        "mode": prefs.getString('UserModeIndex') ?? "",
        "user_id": prefs.getString('user_login_id') ?? "",
        "did_number": prefs.getString('ManualCallerID') ?? "",
        "recall": "0",
        "transfer": "0",
        "conference": "0",
        "login_id": prefs.getString('LoginHourID') ?? "",
        "action_id": rid,
        "manual": "1",
        "outbound": "0",
        "inbound": "0",
        "modeduration": duration,
        "skill": prefs.getString('skillstr') ?? "",
        //"skill":  "us-N-1~",
      };

      // Setup custom HttpClient to bypass SSL only in debug mode
      HttpClient httpClient = HttpClient();
      if (kDebugMode) {
        httpClient.badCertificateCallback =
            (X509Certificate cert, String host, int port) => true;
      }

      final ioClient = IOClient(httpClient);

      final response = await ioClient.post(
        Uri.parse('https://alok.parahittech.com:9095/send-to-ws'),
        headers: {
          'Content-Type': 'application/json',
            },
        body: jsonEncode(payload),
      );

     // print('✅ WebSocket API Event Sent');
      //print('Payload: $payload');

      if (response.statusCode != 200) {
        //print("⚠️ WebSocket API Error: ${response.statusCode} ${response.body}");
      }
    } catch (e) {
   //   print('❌ WebSocket API Exception: $e');
    }
  }
}
