import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../core/websocket_service.dart';
import '../core/ws_api_service.dart';

class WebViewScreen extends StatefulWidget {
  const WebViewScreen({super.key});

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  InAppWebViewController? webViewController;
  bool isLoading = true;
  final FlutterSoundRecorder recorder = FlutterSoundRecorder();

  // Call & recording state
  bool isOnCall = false;
  bool isRecording = false;
  String? recordFilePath;
  String? currentCallRid;
  String? currentCallNumber;
  bool isRecorderReady = false;
  DateTime? recordingStartTime;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeApp();
    });
  }

  Future<void> _initializeApp() async {
    await _requestPermissions();
    await _initializeRecorder();
  }

  @override
  void dispose() {
    if (isRecorderReady) {
      recorder.closeRecorder();
    }
    super.dispose();
  }

  Future<void> _initializeRecorder() async {
    try {
      print("Initializing recorder...");
      final micStatus = await Permission.microphone.status;
      if (!micStatus.isGranted) {
        final micResult = await Permission.microphone.request();
        if (!micResult.isGranted) {
          print('Microphone permission denied');
          return;
        }
      }

      await recorder.openRecorder();
      setState(() => isRecorderReady = true);
      print('✅ Recorder initialized successfully');
    } catch (e) {
      print('❌ Recorder init failed: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Recorder initialization failed: ${e.toString()}')),
      );
    }
  }

  // NEW: Function to get recording directory
  Future<String> getRecordingDirectory() async {
    // Get external storage directory
    Directory? externalDir = await getExternalStorageDirectory();
    if (externalDir == null) {
      throw Exception("External storage not available");
    }

    // Build the required path
    String basePath = '${externalDir.path.split('Android')[0]}glite/CallRecordings';
    final dir = Directory(basePath);

    // Create directory if not exists
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return basePath;
  }

  Future<void> startRecording() async {
    if (!isRecorderReady) {
      print('Recorder not ready');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Audio recorder not ready')),
      );
      return;
    }

    try {
      if (recorder.isRecording) {
        print('Already recording');
        return;
      }

      // Get recording directory - UPDATED
      final recordingDir = await getRecordingDirectory();
      final fileName = 'recording_${DateTime.now().millisecondsSinceEpoch}.aac';
      recordFilePath = '$recordingDir/$fileName';

      print("Starting recording to: $recordFilePath");

      // Start recording
      await recorder.startRecorder(
        toFile: recordFilePath!,
        codec: Codec.aacADTS,
      );

      recordingStartTime = DateTime.now();
      setState(() => isRecording = true);
      print('🎤 Recording started');

      if (currentCallRid != null && currentCallNumber != null) {
        await WsApiService.sendCallEventToWs(
          status: 'RECORDING_STARTED',
          number: currentCallNumber!,
          duration: 0,
          rid: currentCallRid!,
        );
      }
    } catch (e) {
      print('Recording start error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Recording failed: ${e.toString()}')),
      );
    }
  }

  Future<void> stopRecording() async {
    if (!isRecorderReady) return;

    try {
      // FIXED: Change condition to check if NOT recording
      if (!recorder.isRecording) {
        print('No active recording to stop');
        return;
      }

      print("Stopping recording...");
      await recorder.stopRecorder();
      setState(() => isRecording = false);

      int durationSeconds = 0;
      if (recordingStartTime != null) {
        durationSeconds = DateTime.now().difference(recordingStartTime!).inSeconds;
        recordingStartTime = null;
      }

      print('⏹ Recording stopped. Duration: $durationSeconds seconds');

      if (currentCallRid != null && currentCallNumber != null) {
        await WsApiService.sendCallEventToWs(
          status: 'RECORDING_STOPPED',
          number: currentCallNumber!,
          duration: durationSeconds,
          rid: currentCallRid!,
        );
      }

      print('💾 Recording saved at: $recordFilePath');
    } catch (e) {
      print('Recording stop error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("G-Lite")),
      body: Stack(
        children: [
          InAppWebView(
            initialUrlRequest: URLRequest(
                url: WebUri("https://alok.parahittech.com:9095")),
            initialOptions: InAppWebViewGroupOptions(
              crossPlatform: InAppWebViewOptions(
                javaScriptEnabled: true,
                useShouldOverrideUrlLoading: true,
                mediaPlaybackRequiresUserGesture: false,
              ),
              android: AndroidInAppWebViewOptions(
                useHybridComposition: true,
              ),
            ),
            onWebViewCreated: (controller) {
              webViewController = controller;
              _setupHandlers(controller);
            },
            onLoadStop: (controller, url) async {
              setState(() => isLoading = false);
              await _injectLocalStorageListener();
              await _cacheInitialLocalStorage();
            },
            shouldOverrideUrlLoading: (controller, action) async {
              final url = action.request.url.toString();
              if (url.startsWith("tel:")) {
                final Uri uri = Uri.parse(url);
                if (await canLaunchUrl(uri)) {
                  await _handleCallInitiation(url);
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Could not launch dialer")),
                  );
                }
                return NavigationActionPolicy.CANCEL;
              }
              return NavigationActionPolicy.ALLOW;
            },
            onReceivedServerTrustAuthRequest:
                (controller, challenge) async {
              return ServerTrustAuthResponse(
                action: ServerTrustAuthResponseAction.PROCEED,
              );
            },
            androidOnPermissionRequest:
                (controller, origin, resources) async {
              return PermissionRequestResponse(
                resources: resources,
                action: PermissionRequestResponseAction.GRANT,
              );
            },
          ),
          if (isLoading)
            const Center(child: CircularProgressIndicator()),
          if (isOnCall) _buildCallControls(),
        ],
      ),
    );
  }

  Widget _buildCallControls() {
    return Positioned(
      bottom: 30,
      left: 0,
      right: 0,
      child: Container(
        color: Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Center(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 10,
                  spreadRadius: 2,
                )
              ],
            ),
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  currentCallNumber != null
                      ? 'On call with: $currentCallNumber'
                      : 'On call...',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Recording button
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () async {
                          print("Recording button tapped");
                          if (isRecording) {
                            await stopRecording();
                          } else {
                            await startRecording();
                          }
                        },
                        customBorder: const CircleBorder(),
                        child: Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: isRecording ? Colors.red : Colors.blue,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isRecording ? Icons.stop : Icons.mic,
                            color: Colors.white,
                            size: 30,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 20),

                    // End call button
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () async {
                          print("End call button tapped");
                          try {
                            if (isRecording) await stopRecording();
                            setState(() => isOnCall = false);
                          } catch (e) {
                            print("Error ending call: $e");
                          }
                        },
                        customBorder: const CircleBorder(),
                        child: Container(
                          width: 60,
                          height: 60,
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.call_end,
                            color: Colors.white,
                            size: 30,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleCallInitiation(String phoneNumber) async {
    final prefs = await SharedPreferences.getInstance();
    DateTime now = DateTime.now();
    String rid = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}${now.millisecond.toString().padLeft(3, '0')}';

    await prefs.setString('call_rid', rid);
    String cleanedNumber = phoneNumber.replaceFirst("tel:", "");
    await prefs.setString('call_number', cleanedNumber);

    setState(() {
      currentCallRid = rid;
      currentCallNumber = cleanedNumber;
      isOnCall = true;
    });

    await WsApiService.sendCallEventToWs(
      status: 'DIALING',
      number: cleanedNumber,
      duration: 0,
      rid: rid,
    );
  }

  void _setupHandlers(InAppWebViewController controller) {
    controller.addJavaScriptHandler(
      handlerName: 'dialNumberFromSim',
      callback: (args) async {
        if (args.isNotEmpty) {
          String phoneNumber = args[0];
          await _handleCallInitiation(phoneNumber);

          final phoneStatus = await Permission.phone.status;
          if (!phoneStatus.isGranted) {
            final result = await Permission.phone.request();
            if (!result.isGranted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Phone permission not granted")),
              );
              return;
            }
          }

          bool? callResult = await FlutterPhoneDirectCaller.callNumber(phoneNumber);
          if (callResult != true) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Failed to place call")),
            );
          }
        }
      },
    );

    controller.addJavaScriptHandler(
      handlerName: 'localStorageChanged',
      callback: (args) async => await _cacheInitialLocalStorage(),
    );
  }

  Future<void> _injectLocalStorageListener() async {
    if (webViewController == null) return;
    await webViewController!.evaluateJavascript(source: '''
      (function() {
        const originalSetItem = localStorage.setItem;
        localStorage.setItem = function(key, value) {
          originalSetItem.apply(this, arguments);
          window.flutter_inappwebview.callHandler('localStorageChanged');
        };
        const originalRemoveItem = localStorage.removeItem;
        localStorage.removeItem = function(key) {
          originalRemoveItem.apply(this, arguments);
          window.flutter_inappwebview.callHandler('localStorageChanged');
        };
        const originalClear = localStorage.clear;
        localStorage.clear = function() {
          originalClear.apply(this, arguments);
          window.flutter_inappwebview.callHandler('localStorageChanged');
        };
      })();
    ''');
  }

  Future<void> _cacheInitialLocalStorage() async {
    if (webViewController == null) return;
    final keys = [
      'ClientID',
      'CampaignName',
      'Campaign_Type',
      'USER_ID',
      'LoginHourID',
      'UserMode',
      'user_login_id',
      'SIP_ID',
      'skillstr',
      'UserModeIndex',
      'ManualCallerID',
      'RecordID'
    ];
    final prefs = await SharedPreferences.getInstance();
    for (String key in keys) {
      final value = await webViewController!.evaluateJavascript(
          source: 'localStorage.getItem("$key");');
      if (value != null && value is String && value.isNotEmpty) {
        await prefs.setString(key, value);
      }
    }
  }

  Future<void> _requestPermissions() async {
    final statuses = await [
      Permission.phone,
      Permission.microphone,
      Permission.storage,
      Permission.camera,
      Permission.contacts,
      Permission.sms,
      // ADDED: For Android 10+ access to external storage
      Permission.manageExternalStorage,
    ].request();

    if (statuses[Permission.microphone]?.isDenied ?? true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
            Text('Microphone permission required for recording. Please enable in settings.')),
      );
    }

    if (statuses[Permission.phone]?.isDenied ?? true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
            Text('Phone permission required for calling. Please enable in settings.')),
      );
    }

    // ADDED: Check external storage permission
    if (statuses[Permission.manageExternalStorage]?.isDenied ?? true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
            Text('Storage permission required for saving recordings. Please enable in settings.')),
      );
    }
  }
}