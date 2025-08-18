import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:phone_state_background/phone_state_background.dart';
import 'package:path/path.dart' as p;
import 'package:device_info_plus/device_info_plus.dart';

import 'core/websocket_service.dart';
import 'ui/webview_screen.dart';
import 'core/call_handler.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Check & request phone state permission for call background events
  final permission = await PhoneStateBackground.checkPermission();
  if (!permission) {
    await PhoneStateBackground.requestPermissions();
  }

  // Initialize phone state background callback handler
  await PhoneStateBackground.initialize(phoneStateBackgroundCallbackHandler);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'G-Lite',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const SplashScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool folderCreated = false;

  @override
  void initState() {
    super.initState();
    _initSetup();
  }

  Future<void> _initSetup() async {
    // Step 1: Request basic permissions (camera, microphone)
    final statuses = await [
      Permission.camera,
      Permission.microphone,
    ].request();

    if (statuses.values.any((status) => !status.isGranted)) {
      print("⚠️ One or more basic permissions not granted");
    }

    // Step 2: Request storage permission properly depending on Android version
    await _requestStoragePermission();

    // Step 3: Create folder and file in public storage
    await _createPublicFolderAndFile();

    // Step 4: Show splash for a short duration
    await Future.delayed(const Duration(seconds: 2));

    // Step 5: Navigate to WebViewScreen
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const WebViewScreen()),
      );
    }
  }

  Future<void> _requestStoragePermission() async {
    if (!Platform.isAndroid) return;

    int sdkInt = await _getAndroidVersion();

    if (sdkInt >= 30) {
      // Android 11+ → Request MANAGE_EXTERNAL_STORAGE (All Files Access)
      if (!await Permission.manageExternalStorage.isGranted) {
        final status = await Permission.manageExternalStorage.request();
        if (!status.isGranted) {
          print("⚠️ Manage External Storage permission denied. Opening app settings...");
          await openAppSettings();
        }
      }
    } else {
      // Android 10 or below → Request normal storage permission
      if (!await Permission.storage.isGranted) {
        final status = await Permission.storage.request();
        if (!status.isGranted) {
          print("⚠️ Storage permission denied.");
        }
      }
    }
  }

  Future<void> _createPublicFolderAndFile() async {
    try {
      // External storage base path (public storage)
      final basePath = "/storage/emulated/0";
      Directory folder = Directory(p.join(basePath, "G-Lite"));

      if (!await folder.exists()) {
        await folder.create(recursive: true);
        folderCreated = true;
        print("📁 G-Lite folder created at: ${folder.path}");
      } else {
        print("✅ G-Lite folder already exists at: ${folder.path}");
      }

      // Create a text file to verify write access
      File file = File(p.join(folder.path, "output.txt"));
      await file.writeAsString(
        "App initialized at ${DateTime.now()}",
        mode: FileMode.write,
        flush: true,
      );
      print("📄 output.txt created in ${folder.path}");

      if (folderCreated && mounted) {
        _showFolderCreatedDialog();
      }
    } catch (e) {
      print("❌ Error creating folder/file: $e");
    }
  }

  void _showFolderCreatedDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Folder Created"),
        content: const Text("📁 The G-Lite folder has been created successfully!"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  Future<int> _getAndroidVersion() async {
    try {
      if (!Platform.isAndroid) return 0;
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      return androidInfo.version.sdkInt;
    } catch (e) {
      print("Error getting Android version: $e");
      return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text(
          "Loading...",
          style: TextStyle(fontSize: 20),
        ),
      ),
    );
  }
}
