import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:permission_handler/permission_handler.dart';

class WebRTCService {
  static final WebRTCService _instance = WebRTCService._internal();
  factory WebRTCService() => _instance;
  WebRTCService._internal();

  // WebRTC components
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;

  // Socket for signaling (currently using Firestore instead)
  // SocketIO.Socket? _socket;

  // Video renderers
  final RTCVideoRenderer localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer remoteRenderer = RTCVideoRenderer();

  // State management
  bool _isInitialized = false;
  bool _inCall = false;
  bool _isCaller = false;
  String? _currentRoomId;

  // Callbacks
  Function()? onLocalStream;
  Function()? onRemoteStream;
  Function()? onCallEnded;
  Function(String)? onError;

  // ICE servers configuration with Unified Plan
  final Map<String, dynamic> _configuration = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
      {'urls': 'stun:stun2.l.google.com:19302'},
    ],
    'sdpSemantics': 'unified-plan',
  };

  // Request camera and microphone permissions
  Future<bool> requestPermissions() async {
    try {
      if (kDebugMode) print('Requesting camera and microphone permissions...');

      // Check current permission status first
      var cameraStatus = await Permission.camera.status;
      var micStatus = await Permission.microphone.status;

      if (kDebugMode) {
        print('Current camera permission: $cameraStatus');
        print('Current microphone permission: $micStatus');
      }

      // Request permissions if not already granted
      Map<Permission, PermissionStatus> statuses = await [
        Permission.camera,
        Permission.microphone,
      ].request();

      bool cameraGranted =
          statuses[Permission.camera] == PermissionStatus.granted;
      bool micGranted =
          statuses[Permission.microphone] == PermissionStatus.granted;

      if (kDebugMode) {
        print('Camera permission granted: $cameraGranted');
        print('Microphone permission granted: $micGranted');
      }

      if (!cameraGranted || !micGranted) {
        List<String> missingPermissions = [];
        List<String> deniedPermanently = [];

        if (!cameraGranted) {
          missingPermissions.add('Camera');
          if (statuses[Permission.camera] ==
              PermissionStatus.permanentlyDenied) {
            deniedPermanently.add('Camera');
          }
        }
        if (!micGranted) {
          missingPermissions.add('Microphone');
          if (statuses[Permission.microphone] ==
              PermissionStatus.permanentlyDenied) {
            deniedPermanently.add('Microphone');
          }
        }

        String errorMessage;
        if (deniedPermanently.isNotEmpty) {
          errorMessage =
              '${deniedPermanently.join(' and ')} permission permanently denied. Please go to device settings and enable permissions manually.';
        } else {
          errorMessage =
              'Permission denied: ${missingPermissions.join(' and ')} access required for video calls. Please grant permissions and try again.';
        }

        onError?.call(errorMessage);
        return false;
      }

      if (kDebugMode) print('All permissions granted successfully');
      return true;
    } catch (e) {
      if (kDebugMode) print('Permission request error: $e');
      onError?.call('Failed to request permissions: $e');
      return false;
    }
  }

  // Initialize WebRTC
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await localRenderer.initialize();
      await remoteRenderer.initialize();
      _isInitialized = true;
    } catch (e) {
      if (kDebugMode) print('WebRTC initialization error: $e');
      onError?.call('Failed to initialize WebRTC: $e');
    }
  }

  // Create peer connection
  Future<void> _createPeerConnection() async {
    try {
      _peerConnection = await createPeerConnection(_configuration);

      _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
        _sendSignalingMessage({
          'type': 'ice-candidate',
          'candidate': candidate.toMap(),
        });
      };

      _peerConnection!.onTrack = (RTCTrackEvent event) {
        if (event.track.kind == 'video') {
          _remoteStream = event.streams[0];
          remoteRenderer.srcObject = _remoteStream;
          onRemoteStream?.call();
        }
      };

      _peerConnection!.onConnectionState = (RTCPeerConnectionState state) {
        if (kDebugMode) print('Connection state: $state');
        if (state == RTCPeerConnectionState.RTCPeerConnectionStateClosed ||
            state == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
          endCall();
        }
      };
    } catch (e) {
      if (kDebugMode) print('Error creating peer connection: $e');
      onError?.call('Failed to create peer connection: $e');
    }
  }

  // Start local media (camera and microphone)
  Future<void> _startLocalMedia() async {
    try {
      if (kDebugMode) print('Starting local media...');

      // Check permissions again to ensure they're still granted
      bool hasPermissions = await requestPermissions();
      if (!hasPermissions) {
        onError?.call(
            'Camera or microphone permissions are required for video calls');
        return;
      }

      if (kDebugMode) print('Permissions confirmed, requesting user media...');

      // Simplified media constraints that should work on most devices
      final Map<String, dynamic> mediaConstraints = {
        'audio': true,
        'video': {
          'width': {'ideal': 640},
          'height': {'ideal': 480},
          'frameRate': {'ideal': 30},
          'facingMode': 'user',
        }
      };

      _localStream =
          await navigator.mediaDevices.getUserMedia(mediaConstraints);

      if (kDebugMode) print('User media obtained successfully');

      localRenderer.srcObject = _localStream;
      onLocalStream?.call();

      if (_peerConnection != null) {
        // Add tracks individually for Unified Plan
        for (final track in _localStream!.getTracks()) {
          await _peerConnection!.addTrack(track, _localStream!);
        }
        if (kDebugMode) print('Tracks added to peer connection');
      }
    } catch (e) {
      if (kDebugMode) print('Error starting local media: $e');

      // Provide more specific error messages based on the actual error
      String errorMessage = 'Failed to access camera/microphone';

      if (e.toString().toLowerCase().contains('permission') ||
          e.toString().toLowerCase().contains('notallowed')) {
        errorMessage =
            'Camera or microphone permission denied. Please enable permissions in your device settings and restart the app.';
      } else if (e.toString().toLowerCase().contains('notfound') ||
          e.toString().toLowerCase().contains('devicenotfound')) {
        errorMessage = 'Camera or microphone not found on this device.';
      } else if (e
          .toString()
          .toLowerCase()
          .contains('constraintnotsatisfied')) {
        errorMessage = 'Camera settings not supported. Trying fallback...';

        // Try with even simpler constraints as fallback
        try {
          if (kDebugMode) print('Trying fallback media constraints...');
          final Map<String, dynamic> fallbackConstraints = {
            'audio': true,
            'video': true,
          };

          _localStream =
              await navigator.mediaDevices.getUserMedia(fallbackConstraints);
          localRenderer.srcObject = _localStream;
          onLocalStream?.call();

          if (_peerConnection != null) {
            for (final track in _localStream!.getTracks()) {
              await _peerConnection!.addTrack(track, _localStream!);
            }
          }

          if (kDebugMode) print('Fallback media constraints worked');
          return; // Success with fallback
        } catch (fallbackError) {
          if (kDebugMode) print('Fallback also failed: $fallbackError');
          errorMessage =
              'Unable to access camera/microphone with any settings. Error: $fallbackError';
        }
      } else if (e.toString().toLowerCase().contains('overconstrained')) {
        errorMessage = 'Camera settings too restrictive. Please try again.';
      } else {
        errorMessage = 'Camera/microphone access failed: ${e.toString()}';
      }

      onError?.call(errorMessage);
    }
  }

  // Start a call
  Future<void> startCall(String roomId, String appointmentId) async {
    if (!_isInitialized) await initialize();

    _currentRoomId = roomId;
    _isCaller = true;
    _inCall = true;

    try {
      await _createPeerConnection();
      await _startLocalMedia();
      await _connectToSignalingServer(roomId);

      // Create offer
      RTCSessionDescription offer = await _peerConnection!.createOffer();
      await _peerConnection!.setLocalDescription(offer);

      // Send offer through Firestore
      await _sendOfferToFirestore(appointmentId, offer);
    } catch (e) {
      if (kDebugMode) print('Error starting call: $e');
      onError?.call('Failed to start call: $e');
    }
  }

  // Join a call
  Future<void> joinCall(String roomId, String appointmentId) async {
    if (!_isInitialized) await initialize();

    _currentRoomId = roomId;
    _isCaller = false;
    _inCall = true;

    try {
      await _createPeerConnection();
      await _startLocalMedia();
      await _connectToSignalingServer(roomId);

      // Listen for offer from Firestore
      await _listenForOfferFromFirestore(appointmentId);
    } catch (e) {
      if (kDebugMode) print('Error joining call: $e');
      onError?.call('Failed to join call: $e');
    }
  }

  // Send offer through Firestore
  Future<void> _sendOfferToFirestore(
      String appointmentId, RTCSessionDescription offer) async {
    try {
      await FirebaseFirestore.instance
          .collection('webrtc_signals')
          .doc(appointmentId)
          .set({
        'offer': {
          'type': offer.type,
          'sdp': offer.sdp,
        },
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (kDebugMode) print('Error sending offer: $e');
    }
  }

  // Listen for offer from Firestore
  Future<void> _listenForOfferFromFirestore(String appointmentId) async {
    FirebaseFirestore.instance
        .collection('webrtc_signals')
        .doc(appointmentId)
        .snapshots()
        .listen((snapshot) async {
      if (snapshot.exists && snapshot.data() != null) {
        final data = snapshot.data()!;

        if (data.containsKey('offer') && !_isCaller) {
          final offer = data['offer'];
          await _handleOffer(offer);
        }

        if (data.containsKey('answer') && _isCaller) {
          final answer = data['answer'];
          await _handleAnswer(answer);
        }

        if (data.containsKey('iceCandidates')) {
          final candidates = data['iceCandidates'] as List;
          for (var candidateData in candidates) {
            await _handleIceCandidate(candidateData);
          }
        }
      }
    });
  }

  // Handle offer
  Future<void> _handleOffer(Map<String, dynamic> offerData) async {
    try {
      RTCSessionDescription offer = RTCSessionDescription(
        offerData['sdp'],
        offerData['type'],
      );

      await _peerConnection!.setRemoteDescription(offer);

      // Create answer
      RTCSessionDescription answer = await _peerConnection!.createAnswer();
      await _peerConnection!.setLocalDescription(answer);

      // Send answer back through Firestore
      await _sendAnswerToFirestore(_currentRoomId!, answer);
    } catch (e) {
      if (kDebugMode) print('Error handling offer: $e');
    }
  }

  // Send answer through Firestore
  Future<void> _sendAnswerToFirestore(
      String appointmentId, RTCSessionDescription answer) async {
    try {
      await FirebaseFirestore.instance
          .collection('webrtc_signals')
          .doc(appointmentId)
          .update({
        'answer': {
          'type': answer.type,
          'sdp': answer.sdp,
        },
      });
    } catch (e) {
      if (kDebugMode) print('Error sending answer: $e');
    }
  }

  // Handle answer
  Future<void> _handleAnswer(Map<String, dynamic> answerData) async {
    try {
      RTCSessionDescription answer = RTCSessionDescription(
        answerData['sdp'],
        answerData['type'],
      );

      await _peerConnection!.setRemoteDescription(answer);
    } catch (e) {
      if (kDebugMode) print('Error handling answer: $e');
    }
  }

  // Handle ICE candidate
  Future<void> _handleIceCandidate(Map<String, dynamic> candidateData) async {
    try {
      RTCIceCandidate candidate = RTCIceCandidate(
        candidateData['candidate'],
        candidateData['sdpMid'],
        candidateData['sdpMLineIndex'],
      );

      await _peerConnection!.addCandidate(candidate);
    } catch (e) {
      if (kDebugMode) print('Error handling ICE candidate: $e');
    }
  }

  // Connect to signaling server (simplified version using Firestore)
  Future<void> _connectToSignalingServer(String roomId) async {
    // In a production app, you might want to use a dedicated signaling server
    // For now, we'll use Firestore for signaling
    if (kDebugMode) print('Connected to signaling for room: $roomId');
  }

  // Send signaling message
  void _sendSignalingMessage(Map<String, dynamic> message) {
    // Implementation would depend on your signaling server
    // For Firestore-based signaling, you'd update the document
    if (kDebugMode) print('Sending signaling message: $message');
  }

  // Toggle camera
  Future<void> toggleCamera() async {
    if (_localStream != null && _localStream!.getVideoTracks().isNotEmpty) {
      final videoTrack = _localStream!.getVideoTracks().first;
      videoTrack.enabled = !videoTrack.enabled;
    }
  }

  // Toggle microphone
  Future<void> toggleMicrophone() async {
    if (_localStream != null && _localStream!.getAudioTracks().isNotEmpty) {
      final audioTrack = _localStream!.getAudioTracks().first;
      audioTrack.enabled = !audioTrack.enabled;
    }
  }

  // Switch camera
  Future<void> switchCamera() async {
    if (_localStream != null) {
      final videoTrack = _localStream!.getVideoTracks().first;
      await Helper.switchCamera(videoTrack);
    }
  }

  // End call
  Future<void> endCall() async {
    _inCall = false;

    try {
      // Stop all tracks before disposing streams
      if (_localStream != null) {
        for (final track in _localStream!.getTracks()) {
          track.stop();
        }
      }
      if (_remoteStream != null) {
        for (final track in _remoteStream!.getTracks()) {
          track.stop();
        }
      }

      await _localStream?.dispose();
      await _remoteStream?.dispose();
      await _peerConnection?.close();

      _localStream = null;
      _remoteStream = null;
      _peerConnection = null;

      localRenderer.srcObject = null;
      remoteRenderer.srcObject = null;

      // _socket?.disconnect();
      // _socket = null;

      // Clean up Firestore signaling data
      if (_currentRoomId != null) {
        await FirebaseFirestore.instance
            .collection('webrtc_signals')
            .doc(_currentRoomId!)
            .delete();
      }

      _currentRoomId = null;
      onCallEnded?.call();
    } catch (e) {
      if (kDebugMode) print('Error ending call: $e');
    }
  }

  // Dispose resources
  Future<void> dispose() async {
    await endCall();
    await localRenderer.dispose();
    await remoteRenderer.dispose();
    _isInitialized = false;
  }

  // Initiate call to patient
  Future<void> initiateCall({
    required String appointmentId,
    required String patientId,
    required String doctorName,
  }) async {
    try {
      // Create call document in Firestore to notify patient
      await FirebaseFirestore.instance.collection('calls').add({
        'appointmentId': appointmentId,
        'patientId': patientId,
        'doctorName': doctorName,
        'status': 'calling',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (kDebugMode) print('Call initiated for appointment: $appointmentId');
    } catch (e) {
      if (kDebugMode) print('Error initiating call: $e');
      onError?.call('Failed to initiate call');
    }
  }

  // Getters
  bool get isInCall => _inCall;
  bool get isInitialized => _isInitialized;
  MediaStream? get localStream => _localStream;
  MediaStream? get remoteStream => _remoteStream;
}
