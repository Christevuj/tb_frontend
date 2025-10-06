import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/chat_service.dart';
import '../chat_screens/chat_screen.dart';
import '../services/presence_service.dart';

class Dmessages extends StatefulWidget {
  const Dmessages({super.key});

  @override
  State<Dmessages> createState() => _DmessagesState();
}

class _DmessagesState extends State<Dmessages> {
  final ChatService _chatService = ChatService();
  final PresenceService _presenceService = PresenceService();
  String? _currentUserId;
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
      print('Error getting conversation state: $e');
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
        'doctorId': _currentUserId,
        'patientId': patientId,
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
  Future<void> _restoreConversationOnUserReply(String patientId) async {
    try {
      final conversationState = await _getConversationState(patientId);
      if (conversationState != null && conversationState['state'] == 'archived') {
        // Only restore archived conversations when user replies, NOT muted ones
        await _setConversationState(patientId, 'active');
        print('Archived conversation restored for patient: $patientId');
      }
    } catch (e) {
      print('Error restoring conversation on user reply: $e');
    }
  }

  // Method to restore conversation when PATIENT sends a message (for archive only)
  Future<void> _restoreConversationOnPatientMessage(String patientId) async {
    try {
      final conversationState = await _getConversationState(patientId);
      if (conversationState != null && conversationState['state'] == 'archived') {
        // Only restore archived conversations when patient messages, NOT muted ones
        await _setConversationState(patientId, 'active');
        print('Archived conversation restored by patient message: $patientId');
      }
    } catch (e) {
      print('Error restoring conversation on patient message: $e');
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
      print('Testing Firestore connection...');
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

  Future<String> _getPatientName(String patientId) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(patientId)
          .get();

      if (userDoc.exists) {
        final userData = userDoc.data()!;

        // Try to get the full name from firstName + lastName (for patients)
        final firstName = userData['firstName'];
        final lastName = userData['lastName'];
        if (firstName != null && lastName != null) {
          return '$firstName $lastName'.trim();
        }

        // Fallback to 'name' field (for other user types)
        if (userData['name'] != null) {
          return userData['name'];
        }

        // Try username field if it exists
        if (userData['username'] != null) {
          return userData['username'];
        }

        // Try email as last resort for identification
        if (userData['email'] != null) {
          return userData['email']
              .split('@')[0]; // Use part before @ as username
        }
      }

      // If no user document, try to get name from appointments
      final appointmentQuery = await FirebaseFirestore.instance
          .collection('pending_patient_data')
          .where('patientUid', isEqualTo: patientId)
          .limit(1)
          .get();

      if (appointmentQuery.docs.isNotEmpty) {
        return appointmentQuery.docs.first.data()['patientName'] ??
            'Unknown Patient';
      }

      // Try to get from approved appointments as well
      final approvedQuery = await FirebaseFirestore.instance
          .collection('approved_appointments')
          .where('patientUid', isEqualTo: patientId)
          .limit(1)
          .get();

      if (approvedQuery.docs.isNotEmpty) {
        return approvedQuery.docs.first.data()['patientName'] ??
            'Unknown Patient';
      }

      return 'Unknown Patient';
    } catch (e) {
      print('Error getting patient name for $patientId: $e');
      return 'Unknown Patient';
    }
  }

