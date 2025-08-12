// // lib/call_screen.dart
// import 'package:flutter/material.dart';
// import 'package:agora_rtc_engine/agora_rtc_engine.dart';
// import 'call_recorder.dart';
//
// const String appId = "YOUR_AGORA_APP_ID";
// const String channelName = "testchannel";
// const String token = "YOUR_TEMP_TOKEN";
//
// class CallScreen extends StatefulWidget {
//   @override
//   State<CallScreen> createState() => _CallScreenState();
// }
//
// class _CallScreenState extends State<CallScreen> {
//   final CallRecorder _recorder = CallRecorder();
//   bool _joined = false;
//
//   @override
//   void initState() {
//     super.initState();
//     _initAgora();
//     _recorder.init();
//   }
//
//   Future<void> _initAgora() async {
//     // v6.3.2 → Must call createAgoraRtcEngine() first
//     final engine = createAgoraRtcEngine();
//
//     await engine.initialize(RtcEngineContext(appId: appId));
//
//     // Enable audio only
//     await engine.enableAudio();
//
//     // Set channel profile and role
//     await engine.setChannelProfile(ChannelProfileType.channelProfileLiveBroadcasting);
//     await engine.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
//
//     // Event listener
//     engine.registerEventHandler(
//       RtcEngineEventHandler(
//         onJoinChannelSuccess: (connection, elapsed) {
//           setState(() => _joined = true);
//         },
//         onLeaveChannel: (connection, stats) {
//           setState(() => _joined = false);
//         },
//       ),
//     );
//
//     // Join channel
//     await engine.joinChannel(
//       token: token,
//       channelId: channelName,
//       uid: 0,
//       options: const ChannelMediaOptions(),
//     );
//   }
//
//   @override
//   void dispose() {
//     _recorder.dispose();
//     createAgoraRtcEngine().leaveChannel();
//     createAgoraRtcEngine().release();
//     super.dispose();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: const Text("VoIP Call")),
//       body: Center(
//         child: _joined
//             ? Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             const Text("In Call"),
//             ElevatedButton(
//               onPressed: () {
//                 if (_recorder.isRecording) {
//                   _recorder.stopRecording();
//                   setState(() {});
//                 } else {
//                   _recorder.startRecording("voip_call.aac");
//                   setState(() {});
//                 }
//               },
//               child: Text(
//                 _recorder.isRecording
//                     ? "Stop Recording"
//                     : "Start Recording",
//               ),
//             ),
//           ],
//         )
//             : const Text("Joining call..."),
//       ),
//     );
//   }
// }
