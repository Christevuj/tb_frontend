import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/chat_service.dart';
import '../chat_screens/chat_screen.dart';

class Pmessages extends StatefulWidget {
  const Pmessages({super.key});

  @override
  State<Pmessages> createState() => _PmessagesState();
}

class _PmessagesState extends State<Pmessages> {
  final ChatService _chatService = ChatService();
  String? _currentUserId;
  String _searchQuery = '';

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

  Future<void> _openChat(String doctorId, String doctorName) async {
    try {
      // Get current patient's ID
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('No authenticated user found');
      }

      // Create or update user docs for chat - ensure both users exist in users collection
      await _chatService.createUserDoc(
        userId: currentUser.uid,
        name: currentUser.displayName ?? 'Patient',
        role: 'patient',
      );

      await _chatService.createUserDoc(
        userId: doctorId,
        name: doctorName,
        role: 'doctor',
      );

      // Navigate to chat screen
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(
              currentUserId: currentUser.uid,
              otherUserId: doctorId,
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
        }
      }

      // Sort by timestamp manually
      messagedDoctors.sort((a, b) {
        final aTime = a['lastTimestamp'] as Timestamp?;
        final bTime = b['lastTimestamp'] as Timestamp?;

        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;

        return bTime.compareTo(aTime); // Descending order
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
            expandedHeight: 120,
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
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Chat with your care team',
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
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 40),
                            child: Text(
                              'Start a conversation with your care team after booking appointments. They will appear here once you have exchanged messages.',
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
                            'Current User: \\${_currentUserId ?? "Not logged in"}',
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
                                print(
                                    'Tapping doctor: $doctorName ($doctorId)');
                                _openChat(doctorId, doctorName);
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
}
