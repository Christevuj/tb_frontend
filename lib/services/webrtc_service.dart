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
  String? _currentAppointmentId; // Track current appointment ID
  bool _permissionsGranted = false;
  DateTime? _lastPermissionCheck;
  bool _isMediaActive = false;
  String? _activeUserId; // Track which user has active media
  bool _offerProcessed = false; // Track if offer has been processed
  bool _answerProcessed = false; // Track if answer has been processed
  int _processedIceCandidatesCount =
      0; // Track how many ICE candidates have been processed
  List<RTCIceCandidate> _pendingIceCandidates =
      []; // Queue for ICE candidates received before remote description
  bool _remoteDescriptionSet =
      false; // Track if remote description has been set

  // Test mode for single device development
  static bool isTestMode = kDebugMode; // Enable in debug mode
  bool _testModeActive = false;

  // Callbacks
  Function()? onLocalStream;
  Function()? onRemoteStream;
  Function()? onConnectionEstablished;
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
  Future<bool> requestPermissions({bool forceCheck = false}) async {
    try {
      // Use cached result if recent and not forcing a new check
      if (!forceCheck &&
          _permissionsGranted &&
          _lastPermissionCheck != null &&
          DateTime.now().difference(_lastPermissionCheck!).inMinutes < 5) {
        if (kDebugMode) print('✅ Using cached permission result');
        return true;
      }

      if (kDebugMode)
        print('🔐 Requesting camera and microphone permissions...');

      // Check current permission status first
      var cameraStatus = await Permission.camera.status;
      var micStatus = await Permission.microphone.status;

      if (kDebugMode) {
        print('📋 Current camera permission: $cameraStatus');
        print('📋 Current microphone permission: $micStatus');
      }

      // If permissions are already granted, return true
      if (cameraStatus == PermissionStatus.granted &&
          micStatus == PermissionStatus.granted) {
        if (kDebugMode) print('✅ Permissions already granted');
        _permissionsGranted = true;
        _lastPermissionCheck = DateTime.now();
        return true;
      }

      // For Android 13+ (API 33+), we also need to check notification permission for better UX
      List<Permission> permissionsToRequest = [
        Permission.camera,
        Permission.microphone,
      ];

      // Request permissions if not already granted
      if (kDebugMode) print('🔄 Requesting permissions...');
      Map<Permission, PermissionStatus> statuses =
          await permissionsToRequest.request();

      bool cameraGranted =
          statuses[Permission.camera] == PermissionStatus.granted;
      bool micGranted =
          statuses[Permission.microphone] == PermissionStatus.granted;

      if (kDebugMode) {
        print('📊 Camera permission granted: $cameraGranted');
        print('📊 Microphone permission granted: $micGranted');
        print(
            '🔍 Detailed status - Camera: ${statuses[Permission.camera]}, Microphone: ${statuses[Permission.microphone]}');
      }

      bool allGranted = cameraGranted && micGranted;
      _permissionsGranted = allGranted;
      _lastPermissionCheck = DateTime.now();

      if (!allGranted) {
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

        if (kDebugMode) print('Permission error: $errorMessage');
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
    try {
      if (kDebugMode) print('🔄 Initializing WebRTC renderers...');

      // Check if renderers are already initialized and valid
      bool localNeedsInit = false;
      bool remoteNeedsInit = false;

      try {
        // Test if renderer is valid by checking its internal state
        if (localRenderer.srcObject == null && !_isInitialized) {
          localNeedsInit = true;
        }
      } catch (e) {
        localNeedsInit = true;
      }

      try {
        if (remoteRenderer.srcObject == null && !_isInitialized) {
          remoteNeedsInit = true;
        }
      } catch (e) {
        remoteNeedsInit = true;
      }

      // Initialize only if needed
      if (localNeedsInit) {
        if (kDebugMode) print('🔄 Initializing local renderer...');
        await localRenderer.initialize();
      }

      if (remoteNeedsInit) {
        if (kDebugMode) print('🔄 Initializing remote renderer...');
        await remoteRenderer.initialize();
        // Ensure remote renderer is explicitly set to null until we get actual remote stream
        remoteRenderer.srcObject = null;
        if (kDebugMode)
          print(
              '🔒 Remote renderer explicitly set to null until remote stream arrives');
      }

      if (kDebugMode) print('✅ WebRTC renderers initialized successfully');
      _isInitialized = true;
    } catch (e) {
      if (kDebugMode) print('❌ WebRTC initialization error: $e');
      onError?.call('Failed to initialize WebRTC: $e');
      throw e; // Re-throw to handle in calling code
    }
  }

  // Check if media is available for this user
  Future<bool> _canAccessMedia(String userId) async {
    if (!_isMediaActive) {
      if (kDebugMode)
        print('✅ Media not active, access granted for user: $userId');
      return true;
    }

    if (_activeUserId == userId) {
      if (kDebugMode) print('✅ User $userId already has media access');
      return true;
    }

    if (kDebugMode)
      print(
          '⚠️ Media already active for user: $_activeUserId, denying access to: $userId');
    return false;
  }

  // Release media access for this user
  void _releaseMediaAccess(String userId) {
    if (_activeUserId == userId) {
      _isMediaActive = false;
      _activeUserId = null;
      if (kDebugMode) print('✅ Media access released for user: $userId');
    }
  }

  // Acquire media access for this user
  void _acquireMediaAccess(String userId) {
    _isMediaActive = true;
    _activeUserId = userId;
    if (kDebugMode) print('✅ Media access acquired for user: $userId');
  }

  // Create peer connection
  Future<void> _createPeerConnection() async {
    try {
      if (kDebugMode) print('🔄 Creating peer connection...');
      _peerConnection = await createPeerConnection(_configuration);

      _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
        if (kDebugMode)
          print('🧊 ICE candidate generated: ${candidate.candidate}');

        // Send ICE candidate to Firestore for the other peer
        if (_currentAppointmentId != null && candidate.candidate != null) {
          _sendIceCandidate(_currentAppointmentId!, candidate);
        }
      };

      // Monitor ICE gathering state changes
      _peerConnection!.onIceGatheringState = (RTCIceGatheringState state) {
        if (kDebugMode) {
          print('🧊 ICE gathering state changed: $state');
        }
      };

      // Monitor ICE connection state changes
      _peerConnection!.onIceConnectionState = (RTCIceConnectionState state) {
        if (kDebugMode) {
          print('🧊 ICE connection state changed: $state');
        }
      };

      // Use onAddStream (older but more reliable API, especially on Android)
      _peerConnection!.onAddStream = (MediaStream stream) {
        if (kDebugMode) {
          print('═══════════════════════════════════════════════════');
          print('📹 ON ADD STREAM EVENT FIRED (Legacy API)');
          print('   Stream id: ${stream.id}');
          print('   Audio tracks: ${stream.getAudioTracks().length}');
          print('   Video tracks: ${stream.getVideoTracks().length}');

          // Log track details
          for (var track in stream.getTracks()) {
            print(
                '   Track: ${track.kind} - enabled: ${track.enabled}, muted: ${track.muted}, id: ${track.id}');
          }
          print('═══════════════════════════════════════════════════');
        }

        _remoteStream = stream;

        // Ensure all remote tracks are enabled
        for (var track in stream.getTracks()) {
          track.enabled = true;
          if (kDebugMode) {
            print('✅ Enabled remote ${track.kind} track');
          }
        }

        // Safely set remote renderer source object
        try {
          remoteRenderer.srcObject = _remoteStream;
          if (kDebugMode)
            print('✅ Remote renderer source object set via onAddStream');
        } catch (rendererError) {
          if (kDebugMode) {
            print('⚠️ Remote renderer error, reinitializing: $rendererError');
          }
          remoteRenderer.initialize().then((_) {
            remoteRenderer.srcObject = _remoteStream;
            if (kDebugMode) {
              print(
                  '✅ Remote renderer source object set after reinitialization');
            }
          });
        }

        onRemoteStream?.call();
      };

      // Also keep onTrack for newer implementations
      _peerConnection!.onTrack = (RTCTrackEvent event) {
        if (kDebugMode) {
          print('📹 Remote track received via onTrack:');
          print('   Kind: ${event.track.kind}');
          print('   Enabled: ${event.track.enabled}');
          print('   Muted: ${event.track.muted}');
          print('   Streams: ${event.streams.length}');
        }

        // Process all tracks, not just video
        if (event.streams.isNotEmpty) {
          final stream = event.streams[0];

          // Update remote stream if not set or if it's a different stream
          if (_remoteStream == null || _remoteStream!.id != stream.id) {
            if (kDebugMode) print('🔄 Setting remote stream from onTrack');
            _remoteStream = stream;

            // Enable the track
            event.track.enabled = true;
            if (kDebugMode) print('✅ Enabled ${event.track.kind} track');

            // Set remote renderer source object (only for video)
            if (event.track.kind == 'video') {
              try {
                remoteRenderer.srcObject = _remoteStream;
                if (kDebugMode)
                  print('✅ Remote renderer source object set via onTrack');
              } catch (rendererError) {
                if (kDebugMode)
                  print(
                      '⚠️ Remote renderer error, reinitializing: $rendererError');
                remoteRenderer.initialize().then((_) {
                  remoteRenderer.srcObject = _remoteStream;
                  if (kDebugMode)
                    print(
                        '✅ Remote renderer source object set after reinitialization');
                });
              }

              onRemoteStream?.call();
            }
          }
        }
      };

      _peerConnection!.onConnectionState = (RTCPeerConnectionState state) {
        if (kDebugMode) print('🔗 Connection state changed: $state');
        if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
          if (kDebugMode) print('✅ Peer connection established successfully!');
          onConnectionEstablished?.call();
        } else if (state ==
            RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
          if (kDebugMode) print('❌ Peer connection failed!');
          onError?.call('Video call connection failed');
          endCall();
        } else if (state ==
            RTCPeerConnectionState.RTCPeerConnectionStateClosed) {
          if (kDebugMode) print('📴 Peer connection closed');
          endCall();
        }
      };

      if (kDebugMode) print('✅ Peer connection created successfully');

      // Wait for native initialization to complete
      // On some Android devices, the signaling state property isn't immediately available
      await Future.delayed(const Duration(milliseconds: 200));

      if (kDebugMode) {
        final state = _peerConnection?.signalingState;
        print('🔍 Signaling state after initialization: $state');
      }
    } catch (e) {
      if (kDebugMode) print('❌ Error creating peer connection: $e');
      onError?.call('Failed to create peer connection: $e');
    }
  }

  // Start local media (camera and microphone)
  Future<void> _startLocalMedia({String? userId}) async {
    try {
      if (kDebugMode)
        print('🎥 Starting local media for user: ${userId ?? "unknown"}...');

      // Ensure WebRTC is properly initialized first
      if (!_isInitialized) {
        if (kDebugMode) print('🔄 WebRTC not initialized, initializing now...');
        await initialize();
      }

      // Check if media is already active for another user
      if (_isMediaActive && _activeUserId != userId) {
        if (kDebugMode)
          print('⚠️ Media already active for $_activeUserId, waiting...');

        // Wait a bit and try again (graceful retry)
        await Future.delayed(Duration(milliseconds: 1000));

        if (_isMediaActive && _activeUserId != userId) {
          throw Exception(
              'Camera/microphone is already in use by another session. Please wait for the other session to end.');
        }
      }

      // Acquire media access for this user
      if (userId != null) {
        _acquireMediaAccess(userId);
      }

      // Only check permissions if we don't have a recent successful check
      if (!_permissionsGranted ||
          _lastPermissionCheck == null ||
          DateTime.now().difference(_lastPermissionCheck!).inMinutes > 5) {
        if (kDebugMode)
          print('🔄 Re-checking permissions before media access...');
        bool hasPermissions = await requestPermissions();
        if (!hasPermissions) {
          if (userId != null) _releaseMediaAccess(userId);
          onError?.call(
              'Camera or microphone permissions are required for video calls');
          return;
        }
      } else {
        if (kDebugMode)
          print('✅ Using cached permissions, proceeding with media access...');
      }

      if (kDebugMode)
        print('🔒 Permissions confirmed, requesting user media...');

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

      if (kDebugMode)
        print(
            '📋 Attempting to get user media with constraints: $mediaConstraints');

      _localStream =
          await navigator.mediaDevices.getUserMedia(mediaConstraints);

      if (kDebugMode) print('✅ User media obtained successfully');

      // Explicitly enable all tracks
      if (_localStream != null) {
        for (final track in _localStream!.getTracks()) {
          track.enabled = true;
          if (kDebugMode) {
            print(
                '✅ Track enabled: ${track.kind} - enabled: ${track.enabled}, muted: ${track.muted}');
          }
        }
      }

      // Set the source object
      if (kDebugMode) print('🔄 Setting local renderer source object...');
      try {
        localRenderer.srcObject = _localStream;
        if (kDebugMode) print('✅ Local renderer source object set');
      } catch (rendererError) {
        if (kDebugMode)
          print(
              '⚠️ Error setting renderer source, reinitializing: $rendererError');
        await localRenderer.initialize();
        localRenderer.srcObject = _localStream;
        if (kDebugMode)
          print('✅ Local renderer source object set after reinitialization');
      }

      onLocalStream?.call();

      if (_peerConnection != null) {
        // Add tracks individually for Unified Plan
        for (final track in _localStream!.getTracks()) {
          await _peerConnection!.addTrack(track, _localStream!);
          if (kDebugMode) {
            print(
                '✅ Added ${track.kind} track to peer connection - enabled: ${track.enabled}');
          }
        }
        if (kDebugMode) print('✅ All tracks added to peer connection');
      }
    } catch (e) {
      if (kDebugMode) print('❌ Error starting local media: $e');

      // Reset permission cache on media error
      _permissionsGranted = false;
      _lastPermissionCheck = null;

      // Provide more specific error messages based on the actual error
      String errorMessage = 'Failed to access camera/microphone';

      if (e.toString().toLowerCase().contains('permission') ||
          e.toString().toLowerCase().contains('notallowed')) {
        errorMessage =
            'Camera or microphone permission denied. Please enable permissions in your device settings and restart the app.';
      } else if (e.toString().toLowerCase().contains('notfound') ||
          e.toString().toLowerCase().contains('devicenotfound')) {
        errorMessage = 'Camera or microphone not found on this device.';
      } else if (e.toString().toLowerCase().contains('srcobject') ||
          e.toString().toLowerCase().contains('renderer') ||
          e.toString().toLowerCase().contains('disposed')) {
        errorMessage = 'Video renderer was disposed. Reinitializing...';

        // Renderer was disposed, need to dispose and reinitialize
        try {
          if (kDebugMode)
            print('🔄 Disposing and reinitializing disposed renderers...');

          // Dispose existing renderers
          try {
            await localRenderer.dispose();
          } catch (_) {}
          try {
            await remoteRenderer.dispose();
          } catch (_) {}

          // Initialize them again
          await localRenderer.initialize();
          await remoteRenderer.initialize();
          _isInitialized = true;

          if (_localStream != null) {
            localRenderer.srcObject = _localStream;
            onLocalStream?.call();
            if (kDebugMode) print('✅ Renderer reinitialization successful');
            return; // Success after reinitialization
          }
        } catch (reinitError) {
          if (kDebugMode)
            print('❌ Renderer reinitialization failed: $reinitError');
          errorMessage = 'Video renderer failed to reinitialize: $reinitError';
        }
      } else if (e
          .toString()
          .toLowerCase()
          .contains('constraintnotsatisfied')) {
        errorMessage = 'Camera settings not supported. Trying fallback...';

        // Try with even simpler constraints as fallback
        try {
          if (kDebugMode) print('🔄 Trying fallback media constraints...');
          final Map<String, dynamic> fallbackConstraints = {
            'audio': true,
            'video': true,
          };

          _localStream =
              await navigator.mediaDevices.getUserMedia(fallbackConstraints);

          // Try setting renderer source with fallback constraints
          try {
            localRenderer.srcObject = _localStream;
          } catch (rendererError) {
            await localRenderer.initialize();
            localRenderer.srcObject = _localStream;
          }

          onLocalStream?.call();

          if (_peerConnection != null) {
            for (final track in _localStream!.getTracks()) {
              await _peerConnection!.addTrack(track, _localStream!);
            }
          }

          if (kDebugMode) print('✅ Fallback media constraints worked');
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

      // Release media access on error
      if (_activeUserId != null) {
        _releaseMediaAccess(_activeUserId!);
      }

      onError?.call(errorMessage);
    }
  }

  // Start a call
  Future<void> startCall(String roomId, String appointmentId,
      {String? userId}) async {
    try {
      if (kDebugMode)
        print(
            '🚀 Starting call for room: $roomId by user: ${userId ?? "doctor"}');

      // Check if we need to clear old Firestore data
      // This allows either party to start the call first
      await _clearFirestoreSignalingIfNeeded(appointmentId);

      // Ensure clean state before starting
      if (_peerConnection != null) {
        if (kDebugMode)
          print('🧹 Cleaning up existing connection before start...');
        await _peerConnection!.close();
        _peerConnection = null;
      }

      // Ensure proper initialization
      if (!_isInitialized) {
        if (kDebugMode) print('🔄 Initializing WebRTC for call start...');
        await initialize();
      }

      _currentRoomId = roomId;
      _currentAppointmentId = appointmentId;
      _isCaller = true;
      _inCall = true;
      _offerProcessed = false; // Reset for new call
      _answerProcessed = false; // Reset for new call
      _processedIceCandidatesCount = 0; // Reset ICE candidate counter
      _remoteDescriptionSet = false; // Reset remote description flag
      _pendingIceCandidates.clear(); // Clear any pending ICE candidates

      await _createPeerConnection();
      await _startLocalMedia(userId: userId ?? 'doctor');
      await _connectToSignalingServer(roomId);

      // Ensure local tracks are present before creating offer
      if (_localStream != null && _peerConnection != null) {
        final senders = await _peerConnection!.getSenders();
        if (kDebugMode) {
          print('🔍 Verifying local tracks before creating offer:');
          print(
              '   - Local stream has ${_localStream!.getVideoTracks().length} video tracks');
          print(
              '   - Local stream has ${_localStream!.getAudioTracks().length} audio tracks');
          print('   - Peer connection has ${senders.length} senders');
        }

        // If no senders, add tracks
        if (senders.isEmpty) {
          if (kDebugMode) print('⚠️ No senders found! Adding local tracks...');
          for (final track in _localStream!.getTracks()) {
            await _peerConnection!.addTrack(track, _localStream!);
          }
          if (kDebugMode) print('✅ Local tracks added to peer connection');
        }
      }

      // Create offer
      if (kDebugMode) print('🔄 Creating call offer...');

      // Check if peer connection is valid
      if (_peerConnection == null) {
        if (kDebugMode) print('❌ Peer connection is null, cannot create offer');
        throw Exception('Peer connection not initialized');
      }

      // Try to create offer directly - don't rely on signalingState check
      // as it can be null on some Android devices even when the peer connection is valid
      if (kDebugMode) print('🔄 Attempting to create offer...');

      try {
        // Create offer with proper media constraints
        Map<String, dynamic> offerOptions = {
          'offerToReceiveAudio': true,
          'offerToReceiveVideo': true,
        };

        RTCSessionDescription offer =
            await _peerConnection!.createOffer(offerOptions);
        await _peerConnection!.setLocalDescription(offer);

        if (kDebugMode) {
          print('✅ Offer created:');
          print('   Type: ${offer.type}');
          print('   Has video: ${offer.sdp?.contains('m=video') ?? false}');
          print('   Has audio: ${offer.sdp?.contains('m=audio') ?? false}');
          print(
              '   ICE gathering state after setLocalDescription: ${_peerConnection!.iceGatheringState}');
        }

        // ⏳ CRITICAL: Wait for ICE gathering to complete before sending offer
        // This ensures all ICE candidates are generated and sent to Firestore
        if (kDebugMode) print('⏳ Waiting for ICE gathering to complete...');

        // Wait up to 3 seconds for ICE gathering to complete (balanced for speed and reliability)
        final gatheringStartTime = DateTime.now();
        while (_peerConnection!.iceGatheringState !=
            RTCIceGatheringState.RTCIceGatheringStateComplete) {
          await Future.delayed(Duration(
              milliseconds: 50)); // Check every 50ms for faster response
          final elapsed = DateTime.now().difference(gatheringStartTime);

          if (elapsed.inMilliseconds >= 3000) {
            if (kDebugMode) {
              print(
                  '⚠️ ICE gathering timeout after ${elapsed.inMilliseconds}ms, proceeding anyway...');
              print('   Current state: ${_peerConnection!.iceGatheringState}');
            }
            break;
          }
        }

        if (kDebugMode) {
          print(
              '✅ ICE gathering wait complete. State: ${_peerConnection!.iceGatheringState}');
          print(
              '   Time elapsed: ${DateTime.now().difference(gatheringStartTime).inMilliseconds}ms');
        }

        // Send offer through Firestore
        await _sendOfferToFirestore(appointmentId, offer);
        if (kDebugMode) print('✅ Offer created and sent to Firestore');
        
        // Give a brief moment for any remaining ICE candidates to be sent
        await Future.delayed(Duration(milliseconds: 500));
        if (kDebugMode) print('✅ Ready for patient to join');
      } catch (offerError) {
        // If offer creation fails, try recreating the peer connection
        if (kDebugMode)
          print(
              '⚠️ Offer creation failed: $offerError, recreating peer connection...');

        await _createPeerConnection();

        // Re-add tracks after recreation
        if (_localStream != null) {
          if (kDebugMode)
            print('🔄 Re-adding local tracks to new peer connection...');
          for (final track in _localStream!.getTracks()) {
            await _peerConnection!.addTrack(track, _localStream!);
          }
          if (kDebugMode) print('✅ Local tracks re-added successfully');
        }

        // Try creating offer again
        RTCSessionDescription offer = await _peerConnection!.createOffer();
        await _peerConnection!.setLocalDescription(offer);

        // Send offer through Firestore
        await _sendOfferToFirestore(appointmentId, offer);
        if (kDebugMode)
          print('✅ Offer created and sent to Firestore after recreation');
      }

      // Doctor must also listen for the patient's answer
      await _listenForOfferFromFirestore(appointmentId);

      if (kDebugMode)
        print('✅ Call started successfully, waiting for patient to join...');
    } catch (e) {
      if (kDebugMode) print('❌ Error starting call: $e');
      onError?.call('Failed to start call: $e');
    }
  }

  // Join a call
  Future<void> joinCall(String roomId, String appointmentId,
      {String? userId}) async {
    try {
      if (kDebugMode)
        print(
            '🚀 Joining call for room: $roomId by user: ${userId ?? "patient"}');

      // Check if we need to clear old Firestore data
      // This allows either party to join first
      await _clearFirestoreSignalingIfNeeded(appointmentId);

      // Ensure clean state before joining
      if (_peerConnection != null) {
        if (kDebugMode)
          print('🧹 Cleaning up existing connection before join...');
        await _peerConnection!.close();
        _peerConnection = null;
      }

      // Ensure proper initialization
      if (!_isInitialized) {
        if (kDebugMode) print('🔄 Initializing WebRTC for call join...');
        await initialize();
      }

      _currentRoomId = roomId;
      _currentAppointmentId = appointmentId;
      _isCaller = false;
      _inCall = true;
      _offerProcessed = false; // Reset for new call
      _answerProcessed = false; // Reset for new call
      _processedIceCandidatesCount = 0; // Reset ICE candidate counter
      _remoteDescriptionSet = false; // Reset remote description flag
      _pendingIceCandidates.clear(); // Clear any pending ICE candidates

      await _createPeerConnection();
      await _startLocalMedia(userId: userId ?? 'patient');
      await _connectToSignalingServer(roomId);

      // Listen for offer from Firestore
      await _listenForOfferFromFirestore(appointmentId);
    } catch (e) {
      if (kDebugMode) print('❌ Error joining call: $e');
      onError?.call('Failed to join call: $e');
    }
  }

  // Clear Firestore signaling document only if needed (for flexible join order)
  Future<void> _clearFirestoreSignalingIfNeeded(String appointmentId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('webrtc_signals')
          .doc(appointmentId)
          .get();

      if (!doc.exists) {
        if (kDebugMode)
          print(
              '📭 No existing Firestore signaling data (first person to join)');
        return; // No data to clear
      }

      // Check if document is recent (within last 30 seconds to allow for slower networks)
      final data = doc.data();
      if (data != null && data.containsKey('timestamp')) {
        final timestamp = data['timestamp'] as Timestamp?;
        if (timestamp != null) {
          final age = DateTime.now().difference(timestamp.toDate());
          if (kDebugMode) {
            print('🔍 Checking Firestore data freshness:');
            print('   - Document age: ${age.inSeconds}s');
            print('   - Threshold: 30s');
            print('   - Contains offer: ${data.containsKey('offer')}');
            print('   - Contains answer: ${data.containsKey('answer')}');
            print('   - Caller: ${data['caller']}');
          }
          if (age.inSeconds < 30) {
            if (kDebugMode)
              print(
                  '✅ Firestore signaling is fresh (${age.inSeconds}s old), keeping it (second person joining)');
            return; // Recent data, don't clear (second person joining)
          }
        }
      }

      // Old or invalid data, clear it
      if (kDebugMode)
        print(
            '🧹 Clearing old Firestore signaling data (age > 30s) for appointment: $appointmentId');

      await FirebaseFirestore.instance
          .collection('webrtc_signals')
          .doc(appointmentId)
          .delete();

      if (kDebugMode) print('✅ Old Firestore signaling data cleared');
    } catch (e) {
      if (kDebugMode)
        print('⚠️ Error checking/clearing Firestore signaling: $e');
      // Non-critical error, continue anyway
    }
  }

  // Send offer through Firestore
  Future<void> _sendOfferToFirestore(
      String appointmentId, RTCSessionDescription offer) async {
    try {
      if (kDebugMode)
        print('📤 Sending offer to Firestore for appointment: $appointmentId');

      await FirebaseFirestore.instance
          .collection('webrtc_signals')
          .doc(appointmentId)
          .set({
        'offer': {
          'type': offer.type,
          'sdp': offer.sdp,
        },
        'timestamp': FieldValue.serverTimestamp(),
        'caller': 'doctor',
      });

      if (kDebugMode) print('✅ Offer sent successfully to Firestore');
    } catch (e) {
      if (kDebugMode) print('❌ Error sending offer: $e');
      onError?.call('Failed to send call offer: $e');
    }
  }

  // Listen for offer from Firestore
  Future<void> _listenForOfferFromFirestore(String appointmentId) async {
    if (kDebugMode)
      print(
          '👂 Listening for offer from Firestore for appointment: $appointmentId');

    FirebaseFirestore.instance
        .collection('webrtc_signals')
        .doc(appointmentId)
        .snapshots()
        .listen((snapshot) async {
      if (snapshot.exists && snapshot.data() != null) {
        final data = snapshot.data()!;
        if (kDebugMode) {
          print('📥 Received WebRTC signal data: ${data.keys}');
          print('   - _isCaller: $_isCaller');
          print('   - _offerProcessed: $_offerProcessed');
          print('   - _answerProcessed: $_answerProcessed');
          print('   - has offer: ${data.containsKey('offer')}');
          print('   - has answer: ${data.containsKey('answer')}');
        }

        if (data.containsKey('offer') && !_isCaller && !_offerProcessed) {
          if (kDebugMode) print('📩 Processing offer as patient...');
          _offerProcessed = true; // Mark as processed to prevent loop
          final offer = data['offer'];
          await _handleOffer(offer);
        }

        if (data.containsKey('answer') && _isCaller && !_answerProcessed) {
          if (kDebugMode) print('📩 Processing answer as doctor...');
          _answerProcessed = true; // Mark as processed to prevent loop
          final answer = data['answer'];
          await _handleAnswer(answer);
        }

        if (data.containsKey('iceCandidates')) {
          final candidates = data['iceCandidates'] as List;
          // Only process new ICE candidates
          if (candidates.length > _processedIceCandidatesCount) {
            final newCandidates =
                candidates.sublist(_processedIceCandidatesCount);
            if (kDebugMode)
              print(
                  '🧊 Processing ${newCandidates.length} new ICE candidates (total: ${candidates.length})...');

            for (var candidateData in newCandidates) {
              await _handleIceCandidate(candidateData);
              _processedIceCandidatesCount++;
            }
          }
        }
      } else {
        if (kDebugMode)
          print(
              '📭 No WebRTC signal data found for appointment: $appointmentId');
      }
    });
  }

  // Handle offer
  Future<void> _handleOffer(Map<String, dynamic> offerData) async {
    try {
      if (kDebugMode) print('📥 Handling offer from doctor...');

      RTCSessionDescription offer = RTCSessionDescription(
        offerData['sdp'],
        offerData['type'],
      );

      if (kDebugMode) print('🔄 Setting remote description...');
      await _peerConnection!.setRemoteDescription(offer);
      _remoteDescriptionSet = true; // Mark that remote description is now set

      if (kDebugMode)
        print('✅ Remote description set, processing queued ICE candidates...');
      await _processPendingIceCandidates(); // Process any ICE candidates that arrived early

      if (kDebugMode) print('🔄 Creating answer...');
      if (kDebugMode)
        print(
            '🔍 Peer connection state before answer: ${_peerConnection!.signalingState}');

      // Ensure local tracks are still present before creating answer
      if (_localStream != null && _peerConnection != null) {
        final senders = await _peerConnection!.getSenders();
        if (kDebugMode) {
          print('🔍 Verifying local tracks before creating answer:');
          print(
              '   - Local stream has ${_localStream!.getVideoTracks().length} video tracks');
          print(
              '   - Local stream has ${_localStream!.getAudioTracks().length} audio tracks');
          print('   - Peer connection has ${senders.length} senders');
        }

        // If no senders, re-add tracks
        if (senders.isEmpty) {
          if (kDebugMode)
            print('⚠️ No senders found! Re-adding local tracks...');
          for (final track in _localStream!.getTracks()) {
            await _peerConnection!.addTrack(track, _localStream!);
          }
          if (kDebugMode) print('✅ Local tracks re-added to peer connection');
        }
      }

      // Only create answer if in the correct state
      if (_peerConnection!.signalingState ==
          RTCSignalingState.RTCSignalingStateHaveRemoteOffer) {
        // Create answer with proper media constraints
        Map<String, dynamic> answerOptions = {
          'offerToReceiveAudio': true,
          'offerToReceiveVideo': true,
        };

        RTCSessionDescription answer =
            await _peerConnection!.createAnswer(answerOptions);
        await _peerConnection!.setLocalDescription(answer);

        if (kDebugMode) {
          print('✅ Answer created:');
          print('   Type: ${answer.type}');
          print('   Has video: ${answer.sdp?.contains('m=video') ?? false}');
          print('   Has audio: ${answer.sdp?.contains('m=audio') ?? false}');
          print(
              '   ICE gathering state after setLocalDescription: ${_peerConnection!.iceGatheringState}');
        }

        // ⏳ CRITICAL: Wait for ICE gathering to complete before sending answer
        // This ensures all ICE candidates are generated and sent to Firestore
        if (kDebugMode) print('⏳ Waiting for ICE gathering to complete...');

        // Wait up to 3 seconds for ICE gathering to complete (balanced for speed and reliability)
        final gatheringStartTime = DateTime.now();
        while (_peerConnection!.iceGatheringState !=
            RTCIceGatheringState.RTCIceGatheringStateComplete) {
          await Future.delayed(Duration(
              milliseconds: 50)); // Check every 50ms for faster response
          final elapsed = DateTime.now().difference(gatheringStartTime);

          if (elapsed.inMilliseconds >= 3000) {
            if (kDebugMode) {
              print(
                  '⚠️ ICE gathering timeout after ${elapsed.inMilliseconds}ms, proceeding anyway...');
              print('   Current state: ${_peerConnection!.iceGatheringState}');
            }
            break;
          }
        }

        if (kDebugMode) {
          print(
              '✅ ICE gathering wait complete. State: ${_peerConnection!.iceGatheringState}');
          print(
              '   Time elapsed: ${DateTime.now().difference(gatheringStartTime).inMilliseconds}ms');
        }

        if (kDebugMode) print('📤 Sending answer back to doctor...');
        // Send answer back through Firestore
        await _sendAnswerToFirestore(_currentAppointmentId!, answer);
        
        // Give a brief moment for any remaining ICE candidates to be sent
        await Future.delayed(Duration(milliseconds: 500));
        if (kDebugMode) print('✅ Answer sent, awaiting connection');
      } else {
        if (kDebugMode)
          print(
              '⚠️ Cannot create answer, invalid state: ${_peerConnection!.signalingState}');
        throw Exception(
            'Invalid peer connection state for creating answer: ${_peerConnection!.signalingState}');
      }

      if (kDebugMode) print('✅ Offer handled successfully, answer sent');
    } catch (e) {
      if (kDebugMode) print('❌ Error handling offer: $e');
      onError?.call('Failed to process call offer: $e');
    }
  }

  // Send answer through Firestore
  Future<void> _sendAnswerToFirestore(
      String appointmentId, RTCSessionDescription answer) async {
    try {
      if (kDebugMode)
        print('📤 Sending answer to Firestore for appointment: $appointmentId');

      await FirebaseFirestore.instance
          .collection('webrtc_signals')
          .doc(appointmentId)
          .update({
        'answer': {
          'type': answer.type,
          'sdp': answer.sdp,
        },
        'timestamp_answer': FieldValue.serverTimestamp(),
      });

      if (kDebugMode) print('✅ Answer sent successfully to Firestore');
    } catch (e) {
      if (kDebugMode) print('❌ Error sending answer: $e');
      onError?.call('Failed to send call answer: $e');
    }
  }

  // Send ICE candidate to Firestore
  Future<void> _sendIceCandidate(
      String appointmentId, RTCIceCandidate candidate) async {
    try {
      if (kDebugMode)
        print(
            '🧊 Sending ICE candidate to Firestore: ${candidate.candidate?.substring(0, 50)}...');

      await FirebaseFirestore.instance
          .collection('webrtc_signals')
          .doc(appointmentId)
          .set({
        'iceCandidates': FieldValue.arrayUnion([
          {
            'candidate': candidate.candidate,
            'sdpMid': candidate.sdpMid,
            'sdpMLineIndex': candidate.sdpMLineIndex,
          }
        ]),
      }, SetOptions(merge: true));

      if (kDebugMode) print('✅ ICE candidate sent successfully');
    } catch (e) {
      if (kDebugMode) print('❌ Error sending ICE candidate: $e');
      // Don't call onError for ICE candidate failures, they're not critical
    }
  }

  // Handle answer
  Future<void> _handleAnswer(Map<String, dynamic> answerData) async {
    try {
      if (kDebugMode) print('📥 Handling answer from patient...');

      RTCSessionDescription answer = RTCSessionDescription(
        answerData['sdp'],
        answerData['type'],
      );

      if (kDebugMode) print('🔄 Setting remote description from answer...');
      await _peerConnection!.setRemoteDescription(answer);
      _remoteDescriptionSet = true; // Mark that remote description is now set

      if (kDebugMode)
        print('✅ Remote description set, processing queued ICE candidates...');
      await _processPendingIceCandidates(); // Process any ICE candidates that arrived early

      if (kDebugMode)
        print(
            '✅ Answer handled successfully, connection should be established');
    } catch (e) {
      if (kDebugMode) print('❌ Error handling answer: $e');
      onError?.call('Failed to process call answer: $e');
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

      // Only add ICE candidates after remote description is set
      if (!_remoteDescriptionSet) {
        if (kDebugMode)
          print('🧊 Queueing ICE candidate (remote description not set yet)');
        _pendingIceCandidates.add(candidate);
        return;
      }

      if (kDebugMode) print('🧊 Adding ICE candidate to peer connection');
      await _peerConnection!.addCandidate(candidate);
    } catch (e) {
      if (kDebugMode) print('Error handling ICE candidate: $e');
    }
  }

  // Process queued ICE candidates after remote description is set
  Future<void> _processPendingIceCandidates() async {
    if (_pendingIceCandidates.isEmpty) return;

    if (kDebugMode)
      print(
          '🧊 Processing ${_pendingIceCandidates.length} queued ICE candidates');

    for (var candidate in _pendingIceCandidates) {
      try {
        await _peerConnection!.addCandidate(candidate);
      } catch (e) {
        if (kDebugMode) print('Error adding queued ICE candidate: $e');
      }
    }

    _pendingIceCandidates.clear();
    if (kDebugMode) print('✅ All queued ICE candidates processed');
  }

  // Connect to signaling server (simplified version using Firestore)
  Future<void> _connectToSignalingServer(String roomId) async {
    // In a production app, you might want to use a dedicated signaling server
    // For now, we'll use Firestore for signaling
    if (kDebugMode) print('Connected to signaling for room: $roomId');
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

      // Dispose streams
      await _localStream?.dispose();
      await _remoteStream?.dispose();

      // Close peer connection
      await _peerConnection?.close();

      // Reset permission cache when call ends
      _permissionsGranted = false;
      _lastPermissionCheck = null;

      // Release media access
      if (_activeUserId != null) {
        _releaseMediaAccess(_activeUserId!);
      }

      // Clear stream references but keep renderers alive
      _localStream = null;
      _remoteStream = null;
      _peerConnection = null;

      // Clear renderer sources but don't dispose renderers
      localRenderer.srcObject = null;
      remoteRenderer.srcObject = null;

      // Note: We keep renderers initialized so user can rejoin

      // Clean up Firestore signaling data
      if (_currentAppointmentId != null) {
        await FirebaseFirestore.instance
            .collection('webrtc_signals')
            .doc(_currentAppointmentId!)
            .delete();
        if (kDebugMode) print('🧹 Cleaned up Firestore signaling data');
      }

      _currentRoomId = null;
      _currentAppointmentId = null;
      _offerProcessed = false; // Reset for next call
      _answerProcessed = false; // Reset for next call
      _processedIceCandidatesCount = 0; // Reset ICE candidate counter
      _remoteDescriptionSet = false; // Reset remote description flag
      _pendingIceCandidates.clear(); // Clear any pending ICE candidates

      if (kDebugMode) print('✅ Call ended - ready to rejoin');
      onCallEnded?.call();
    } catch (e) {
      if (kDebugMode) print('Error ending call: $e');
    }
  }

  // Dispose resources - Only call this when app is closing!
  // For ending a call and rejoining, use endCall() instead
  Future<void> dispose() async {
    if (kDebugMode)
      print(
          '⚠️ WebRTCService.dispose() called - This should only happen on app shutdown!');
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
