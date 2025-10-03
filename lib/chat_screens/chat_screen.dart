import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/chat_service.dart';
import '../models/message.dart';
import '../services/presence_service.dart';

class ChatScreen extends StatefulWidget {
  final String currentUserId;
  final String otherUserId;

  const ChatScreen({
    super.key,
    required this.currentUserId,
    required this.otherUserId,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ChatService _chatService = ChatService();
  final TextEditingController _controller = TextEditingController();
  final PresenceService _presenceService = PresenceService();

  late final String _chatId;
  String _otherUserName = '';
  bool _isOtherUserOnline = false;
  String _otherUserStatus = 'Offline';
  final Map<String, bool> _expandedTimestamps =
      {}; // Track which messages have expanded timestamps

  @override
  void initState() {
    super.initState();
    // Generate chatId automatically based on both users
    _chatId =
        _chatService.generateChatId(widget.currentUserId, widget.otherUserId);

    // Get the other user's name
    _getOtherUserName();

    // Start monitoring other user's presence
    _monitorOtherUserPresence();

    // Debug: Print the chat ID and user IDs
    print('Chat initialized:');
    print('Current User: ${widget.currentUserId}');
    print('Other User: ${widget.otherUserId}');
    print('Chat ID: $_chatId');
  }

  void _monitorOtherUserPresence() {
    // Listen to the other user's presence status
    _presenceService
        .getUserPresenceStream(widget.otherUserId)
        .listen((isOnline) {
      if (mounted) {
        setState(() {
          _isOtherUserOnline = isOnline;
        });
      }
    });

    // Also update the status text periodically
    _updateOtherUserStatus();
  }

  void _updateOtherUserStatus() async {
    final status = await _presenceService.getLastSeenText(widget.otherUserId);
    if (mounted) {
      setState(() {
        _otherUserStatus = status;
      });
    }
  }

  Future<void> _getOtherUserName() async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.otherUserId)
          .get();

      if (userDoc.exists) {
        setState(() {
          _otherUserName = userDoc.data()?['name'] ?? widget.otherUserId;
        });
        return;
      }

      // If no user document, try to get name from appointments
      final appointmentQuery = await FirebaseFirestore.instance
          .collection('pending_patient_data')
          .where('patientUid', isEqualTo: widget.otherUserId)
          .limit(1)
          .get();

      if (appointmentQuery.docs.isNotEmpty) {
        setState(() {
          _otherUserName = appointmentQuery.docs.first.data()['patientName'] ??
              widget.otherUserId;
        });
        return;
      }

      // Try as doctor
      final doctorQuery = await FirebaseFirestore.instance
          .collection('pending_patient_data')
          .where('doctorUid', isEqualTo: widget.otherUserId)
          .limit(1)
          .get();

      if (doctorQuery.docs.isNotEmpty) {
        setState(() {
          _otherUserName =
              doctorQuery.docs.first.data()['doctorName'] ?? widget.otherUserId;
        });
        return;
      }

      // Fallback to otherUserId
      setState(() {
        _otherUserName = widget.otherUserId;
      });
    } catch (e) {
      print('Error getting user name: $e');
      setState(() {
        _otherUserName = widget.otherUserId;
      });
    }
  }

  String _formatDetailedTime(DateTime timestamp) {
    final now = DateTime.now();
    final messageDate =
        DateTime(timestamp.year, timestamp.month, timestamp.day);
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    // Convert to 12-hour format
    final hour = timestamp.hour;
    final minute = timestamp.minute;
    final period = hour >= 12 ? 'pm' : 'am';
    final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    final timeString =
        '$displayHour:${minute.toString().padLeft(2, '0')}$period';

    if (messageDate == today) {
      return timeString;
    } else if (messageDate == yesterday) {
      return 'Yesterday $timeString';
    } else if (now.difference(timestamp).inDays < 7) {
      const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return '${weekdays[timestamp.weekday - 1]} $timeString';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year.toString().substring(2)} $timeString';
    }
  }

  String _formatMessengerTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final messageDate =
        DateTime(timestamp.year, timestamp.month, timestamp.day);
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    // Convert to 12-hour format
    final hour = timestamp.hour;
    final minute = timestamp.minute;
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    final timeString =
        '$displayHour:${minute.toString().padLeft(2, '0')} $period';

    if (messageDate == today) {
      return 'TODAY';
    } else if (messageDate == yesterday) {
      return 'YESTERDAY';
    } else if (now.difference(timestamp).inDays < 7) {
      const weekdays = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
      return '${weekdays[timestamp.weekday - 1]} AT $timeString';
    } else if (timestamp.year == now.year) {
      const months = [
        'JAN',
        'FEB',
        'MAR',
        'APR',
        'MAY',
        'JUN',
        'JUL',
        'AUG',
        'SEP',
        'OCT',
        'NOV',
        'DEC'
      ];
      return '${months[timestamp.month - 1]} ${timestamp.day}';
    } else {
      const months = [
        'JAN',
        'FEB',
        'MAR',
        'APR',
        'MAY',
        'JUN',
        'JUL',
        'AUG',
        'SEP',
        'OCT',
        'NOV',
        'DEC'
      ];
      return '${months[timestamp.month - 1]} ${timestamp.day}, ${timestamp.year}';
    }
  }

  bool _shouldShowDateSeparator(DateTime current, DateTime? previous) {
    if (previous == null) return true; // Always show for first message

    final currentDate = DateTime(current.year, current.month, current.day);
    final previousDate = DateTime(previous.year, previous.month, previous.day);

    return currentDate != previousDate;
  }

  Widget _buildDateSeparator(DateTime timestamp) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Text(
            _formatMessengerTimestamp(timestamp),
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 12,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }

  void _showDeleteConversationDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(
                Icons.warning_rounded,
                color: Colors.redAccent,
                size: 24,
              ),
              const SizedBox(width: 12),
              const Text(
                'Delete Conversation',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2C2C2C),
                ),
              ),
            ],
          ),
          content: Text(
            'Are you sure you want to delete this entire conversation? This action cannot be undone.',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
              height: 1.4,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                HapticFeedback.lightImpact();
                Navigator.of(context).pop();
              },
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Container(
              margin: const EdgeInsets.only(left: 8),
              child: ElevatedButton(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  Navigator.of(context).pop();
                  _deleteConversation();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                ),
                child: const Text(
                  'Delete',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _deleteConversation() async {
    try {
      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              SizedBox(width: 16),
              Text('Deleting conversation...'),
            ],
          ),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 3),
        ),
      );

      // Delete the conversation using the chat service
      await _chatService.deleteConversation(
          widget.currentUserId, widget.otherUserId);

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white),
                SizedBox(width: 16),
                Text('Conversation deleted successfully'),
              ],
            ),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 2),
          ),
        );

        // Navigate back after a short delay
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (mounted) {
            Navigator.of(context).pop();
          }
        });
      }
    } catch (e) {
      print('Error deleting conversation: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting conversation: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }
  }

  void _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    try {
      // Mark current user as active when sending a message
      await _presenceService.markAsActive();

      await _chatService.sendTextMessage(
        senderId: widget.currentUserId,
        receiverId: widget.otherUserId,
        text: text,
      );
      _controller.clear();

      // Update the other user's status after sending message
      _updateOtherUserStatus();
    } catch (e) {
      print('Error sending message: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error sending message: $e'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      body: Column(
        children: [
          // Modern Header with Gradient
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.redAccent,
                  Colors.redAccent.withOpacity(0.8),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: Color(0x26000000),
                  blurRadius: 10,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Modern Back Button
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        icon: const Icon(
                          Icons.arrow_back_ios_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          Navigator.of(context).pop();
                        },
                      ),
                    ),
                    const SizedBox(width: 16),

                    // User Avatar with Online Status
                    Stack(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFFFF5252),
                                Color(0xFFE91E63)
                              ], // redAccent to pink accent
                            ),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: Center(
                            child: Text(
                              widget.otherUserId.isNotEmpty
                                  ? widget.otherUserId[0].toUpperCase()
                                  : 'U',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        // Online Status Indicator - green if user is active, gray if offline (like Messenger)
                        Positioned(
                          bottom: 2,
                          right: 2,
                          child: Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              color: _isOtherUserOnline
                                  ? const Color(
                                      0xFF4CAF50) // Green if user is currently active
                                  : Colors
                                      .grey, // Gray if user is offline/inactive
                              borderRadius: BorderRadius.circular(7),
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 16),

                    // User Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _otherUserName.isEmpty
                                ? widget.otherUserId
                                : _otherUserName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          // Show real presence status like Messenger
                          Text(
                            _otherUserStatus,
                            style: TextStyle(
                              color: _isOtherUserOnline
                                  ? Colors.white70
                                  : Colors.white54,
                              fontSize: 13,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // More Options Button
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: PopupMenuButton<String>(
                        padding: EdgeInsets.zero,
                        icon: const Icon(
                          Icons.more_vert_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                        color: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 8,
                        onSelected: (value) {
                          HapticFeedback.lightImpact();
                          if (value == 'delete') {
                            _showDeleteConversationDialog();
                          }
                        },
                        itemBuilder: (BuildContext context) => [
                          PopupMenuItem<String>(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.delete_outline_rounded,
                                  color: Colors.red.shade400,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Delete Conversation',
                                  style: TextStyle(
                                    color: Colors.red.shade400,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // 🔹 Messages List
          Expanded(
            child: StreamBuilder<List<Message>>(
              stream: _chatService.getMessages(
                  widget.currentUserId, widget.otherUserId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(25),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFFFF5252), // redAccent
                          strokeWidth: 3,
                        ),
                      ),
                    ),
                  );
                }

                // Debug: Print what we're getting
                print('Chat ${widget.currentUserId} -> ${widget.otherUserId}:');
                print('Has data: ${snapshot.hasData}');
                print('Data length: ${snapshot.data?.length ?? 0}');
                print('Error: ${snapshot.error}');

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(40),
                          ),
                          child: Icon(
                            Icons.error_outline_rounded,
                            color: Colors.red.shade300,
                            size: 40,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Something went wrong',
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
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
                          child: Icon(
                            Icons.chat_bubble_outline_rounded,
                            color: Colors.redAccent,
                            size: 50,
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'No messages yet',
                          style: TextStyle(
                            color: Color(0xFF2C2C2C),
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Send a message to start the conversation',
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 16,
                            fontWeight: FontWeight.w400,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                final messages = snapshot.data!;

                return ListView.builder(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: messages.length,
                  itemBuilder: (context, i) {
                    final m = messages[i];
                    final isMe = m.senderId == widget.currentUserId;
                    final showAvatar = i == messages.length - 1 ||
                        messages[i + 1].senderId != m.senderId;

                    // Check if we need to show date separator
                    final previousMessage = i > 0 ? messages[i - 1] : null;
                    final showDateSeparator = _shouldShowDateSeparator(
                        m.timestamp, previousMessage?.timestamp);

                    return Column(
                      children: [
                        // Show date separator if needed
                        if (showDateSeparator) _buildDateSeparator(m.timestamp),

                        // Message container
                        Container(
                          margin: EdgeInsets.only(
                            top: 2,
                            bottom: showAvatar ? 12 : 2,
                            left: isMe ? 50 : 0,
                            right: isMe ? 0 : 50,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisAlignment: isMe
                                ? MainAxisAlignment.end
                                : MainAxisAlignment.start,
                            children: [
                              if (!isMe && showAvatar) ...[
                                // Other user Avatar (only show for last message in group)
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFFFF5252),
                                        Color(0xFFE91E63)
                                      ], // redAccent to pink accent
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                        color: Colors.white, width: 1.5),
                                  ),
                                  child: Center(
                                    child: Text(
                                      widget.otherUserId.isNotEmpty
                                          ? widget.otherUserId[0].toUpperCase()
                                          : 'U',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ] else if (!isMe) ...[
                                const SizedBox(width: 40),
                              ],

                              // Message Bubble
                              Flexible(
                                child: Column(
                                  crossAxisAlignment: isMe
                                      ? CrossAxisAlignment.end
                                      : CrossAxisAlignment.start,
                                  children: [
                                    GestureDetector(
                                      onTap: () {
                                        HapticFeedback.lightImpact();
                                        setState(() {
                                          _expandedTimestamps[m.id] =
                                              !(_expandedTimestamps[m.id] ??
                                                  false);
                                        });
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 12,
                                        ),
                                        decoration: BoxDecoration(
                                          gradient: isMe
                                              ? LinearGradient(
                                                  begin: Alignment.topLeft,
                                                  end: Alignment.bottomRight,
                                                  colors: [
                                                    Colors.redAccent,
                                                    Colors.redAccent
                                                        .withOpacity(0.8),
                                                  ],
                                                )
                                              : null,
                                          color: isMe ? null : Colors.white,
                                          borderRadius: BorderRadius.only(
                                            topLeft: const Radius.circular(20),
                                            topRight: const Radius.circular(20),
                                            bottomLeft: isMe
                                                ? const Radius.circular(20)
                                                : const Radius.circular(4),
                                            bottomRight: isMe
                                                ? const Radius.circular(4)
                                                : const Radius.circular(20),
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: isMe
                                                  ? const Color(
                                                      0x33FF5252) // redAccent with opacity
                                                  : const Color(0x1A000000),
                                              blurRadius: 8,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: Text(
                                          m.text,
                                          style: TextStyle(
                                            color: isMe
                                                ? Colors.white
                                                : const Color(0xFF2C2C2C),
                                            fontSize: 16,
                                            fontWeight: FontWeight.w400,
                                            height: 1.4,
                                          ),
                                        ),
                                      ),
                                    ),
                                    // Show timestamp below bubble if expanded
                                    if (_expandedTimestamps[m.id] ?? false) ...[
                                      const SizedBox(height: 4),
                                      AnimatedContainer(
                                        duration:
                                            const Duration(milliseconds: 200),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade100,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              _formatDetailedTime(m.timestamp),
                                              style: TextStyle(
                                                color: Colors.grey.shade600,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w400,
                                              ),
                                            ),
                                            if (isMe) ...[
                                              const SizedBox(width: 4),
                                              Icon(
                                                Icons.done_all_rounded,
                                                size: 14,
                                                color: Colors.grey.shade600,
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ], // Close Row children (Row inside Container)
                          ), // Close Row
                        ), // Close Container
                      ], // Close Column children
                    ); // Close Column
                  },
                );
              },
            ),
          ),

          // Modern Input Area
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  // Attachment Button
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F2F5),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: IconButton(
                      icon: const Icon(
                        Icons.add_rounded,
                        color: Color(0xFFFF5252), // redAccent
                        size: 24,
                      ),
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        // Add attachment functionality here
                      },
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Input Field
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F2F5),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: TextField(
                        controller: _controller,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _send(),
                        maxLines: null,
                        decoration: const InputDecoration(
                          hintText: 'Type a message...',
                          hintStyle: TextStyle(
                            color: Color(0xFF8E8E93),
                            fontSize: 16,
                            fontWeight: FontWeight.w400,
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                        ),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                          color: Color(0xFF2C2C2C),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Send Button
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.redAccent,
                          Colors.redAccent.withOpacity(0.8),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.redAccent.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(22),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(22),
                        onTap: () {
                          HapticFeedback.lightImpact();
                          _send();
                        },
                        child: const Center(
                          child: Icon(
                            Icons.send_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}
