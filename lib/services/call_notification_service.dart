import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../widgets/incoming_call_widget.dart';

class CallNotificationService {
  static final CallNotificationService _instance =
      CallNotificationService._internal();
  static CallNotificationService get instance => _instance;
  CallNotificationService._internal();

  StreamSubscription<QuerySnapshot>? _callListener;
  OverlayEntry? _overlayEntry;
  String? _currentUserId;

  void initialize(String userId) {
    _currentUserId = userId;
    _startListening();
  }

  void _startListening() {
    if (_currentUserId == null) return;

    _callListener = FirebaseFirestore.instance
        .collection('calls')
        .where('patientId', isEqualTo: _currentUserId)
        .where('status', isEqualTo: 'calling')
        .snapshots()
        .listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          _showIncomingCall(change.doc);
        }
      }
    });
  }

  void _showIncomingCall(DocumentSnapshot callDoc) {
    if (_overlayEntry != null) return; // Already showing a call

    final data = callDoc.data() as Map<String, dynamic>;
    final appointmentId = data['appointmentId'] as String;
    final doctorName = data['doctorName'] as String;

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 10,
        left: 0,
        right: 0,
        child: Material(
          color: Colors.transparent,
          child: IncomingCallWidget(
            appointmentId: appointmentId,
            doctorName: doctorName,
            onDismiss: () => _dismissCall(callDoc.id),
          ),
        ),
      ),
    );

    // Get overlay from the current context
    final context = navigatorKey.currentContext;
    if (context != null) {
      Overlay.of(context).insert(_overlayEntry!);
    }
  }

  void _dismissCall(String callId) {
    _overlayEntry?.remove();
    _overlayEntry = null;

    // Update call status to rejected/ended
    FirebaseFirestore.instance
        .collection('calls')
        .doc(callId)
        .update({'status': 'ended'});
  }

  void dispose() {
    _callListener?.cancel();
    _overlayEntry?.remove();
    _overlayEntry = null;
  }
}

// Global navigator key for overlay access
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
