import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/chat_service.dart';
import '../chat_screens/health_chat_screen.dart';

class Pmessages extends StatefulWidget {
  const Pmessages({super.key});

  @override
  State<Pmessages> createState() => _PmessagesState();
}

class _PmessagesState extends State<Pmessages> {
  final ChatService _chatService = ChatService();
  String? _currentUserId;
  String _searchQuery = '';

  // Method to get conversation state (archived, muted, deleted)
  Future<Map<String, dynamic>?> _getConversationState(String doctorId) async {
    try {
      final chatId = _getChatId(_currentUserId!, doctorId);
      final stateDoc = await FirebaseFirestore.instance
          .collection('conversation_states')
          .doc(chatId)
          .get();

      if (stateDoc.exists) {
        return stateDoc.data();
      }
      return null;
    } catch (e) {
      print('Error getting conversation state: $e');
      return null;
    }
  }

  // Method to set conversation state
  Future<void> _setConversationState(String doctorId, String state) async {
    try {
      final chatId = _getChatId(_currentUserId!, doctorId);
      await FirebaseFirestore.instance
          .collection('conversation_states')
          .doc(chatId)
          .set({
        'state': state, // 'archived', 'muted', 'deleted', or 'active'
        'timestamp': Timestamp.now(),
        'patientId': _currentUserId,
        'doctorId': doctorId,
      });
    } catch (e) {
      print('Error setting conversation state: $e');
    }
  }

  // Generate consistent chat ID
  String _getChatId(String userId1, String userId2) {
    final sortedIds = [userId1, userId2]..sort();
    return '${sortedIds[0]}_${sortedIds[1]}';
  }

  // Method to restore conversation when USER sends a message (for archive only)
  Future<void> _restoreConversationOnUserReply(String doctorId) async {
    try {
      final conversationState = await _getConversationState(doctorId);
      if (conversationState != null &&
          conversationState['state'] == 'archived') {
        // Only restore archived conversations when user replies, NOT muted ones
        await _setConversationState(doctorId, 'active');
        print('Archived conversation restored for doctor: $doctorId');
      }
    } catch (e) {
      print('Error restoring conversation on user reply: $e');
    }
  }

