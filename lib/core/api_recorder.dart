// lib/core/api_recorder.dart
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class ApiRecorder {
  static Future<http.Response> callApi(
      String url, {
        String method = 'GET',
        Map<String, String>? headers,
        Object? body,
      }) async {
    final startTime = DateTime.now();
    print("API call started: $url at $startTime");

    late http.Response response;

    if (method == 'POST') {
      response = await http.post(Uri.parse(url), headers: headers, body: body);
    } else {
      response = await http.get(Uri.parse(url), headers: headers);
    }

    final endTime = DateTime.now();
    print("API call ended: $url at $endTime with status: ${response.statusCode}");

    await _recordCall(url, method, headers, body, response, startTime, endTime);

    return response;
  }

  static Future<void> _recordCall(
      String url,
      String method,
      Map<String, String>? headers,
      Object? body,
      http.Response response,
      DateTime start,
      DateTime end,
      ) async {
    final log =
        "URL: $url, Method: $method, Status: ${response.statusCode}, Duration: ${end.difference(start).inMilliseconds} ms, Time: $start";

    // Print to console
    print("Recorded API call -> $log");

    // Save to local file
    try {
      final directory = await getApplicationDocumentsDirectory();
      final path = directory.path;
      final file = File('$path/api_call_log.txt');

      await file.writeAsString(log + '\n', mode: FileMode.append);
    } catch (e) {
      print("Error writing API log to file: $e");
    }
  }
}
