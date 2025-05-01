import 'package:flutter/material.dart';
import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';
import 'package:zego_uikit_signaling_plugin/zego_uikit_signaling_plugin.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

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
      // For web, we'll assume permissions are granted
      setState(() {
        hasCameraPermission = true;
      });
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
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Camera and microphone access required',
                        style: TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _checkPermissions,
                        child: const Text('Grant Permissions'),
                      ),
                    ],
                  ),
                )
              : Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (!isInCall) ...[
                        ElevatedButton.icon(
                          onPressed: startMeeting,
                          icon: const Icon(Icons.video_call),
                          label: const Text('Start Meeting'),
                        ),
                      ] else ...[
                        const Text('Meeting in progress...'),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: endCall,
                          icon: const Icon(Icons.call_end),
                          label: const Text('End Meeting'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
    );
  }
}