import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/chat_service.dart';
import '../chat_screens/chat_screen.dart';

class Hmessages extends StatefulWidget {
  const Hmessages({super.key});

  @override
  State<Hmessages> createState() => _HmessagesState();
}

class _HmessagesState extends State<Hmessages> {
  final ChatService _chatService = ChatService();
  String? _currentUserId;
  String? _currentUserName;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _getCurrentUserDetails();
    _testFirestoreConnection();
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
          final patientName = await _getPatientName(patientId);
          final contactRole =
              await _chatService.getUserRole(patientId) ?? 'patient';
          messagedPatients.add({
            'id': patientId,
            'name': patientName,
            'lastMessage': chatData['lastMessage'] ?? 'No messages yet',
            'lastTimestamp': chatData['lastTimestamp'],
            'role': contactRole,
          });
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
      return Container(
        color: const Color(0xFFF8F9FD),
        child: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.redAccent),
          ),
        ),
      );
    }

    return Container(
      color: const Color(0xFFF8F9FD),
      child: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 120,
            floating: false,
            pinned: true,
            elevation: 0,
            backgroundColor: Colors.transparent,
            automaticallyImplyLeading: false,
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
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Chat with your patients',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
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
                                Icons.chat_bubble_rounded,
                                color: Colors.white,
                                size: 22,
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
                debugPrint('StreamBuilder state: ${snapshot.connectionState}');
                debugPrint('Has data: ${snapshot.hasData}');
                debugPrint('Data length: ${snapshot.data?.length ?? 0}');
                debugPrint('Error: ${snapshot.error}');

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
                  debugPrint('StreamBuilder error: ${snapshot.error}');
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
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 40),
                            child: Text(
                              'Patient conversations will appear here once you start exchanging messages.',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 16,
                                height: 1.4,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Current User: ${_currentUserId ?? "Not logged in"}',
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 12,
                            ),
                          ),
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
                      final patientName =
                          patient['name'] as String? ?? 'Unknown Patient';
                      final patientId = patient['id'] as String? ?? '';
                      final String? roleValue =
                          (patient['role'] as String?)?.toLowerCase();
                      String? roleLabel;
                      Color roleColor = Colors.teal;
                      if (roleValue == 'healthcare') {
                        roleLabel = 'Health Worker';
                        roleColor = Colors.redAccent;
                      } else if (roleValue == 'doctor') {
                        roleLabel = 'Doctor';
                        roleColor = Colors.blueAccent;
                      } else if (roleValue == 'patient') {
                        roleLabel = 'Patient';
                        roleColor = Colors.teal;
                      } else if (roleValue == 'guest') {
                        roleLabel = 'Guest';
                        roleColor = Colors.orange;
                      }

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
                              HapticFeedback.selectionClick();
                              _openChat(patientId, patientName);
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
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  if (roleLabel != null) ...[
                                                    const SizedBox(width: 8),
                                                    Container(
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                        horizontal: 10,
                                                        vertical: 4,
                                                      ),
                                                      decoration: BoxDecoration(
                                                        color: roleColor
                                                            .withOpacity(0.12),
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
}
