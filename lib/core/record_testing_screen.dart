import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class RecordTestScreen extends StatefulWidget {
  @override
  _RecordTestScreenState createState() => _RecordTestScreenState();
}

class _RecordTestScreenState extends State<RecordTestScreen> {
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  bool _isRecorderInitialized = false;
  bool _isRecording = false;
  String? _recordedFilePath;

  @override
  void initState() {
    super.initState();
    _initRecorder();
  }

  Future<void> _initRecorder() async {
    final micStatus = await Permission.microphone.request();
    if (micStatus != PermissionStatus.granted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Microphone permission is required')),
      );
      return;
    }
    await _recorder.openRecorder();
    _isRecorderInitialized = true;
    setState(() {});
  }

  Future<void> _startRecording() async {
    if (!_isRecorderInitialized) return;
    final dir = await getApplicationDocumentsDirectory();
    final path = '${dir.path}/test_record_${DateTime.now().millisecondsSinceEpoch}.wav';

    await _recorder.startRecorder(
      toFile: path,
      codec: Codec.pcm16WAV,
      audioSource: AudioSource.microphone,
    );
    setState(() {
      _isRecording = true;
      _recordedFilePath = null;
    });
    print('Recording started');
  }

  Future<void> _stopRecording() async {
    if (!_isRecorderInitialized || !_isRecording) return;
    final path = await _recorder.stopRecorder();
    setState(() {
      _isRecording = false;
      _recordedFilePath = path;
    });
    print('Recording stopped, saved at $path');
  }

  @override
  void dispose() {
    _recorder.closeRecorder();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Record Test')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            ElevatedButton(
              onPressed: _isRecording ? _stopRecording : _startRecording,
              child: Text(_isRecording ? 'Stop Recording' : 'Start Recording (5s)'),
            ),
            SizedBox(height: 20),
            if (_isRecording) Text('Recording...'),
            if (_recordedFilePath != null) ...[
              Text('Recorded file path:'),
              SelectableText(_recordedFilePath!),
            ],
          ],
        ),
      ),
    );
  }
}
