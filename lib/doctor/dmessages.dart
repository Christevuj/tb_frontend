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

  @override
  void initState() {
    super.initState();
    _getCurrentUserId();
    _testFirestoreConnection();
  }

  Future<void> _testFirestoreConnection() async {
    try {
      print('Testing Firestore connection...');
      final testQuery = await FirebaseFirestore.instance
          .collection('chats')
          .limit(1)
          .get();
      print('Firestore connection successful. Found ${testQuery.docs.length} chats in total');
      
      // Check if there are any chats at all
      final allChats = await FirebaseFirestore.instance
          .collection('chats')
          .get();
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
          return userData['email'].split('@')[0]; // Use part before @ as username
        }
      }
      
      // If no user document, try to get name from appointments
      final appointmentQuery = await FirebaseFirestore.instance
          .collection('pending_patient_data')
          .where('patientUid', isEqualTo: patientId)
          .limit(1)
          .get();
      
      if (appointmentQuery.docs.isNotEmpty) {
        return appointmentQuery.docs.first.data()['patientName'] ?? 'Unknown Patient';
      }
      
      // Try to get from approved appointments as well
      final approvedQuery = await FirebaseFirestore.instance
          .collection('approved_appointments')
          .where('patientUid', isEqualTo: patientId)
          .limit(1)
          .get();
      
      if (approvedQuery.docs.isNotEmpty) {
        return approvedQuery.docs.first.data()['patientName'] ?? 'Unknown Patient';
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
    final messageDate = DateTime(messageTime.year, messageTime.month, messageTime.day);
    
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
          print('Found patient ID: $patientId');
          final patientName = await _getPatientName(patientId);
          print('Patient name: $patientName');
          
          messagedPatients.add({
            'id': patientId,
            'name': patientName,
            'lastMessage': chatData['lastMessage'] ?? 'No messages yet',
            'lastTimestamp': chatData['lastTimestamp'],
          });
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
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
                                    'Chats',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 32,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Recent conversations',
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
                    child: Container(
                      height: 200,
                      child: Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.redAccent),
                        ),
                      ),
                    ),
                  );
                }

                if (snapshot.hasError) {
                  print('StreamBuilder error: ${snapshot.error}');
                  return SliverToBoxAdapter(
                    child: Container(
                      height: 200,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error, color: Colors.redAccent, size: 48),
                            SizedBox(height: 16),
                            Text(
                              'Error loading conversations',
                              style: TextStyle(color: Colors.redAccent),
                            ),
                            Text(
                              '${snapshot.error}',
                              style: TextStyle(color: Colors.grey, fontSize: 12),
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
                    child: Container(
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
                              'Start messaging with patients by visiting them in the "View Pending" appointments section and begin a conversation.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 16,
                                height: 1.5,
                              ),
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

                return SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final patient = patients[index];
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
                                          borderRadius: BorderRadius.circular(12),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.redAccent.withOpacity(0.3),
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
                                          stream: _presenceService.getUserPresenceStream(patientId),
                                          builder: (context, snapshot) {
                                            final isOnline = snapshot.data ?? false;
                                            return Container(
                                              width: 16,
                                              height: 16,
                                              decoration: BoxDecoration(
                                                color: isOnline 
                                                    ? Colors.lightGreen.shade400 // Green if patient is currently active
                                                    : Colors.grey, // Gray if patient is offline/inactive
                                                borderRadius: BorderRadius.circular(8),
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
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
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
                                            Text(
                                              _formatTimeDetailed(patient['lastTimestamp']),
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
                                                patient['lastMessage'] ?? 'No messages yet',
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
                                  
                                  const SizedBox(width: 8),
                                  
                                  // Arrow icon
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade50,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Icon(
                                      Icons.arrow_forward_ios_rounded,
                                      color: Colors.grey.shade400,
                                      size: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                    childCount: patients.length,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _testStreamManually() {
    print('🧪 Testing stream manually...');
    _streamMessagedPatients().listen(
      (conversations) {
        print('🧪 Manual stream test - Got ${conversations.length} conversations');
        for (var conv in conversations) {
          print('🧪 Manual stream test - Conversation: $conv');
        }
      },
      onError: (error) {
        print('🧪 Manual stream test - Error: $error');
      },
    );
  }

  void _debugShowCurrentState() {
    print('📊 Current widget state:');
    print('📊 _currentUserId: $_currentUserId');
    print('📊 Widget mounted: ${mounted}');
    print('📊 Context: ${context.mounted}');
  }
}
