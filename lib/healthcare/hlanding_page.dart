import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/chat_service.dart';
import '../services/alias_service.dart';
import '../chat_screens/chat_screen.dart';
import 'hmenu.dart';

class Hlandingpage extends StatefulWidget {
  const Hlandingpage({super.key});

  @override
  State<Hlandingpage> createState() => _HlandingpageState();
}

class _HlandingpageState extends State<Hlandingpage> {
  final ChatService _chatService = ChatService();
  final AliasService _aliasService = AliasService();
  String? _currentUserId;
  String? _currentUserName;
  String _searchQuery = '';

  // Method to get conversation state (archived, muted, deleted)
  Future<Map<String, dynamic>?> _getConversationState(String patientId) async {
    try {
      final chatId = _getChatId(_currentUserId!, patientId);
      final stateDoc = await FirebaseFirestore.instance
          .collection('conversation_states')
          .doc(chatId)
          .get();

      if (stateDoc.exists) {
        return stateDoc.data();
      }
      return null;
    } catch (e) {
      debugPrint('Error getting conversation state: $e');
      return null;
    }
  }

  // Method to set conversation state
  Future<void> _setConversationState(String patientId, String state) async {
    try {
      final chatId = _getChatId(_currentUserId!, patientId);
      await FirebaseFirestore.instance
          .collection('conversation_states')
          .doc(chatId)
          .set({
        'state': state, // 'archived', 'muted', 'deleted', or 'active'
        'timestamp': Timestamp.now(),
        'healthcareId': _currentUserId,
        'patientId': patientId,
      });
    } catch (e) {
      debugPrint('Error setting conversation state: $e');
    }
  }

  // Generate consistent chat ID
  String _getChatId(String userId1, String userId2) {
    final sortedIds = [userId1, userId2]..sort();
    return '${sortedIds[0]}_${sortedIds[1]}';
  }

  @override
  void initState() {
    super.initState();
    _getCurrentUserDetails();
    _testFirestoreConnection();
    _checkTempPasswordAndShowPopup();
  }

  // Check if using temp password and show security popup
  void _checkTempPasswordAndShowPopup() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final docSnapshot = await FirebaseFirestore.instance
          .collection('healthcare')
          .doc(user.uid)
          .get();

