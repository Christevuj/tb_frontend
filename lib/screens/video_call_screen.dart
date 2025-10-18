import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../services/webrtc_service.dart';

class VideoCallScreen extends StatefulWidget {
  final String appointmentId;
  final String patientName;
  final String? doctorName; // Add doctor name parameter
  final bool isDoctorCalling;
  final String? roomId;
  final VoidCallback? onCallEnded;

  const VideoCallScreen({
    super.key,
    required this.appointmentId,
    required this.patientName,
    this.doctorName,
    this.isDoctorCalling = false,
    this.roomId,
    this.onCallEnded,
  });

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  final WebRTCService _webrtcService = WebRTCService();
  bool _isConnected = false;
  bool _isMuted = false;
  bool _isVideoOff = false;
  bool _isInitializing = true;
  bool _callEnded = false;

  String _remoteVideoStatus = '';
  Timer? _remoteVideoStatusTimer;

  @override
  void initState() {
    super.initState();
    // Hide system UI for immersive video call experience
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _initializeCall();

    // Start periodic remote video track status update
    _remoteVideoStatusTimer = Timer.periodic(Duration(seconds: 1), (_) {
      final remote = _webrtcService.remoteRenderer;
      final remoteStream = remote.srcObject;
      String status = '';
      if (remoteStream != null) {
        final videoTracks = remoteStream.getVideoTracks();
        if (videoTracks.isNotEmpty) {
          final t = videoTracks.first;
          status = 'enabled: ${t.enabled}, muted: ${t.muted}';
        } else {
          status = 'no video track';
        }
      } else {
        status = 'no remote stream';
      }
      if (mounted) {
        setState(() {
          _remoteVideoStatus = status;
        });
      }
    });
  }