  // Method to restore conversation when DOCTOR sends a message (for archive only)
  Future<void> _restoreConversationOnDoctorMessage(String doctorId) async {
    try {
      final conversationState = await _getConversationState(doctorId);
      if (conversationState != null &&
          conversationState['state'] == 'archived') {
        // Only restore archived conversations when doctor messages, NOT muted ones
        await _setConversationState(doctorId, 'active');
        print('Archived conversation restored by doctor message: $doctorId');
      }
    } catch (e) {
      print('Error restoring conversation on doctor message: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    _getCurrentUserId();
    _testFirestoreConnection();
  }

  Future<void> _testFirestoreConnection() async {
    try {
      print('Testing Firestore connection for patient...');
      final testQuery =
          await FirebaseFirestore.instance.collection('chats').limit(1).get();
      print(
          'Firestore connection successful. Found ${testQuery.docs.length} chats in total');

      // Check if there are any chats at all
      final allChats =
          await FirebaseFirestore.instance.collection('chats').get();
      print('Total chats in database: ${allChats.docs.length}');

      for (var doc in allChats.docs) {
        print('Chat ${doc.id}: ${doc.data()}');
      }
    } catch (e) {
      print('Firestore connection error: $e');
    }
  }

  Future<void> _getCurrentUserId() async {
    final user = FirebaseAuth.instance.currentUser;
    print('Current Firebase user: ${user?.uid}');
    if (user != null) {
      setState(() {
        _currentUserId = user.uid;
      });
      print('Set current user ID: $_currentUserId');
    } else {
      print('No authenticated user found');
    }
  }

  Future<String> _getDoctorName(String doctorId) async {
    try {
      // Try to get from 'doctors' collection first
      final doctorDoc = await FirebaseFirestore.instance
          .collection('doctors')
          .doc(doctorId)
          .get();
      if (doctorDoc.exists) {
        final data = doctorDoc.data();
        if (data != null &&
            data['fullName'] != null &&
            (data['fullName'] as String).trim().isNotEmpty) {
          return data['fullName'];
        }
        // fallback to 'name' if present
        if (data != null &&
            data['name'] != null &&
            (data['name'] as String).trim().isNotEmpty) {
          return data['name'];
        }
      }

      // Check healthcare workers collection (patient-to-healthcare chats)
      final healthcareDoc = await FirebaseFirestore.instance
          .collection('healthcare')
          .doc(doctorId)
          .get();
      if (healthcareDoc.exists) {
        final data = healthcareDoc.data();
        if (data != null) {
          final fullName = data['fullName'];
          if (fullName is String && fullName.trim().isNotEmpty) {
            return fullName.trim();
          }
          final name = data['name'];
          if (name is String && name.trim().isNotEmpty) {
            return name.trim();
          }
        }
      } else {
        final altHealthcareQuery = await FirebaseFirestore.instance
            .collection('healthcare')
            .where('authUid', isEqualTo: doctorId)
            .limit(1)
            .get();
        if (altHealthcareQuery.docs.isNotEmpty) {
          final data = altHealthcareQuery.docs.first.data();
          final fullName = data['fullName'];
          if (fullName is String && fullName.trim().isNotEmpty) {
            return fullName.trim();
          }
          final name = data['name'];
          if (name is String && name.trim().isNotEmpty) {
            return name.trim();
          }
        }
      }

      // Fallback to previous logic: users collection
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(doctorId)
          .get();
      if (userDoc.exists) {
        final userData = userDoc.data();
        if (userData != null &&
            userData['name'] != null &&
            (userData['name'] as String).trim().isNotEmpty) {
          return userData['name'];
        }
      }

      // If no user document, try to get name from appointments
      final appointmentQuery = await FirebaseFirestore.instance
          .collection('pending_patient_data')
          .where('doctorUid', isEqualTo: doctorId)
          .limit(1)
          .get();
      if (appointmentQuery.docs.isNotEmpty) {
        final docData = appointmentQuery.docs.first.data();
        if (docData['doctorName'] != null &&
            (docData['doctorName'] as String).trim().isNotEmpty) {
          return docData['doctorName'];
        }
      }

      // Try approved appointments
      final approvedQuery = await FirebaseFirestore.instance
          .collection('approved_appointments')
          .where('doctorUid', isEqualTo: doctorId)
          .limit(1)
          .get();
      if (approvedQuery.docs.isNotEmpty) {
        final docData = approvedQuery.docs.first.data();
        if (docData['doctorName'] != null &&
            (docData['doctorName'] as String).trim().isNotEmpty) {
          return docData['doctorName'];
        }
      }

      return 'Unknown Doctor';
    } catch (e) {
      return 'Unknown Doctor';
    }
  }

  Future<void> _openChat(String doctorId, String doctorName, {String? role}) async {
    try {
      // Get current patient's ID
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('No authenticated user found');
      }

      // Restore conversation if it was archived when user opens chat to reply
      await _restoreConversationOnUserReply(doctorId);

      // Create or update user docs for chat - ensure both users exist in users collection
      await _chatService.createUserDoc(
        userId: currentUser.uid,
        name: currentUser.displayName ?? 'Patient',
        role: 'patient',
      );

      await _chatService.createUserDoc(
        userId: doctorId,
        name: doctorName,
        role: role ?? 'doctor',
      );

      // Navigate to chat screen
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PatientHealthWorkerChatScreen(
              currentUserId: currentUser.uid,
              healthWorkerId: doctorId,
              healthWorkerName: doctorName,
              healthWorkerProfilePicture: null,
              role: role,
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

  // Open chat without restoring conversation state (used in archived messages modal)
  Future<void> _openChatWithoutRestore(
      String doctorId, String doctorName, {String? role}) async {
    try {
      // Get current patient's ID
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('No authenticated user found');
      }

      // DO NOT restore conversation state - just open chat

      // Create or update user docs for chat - ensure both users exist in users collection
      await _chatService.createUserDoc(
        userId: currentUser.uid,
        name: currentUser.displayName ?? 'Patient',
        role: 'patient',
      );

      await _chatService.createUserDoc(
        userId: doctorId,
        name: doctorName,
        role: role ?? 'doctor',
      );

      // Navigate to chat screen
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PatientHealthWorkerChatScreen(
              currentUserId: currentUser.uid,
              healthWorkerId: doctorId,
              healthWorkerName: doctorName,
              healthWorkerProfilePicture: null,
              role: role,
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
          'color': Colors.redAccent,
          'gradientColors': [Colors.redAccent, Colors.red.shade400],
        };
    }
  }

  // Stream list of doctors that the patient has messaged (real-time updates)
  Stream<List<Map<String, dynamic>>> _streamMessagedDoctors() {
    if (_currentUserId == null) {
      print('Current user ID is null');
      return Stream.value([]);
    }

    print('Streaming chats for patient: $_currentUserId');

    return FirebaseFirestore.instance
        .collection('chats')
        .where('participants', arrayContains: _currentUserId)
        .snapshots()
        .asyncMap((chatsSnapshot) async {
      print('Found ${chatsSnapshot.docs.length} chats');
      final messagedDoctors = <Map<String, dynamic>>[];

      for (var chatDoc in chatsSnapshot.docs) {
        final chatData = chatDoc.data();
        final participants = List<String>.from(chatData['participants'] ?? []);

        print('Chat ${chatDoc.id}: participants = $participants');

        // Find the other participant (doctor)
        final doctorId = participants.firstWhere(
          (id) => id != _currentUserId,
          orElse: () => '',
        );

        if (doctorId.isNotEmpty) {
          // Check conversation state - exclude archived, muted, or deleted
          final conversationState = await _getConversationState(doctorId);
          final state = conversationState?['state'] ?? 'active';

          // Only include active conversations in main chat list
          if (state == 'active') {
            print('Found doctor ID: $doctorId');
            final doctorName = await _getDoctorName(doctorId);
            print('Doctor name: $doctorName');

            // Determine role by checking healthcare collection first, then fall back to doctor
            String contactRole = 'doctor';
            try {
              // Check if user exists in healthcare collection
              final healthcareDoc = await FirebaseFirestore.instance
                  .collection('healthcare')
                  .doc(doctorId)
                  .get();

              if (healthcareDoc.exists) {
                contactRole = 'healthcare';
              } else {
                // Also check by authUid field
                final healthcareQuery = await FirebaseFirestore.instance
                    .collection('healthcare')
                    .where('authUid', isEqualTo: doctorId)
                    .limit(1)
                    .get();

                if (healthcareQuery.docs.isNotEmpty) {
                  contactRole = 'healthcare';
                } else {
                  // Check users collection for role field
                  final userDoc = await FirebaseFirestore.instance
                      .collection('users')
                      .doc(doctorId)
                      .get();
                  if (userDoc.exists) {
                    final userData = userDoc.data();
                    contactRole = userData?['role'] ?? 'doctor';
                  }
                }
              }
            } catch (e) {
              print('Error determining role for $doctorId: $e');
              contactRole = 'doctor';
            }

            messagedDoctors.add({
              'id': doctorId,
              'name': doctorName,
              'lastMessage': chatData['lastMessage'] ?? 'No messages yet',
              'lastTimestamp': chatData['lastTimestamp'],
              'role': contactRole,
            });
          } else {
            print('Skipping doctor $doctorId - conversation state: $state');
          }
        }
      }

      // Sort by timestamp manually
      messagedDoctors.sort((a, b) {
        final aTime = a['lastTimestamp'] as Timestamp?;
        final bTime = b['lastTimestamp'] as Timestamp?;

        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;  // null timestamps go to bottom
        if (bTime == null) return -1;

        return bTime.compareTo(aTime); // Descending order (newest first, recent chats at top)
      });

      print('Returning ${messagedDoctors.length} doctors');
      return messagedDoctors;
    }).handleError((error) {
      print('Stream error: $error');
      return <Map<String, dynamic>>[];
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUserId == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8F9FD),
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.redAccent),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      body: CustomScrollView(
        slivers: [
          // Modern Header with sliver app bar
          SliverAppBar(
            expandedHeight: 90,
            floating: false,
            pinned: true,
            elevation: 0,
            backgroundColor: Colors.transparent,
            systemOverlayStyle: SystemUiOverlayStyle.dark,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.redAccent,
                      Colors.redAccent.withOpacity(0.8),
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Messages',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 32,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            GestureDetector(
                              onTap: () => _showArchivedMessages(),
                              child: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(22),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.2),
                                    width: 1,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.archive_rounded,
                                  color: Colors.white,
                                  size: 22,
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
            ),
          ),

          // Search bar (optimized)
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverToBoxAdapter(
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.grey.shade300,
                    width: 1,
                  ),
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
          ),

          // Doctors list
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: StreamBuilder<List<Map<String, dynamic>>>(
              key: ValueKey(_currentUserId), // Force rebuild when user changes
              stream: _streamMessagedDoctors(),
              builder: (context, snapshot) {
                // Debug prints
                print('StreamBuilder state: \\${snapshot.connectionState}');
                print('Has data: \\${snapshot.hasData}');
                print('Data length: \\${snapshot.data?.length ?? 0}');
                print('Error: \\${snapshot.error}');

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return SliverToBoxAdapter(
                    child: SizedBox(
                      height: 200,
                      child: Center(
                        child: CircularProgressIndicator(
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.redAccent),
                        ),
                      ),
                    ),
                  );
                }

                if (snapshot.hasError) {
                  print('StreamBuilder error: \\${snapshot.error}');
                  return SliverToBoxAdapter(
                    child: SizedBox(
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
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return SliverToBoxAdapter(
                    child: SizedBox(
                      height: 400,
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
                            child: Icon(
                              Icons.chat_bubble_outline_rounded,
                              color: Colors.redAccent,
                              size: 50,
                            ),
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'No conversations yet',
                            style: TextStyle(
                              color: Color(0xFF2C2C2C),
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                      ),
                    ),
                  );
                }

                final doctors = snapshot.data!;

                // Filter doctors based on search query
                final filteredDoctors = _searchQuery.isEmpty
                    ? doctors
                    : doctors.where((doctor) {
                        final name =
                            (doctor['name'] as String? ?? '').toLowerCase();
                        final lastMessage =
                            (doctor['lastMessage'] as String? ?? '')
                                .toLowerCase();
                        return name.contains(_searchQuery) ||
                            lastMessage.contains(_searchQuery);
                      }).toList();

                return SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final doctor = filteredDoctors[index];
                      final doctorName = doctor['name'];
                      final doctorId = doctor['id'];
                      final String? roleValue =
                          (doctor['role'] as String?)?.toLowerCase();

                      // Get role information using helper method
                      final roleInfo = _getRoleInfo(roleValue);
                      final String? roleLabel = roleInfo['label'] as String?;
                      final Color roleColor = roleInfo['color'] as Color;
                      final List<Color> avatarGradient =
                          roleInfo['gradientColors'] as List<Color>;

                      return RepaintBoundary(
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.grey.shade200,
                              width: 1,
                            ),
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
                                HapticFeedback.lightImpact();
                                print(
                                    'Tapping doctor: $doctorName ($doctorId)');
                                _openChat(doctorId, doctorName, role: roleValue);
                              },
                              onLongPress: () {
                                HapticFeedback.mediumImpact();
                                _showMessageOptions(doctorId, doctorName);
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Row(
                                  children: [
                                    // Avatar with online status (optimized)
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
                                              doctorName.isNotEmpty
                                                  ? doctorName[0].toUpperCase()
                                                  : 'D',
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
                                            width: 12,
                                            height: 12,
                                            decoration: BoxDecoration(
                                              color: Colors.green,
                                              shape: BoxShape.circle,
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
                                                        doctorName,
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
                                                    doctor['lastTimestamp']),
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
                                                  doctor['lastMessage'] ??
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
                        ),
                      );
                    },
                    childCount: filteredDoctors.length,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
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

        final doctorId = participants.firstWhere(
          (id) => id != _currentUserId,
          orElse: () => '',
        );

        if (doctorId.isNotEmpty) {
          final conversationState = await _getConversationState(doctorId);
          final state = conversationState?['state'] ?? 'active';

          // Only include archived and muted conversations (NOT deleted)
          if (state == 'archived' || state == 'muted') {
            final doctorName = await _getDoctorName(doctorId);
            
            // Determine role by checking healthcare collection first, then fall back to doctor
            String contactRole = 'doctor';
            try {
              final healthcareDoc = await FirebaseFirestore.instance
                  .collection('healthcare')
                  .doc(doctorId)
                  .get();

              if (healthcareDoc.exists) {
                contactRole = 'healthcare';
              } else {
                final healthcareQuery = await FirebaseFirestore.instance
                    .collection('healthcare')
                    .where('authUid', isEqualTo: doctorId)
                    .limit(1)
                    .get();

                if (healthcareQuery.docs.isNotEmpty) {
                  contactRole = 'healthcare';
                } else {
                  final userDoc = await FirebaseFirestore.instance
                      .collection('users')
                      .doc(doctorId)
                      .get();
                  if (userDoc.exists) {
                    final userData = userDoc.data();
                    contactRole = userData?['role'] ?? 'doctor';
                  }
                }
              }
            } catch (e) {
              print('Error determining role for $doctorId: $e');
              contactRole = 'doctor';
            }
            
            archivedConversations.add({
              'id': doctorId,
              'name': doctorName,
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
                        Colors.teal,
                        Colors.teal.withOpacity(0.8),
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
                              color: Colors.teal,
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
                                        : 'D',
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
                                  backgroundColor: Colors.teal,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: const Text('Restore'),
                              ),
                              onTap: () {
                                Navigator.pop(context);
                                _openChatWithoutRestore(
                                    conversation['id'], 
                                    conversation['name'],
                                    role: conversation['role']);
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

  // Show message options (archive, mute, delete)
  void _showMessageOptions(String doctorId, String doctorName) {
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
                  // Removed sender name (doctorName) above the Archive option
                  _buildOptionTile(
                    icon: Icons.archive_rounded,
                    title: 'Archive',
                    subtitle: 'Hide this conversation',
                    color: Colors.blue,
                    onTap: () {
                      Navigator.pop(context);
                      _archiveMessage(doctorId);
                    },
                  ),
                  _buildOptionTile(
                    icon: Icons.delete_rounded,
                    title: 'Delete',
                    subtitle: 'Remove this conversation',
                    color: Colors.red,
                    onTap: () {
                      Navigator.pop(context);
                      _deleteMessage(doctorId);
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
  void _archiveMessage(String doctorId) async {
    try {
      await _setConversationState(doctorId, 'archived');
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
                await _setConversationState(doctorId, 'active');
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

  // Mute message functionality
  void _muteMessage(String doctorId) async {
    try {
      await _setConversationState(doctorId, 'muted');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Conversation muted'),
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.orange,
            action: SnackBarAction(
              label: 'Undo',
              textColor: Colors.white,
              onPressed: () => _setConversationState(doctorId, 'active'),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error muting conversation: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Delete message functionality - permanently remove
  void _deleteMessage(String doctorId) async {
    try {
      final chatId = _getChatId(_currentUserId!, doctorId);

      // Show confirmation dialog
      bool? confirmDelete = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
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
}