      if (docSnapshot.exists) {
        final data = docSnapshot.data();
        final tempPassword = data?['tempPassword'];
        final passwordChangedAt = data?['passwordChangedAt'];

        // Only show popup if tempPassword exists AND password hasn't been changed yet
        // (passwordChangedAt field is null or doesn't exist)
        if (tempPassword != null &&
            tempPassword.toString().isNotEmpty &&
            passwordChangedAt == null) {
          // Delay to ensure widget is fully built
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              _showSecurityPopup();
            }
          });
        }
      }
    } catch (e) {
      debugPrint('Error checking temp password: $e');
    }
  }

  // Show security popup for temp password users
  void _showSecurityPopup() {
    showDialog(
      context: context,
      barrierDismissible: false, // User must take action
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 8,
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Container(
            constraints: BoxConstraints(
              maxWidth: 400,
              maxHeight: MediaQuery.of(context).size.height * 0.8,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.redAccent.withOpacity(0.3),
                    width: 1.5,
                  ),
                ),
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Icon with gradient background
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.redAccent,
                            Colors.redAccent.shade700,
                          ],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.redAccent.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.lock_clock_rounded,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Title
                    const Text(
                      'Security Notice',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    // Subtitle
                    Text(
                      'Temporary Password Detected',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    // Info box
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.red.shade50,
                            Colors.red.shade100.withOpacity(0.5),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.redAccent.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.info_outline,
                                  color: Colors.redAccent.shade700, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'For your security, please update:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.redAccent.shade700,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildSecurityItem('Change your password'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Buttons
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: Colors.grey.shade300,
                                  width: 1,
                                ),
                              ),
                            ),
                            child: Text(
                              'Later',
                              style: TextStyle(
                                color: Colors.grey.shade700,
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.redAccent,
                              foregroundColor: Colors.white,
                              elevation: 4,
                              shadowColor: Colors.redAccent.withOpacity(0.5),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            onPressed: () {
                              Navigator.of(context).pop();
                              // Navigate to account page (index 2 in hmenu.dart)
                              Navigator.of(context).pushReplacement(
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const HealthMainWrapper(initialIndex: 2),
                                ),
                              );
                            },
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.settings, size: 18),
                                SizedBox(width: 8),
                                Text(
                                  'Update Now',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // Helper widget for security checklist items
  Widget _buildSecurityItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.redAccent,
                width: 2,
              ),
            ),
            child: const Icon(
              Icons.check,
              size: 12,
              color: Colors.redAccent,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade800,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _testFirestoreConnection() async {
    try {
      debugPrint('Testing Firestore connection for healthcare worker...');
      final testQuery =
          await FirebaseFirestore.instance.collection('chats').limit(1).get();
      debugPrint(
          'Firestore connection successful. Found ${testQuery.docs.length} chats in total');

      final allChats =
          await FirebaseFirestore.instance.collection('chats').get();
      debugPrint('Total chats in database: ${allChats.docs.length}');
    } catch (e) {
      debugPrint('Firestore connection error: $e');
    }
  }

  Future<void> _getCurrentUserDetails() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint('No authenticated healthcare user found');
      return;
    }

    final resolvedName = await _resolveCurrentUserName(user);

    if (!mounted) return;
    setState(() {
      _currentUserId = user.uid;
      _currentUserName = resolvedName;
    });

    try {
      await _chatService.createUserDoc(
        userId: user.uid,
        name: resolvedName,
        role: 'healthcare',
      );
    } catch (e) {
      debugPrint('Error ensuring healthcare user doc: $e');
    }
  }

  Future<String> _resolveCurrentUserName(User user) async {
    try {
      final existingUserDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (existingUserDoc.exists) {
        final data = existingUserDoc.data();
        if (data != null) {
          final firstName = data['firstName'];
          final lastName = data['lastName'];
          final combined = [firstName, lastName]
              .whereType<String>()
              .where((part) => part.trim().isNotEmpty)
              .join(' ');
          if (combined.trim().isNotEmpty) {
            return combined.trim();
          }
          final displayName = data['name'];
          if (displayName is String && displayName.trim().isNotEmpty) {
            return displayName.trim();
          }
        }
      }

      final healthcareDoc = await FirebaseFirestore.instance
          .collection('healthcare')
          .doc(user.uid)
          .get();
      if (healthcareDoc.exists) {
        final data = healthcareDoc.data();
        if (data != null) {
          final fullName = data['fullName'] ?? data['name'];
          if (fullName is String && fullName.trim().isNotEmpty) {
            return fullName.trim();
          }
        }
      }
    } catch (e) {
      debugPrint('Error resolving healthcare name: $e');
    }

    if (user.displayName != null && user.displayName!.trim().isNotEmpty) {
      return user.displayName!.trim();
    }

    if (user.email != null && user.email!.contains('@')) {
      return user.email!.split('@').first;
    }

    return 'Healthcare Worker';
  }

  Future<String> _getPatientName(String patientId) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(patientId)
          .get();

      if (userDoc.exists) {
        final userData = userDoc.data()!;

        final firstName = userData['firstName'];
        final lastName = userData['lastName'];
        if (firstName != null && lastName != null) {
          final fullName = '$firstName $lastName'.trim();
          if (fullName.isNotEmpty) return fullName;
        }

        if (userData['name'] != null &&
            (userData['name'] as String).trim().isNotEmpty) {
          return (userData['name'] as String).trim();
        }

        if (userData['username'] != null &&
            (userData['username'] as String).trim().isNotEmpty) {
          return (userData['username'] as String).trim();
        }

        if (userData['email'] != null &&
            (userData['email'] as String).contains('@')) {
          return (userData['email'] as String).split('@').first;
        }
      }

      final appointmentQuery = await FirebaseFirestore.instance
          .collection('pending_patient_data')
          .where('patientUid', isEqualTo: patientId)
          .limit(1)
          .get();

      if (appointmentQuery.docs.isNotEmpty) {
        final candidate = appointmentQuery.docs.first.data()['patientName'];
        if (candidate is String && candidate.trim().isNotEmpty) {
          return candidate.trim();
        }
      }

      final approvedQuery = await FirebaseFirestore.instance
          .collection('approved_appointments')
          .where('patientUid', isEqualTo: patientId)
          .limit(1)
          .get();

      if (approvedQuery.docs.isNotEmpty) {
        final candidate = approvedQuery.docs.first.data()['patientName'];
        if (candidate is String && candidate.trim().isNotEmpty) {
          return candidate.trim();
        }
      }

      return 'Unknown Patient';
    } catch (e) {
      debugPrint('Error getting patient name for $patientId: $e');
      return 'Unknown Patient';
    }
  }

  Future<void> _openChat(String patientId, String patientName) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('No authenticated user found');
      }

      final healthcareName = _currentUserName ??
          currentUser.displayName ??
          currentUser.email ??
          'Healthcare Worker';

      await _chatService.createUserDoc(
        userId: currentUser.uid,
        name: healthcareName,
        role: 'healthcare',
      );

      await _chatService.createUserDoc(
        userId: patientId,
        name: patientName,
        role: 'patient',
      );

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(
              currentUserId: currentUser.uid,
              otherUserId: patientId,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening chat: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            action: SnackBarAction(
              label: 'Dismiss',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      }
    }
  }

  String _formatTimeDetailed(Timestamp? timestamp) {
    if (timestamp == null) return 'now';

    final messageTime = timestamp.toDate();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate =
        DateTime(messageTime.year, messageTime.month, messageTime.day);

    final hour = messageTime.hour;
    final minute = messageTime.minute.toString().padLeft(2, '0');
    final period = hour < 12 ? 'AM' : 'PM';
    final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);

    if (messageDate == today) {
      return '$displayHour:$minute $period';
    } else if (now.difference(messageTime).inDays == 1) {
      return 'Yesterday';
    } else if (now.difference(messageTime).inDays < 7) {
      const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return weekdays[messageTime.weekday - 1];
    } else {
      return '${messageTime.day}/${messageTime.month}';
    }
  }

  // Helper method to get role label and color
  Map<String, dynamic> _getRoleInfo(String? roleValue) {
    final role = roleValue?.toLowerCase();

    switch (role) {
      case 'healthcare':
        return {
          'label': 'Health Worker',
          'color': Colors.redAccent,
          'gradientColors': [Colors.redAccent, Colors.red.shade400],
        };
      case 'doctor':
        return {
          'label': 'Doctor',
          'color': Colors.blueAccent,
          'gradientColors': [Colors.blueAccent, Colors.blue.shade400],
        };
      case 'patient':
        return {
          'label': 'Patient',
          'color': Colors.teal,
          'gradientColors': [Colors.teal, Colors.teal.shade400],
        };
      case 'guest':
        return {
          'label': 'Guest',
          'color': Colors.orange,
          'gradientColors': [Colors.orange, Colors.orangeAccent],
        };
      default:
        return {
          'label': null,
          'color': Colors.teal,
          'gradientColors': [Colors.teal, Colors.teal.shade400],
        };
    }
  }

  Stream<List<Map<String, dynamic>>> _streamMessagedPatients() {
    if (_currentUserId == null) {
      debugPrint('Current healthcare user ID is null');
      return Stream.value([]);
    }

    debugPrint(
        '📥 LANDING PAGE: Streaming ALL incoming messages for healthcare user: $_currentUserId');

    return FirebaseFirestore.instance
        .collection('chats')
        .where('participants', arrayContains: _currentUserId)
        .snapshots()
        .asyncMap((chatsSnapshot) async {
      debugPrint(
          '📥 LANDING PAGE: Found ${chatsSnapshot.docs.length} total chats');
      final incomingMessages = <Map<String, dynamic>>[];

      // Get list of approved patients that healthcare worker initiated chat with
      final approvedPatientIds = await _getApprovedPatientIds();
      debugPrint(
          '📥 LANDING PAGE: Approved patients (initiated by healthcare): ${approvedPatientIds.length}');

      for (var chatDoc in chatsSnapshot.docs) {
        final chatData = chatDoc.data();
        final participants = List<String>.from(chatData['participants'] ?? []);

        final contactId = participants.firstWhere(
          (id) => id != _currentUserId,
          orElse: () => '',
        );

        if (contactId.isNotEmpty) {
          // Check conversation state
          final conversationState = await _getConversationState(contactId);
          final state = conversationState?['state'];

          // LANDING PAGE shows:
          // 1. ALL conversations WITHOUT a state (new incoming messages from patients/guests)
          // 2. Conversations NOT in the approved patients list (patients/guests who messaged first)
          // 3. Exclude archived/deleted conversations

          final isApprovedPatient = approvedPatientIds.contains(contactId);
          final shouldShowInLanding =
              (state == null || state == 'active') && !isApprovedPatient;

          if (shouldShowInLanding) {
            final contactName = await _getPatientName(contactId);
            final contactRole =
                await _chatService.getUserRole(contactId) ?? 'patient';

            // Get or create alias for patients
            String displayName;
            if (contactRole == 'patient') {
              displayName = await _aliasService.getOrCreatePatientAlias(
                healthcareId: _currentUserId!,
                patientId: contactId,
              );
            } else {
              // For doctors, healthcare, and guests, show real names
              displayName = contactName;
            }

            debugPrint(
                '📥 LANDING PAGE: Including $displayName (role: $contactRole, state: $state)');

            incomingMessages.add({
              'id': contactId,
              'name': displayName,
              'realName': contactName,
              'lastMessage': chatData['lastMessage'] ?? 'No messages yet',
              'lastTimestamp': chatData['lastTimestamp'],
              'role': contactRole,
            });
          } else {
            debugPrint(
                '📤 SKIP for LANDING: $contactId (approved: $isApprovedPatient, state: $state) - Should be in hmessages.dart');
          }
        }
      }

      incomingMessages.sort((a, b) {
        final aTime = a['lastTimestamp'] as Timestamp?;
        final bTime = b['lastTimestamp'] as Timestamp?;

        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;

        return bTime.compareTo(aTime);
      });

      debugPrint(
          '📥 LANDING PAGE: Showing ${incomingMessages.length} incoming conversations');
      return incomingMessages;
    }).handleError((error) {
      debugPrint('❌ LANDING PAGE: Stream error: $error');
      return <Map<String, dynamic>>[];
    });
  }

  // Get list of approved patient IDs that healthcare worker has initiated chat with
  Future<Set<String>> _getApprovedPatientIds() async {
    if (_currentUserId == null) {
      return {};
    }

    try {
      // Get all patients that have 'active' conversation state set by this healthcare worker
      // This means the healthcare worker initiated the chat (from approved patients list)
      final approvedIds = <String>{};

      final statesQuery = await FirebaseFirestore.instance
          .collection('conversation_states')
          .where('healthcareId', isEqualTo: _currentUserId)
          .where('state', isEqualTo: 'active')
          .get();

      for (var doc in statesQuery.docs) {
        final data = doc.data();
        final patientId = data['patientId'] as String?;
        if (patientId != null) {
          approvedIds.add(patientId);
        }
      }

      debugPrint(
          '📋 Found ${approvedIds.length} approved patients with active state');
      return approvedIds;
    } catch (e) {
      debugPrint('Error getting approved patient IDs: $e');
      return {};
    }
  }

  // Show message options (archive, delete)
  void _showMessageOptions(String patientId, String patientName) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _buildOptionTile(
                    icon: Icons.archive_rounded,
                    title: 'Archive',
                    subtitle: 'Hide this conversation',
                    color: Colors.blue,
                    onTap: () {
                      Navigator.pop(context);
                      _archiveMessage(patientId);
                    },
                  ),
                  _buildOptionTile(
                    icon: Icons.delete_rounded,
                    title: 'Delete',
                    subtitle: 'Remove this conversation',
                    color: Colors.red,
                    onTap: () {
                      Navigator.pop(context);
                      _deleteMessage(patientId);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: Colors.grey.shade600,
          fontSize: 14,
        ),
      ),
      onTap: onTap,
    );
  }

  // Archive message functionality
  void _archiveMessage(String patientId) async {
    try {
      await _setConversationState(patientId, 'archived');
      if (mounted) {
        setState(() {}); // Trigger rebuild to remove from main list
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Conversation archived'),
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.blue,
            action: SnackBarAction(
              label: 'Undo',
              textColor: Colors.white,
              onPressed: () async {
                await _setConversationState(patientId, 'active');
                if (mounted) {
                  setState(() {}); // Trigger rebuild to show in main list again
                }
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error archiving conversation: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Delete message functionality - permanently remove
  void _deleteMessage(String patientId) async {
    try {
      final chatId = _getChatId(_currentUserId!, patientId);

      // Show confirmation dialog
      bool? confirmDelete = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('Delete Conversation'),
          content: const Text(
              'This conversation will be permanently deleted. This action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        ),
      );

      if (confirmDelete == true) {
        // Permanently delete the chat document and conversation state
        await FirebaseFirestore.instance
            .collection('chats')
            .doc(chatId)
            .delete();
        await FirebaseFirestore.instance
            .collection('conversation_states')
            .doc(chatId)
            .delete();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Conversation permanently deleted'),
              duration: Duration(seconds: 2),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting conversation: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Get archived conversations
  Stream<List<Map<String, dynamic>>> _streamArchivedConversations() {
    if (_currentUserId == null) {
      return Stream.value([]);
    }

    return FirebaseFirestore.instance
        .collection('chats')
        .where('participants', arrayContains: _currentUserId)
        .snapshots()
        .asyncMap((chatsSnapshot) async {
      final archivedConversations = <Map<String, dynamic>>[];

      for (var chatDoc in chatsSnapshot.docs) {
        final chatData = chatDoc.data();
        final participants = List<String>.from(chatData['participants'] ?? []);

        final patientId = participants.firstWhere(
          (id) => id != _currentUserId,
          orElse: () => '',
        );

        if (patientId.isNotEmpty) {
          final conversationState = await _getConversationState(patientId);
          final state = conversationState?['state'] ?? 'active';

          // Only include archived conversations (NOT deleted)
          if (state == 'archived') {
            final patientName = await _getPatientName(patientId);
            final contactRole =
                await _chatService.getUserRole(patientId) ?? 'patient';

            // Get display name with alias
            String displayName;
            if (contactRole == 'patient') {
              displayName = await _aliasService.getOrCreatePatientAlias(
                healthcareId: _currentUserId!,
                patientId: patientId,
              );
            } else {
              displayName = patientName;
            }

            archivedConversations.add({
              'id': patientId,
              'name': displayName,
              'realName': patientName,
              'lastMessage': chatData['lastMessage'] ?? 'No messages yet',
              'lastTimestamp': chatData['lastTimestamp'],
              'state': state,
              'archivedAt': conversationState?['timestamp'],
              'role': contactRole,
            });
          }
        }
      }

      // Sort by archived timestamp
      archivedConversations.sort((a, b) {
        final aTime = a['archivedAt'] as Timestamp?;
        final bTime = b['archivedAt'] as Timestamp?;

        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;

        return bTime.compareTo(aTime);
      });

      return archivedConversations;
    });
  }

  // Show archived messages
  void _showArchivedMessages() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            width: 500,
            height: 600,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.redAccent,
                        Colors.redAccent.withOpacity(0.8),
                      ],
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.archive_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Archived Messages',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(
                          Icons.close,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),

                // Content
                Expanded(
                  child: StreamBuilder<List<Map<String, dynamic>>>(
                    stream: _streamArchivedConversations(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(40),
                            child: CircularProgressIndicator(
                              color: Colors.redAccent,
                            ),
                          ),
                        );
                      }

                      if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.all(40),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.archive_outlined,
                                size: 64,
                                color: Colors.grey,
                              ),
                              SizedBox(height: 16),
                              Text(
                                'No archived messages yet',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Archived conversations will appear here.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      final archivedConversations = snapshot.data!;

                      return ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        itemCount: archivedConversations.length,
                        itemBuilder: (context, index) {
                          final conversation = archivedConversations[index];
                          final String? roleValue =
                              (conversation['role'] as String?)?.toLowerCase();

                          List<Color> avatarGradient;
                          if (roleValue == 'healthcare') {
                            avatarGradient = [
                              Colors.redAccent,
                              Colors.deepOrange.shade400
                            ];
                          } else if (roleValue == 'doctor') {
                            avatarGradient = [
                              Colors.blueAccent,
                              Colors.blue.shade400
                            ];
                          } else {
                            avatarGradient = [
                              Colors.teal,
                              Colors.teal.shade400
                            ];
                          }

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.grey.shade200,
                              ),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(16),
                              leading: Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: avatarGradient,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Center(
                                  child: Text(
                                    conversation['name'].isNotEmpty
                                        ? conversation['name'][0].toUpperCase()
                                        : 'P',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              title: Text(
                                conversation['name'],
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                              subtitle: Text(
                                conversation['lastMessage'],
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              trailing: ElevatedButton(
                                onPressed: () async {
                                  await _setConversationState(
                                      conversation['id'], 'active');
                                  if (mounted) {
                                    Navigator.of(context).pop();
                                    setState(
                                        () {}); // Trigger rebuild to show in main list
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Conversation restored'),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.redAccent,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: const Text('Restore'),
                              ),
                              onTap: () {
                                Navigator.pop(context);
                                _openChat(
                                    conversation['id'], conversation['name']);
                              },
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUserId == null) {
      return Container(
        color: const Color(0xFFF8F9FD),
        child: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.redAccent),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Logo Header with Archive Icon
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Image.asset("assets/images/tbisita_logo2.png",
                      height: 30, alignment: Alignment.centerLeft),
                  const SizedBox(height: 10),
                  // Archive Icon (moved down)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: Colors.redAccent.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(22),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(22),
                          onTap: _showArchivedMessages,
                          child: const Icon(
                            Icons.archive_rounded,
                            color: Colors.redAccent,
                            size: 22,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 3),

            // Search bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F2F5),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: TextField(
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value.toLowerCase();
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Search conversations...',
                    hintStyle: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                    ),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: Colors.grey.shade400,
                      size: 22,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 3),

            // Patients list
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: StreamBuilder<List<Map<String, dynamic>>>(
                  stream: _streamMessagedPatients(),
                  builder: (context, snapshot) {
                    // Debug prints
                    debugPrint(
                        'StreamBuilder state: ${snapshot.connectionState}');
                    debugPrint('Has data: ${snapshot.hasData}');
                    debugPrint('Data length: ${snapshot.data?.length ?? 0}');
                    debugPrint('Error: ${snapshot.error}');

                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return SizedBox(
                        height: 200,
                        child: Center(
                          child: CircularProgressIndicator(
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.redAccent),
                          ),
                        ),
                      );
                    }

                    if (snapshot.hasError) {
                      debugPrint('StreamBuilder error: ${snapshot.error}');
                      return SizedBox(
                        height: 200,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.error,
                                  color: Colors.redAccent, size: 48),
                              SizedBox(height: 16),
                              Text(
                                'Unable to load conversations',
                                style: TextStyle(color: Colors.redAccent),
                              ),
                              Text(
                                'Please check your connection and try again',
                                style: TextStyle(color: Colors.grey.shade600),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.redAccent.withOpacity(0.1),
                                    Colors.redAccent.withOpacity(0.05),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(50),
                              ),
                              child: const Icon(
                                Icons.chat_bubble_outline_rounded,
                                color: Colors.redAccent,
                                size: 50,
                              ),
                            ),
                            const SizedBox(height: 24),
                            const Text(
                              'No conversations yet',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Color(0xFF2C2C2C),
                                fontSize: 22,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                        ),
                      );
                    }

                    final patients = snapshot.data!;

                    // Filter patients based on search query
                    final filteredPatients = _searchQuery.isEmpty
                        ? patients
                        : patients.where((patient) {
                            final name = (patient['name'] as String? ?? '')
                                .toLowerCase();
                            final lastMessage =
                                (patient['lastMessage'] as String? ?? '')
                                    .toLowerCase();
                            return name.contains(_searchQuery) ||
                                lastMessage.contains(_searchQuery);
                          }).toList();

                    return ListView.builder(
                      itemCount: filteredPatients.length,
                      itemBuilder: (context, index) {
                        final patient = filteredPatients[index];
                        final patientName =
                            patient['name'] as String? ?? 'Unknown Patient';
                        final patientId = patient['id'] as String? ?? '';
                        final String? roleValue =
                            (patient['role'] as String?)?.toLowerCase();

                        // Get role information using helper method
                        final roleInfo = _getRoleInfo(roleValue);
                        final String? roleLabel = roleInfo['label'] as String?;
                        final Color roleColor = roleInfo['color'] as Color;
                        final List<Color> avatarGradient =
                            roleInfo['gradientColors'] as List<Color>;

                        return Container(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 15,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(16),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              splashColor: Colors.redAccent.withOpacity(0.1),
                              highlightColor:
                                  Colors.redAccent.withOpacity(0.05),
                              onTap: () {
                                HapticFeedback.selectionClick();
                                _openChat(patientId, patientName);
                              },
                              onLongPress: () {
                                HapticFeedback.mediumImpact();
                                _showMessageOptions(patientId, patientName);
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Row(
                                  children: [
                                    // Avatar with online status
                                    Stack(
                                      children: [
                                        Container(
                                          width: 44,
                                          height: 44,
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                              colors: avatarGradient,
                                            ),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            boxShadow: [
                                              BoxShadow(
                                                color:
                                                    roleColor.withOpacity(0.3),
                                                blurRadius: 8,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          child: Center(
                                            child: Text(
                                              patientName.isNotEmpty
                                                  ? patientName[0].toUpperCase()
                                                  : 'P',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 22,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ),
                                        // Online status indicator
                                        Positioned(
                                          bottom: 2,
                                          right: 2,
                                          child: Container(
                                            width: 16,
                                            height: 16,
                                            decoration: BoxDecoration(
                                              color: Colors.green,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              border: Border.all(
                                                color: Colors.white,
                                                width: 2,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(width: 16),
                                    // Name and message info
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(
                                                child: Row(
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        patientName,
                                                        style: const TextStyle(
                                                          fontSize: 17,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          color:
                                                              Color(0xFF1A1A1A),
                                                        ),
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                    ),
                                                    if (roleLabel != null) ...[
                                                      const SizedBox(width: 8),
                                                      Container(
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                          horizontal: 10,
                                                          vertical: 4,
                                                        ),
                                                        decoration:
                                                            BoxDecoration(
                                                          color: roleColor
                                                              .withOpacity(
                                                                  0.12),
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(12),
                                                        ),
                                                        child: Text(
                                                          roleLabel,
                                                          style: TextStyle(
                                                            color: roleColor,
                                                            fontSize: 11,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                              ),
                                              Text(
                                                _formatTimeDetailed(
                                                    patient['lastTimestamp']
                                                        as Timestamp?),
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: Colors.grey.shade500,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  patient['lastMessage']
                                                          as String? ??
                                                      'No messages yet',
                                                  style: TextStyle(
                                                    fontSize: 15,
                                                    color: Colors.grey.shade600,
                                                    fontWeight: FontWeight.w400,
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
