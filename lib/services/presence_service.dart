import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';

class PresenceService {
  static final PresenceService _instance = PresenceService._internal();
  factory PresenceService() => _instance;
  PresenceService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Timer? _presenceTimer;
  String? _currentUserId;
  bool _isActive = false;

  /// Initialize presence tracking for the current user
  Future<void> initialize() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _currentUserId = user.uid;
    await _setUserOnline();
    _startPresenceUpdates();
  }

  /// Set user as online and update last seen timestamp
  Future<void> _setUserOnline() async {
    if (_currentUserId == null) return;

    try {
      await _firestore.collection('user_presence').doc(_currentUserId).set({
        'isOnline': true,
        'lastSeen': FieldValue.serverTimestamp(),
        'userId': _currentUserId,
      }, SetOptions(merge: true));

      _isActive = true;
    } catch (e) {
      print('Error setting user online: $e');
    }
  }

  /// Set user as offline
  Future<void> _setUserOffline() async {
    if (_currentUserId == null) return;

    try {
      await _firestore.collection('user_presence').doc(_currentUserId).set({
        'isOnline': false,
        'lastSeen': FieldValue.serverTimestamp(),
        'userId': _currentUserId,
      }, SetOptions(merge: true));

      _isActive = false;
    } catch (e) {
      print('Error setting user offline: $e');
    }
  }

  /// Start periodic presence updates (heartbeat)
  void _startPresenceUpdates() {
    _presenceTimer?.cancel();
    
    // Update presence every 30 seconds to show user is still active
    _presenceTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
      if (_isActive && _currentUserId != null) {
        await _setUserOnline();
      }
    });
  }

  /// Call this when user becomes active (opens app, sends message, etc.)
  Future<void> markAsActive() async {
    if (!_isActive) {
      await _setUserOnline();
    }
  }

  /// Call this when user goes to background or becomes inactive
  Future<void> markAsInactive() async {
    await _setUserOffline();
    _presenceTimer?.cancel();
  }

  /// Get real-time presence status for a specific user
  Stream<bool> getUserPresenceStream(String userId) {
    return _firestore
        .collection('user_presence')
        .doc(userId)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return false;
      
      final data = doc.data() as Map<String, dynamic>;
      final isOnline = data['isOnline'] as bool? ?? false;
      final lastSeen = data['lastSeen'] as Timestamp?;
      
      if (!isOnline) return false;
      
      // If no lastSeen timestamp, consider offline
      if (lastSeen == null) return false;
      
      // Consider user offline if last seen is more than 2 minutes ago
      final now = DateTime.now();
      final lastSeenTime = lastSeen.toDate();
      final difference = now.difference(lastSeenTime);
      
      // User is considered online if they were active within the last 2 minutes
      return difference.inMinutes < 2;
    });
  }

  /// Get presence status for a user (one-time check)
  Future<bool> getUserPresenceStatus(String userId) async {
    try {
      final doc = await _firestore
          .collection('user_presence')
          .doc(userId)
          .get();

      if (!doc.exists) return false;
      
      final data = doc.data() as Map<String, dynamic>;
      final isOnline = data['isOnline'] as bool? ?? false;
      final lastSeen = data['lastSeen'] as Timestamp?;
      
      if (!isOnline) return false;
      
      if (lastSeen == null) return false;
      
      final now = DateTime.now();
      final lastSeenTime = lastSeen.toDate();
      final difference = now.difference(lastSeenTime);
      
      return difference.inMinutes < 2;
    } catch (e) {
      print('Error getting user presence: $e');
      return false;
    }
  }

  /// Get formatted last seen time
  Future<String> getLastSeenText(String userId) async {
    try {
      final doc = await _firestore
          .collection('user_presence')
          .doc(userId)
          .get();

      if (!doc.exists) return 'Offline';
      
      final data = doc.data() as Map<String, dynamic>;
      final isOnline = data['isOnline'] as bool? ?? false;
      final lastSeen = data['lastSeen'] as Timestamp?;
      
      if (isOnline && lastSeen != null) {
        final now = DateTime.now();
        final lastSeenTime = lastSeen.toDate();
        final difference = now.difference(lastSeenTime);
        
        if (difference.inMinutes < 2) {
          return 'Active now';
        }
      }
      
      if (lastSeen != null) {
        final lastSeenTime = lastSeen.toDate();
        final now = DateTime.now();
        final difference = now.difference(lastSeenTime);
        
        if (difference.inMinutes < 60) {
          return 'Active ${difference.inMinutes}m ago';
        } else if (difference.inHours < 24) {
          return 'Active ${difference.inHours}h ago';
        } else {
          return 'Active ${difference.inDays}d ago';
        }
      }
      
      return 'Offline';
    } catch (e) {
      print('Error getting last seen: $e');
      return 'Offline';
    }
  }

  /// Cleanup resources
  void dispose() {
    _presenceTimer?.cancel();
    if (_currentUserId != null) {
      _setUserOffline();
    }
  }
}