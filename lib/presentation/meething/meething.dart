import 'package:flutter/material.dart';
import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';
import 'package:zego_uikit_signaling_plugin/zego_uikit_signaling_plugin.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:html' as html;

void main() {
  // Initialize ZegoUIKit
  WidgetsFlutterBinding.ensureInitialized();
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Video Meeting App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const Meething(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class Meething extends StatefulWidget {
  const Meething({super.key});

  @override
  State<Meething> createState() => _MeethingState();
}

class _MeethingState extends State<Meething> {
  // ZegoCloud credentials - replace with your own
  final int appID = 572486457; // Your AppID
  final String appSign = 'edd5ddbb9f97537e492e1cea462226df297fc537f60d2db079463a36f753a011'; // Your AppSign
  
  // User and call details
  late final String userID;
  late final String userName;
  late String callID;
  
  bool isInCall = false;
  bool isInitialized = false;
  String? inviteUrl;
  bool hasCameraPermission = false;
  bool isStartingMeeting = false;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    if (kIsWeb) {
      // For web, we'll request permissions when starting the meeting
      setState(() {
        hasCameraPermission = true;
      });
    } else {
      // For mobile platforms
      final cameraStatus = await Permission.camera.request();
      final microphoneStatus = await Permission.microphone.request();
      
      setState(() {
        hasCameraPermission = cameraStatus.isGranted && microphoneStatus.isGranted;
      });
    }
    
    if (hasCameraPermission) {
      initializeZegoCloud();
    }
  }

  void initializeZegoCloud() {
    // Generate unique user ID and name
    userID = 'user_${DateTime.now().millisecondsSinceEpoch}';
    userName = 'User_${DateTime.now().millisecondsSinceEpoch}';
    callID = 'meeting_${DateTime.now().millisecondsSinceEpoch}';

    // Initialize ZegoUIKitPrebuiltCall
    ZegoUIKit().initLog().then((value) {
      ZegoUIKitPrebuiltCallInvitationService().init(
        appID: appID,
        appSign: appSign,
        userID: userID,
        userName: userName,
        plugins: [ZegoUIKitSignalingPlugin()],
        requireConfig: (ZegoCallInvitationData data) {
          final config = (data.invitees.length > 1)
              ? ZegoUIKitPrebuiltCallConfig.groupVideoCall()
              : ZegoUIKitPrebuiltCallConfig.oneOnOneVideoCall();
          
          // Configure call settings
          config
            ..turnOnCameraWhenJoining = true
            ..turnOnMicrophoneWhenJoining = true
            ..useSpeakerWhenJoining = true;
          
          return config;
        },
      );
      
      setState(() {
        isInitialized = true;
      });
    });
  }

  Future<void> startMeeting() async {
    if (!isInitialized || isStartingMeeting) return;
    
    setState(() {
      isStartingMeeting = true;
    });
    
    if (kIsWeb) {
      // For web, request permissions when starting the meeting
      try {
        final stream = await html.window.navigator.mediaDevices?.getUserMedia({
          'video': true,
          'audio': true
        });
        if (stream != null) {
          stream.getTracks().forEach((track) => track.stop());
          setState(() {
            hasCameraPermission = true;
          });
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please allow camera and microphone access'),
            duration: Duration(seconds: 3),
          ),
        );
        setState(() {
          isStartingMeeting = false;
        });
        return;
      }
    }
    
    setState(() {
      isInCall = true;
      callID = 'meeting_${DateTime.now().millisecondsSinceEpoch}';
      inviteUrl = 'https://your-domain.com/join/$callID';
      isStartingMeeting = false;
    });
  }

  void copyInviteUrl() {
    if (inviteUrl != null) {
      Clipboard.setData(ClipboardData(text: inviteUrl!));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invite URL copied to clipboard')),
      );
    }
  }

  void endCall() {
    setState(() {
      isInCall = false;
      inviteUrl = null;
    });
  }

  @override
  void dispose() {
    ZegoUIKitPrebuiltCallInvitationService().uninit();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Video Meeting'),
        centerTitle: true,
        elevation: 0,
        actions: [
          if (isInCall)
            IconButton(
              icon: const Icon(Icons.person_add),
              onPressed: copyInviteUrl,
              tooltip: 'Invite Participants',
            ),
        ],
      ),
      body: !isInitialized
          ? const Center(child: CircularProgressIndicator())
          : !hasCameraPermission
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.camera_alt,
                        size: 64,
                        color: Colors.red,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Camera and Microphone Access Required',
                        style: TextStyle(fontSize: 18),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: _checkPermissions,
                        child: const Text('Grant Permissions'),
                      ),
                    ],
                  ),
                )
          : isInCall
              ? Stack(
                  children: [
                    ZegoUIKitPrebuiltCall(
                      appID: appID,
                      appSign: appSign,
                      userID: userID,
                      userName: userName,
                      callID: callID,
                      config: ZegoUIKitPrebuiltCallConfig.oneOnOneVideoCall()
                        ..turnOnCameraWhenJoining = true
                        ..turnOnMicrophoneWhenJoining = true
                        ..useSpeakerWhenJoining = true,
                    ),
                    if (inviteUrl != null)
                      Positioned(
                        top: 16,
                        right: 16,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.link, color: Colors.white),
                              const SizedBox(width: 8),
                              Text(
                                'Invite URL: $inviteUrl',
                                style: const TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                )
              : Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.video_camera_front_rounded,
                          size: 100,
                          color: Colors.blue,
                        ),
                        const SizedBox(height: 30),
                        const Text(
                          'Start a Video Meeting',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Column(
                            children: [
                              const Text(
                                'How to use:',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                kIsWeb
                                    ? '1. Click "Start Meeting" to begin\n'
                                      '2. Allow camera/microphone access\n'
                                      '3. Click the person icon to get invite URL\n'
                                      '4. Share the URL with others\n'
                                      '5. Click hang up to end the meeting'
                                    : '1. Click "Start Meeting" to begin\n'
                                      '2. Click the person icon to get invite URL\n'
                                      '3. Share the URL with others\n'
                                      '4. Click hang up to end the meeting',
                                style: const TextStyle(fontSize: 16),
                                textAlign: TextAlign.left,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 40),
                        ElevatedButton(
                          onPressed: isStartingMeeting ? null : startMeeting,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 40,
                              vertical: 16,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isStartingMeeting ? Icons.hourglass_empty : Icons.video_call,
                                size: 28,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                isStartingMeeting ? 'Starting...' : 'Start Meeting',
                                style: const TextStyle(fontSize: 20),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }
}