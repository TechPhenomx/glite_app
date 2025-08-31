import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionScreen extends StatefulWidget {
  const PermissionScreen({super.key});

  @override
  State<PermissionScreen> createState() => _PermissionScreenState();
}

class _PermissionScreenState extends State<PermissionScreen> {
  bool _granted = false;

  Future<void> _requestPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.microphone,
      Permission.storage,
      Permission.phone,
    ].request();

    bool allGranted =
    statuses.values.every((status) => status.isGranted);

    if (allGranted) {
      setState(() {
        _granted = true;
      });
      Navigator.pushReplacementNamed(context, '/webview');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please grant all permissions to continue")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: !_granted
            ? Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "We need permissions to continue",
              style: TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _requestPermissions,
              child: const Text("Grant Permissions"),
            ),
          ],
        )
            : const CircularProgressIndicator(),
      ),
    );
  }
}