  Future<void> _openChat(String patientId, String patientName) async {
    try {
      // Get current doctor's ID
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('No authenticated user found');
      }

      // Mark messages as read when opening the chat
      await _chatService.markMessagesAsRead(currentUser.uid, patientId);

      // Restore conversation if it was archived when user opens chat to reply
      await _restoreConversationOnUserReply(patientId);

      // Create or update user docs for chat - ensure both users exist in users collection
      await _chatService.createUserDoc(
        userId: currentUser.uid,
        name: 'Dr. ${currentUser.displayName ?? 'Doctor'}',
        role: 'doctor',
      );

      await _chatService.createUserDoc(
        userId: patientId,
        name: patientName,
        role: 'patient',
      );

      // Navigate to chat screen
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

  // Open chat without restoring conversation state (used in archived messages modal)
  Future<void> _openChatWithoutRestore(String patientId, String patientName) async {
    try {
      // Get current doctor's ID
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('No authenticated user found');
      }

      // Mark messages as read when opening the chat
      await _chatService.markMessagesAsRead(currentUser.uid, patientId);

      // DO NOT restore conversation state - just open chat

      // Create or update user docs for chat - ensure both users exist in users collection
      await _chatService.createUserDoc(
        userId: currentUser.uid,
        name: 'Dr. ${currentUser.displayName ?? 'Doctor'}',
        role: 'doctor',
      );

      await _chatService.createUserDoc(
        userId: patientId,
        name: patientName,
        role: 'patient',
      );

      // Navigate to chat screen
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

  // Stream list of patients that the doctor has messaged (real-time updates)
  Stream<List<Map<String, dynamic>>> _streamMessagedPatients() {
    if (_currentUserId == null) {
      print('Current user ID is null');
      return Stream.value([]);
    }

    print('Streaming chats for user: $_currentUserId');

    return FirebaseFirestore.instance
        .collection('chats')
        .where('participants', arrayContains: _currentUserId)
        // Remove orderBy temporarily to avoid index issues
        .snapshots()
        .asyncMap((chatsSnapshot) async {
      print('Found ${chatsSnapshot.docs.length} chats');
      final messagedPatients = <Map<String, dynamic>>[];

      for (var chatDoc in chatsSnapshot.docs) {
        final chatData = chatDoc.data();
        final participants = List<String>.from(chatData['participants'] ?? []);

        print('Chat ${chatDoc.id}: participants = $participants');

        // Find the other participant (patient)
        final patientId = participants.firstWhere(
          (id) => id != _currentUserId,
          orElse: () => '',
        );

        if (patientId.isNotEmpty) {
          // Check conversation state - exclude archived, muted, or deleted
          final conversationState = await _getConversationState(patientId);
          final state = conversationState?['state'] ?? 'active';
          
          // Only include active conversations in main chat list
          if (state == 'active') {
            print('Found patient ID: $patientId');
            final patientName = await _getPatientName(patientId);
            print('Patient name: $patientName');

            // Get unread messages count
            final unreadCount = await _chatService.getUnreadMessagesCount(_currentUserId!, patientId);

            messagedPatients.add({
              'id': patientId,
              'name': patientName,
              'lastMessage': chatData['lastMessage'] ?? 'No messages yet',
              'lastTimestamp': chatData['lastTimestamp'],
              'unreadCount': unreadCount,
            });
          } else {
            print('Skipping patient $patientId - conversation state: $state');
          }
        }
      }

      // Sort by timestamp manually
      messagedPatients.sort((a, b) {
        final aTime = a['lastTimestamp'] as Timestamp?;
        final bTime = b['lastTimestamp'] as Timestamp?;

        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;

        return bTime.compareTo(aTime); // Descending order
      });

      print('Returning ${messagedPatients.length} patients');
      return messagedPatients;
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

          // Search bar
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverToBoxAdapter(
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white,
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
          ),

          // Patients list
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _streamMessagedPatients(),
              builder: (context, snapshot) {
                // Debug prints
                print('StreamBuilder state: ${snapshot.connectionState}');
                print('Has data: ${snapshot.hasData}');
                print('Data length: ${snapshot.data?.length ?? 0}');
                print('Error: ${snapshot.error}');

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
                  print('StreamBuilder error: ${snapshot.error}');
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
                              'Error loading conversations',
                              style: TextStyle(color: Colors.redAccent),
                            ),
                            Text(
                              '${snapshot.error}',
                              style:
                                  TextStyle(color: Colors.grey, fontSize: 12),
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

                final patients = snapshot.data!;

                // Filter patients based on search query
                final filteredPatients = _searchQuery.isEmpty
                    ? patients
                    : patients.where((patient) {
                        final name =
                            (patient['name'] as String? ?? '').toLowerCase();
                        final lastMessage =
                            (patient['lastMessage'] as String? ?? '')
                                .toLowerCase();
                        return name.contains(_searchQuery) ||
                            lastMessage.contains(_searchQuery);
                      }).toList();

                return SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final patient = filteredPatients[index];
                      final patientName = patient['name'];
                      final patientId = patient['id'];

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
                            highlightColor: Colors.redAccent.withOpacity(0.05),
                            onTap: () {
                              HapticFeedback.lightImpact();
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
                                  // Avatar with online indicator
                                  Stack(
                                    children: [
                                      Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            colors: [
                                              Colors.redAccent,
                                              Colors.deepOrange.shade400,
                                            ],
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.redAccent
                                                  .withOpacity(0.3),
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
                                      // Online indicator - green if patient is active, gray if offline (like Messenger)
                                      Positioned(
                                        bottom: 2,
                                        right: 2,
                                        child: StreamBuilder<bool>(
                                          stream: _presenceService
                                              .getUserPresenceStream(patientId),
                                          builder: (context, snapshot) {
                                            final isOnline =
                                                snapshot.data ?? false;
                                            return Container(
                                              width: 16,
                                              height: 16,
                                              decoration: BoxDecoration(
                                                color: isOnline
                                                    ? Colors.lightGreen
                                                        .shade400 // Green if patient is currently active
                                                    : Colors
                                                        .grey, // Gray if patient is offline/inactive
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                border: Border.all(
                                                  color: Colors.white,
                                                  width: 2,
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(width: 16),

                                  // Chat info
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
                                              child: Text(
                                                patientName,
                                                style: TextStyle(
                                                  fontSize: 17,
                                                  fontWeight: (patient['unreadCount'] ?? 0) > 0 ? FontWeight.w800 : FontWeight.w600,
                                                  color: const Color(0xFF1A1A1A),
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            Text(
                                              _formatTimeDetailed(
                                                  patient['lastTimestamp']),
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
                                                patient['lastMessage'] ??
                                                    'No messages yet',
                                                style: TextStyle(
                                                  fontSize: 15,
                                                  color: (patient['unreadCount'] ?? 0) > 0 ? const Color(0xFF1A1A1A) : Colors.grey.shade600,
                                                  fontWeight: (patient['unreadCount'] ?? 0) > 0 ? FontWeight.w600 : FontWeight.w400,
                                                ),
                                                overflow: TextOverflow.ellipsis,
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
                    childCount: filteredPatients.length,
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

        final patientId = participants.firstWhere(
          (id) => id != _currentUserId,
          orElse: () => '',
        );

        if (patientId.isNotEmpty) {
          final conversationState = await _getConversationState(patientId);
          final state = conversationState?['state'] ?? 'active';
          
          // Only include archived and muted conversations (NOT deleted)
          if (state == 'archived' || state == 'muted') {
            final patientName = await _getPatientName(patientId);
            archivedConversations.add({
              'id': patientId,
              'name': patientName,
              'lastMessage': chatData['lastMessage'] ?? 'No messages yet',
              'lastTimestamp': chatData['lastTimestamp'],
              'state': state,
              'archivedAt': conversationState?['timestamp'],
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  const Text(
                    'Archived Messages',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: _streamArchivedConversations(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(
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
                              color: Colors.grey,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  final archivedConversations = snapshot.data!;

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: archivedConversations.length,
                    itemBuilder: (context, index) {
                      final conversation = archivedConversations[index];
                      final state = conversation['state'];
                      
                      Color stateColor;
                      IconData stateIcon;
                      
                      switch (state) {
                        case 'archived':
                          stateColor = Colors.blue;
                          stateIcon = Icons.archive_rounded;
                          break;
                        default:
                          stateColor = Colors.grey;
                          stateIcon = Icons.chat_bubble_outline;
                      }

                      return Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: stateColor.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: ListTile(
                          leading: Stack(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade300,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Center(
                                  child: Text(
                                    conversation['name'].isNotEmpty
                                        ? conversation['name'][0].toUpperCase()
                                        : 'P',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  width: 16,
                                  height: 16,
                                  decoration: BoxDecoration(
                                    color: stateColor,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 2,
                                    ),
                                  ),
                                  child: Icon(
                                    stateIcon,
                                    size: 8,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          title: Text(
                            conversation['name'],
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            conversation['lastMessage'],
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: TextButton(
                            onPressed: () {
                              _setConversationState(conversation['id'], 'active');
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Conversation restored'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            },
                            child: const Text('Restore'),
                          ),
                          onTap: () {
                            // For archived conversations: only open chat, don't auto-restore
                            // For muted conversations: only open chat, don't auto-restore
                            Navigator.pop(context);
                            
                            // Open chat without restoring the conversation state
                            _openChatWithoutRestore(conversation['id'], conversation['name']);
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
  }

  // Show message options (archive, mute, delete)
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
                  // Removed sender name (doctorName) above the Archive option
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Conversation archived'),
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.blue,
            action: SnackBarAction(
              label: 'Undo',
              textColor: Colors.white,
              onPressed: () => _setConversationState(patientId, 'active'),
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
          title: const Text('Delete Conversation'),
          content: const Text('This conversation will be permanently deleted. This action cannot be undone.'),
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
        await FirebaseFirestore.instance.collection('chats').doc(chatId).delete();
        await FirebaseFirestore.instance.collection('conversation_states').doc(chatId).delete();
        
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
