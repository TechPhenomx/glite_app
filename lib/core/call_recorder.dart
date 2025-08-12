// // lib/call_recorder.dart
// import 'package:flutter_sound/flutter_sound.dart';
// import 'package:permission_handler/permission_handler.dart';
//
// class CallRecorder {
//   final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
//   bool _isRecording = false;
//
//   bool get isRecording => _isRecording;
//
//   Future<void> init() async {
//     await Permission.microphone.request();
//     await Permission.storage.request();
//     await _recorder.openRecorder();
//   }
//
//   Future<void> startRecording(String fileName) async {
//     if (_isRecording) return;
//
//     await _recorder.startRecorder(
//       toFile: fileName,
//       codec: Codec.aacMP4,
//     );
//
//     _isRecording = true;
//   }
//
//   Future<void> stopRecording() async {
//     if (!_isRecording) return;
//
//     await _recorder.stopRecorder();
//     _isRecording = false;
//   }
//
//   void dispose() {
//     _recorder.closeRecorder();
//   }
// }
