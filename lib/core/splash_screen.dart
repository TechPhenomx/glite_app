import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:file_picker/file_picker.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _initFlow();
  }

  Future<void> _initFlow() async {
    // 2-second splash delay
    await Future.delayed(const Duration(seconds: 2));

    // Request basic permissions
    await [
      Permission.phone,
      Permission.microphone,
      Permission.camera,
    ].request();

    // Request All Files Access (Android 11+)
    if (await Permission.manageExternalStorage.isDenied ||
        await Permission.manageExternalStorage.isPermanentlyDenied) {
      await Permission.manageExternalStorage.request();
    }

    // After permissions, open folder picker
    await _pickFolder();
  }

  Future<void> _pickFolder() async {
    String? selectedDirectory = await FilePicker.platform.getDirectoryPath();

    if (selectedDirectory != null) {
      // Show success message
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Path added successfully')),
      );

      // Navigate to WebView screen after short delay
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/webview');
    } else {
      // User canceled folder selection, you can ask again or exit
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a folder to continue')),
      );

      // Optionally, reopen folder picker
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return;
      _pickFolder();
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
