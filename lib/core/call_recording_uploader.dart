import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:file_picker/file_picker.dart';
import 'dart:convert';

class CallRecordingUploader extends StatefulWidget {
  @override
  _CallRecordingUploaderState createState() => _CallRecordingUploaderState();
}

class _CallRecordingUploaderState extends State<CallRecordingUploader> {
  Directory? recordingsDir;
  List<String> uploadedFiles = [];
  TextEditingController pathController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initUploader();
  }

  Future<void> _initUploader() async {
    if (!await Permission.storage.request().isGranted) {
      print('Storage permission denied');
      return;
    }

    recordingsDir = Directory('/Internal Storage/Recordings/Call');

    if (!await recordingsDir!.exists()) {
      await _selectFolderSAF();
    }

    _monitorRecordings();
  }

  Future<void> _selectFolderSAF() async {
    String? selectedPath = await FilePicker.platform.getDirectoryPath();
    if (selectedPath != null) {
      recordingsDir = Directory(selectedPath);
      print('Selected folder: $selectedPath');
    } else {
      print('No folder selected');
    }
  }

  void _setCustomPath() {
    if (pathController.text.isNotEmpty) {
      recordingsDir = Directory(pathController.text);
      _monitorRecordings();
      print('Custom path set: ${pathController.text}');
    }
  }

  void _monitorRecordings() {
    if (recordingsDir == null) return;

    recordingsDir!.watch().listen((event) {
      if (event.type == FileSystemEvent.create) {
        String filePath = event.path;
        if (!uploadedFiles.contains(filePath)) {
          _uploadFileWithMetadata(filePath);
        }
      }
    });
    print('Monitoring recordings in: ${recordingsDir!.path}');
  }

  Future<void> _uploadFileWithMetadata(String filePath) async {
    File file = File(filePath);
    String fileName = path.basename(file.path);
    DateTime createdAt = await file.lastModified();

    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('https://your-server.com/upload'),
      );

      request.files.add(await http.MultipartFile.fromPath('file', file.path));

      // Add metadata as fields
      request.fields['file_name'] = fileName;
      request.fields['created_at'] = createdAt.toIso8601String();

      var response = await request.send();

      if (response.statusCode == 200) {
        print('Uploaded $fileName successfully!');
        uploadedFiles.add(filePath);
      } else {
        print('Failed to upload $fileName, retrying...');
        await Future.delayed(Duration(seconds: 5));
        _uploadFileWithMetadata(filePath);
      }
    } catch (e) {
      print('Error uploading $fileName: $e, retrying...');
      await Future.delayed(Duration(seconds: 5));
      _uploadFileWithMetadata(filePath);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Call Recording Auto Uploader')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: pathController,
              decoration: InputDecoration(
                labelText: 'Custom recordings path (optional)',
              ),
            ),
            SizedBox(height: 10),
            ElevatedButton(
              onPressed: _setCustomPath,
              child: Text('Set Custom Path'),
            ),
            SizedBox(height: 10),
            ElevatedButton(
              onPressed: _selectFolderSAF,
              child: Text('Select Folder (if default inaccessible)'),
            ),
            SizedBox(height: 20),
            Text(
              'Monitoring recordings in: ${recordingsDir?.path ?? 'No folder selected'}',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