  Future<void> _initializeCall() async {
    try {
      print('═══════════════════════════════════════════════════');
      print('📱 VideoCallScreen._initializeCall STARTED');
      print('   - isDoctorCalling: ${widget.isDoctorCalling}');
      print('   - appointmentId: ${widget.appointmentId}');
      print('   - roomId: ${widget.roomId}');
      print('═══════════════════════════════════════════════════');

      print('🔄 Initializing WebRTCService...');
      await _webrtcService.initialize();
      print('✅ WebRTCService initialized');

      // Set up callbacks
      _webrtcService.onLocalStream = () {
        setState(() {
          _isInitializing = false;
        });
      };

      _webrtcService.onRemoteStream = () {
        print('📹 onRemoteStream callback triggered');

        // Verify remote stream has video tracks before showing
        final remoteStream = _webrtcService.remoteRenderer.srcObject;
        final localStream = _webrtcService.localRenderer.srcObject;

        if (remoteStream != null) {
          // CRITICAL: Make sure remote stream is NOT the same as local stream
          if (localStream != null && remoteStream.id == localStream.id) {
            print('⚠️ Remote stream is same as local stream - ignoring!');
            return;
          }

          final videoTracks = remoteStream.getVideoTracks();
          print('   Remote stream ID: ${remoteStream.id}');
          print('   Remote stream has ${videoTracks.length} video tracks');

          if (videoTracks.isNotEmpty) {
            for (var track in videoTracks) {
              print(
                  '   Video track: enabled=${track.enabled}, muted=${track.muted}');
            }

            // DON'T set _isConnected here - wait for peer connection state to be "connected"
            print(
                '✅ Remote stream received but waiting for peer connection to establish');
          } else {
            print('⚠️ Remote stream received but no video tracks yet');
          }
        } else {
          print('⚠️ onRemoteStream called but srcObject is null');
        }
      };

      _webrtcService.onConnectionEstablished = () {
        print(
            '🔗 onConnectionEstablished callback triggered - setting _isConnected to true');
        setState(() {
          _isConnected = true;
        });
        print('🔗 UI state updated - _isConnected: $_isConnected');
      };

      _webrtcService.onCallEnded = () {
        if (mounted) {
          print('Call ended, navigating back...');
          _handleCallEnd();
        }
      };

      _webrtcService.onError = (error) {
        print('WebRTC Error: $error');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Call error: $error'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Dismiss',
              textColor: Colors.white,
              onPressed: () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
              },
            ),
          ),
        );

        // If error during initialization, close the screen
        if (_isInitializing && mounted) {
          Navigator.of(context).pop();
        }
      };

      // Start or join call
      String actualRoomId = widget.roomId ?? 'room_${widget.appointmentId}';

      print(
          '🔧 VideoCallScreen - About to ${widget.isDoctorCalling ? "start" : "join"} call');
      print('   - isDoctorCalling: ${widget.isDoctorCalling}');
      print('   - actualRoomId: $actualRoomId');
      print('   - appointmentId: ${widget.appointmentId}');

      if (widget.isDoctorCalling) {
        print('🏥 DOCTOR: Calling startCall...');
        await _webrtcService.startCall(
          actualRoomId,
          widget.appointmentId,
          userId: 'doctor',
        );
        print('🏥 DOCTOR: startCall completed');
      } else {
        print('🏥 PATIENT: Calling joinCall...');
        await _webrtcService.joinCall(
          actualRoomId,
          widget.appointmentId,
          userId: 'patient',
        );
        print('🏥 PATIENT: joinCall completed');
      }
    } catch (e) {
      print('💥 CRITICAL ERROR in _initializeCall: $e');
      print('   Stack trace: ${StackTrace.current}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to initialize call: $e'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 5),
        ),
      );
      // Close the screen on initialization failure
      if (mounted) {
        Navigator.of(context).pop();
      }
    } finally {
      // Ensure loading state is cleared
      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
    }
  }

  Future<void> _handleCallEnd() async {
    if (_callEnded) return; // Prevent multiple calls

    print('_handleCallEnd called');

    // Restore system UI when call ends
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    setState(() {
      _callEnded = true;
    });

    // End the WebRTC call first to prevent disposal errors
    try {
      print('Ending WebRTC call...');
      await _webrtcService.endCall();
      print('WebRTC call ended successfully');
    } catch (e) {
      print('Error ending WebRTC call: $e');
    }

    // Show call ended message briefly before navigating back
    print('Showing call ended message...');
    await Future.delayed(
        Duration(seconds: 2)); // Longer delay to see the message

    if (mounted) {
      print('Widget is mounted, attempting navigation...');

      // Call the callback if provided
      widget.onCallEnded?.call();

      print('About to call Navigator.pop()');
      Navigator.of(context).pop();
      print('Navigator.pop() called successfully');
    } else {
      print('Widget is not mounted, skipping navigation');
    }
  }

  @override
  void dispose() {
    print('VideoCallScreen dispose() called');
    // Restore system UI when leaving video call
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    // End the call - DON'T dispose WebRTCService (it's a singleton)
    if (!_callEnded) {
      _webrtcService.endCall().catchError((e) {
        print('Error ending call in dispose: $e');
      });
    }

    // Note: We don't call _webrtcService.dispose() because:
    // 1. WebRTCService is a singleton shared across the app
    // 2. We want to be able to rejoin calls without reinitializing
    // 3. Only endCall() should be called to clean up call-specific resources

    _remoteVideoStatusTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Remote video (full screen)
          if (_isConnected && !_callEnded)
            SizedBox.expand(
              child: Builder(builder: (context) {
                final renderer = _webrtcService.remoteRenderer;
                final srcObject = renderer.srcObject;
                print('📺 Building remote video view:');
                print('   - renderer srcObject: ${srcObject?.id}');
                if (srcObject != null) {
                  print(
                      '   - video tracks: ${srcObject.getVideoTracks().length}');
                  print(
                      '   - audio tracks: ${srcObject.getAudioTracks().length}');
                  for (var track in srcObject.getVideoTracks()) {
                    print(
                        '   - video track enabled: ${track.enabled}, muted: ${track.muted}');
                  }
                }
                return RTCVideoView(
                  renderer,
                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                  mirror: false, // Don't mirror remote video
                );
              }),
            )
          else if (!_callEnded)
            Container(
              color: Colors.grey.shade800,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 20),
                    Text(
                      _isInitializing
                          ? 'Initializing call...'
                          : widget.isDoctorCalling
                              ? 'Waiting for ${widget.patientName} to join...'
                              : 'Joining call with doctor...',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),

          // Local video (picture-in-picture)
          if (!_isInitializing && !_callEnded)
            Positioned(
              top: 50,
              right: 20,
              child: Container(
                width: 120,
                height: 160,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: _isVideoOff
                      ? Container(
                          color: Colors.grey.shade800,
                          child: Icon(
                            Icons.videocam_off,
                            color: Colors.white,
                            size: 40,
                          ),
                        )
                      : RTCVideoView(
                          _webrtcService.localRenderer,
                          mirror: true,
                          objectFit:
                              RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                        ),
                ),
              ),
            ),

          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(20, 50, 20, 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.7),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.blue,
                    child: Text(
                      widget.isDoctorCalling
                          ? (widget.doctorName?.isNotEmpty == true
                              ? widget.doctorName![0].toUpperCase()
                              : 'D')
                          : (widget.patientName.isNotEmpty
                              ? widget.patientName[0].toUpperCase()
                              : 'P'),
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.isDoctorCalling
                              ? (widget.doctorName ?? 'Doctor')
                              : widget.patientName,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          _isConnected ? 'Connected' : 'Connecting...',
                          style: TextStyle(
                            color: _isConnected ? Colors.green : Colors.orange,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom control bar
          if (!_callEnded)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.fromLTRB(20, 20, 20, 40),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withOpacity(0.8),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Mute button
                    CircleAvatar(
                      radius: 25,
                      backgroundColor: _isMuted
                          ? Colors.red.withOpacity(0.8)
                          : Colors.white.withOpacity(0.2),
                      child: IconButton(
                        icon: Icon(
                          _isMuted ? Icons.mic_off : Icons.mic,
                          color: Colors.white,
                          size: 24,
                        ),
                        onPressed: () async {
                          await _webrtcService.toggleMicrophone();
                          setState(() {
                            _isMuted = !_isMuted;
                          });
                        },
                      ),
                    ),

                    // End call button
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: Colors.red,
                      child: IconButton(
                        icon: Icon(
                          Icons.call_end,
                          color: Colors.white,
                          size: 28,
                        ),
                        onPressed: () async {
                          print('End call button pressed');
                          try {
                            await _webrtcService.endCall();
                            await _handleCallEnd();
                          } catch (e) {
                            print('Error ending call: $e');
                            // Force navigation even if there was an error
                            if (mounted) {
                              _handleCallEnd();
                            }
                          }
                        },
                      ),
                    ),

                    // Video toggle button
                    CircleAvatar(
                      radius: 25,
                      backgroundColor: _isVideoOff
                          ? Colors.red.withOpacity(0.8)
                          : Colors.white.withOpacity(0.2),
                      child: IconButton(
                        icon: Icon(
                          _isVideoOff ? Icons.videocam_off : Icons.videocam,
                          color: Colors.white,
                          size: 24,
                        ),
                        onPressed: () async {
                          await _webrtcService.toggleCamera();
                          setState(() {
                            _isVideoOff = !_isVideoOff;
                          });
                        },
                      ),
                    ),

                    // Switch camera button
                    CircleAvatar(
                      radius: 25,
                      backgroundColor: Colors.white.withOpacity(0.2),
                      child: IconButton(
                        icon: Icon(
                          Icons.switch_camera,
                          color: Colors.white,
                          size: 24,
                        ),
                        onPressed: () async {
                          await _webrtcService.switchCamera();
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ...existing code...
        ],
      ),
    );
  }
}
