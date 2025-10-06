import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../services/webrtc_service.dart';

class VideoCallScreen extends StatefulWidget {
  final String appointmentId;
  final String patientName;
  final bool isDoctorCalling;

  const VideoCallScreen({
    Key? key,
    required this.appointmentId,
    required this.patientName,
    this.isDoctorCalling = false,
  }) : super(key: key);

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  final WebRTCService _webrtcService = WebRTCService();
  bool _isConnected = false;
  bool _isMuted = false;
  bool _isVideoOff = false;
  bool _isInitializing = true;

  @override
  void initState() {
    super.initState();
    _initializeCall();
  }

  Future<void> _initializeCall() async {
    try {
      await _webrtcService.initialize();

      // Set up callbacks
      _webrtcService.onLocalStream = () {
        setState(() {
          _isInitializing = false;
        });
      };

      _webrtcService.onRemoteStream = () {
        setState(() {
          _isConnected = true;
        });
      };

      _webrtcService.onCallEnded = () {
        Navigator.of(context).pop();
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
        if (_isInitializing) {
          Navigator.of(context).pop();
        }
      };

      // Start or join call
      if (widget.isDoctorCalling) {
        await _webrtcService.startCall(
          'room_${widget.appointmentId}',
          widget.appointmentId,
        );
      } else {
        await _webrtcService.joinCall(
          'room_${widget.appointmentId}',
          widget.appointmentId,
        );
      }
    } catch (e) {
      print('Failed to initialize call: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to initialize call: $e'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 5),
        ),
      );
      // Close the screen on initialization failure
      Navigator.of(context).pop();
    } finally {
      // Ensure loading state is cleared
      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _webrtcService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Remote video (full screen)
          if (_isConnected)
            SizedBox.expand(
              child: RTCVideoView(
                _webrtcService.remoteRenderer,
                objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
              ),
            )
          else
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
                          : 'Waiting for ${widget.patientName} to join...',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),

          // Local video (picture-in-picture)
          if (!_isInitializing)
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

          // Top bar with patient info
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
                      widget.patientName.isNotEmpty
                          ? widget.patientName[0].toUpperCase()
                          : 'P',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.patientName,
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
                ],
              ),
            ),
          ),

          // Bottom control bar
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
                        await _webrtcService.endCall();
                        Navigator.of(context).pop();
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
        ],
      ),
    );
  }
}
