import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/chat_service.dart';
import '../chat_screens/guest_chat_screen.dart';

class Gmessages extends StatefulWidget {
  const Gmessages({super.key});

  @override
  State<Gmessages> createState() => _GmessagesState();
}

class _GmessagesState extends State<Gmessages> {
  final ChatService _chatService = ChatService();
  String? _currentUserId;
  String? _currentUserName;
  String searchQuery = "";

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
        'guestId': _currentUserId,
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

  // Method to restore conversation when USER sends a message (for archive only)
  Future<void> _restoreConversationOnUserReply(String patientId) async {
    try {
      final conversationState = await _getConversationState(patientId);
      if (conversationState != null && conversationState['state'] == 'archived') {
        // Only restore archived conversations when user replies, NOT muted ones
        await _setConversationState(patientId, 'active');
        debugPrint('Archived conversation restored for patient: $patientId');
      }
    } catch (e) {
      debugPrint('Error restoring conversation on user reply: $e');
    }
  }

  // Method to restore conversation when PATIENT sends a message (for archive only)
  Future<void> _restoreConversationOnPatientMessage(String patientId) async {
    try {
      final conversationState = await _getConversationState(patientId);
      if (conversationState != null && conversationState['state'] == 'archived') {
        // Only restore archived conversations when patient messages, NOT muted ones
        await _setConversationState(patientId, 'active');
        debugPrint('Archived conversation restored by patient message: $patientId');
      }
    } catch (e) {
      debugPrint('Error restoring conversation on patient message: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    _getCurrentUserDetails();
  }

  Future<void> _getCurrentUserDetails() async {
    User? user = FirebaseAuth.instance.currentUser;
    String? userId;

    // If no user is authenticated, try anonymous sign-in or use temporary ID
    if (user == null) {
      debugPrint(
          'No authenticated guest user found, attempting anonymous sign-in...');
      try {
        final userCredential = await FirebaseAuth.instance.signInAnonymously();
        user = userCredential.user;
        userId = user?.uid;
        debugPrint('Guest signed in anonymously with UID: $userId');
      } catch (e) {
        // If anonymous auth is disabled, use a temporary guest ID
        debugPrint('Anonymous auth not available: $e');
        debugPrint('Using temporary guest ID for this session...');
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        userId = 'guest_$timestamp';
      }
    } else {
      userId = user.uid;
    }

    if (userId == null) {
      debugPrint('Failed to get or create guest user ID');
      return;
    }

    final resolvedName =
        user != null ? await _resolveCurrentUserName(user) : 'Anonymous';

    if (!mounted) return;
    setState(() {
      _currentUserId = userId;
      _currentUserName = resolvedName;
    });

    try {
      // Register guest user with 'guest' role
      await _chatService.createUserDoc(
        userId: userId,
        name: resolvedName,
        role: 'guest',
      );
    } catch (e) {
      debugPrint('Error ensuring guest user doc: $e');
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

      // Check if it's a healthcare worker (should not happen in guest mode, but for safety)
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
      debugPrint('Error resolving guest name: $e');
    }

    if (user.displayName != null && user.displayName!.trim().isNotEmpty) {
      return user.displayName!.trim();
    }

    if (user.email != null && user.email!.contains('@')) {
      return user.email!.split('@').first;
    }

    // Default name for anonymous/guest users
    return 'Anonymous';
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

      return 'Unknown Patient';
    } catch (e) {
      debugPrint('Error getting patient name for $patientId: $e');
      return 'Unknown Patient';
    }
  }

  Future<void> _openChat(
      String patientId, String patientName, String? profilePicture) async {
    try {
      User? currentUser = FirebaseAuth.instance.currentUser;
      String guestUid;

      // If no user is authenticated, try anonymous sign-in or use temporary ID
      if (currentUser == null) {
        try {
          debugPrint(
              'Guest not authenticated, attempting anonymous sign-in...');
          final userCredential =
              await FirebaseAuth.instance.signInAnonymously();
          currentUser = userCredential.user;
          if (currentUser != null) {
            guestUid = currentUser.uid;
            debugPrint('Guest signed in anonymously with UID: $guestUid');
          } else {
            throw Exception('Anonymous sign-in returned null user');
          }
        } catch (authError) {
          // If anonymous auth is disabled, use a temporary guest ID
          debugPrint('Anonymous auth not available: $authError');
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          guestUid = 'guest_$timestamp';
          debugPrint('Using temporary guest ID: $guestUid');
        }
      } else {
        guestUid = currentUser.uid;
      }

      // Restore conversation if it was archived when user opens chat to reply
      await _restoreConversationOnUserReply(patientId);

      final guestName = _currentUserName ??
          currentUser?.displayName ??
          currentUser?.email ??
          'Anonymous';

      // Register guest with 'guest' role
      await _chatService.createUserDoc(
        userId: guestUid,
        name: guestName,
        role: 'guest',
      );

      // Register patient with 'patient' role
      await _chatService.createUserDoc(
        userId: patientId,
        name: patientName,
        role: 'patient',
      );

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => GuestPatientChatScreen(
              guestId: guestUid,
              patientId: patientId,
              patientName: patientName,
              patientProfilePicture: profilePicture,
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
          ),
        );
      }
    }
  }

  // Open chat without restoring conversation state (used in archived messages modal)
  Future<void> _openChatWithoutRestore(
      String patientId, String patientName, String? profilePicture) async {
    try {
      User? currentUser = FirebaseAuth.instance.currentUser;
      String guestUid;

      // If no user is authenticated, try anonymous sign-in or use temporary ID
      if (currentUser == null) {
        try {
          debugPrint(
              'Guest not authenticated, attempting anonymous sign-in...');
          final userCredential =
              await FirebaseAuth.instance.signInAnonymously();
          currentUser = userCredential.user;
          if (currentUser != null) {
            guestUid = currentUser.uid;
            debugPrint('Guest signed in anonymously with UID: $guestUid');
          } else {
            throw Exception('Anonymous sign-in returned null user');
          }
        } catch (authError) {
          // If anonymous auth is disabled, use a temporary guest ID
          debugPrint('Anonymous auth not available: $authError');
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          guestUid = 'guest_$timestamp';
          debugPrint('Using temporary guest ID: $guestUid');
        }
      } else {
        guestUid = currentUser.uid;
      }

      // DO NOT restore conversation state - just open chat

      final guestName = _currentUserName ??
          currentUser?.displayName ??
          currentUser?.email ??
          'Anonymous';

      // Register guest with 'guest' role
      await _chatService.createUserDoc(
        userId: guestUid,
        name: guestName,
        role: 'guest',
      );

      // Register patient with 'patient' role
      await _chatService.createUserDoc(
        userId: patientId,
        name: patientName,
        role: 'patient',
      );

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => GuestPatientChatScreen(
              guestId: guestUid,
              patientId: patientId,
              patientName: patientName,
              patientProfilePicture: profilePicture,
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
          ),
        );
      }
    }
  }

  // Generate random pastel colors based on a string (for consistent colors per user)
  List<Color> _generatePastelColors(String seed) {
    // Use the seed string to generate a consistent hash
    int hash = 0;
    for (int i = 0; i < seed.length; i++) {
      hash = seed.codeUnitAt(i) + ((hash << 5) - hash);
    }

    // Generate two pastel colors from the hash
    final random1 = (hash & 0xFF) / 255.0;
    final random2 = ((hash >> 8) & 0xFF) / 255.0;

    // Create pastel colors (high lightness, medium saturation)
    final hue1 = (random1 * 360);
    final hue2 = ((random2 * 360) + 30) % 360; // Offset for gradient

    final color1 = HSLColor.fromAHSL(1.0, hue1, 0.5, 0.85).toColor();
    final color2 = HSLColor.fromAHSL(1.0, hue2, 0.5, 0.80).toColor();

    return [color1, color2];
  }

  // Helper method to get role label and color
  Map<String, dynamic> _getRoleInfo(String? roleValue, {String? name}) {
    final role = roleValue?.toLowerCase();

    // Special handling for guests or anonymous users
    if (name == 'Anonymous' || name == 'Guest' || role == 'guest') {
      return {
        'label': 'Guest',
        'color': Colors.orange,
      };
    }

    switch (role) {
      case 'healthcare':
        return {
          'label': 'Health Worker',
          'color': Colors.redAccent,
        };
      case 'doctor':
        return {
          'label': 'Doctor',
          'color': Colors.blueAccent,
        };
      case 'patient':
        return {
          'label': 'Patient',
          'color': Colors.teal,
        };
      default:
        return {
          'label': null,
          'color': Colors.teal,
        };
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

  Stream<List<Map<String, dynamic>>> _streamMessagedPatients() {
    if (_currentUserId == null) {
      debugPrint('Current healthcare user ID is null');
      return Stream.value([]);
    }

    debugPrint('Streaming chats for healthcare user: $_currentUserId');

    return FirebaseFirestore.instance
        .collection('chats')
        .where('participants', arrayContains: _currentUserId)
        .snapshots()
        .asyncMap((chatsSnapshot) async {
      debugPrint(
          'Found ${chatsSnapshot.docs.length} chats for healthcare user');
      final messagedPatients = <Map<String, dynamic>>[];

      for (var chatDoc in chatsSnapshot.docs) {
        final chatData = chatDoc.data();
        final participants = List<String>.from(chatData['participants'] ?? []);

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
            final patientName = await _getPatientName(patientId);
            final contactRole =
                await _chatService.getUserRole(patientId) ?? 'patient';

            // Get profile picture if available
            String? profilePicture;
            try {
              final userDoc = await FirebaseFirestore.instance
                  .collection('users')
                  .doc(patientId)
                  .get();
              if (userDoc.exists) {
                profilePicture = userDoc.data()?['profilePicture'] as String?;
              }
            } catch (e) {
              debugPrint('Error fetching profile picture: $e');
            }

            messagedPatients.add({
              'id': patientId,
              'name': patientName,
              'lastMessage': chatData['lastMessage'] ?? 'No messages yet',
              'lastTimestamp': chatData['lastTimestamp'],
              'role': contactRole,
              'profilePicture': profilePicture,
            });
          } else {
            debugPrint('Skipping patient $patientId - conversation state: $state');
          }
        }
      }

      messagedPatients.sort((a, b) {
        final aTime = a['lastTimestamp'] as Timestamp?;
        final bTime = b['lastTimestamp'] as Timestamp?;

        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;

        return bTime.compareTo(aTime);
      });

      return messagedPatients;
    }).handleError((error) {
      debugPrint('Stream error for healthcare chats: $error');
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
                      searchQuery = value.toLowerCase();
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
                            child: const Icon(
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
                final filteredPatients = searchQuery.isEmpty
                    ? patients
                    : patients.where((patient) {
                        final name = (patient['name'] as String? ?? '')
                            .toLowerCase();
                        final lastMessage =
                            (patient['lastMessage'] as String? ?? '')
                                .toLowerCase();
                        return name.contains(searchQuery) ||
                            lastMessage.contains(searchQuery);
                      }).toList();

                return SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                        final patient = filteredPatients[index];
                        final patientName =
                            patient['name'] as String? ?? 'Unknown Patient';
                        final patientId = patient['id'] as String? ?? '';
                        final profilePicture =
                            patient['profilePicture'] as String?;
                        final String? roleValue =
                            (patient['role'] as String?)?.toLowerCase();

                        // Get role information using helper method
                        final roleInfo =
                            _getRoleInfo(roleValue, name: patientName);
                        final String? roleLabel = roleInfo['label'] as String?;
                        final Color roleColor = roleInfo['color'] as Color;

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
                                HapticFeedback.lightImpact();
                                _openChat(
                                    patientId, patientName, profilePicture);
                              },
                              onLongPress: () {
                                HapticFeedback.mediumImpact();
                                _showMessageOptions(patientId, patientName);
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Row(
                                  children: [
                                    // Avatar
                                    Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors:
                                              _generatePastelColors(patientId),
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                        boxShadow: [
                                          BoxShadow(
                                            color: _generatePastelColors(
                                                    patientId)[0]
                                                .withOpacity(0.3),
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: profilePicture != null &&
                                              profilePicture.isNotEmpty
                                          ? ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              child: Image.network(
                                                profilePicture,
                                                fit: BoxFit.cover,
                                                errorBuilder: (context, error,
                                                    stackTrace) {
                                                  return Center(
                                                    child: Text(
                                                      patientName.isNotEmpty
                                                          ? patientName[0]
                                                              .toUpperCase()
                                                          : 'P',
                                                      style: TextStyle(
                                                        color: _generatePastelColors(
                                                                        patientId)[0]
                                                                    .computeLuminance() >
                                                                0.5
                                                            ? Colors.black87
                                                            : Colors.white,
                                                        fontSize: 22,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                  );
                                                },
                                              ),
                                            )
                                          : Center(
                                              child: Text(
                                                patientName.isNotEmpty
                                                    ? patientName[0]
                                                        .toUpperCase()
                                                    : 'P',
                                                style: TextStyle(
                                                  color: _generatePastelColors(
                                                                  patientId)[0]
                                                              .computeLuminance() >
                                                          0.5
                                                      ? Colors.black87
                                                      : Colors.white,
                                                  fontSize: 22,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
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
                                                child: Row(
                                                  children: [
                                                    Flexible(
                                                      child: Text(
                                                        patientName,
                                                        style: const TextStyle(
                                                          fontSize: 17,
                                                          fontWeight: FontWeight.w600,
                                                          color: Color(0xFF1A1A1A),
                                                        ),
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                    if (roleLabel != null) ...[
                                                      const SizedBox(width: 8),
                                                      Container(
                                                        padding: const EdgeInsets
                                                            .symmetric(
                                                          horizontal: 8,
                                                          vertical: 2,
                                                        ),
                                                        decoration: BoxDecoration(
                                                          color: roleColor
                                                              .withOpacity(0.1),
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                  8),
                                                        ),
                                                        child: Text(
                                                          roleLabel,
                                                          style: TextStyle(
                                                            fontSize: 10,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            color: roleColor,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ],
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
                                                    color: Colors.grey.shade600,
                                                    fontWeight: FontWeight.w400,
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
          
          // Only include archived conversations (NOT deleted)
          if (state == 'archived') {
            final patientName = await _getPatientName(patientId);
            
            // Get profile picture if available
            String? profilePicture;
            try {
              final userDoc = await FirebaseFirestore.instance
                  .collection('users')
                  .doc(patientId)
                  .get();
              if (userDoc.exists) {
                profilePicture = userDoc.data()?['profilePicture'] as String?;
              }
            } catch (e) {
              debugPrint('Error fetching profile picture: $e');
            }

            archivedConversations.add({
              'id': patientId,
              'name': patientName,
              'lastMessage': chatData['lastMessage'] ?? 'No messages yet',
              'lastTimestamp': chatData['lastTimestamp'],
              'state': state,
              'archivedAt': conversationState?['timestamp'],
              'profilePicture': profilePicture,
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
                        Colors.orange,
                        Colors.orange.withOpacity(0.8),
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
                              color: Colors.orange,
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
                          final String? roleValue = (conversation['role'] as String?)?.toLowerCase();
                          
                          List<Color> avatarGradient;
                          if (roleValue == 'healthcare') {
                            avatarGradient = [Colors.redAccent, Colors.deepOrange.shade400];
                          } else if (roleValue == 'doctor') {
                            avatarGradient = [Colors.blueAccent, Colors.blue.shade400];
                          } else {
                            avatarGradient = [Colors.orange, Colors.deepOrange.shade400];
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
                                  await _setConversationState(conversation['id'], 'active');
                                  if (mounted) {
                                    Navigator.of(context).pop();
                                    setState(() {}); // Trigger rebuild to show in main list
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Conversation restored'),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange,
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
                                  conversation['profilePicture']
                                );
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
                  // Removed patient name display above options
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
