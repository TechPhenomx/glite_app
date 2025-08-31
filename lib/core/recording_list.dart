import 'dart:io';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;

// Model class for Recording
class Recording {
  final String name;
  final String path;
  final Duration duration;

  Recording({required this.name, required this.path, required this.duration});
}

// Function to fetch recordings from selected folder
Future<List<Recording>> getRecordings(String folderPath) async {
  final dir = Directory(folderPath);

  if (!await dir.exists()) {
    return []; // If folder doesn’t exist, return empty
  }

  final files = dir.listSync().whereType<File>().toList();

  List<Recording> recordings = files
      .where((file) =>
  file.path.endsWith('.mp3') ||
      file.path.endsWith('.m4a') ||
      file.path.endsWith('.wav'))
      .map((file) => Recording(
    name: file.path.split('/').last,
    path: file.path,
    duration: Duration.zero, // Optional: fetch actual duration if needed
  ))
      .toList();

  return recordings;
}

// Function to upload a single file
Future<void> uploadRecording(String filePath, String uploadUrl) async {
  final file = File(filePath);
  if (!await file.exists()) return;

  final request = http.MultipartRequest('POST', Uri.parse(uploadUrl));
  request.files.add(await http.MultipartFile.fromPath('file', filePath));
  final response = await request.send();

  if (response.statusCode == 200) {
    print('Uploaded ${filePath.split('/').last} successfully');
  } else {
    print('Failed to upload ${filePath.split('/').last}');
  }
}

// Main screen
class RecordingListScreen extends StatefulWidget {
  const RecordingListScreen({super.key});

  @override
  State<RecordingListScreen> createState() => _RecordingListScreenState();
}

class _RecordingListScreenState extends State<RecordingListScreen> {
  List<Recording> recordings = [];
  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _currentPlayingPath;
  String? folderPath;

  // Replace with your server URL
  final String uploadUrl = 'https://yourserver.com/upload';

  @override
  void initState() {
    super.initState();
    _checkPermissionsAndLoad();
  }

  Future<void> _checkPermissionsAndLoad() async {
    // Request storage permission
    if (!await Permission.manageExternalStorage.isGranted) {
      await Permission.manageExternalStorage.request();
    }

    // After permission, ask user to pick folder
    await _pickFolderAndLoad();
  }

  Future<void> _pickFolderAndLoad() async {
    String? selectedFolder = await FilePicker.platform.getDirectoryPath();

    if (selectedFolder != null) {
      folderPath = selectedFolder;
      final recs = await getRecordings(folderPath!);
      setState(() {
        recordings = recs;
      });

      // Automatically upload all recordings
      for (var rec in recordings) {
        uploadRecording(rec.path, uploadUrl);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Recordings uploaded successfully!')),
      );
    }
  }

  void togglePlayPause(String path) async {
    if (_currentPlayingPath == path) {
      await _audioPlayer.pause();
      setState(() {
        _currentPlayingPath = null;
      });
    } else {
      await _audioPlayer.stop();
      await _audioPlayer.play(DeviceFileSource(path));
      setState(() {
        _currentPlayingPath = path;
      });
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Recordings"),
        actions: [
          IconButton(
            icon: const Icon(Icons.folder_open),
            onPressed: _pickFolderAndLoad,
          ),
        ],
      ),
      body: recordings.isEmpty
          ? const Center(child: Text("No recordings found"))
          : ListView.builder(
        itemCount: recordings.length,
        itemBuilder: (context, index) {
          final rec = recordings[index];
          final isPlaying = _currentPlayingPath == rec.path;

          return ListTile(
            leading: const Icon(Icons.mic),
            title: Text(rec.name),
            subtitle: Text("${rec.duration.inSeconds} sec"),
            trailing: IconButton(
              icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
              onPressed: () => togglePlayPause(rec.path),
            ),
          );
        },
      ),
    );
  }
}

void main() {
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: RecordingListScreen(),
  ));
}
