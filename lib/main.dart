import 'package:flutter/material.dart';
import 'package:glite/core/permission_screen.dart';
import 'package:glite/ui/webview_screen.dart';
import 'package:glite/core/splash_screen.dart';

import 'core/recording_list.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Glite App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const SplashScreen(),
      routes: {
        '/permission': (context) => const PermissionScreen(),
        '/webview': (context) => const WebViewScreen(),
        '/recording_list': (context) => const RecordingListScreen(),
      },
    );
  }
}
