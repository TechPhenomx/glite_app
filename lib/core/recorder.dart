// core/recorder.dart
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_sound/flutter_sound.dart';

class CallRecorder {
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();

  Future<void> startRecording() async {
    try {
      if (!_recorder.isRecording) {
        await _recorder.openRecorder();
        Directory tempDir = await getApplicationDocumentsDirectory();
        String filePath = '${tempDir.path}/call_record_${DateTime.now().millisecondsSinceEpoch}.aac';

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('last_recording_path', filePath);

        await _recorder.startRecorder(
          toFile: filePath,
          codec: Codec.aacADTS,
        );
      }
    } catch (e) {
      print("Error starting recording: $e");
    }
  }

  Future<String?> stopRecording() async {
    try {
      if (_recorder.isRecording) {
        final path = await _recorder.stopRecorder();
        await _recorder.closeRecorder();
        return path;
      }
    } catch (e) {
      print("Error stopping recording: $e");
    }
    return null;
  }
}
