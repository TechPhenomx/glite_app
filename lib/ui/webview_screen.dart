import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';
import 'package:flutter_sound/public/flutter_sound_recorder.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/websocket_service.dart';
import '../core/ws_api_service.dart'; // adjust path if needed



class WebViewScreen extends StatefulWidget {
  const WebViewScreen({super.key});

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  InAppWebViewController? webViewController;
  bool isLoading = true;
  final FlutterSoundRecorder recorder = FlutterSoundRecorder();


  @override
  void initState() {
    super.initState();
    _requestPermissions();
    initRecorder();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("G-Lite")),
      body: Stack(
        children: [
          InAppWebView(
            initialUrlRequest: URLRequest(
              url: WebUri("https://alok.parahittech.com:9095"),
            ),
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

            // ✅ Handle SSL errors (bypass)
            onReceivedServerTrustAuthRequest:
                (controller, challenge) async {
              return ServerTrustAuthResponse(
                action: ServerTrustAuthResponseAction.PROCEED,
              );
            },

            // ✅ Auto-grant permissions (camera, mic)
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
        ],
      ),
    );
  }

  void _setupHandlers(InAppWebViewController controller) {
    controller.addJavaScriptHandler(
      handlerName: 'dialNumberFromSim',
      callback: (args) async {
        if (args.isNotEmpty) {
          String phoneNumber = args[0];
          final prefs = await SharedPreferences.getInstance();
          DateTime now = DateTime.now();
          String rid = '${now.year}${now.month.toString().padLeft(2, '0')}${now
              .day.toString().padLeft(2, '0')}${now.hour.toString().padLeft(
              2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second
              .toString().padLeft(2, '0')}${now.millisecond.toString().padLeft(
              3, '0')}';
          await prefs.setString('call_rid', rid);
          String cleanedNumber = phoneNumber.replaceFirst("tel:", "");
          await prefs.setString('call_number', cleanedNumber);
          // await prefs.setBool('was_dialed_from_app', true);

          // 🟢 Send DIALING status here before the call is placed
          await WsApiService.sendCallEventToWs(
            status: 'DIALING',
            number: cleanedNumber,
            duration: 0,
            rid: rid,
          );
          if (!await Permission.phone
              .request()
              .isGranted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Phone permission not granted")),
            );
            return;
          }

          bool? result =
          await FlutterPhoneDirectCaller.callNumber(phoneNumber);
          if (result != true) {
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
        source: 'localStorage.getItem("$key");',
      );
      if (value != null && value is String && value.isNotEmpty) {
        await prefs.setString(key, value);
      }
    }
  }

  Future<void> _requestPermissions() async {
    await [
      Permission.phone,
      Permission.microphone,
      Permission.storage,
      Permission.camera,
      Permission.contacts,
      Permission.sms,
    ].request();
  }

  Future<void> initRecorder() async {
    await Permission.microphone.request();
    await recorder.openRecorder();
  }
}