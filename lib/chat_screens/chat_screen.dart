import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:async';
import '../services/chat_service.dart';
import '../services/alias_service.dart';
import '../models/message.dart';
import '../services/presence_service.dart';
import '../services/working_hours_service.dart';
import '../widgets/zoomable_image_viewer.dart';

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
  final AliasService _aliasService = AliasService();
  final TextEditingController _controller = TextEditingController();
  final PresenceService _presenceService = PresenceService();

  late final String _chatId;
  String _otherUserName = '';
  String?
      _myAliasFromHealthcare; // The name healthcare worker uses for current user
  bool _showAliasBanner = true; // Controls visibility of alias banner
  String? _otherUserRole; // Track if other user is healthcare
  bool _isOtherUserOnline = false;
  String _otherUserStatus = 'Offline';
  final Map<String, bool> _expandedTimestamps =
      {}; // Track which messages have expanded timestamps

  // Working hours & blocking tracking (only for patients chatting with healthcare)
  bool _isBlocked = false;
  int _remainingMessages = WorkingHoursService.maxMessagesBeforeBlock;
  StreamSubscription<List<Message>>? _messageSubscription;
  String? _lastProcessedMessageId; // Track last healthcare worker message
  String? _currentUserRole; // Track current user's role

  @override
  void initState() {
    super.initState();
    // Generate chatId automatically based on both users
    _chatId =
        _chatService.generateChatId(widget.currentUserId, widget.otherUserId);

    // Mark messages as read when chat screen is opened
    _chatService.markMessagesAsRead(widget.currentUserId, widget.otherUserId);

    // Get the other user's name and role
    _getOtherUserName();
    _getOtherUserRole();
    _initializeAliasMonitoring();
    _initializeCurrentUserRole();

    // Start monitoring other user's presence
    _monitorOtherUserPresence();

    // Debug: Print the chat ID and user IDs
    print('Chat initialized:');
    print('Current User: ${widget.currentUserId}');
    print('Other User: ${widget.otherUserId}');
    print('Chat ID: $_chatId');
  }

  // Initialize current user role and check if blocking restrictions apply
  void _initializeCurrentUserRole() async {
    final role = await _chatService.getUserRole(widget.currentUserId);
    setState(() {
      _currentUserRole = role;
    });

    // Only check block status if current user is patient/guest and other user is healthcare
    if ((role == 'patient' || role == 'guest') &&
        _otherUserRole == 'healthcare') {
      _checkBlockStatus();
      _listenToHealthWorkerReplies();
    }
  }

  // Check block status
  void _checkBlockStatus() async {
    final blocked = await WorkingHoursService.isPatientBlocked(_chatId);
    final msgCount = await WorkingHoursService.getPatientMessageCount(_chatId);
    final remaining = WorkingHoursService.maxMessagesBeforeBlock - msgCount;

    if (mounted) {
      setState(() {
        _isBlocked = blocked;
        _remainingMessages = remaining > 0 ? remaining : 0;
      });
    }
  }

  // Listen to healthcare worker replies to auto-unblock
  void _listenToHealthWorkerReplies() {
    _messageSubscription = _chatService
        .getMessages(widget.currentUserId, widget.otherUserId)
        .listen((messages) async {
      if (messages.isNotEmpty) {
        final lastMessage = messages.first;
        
        // Only reset if this is a NEW healthcare worker message we haven't processed yet
        // AND it's not an auto-reply (auto-replies don't count as real responses)
        if (lastMessage.senderId == widget.otherUserId &&
            lastMessage.id != _lastProcessedMessageId &&
            !lastMessage.text.startsWith('🤖 Automated Reply:')) {
          debugPrint('🔓 Healthcare worker sent new message - resetting block');
          _lastProcessedMessageId = lastMessage.id; // Mark as processed
          
          // Healthcare worker replied - reset block
          await WorkingHoursService.resetPatientMessageCount(_chatId);
          _checkBlockStatus();
        }
      }
    });
  }

  Future<void> _getOtherUserRole() async {
    final role = await _chatService.getUserRole(widget.otherUserId);
    if (mounted) {
      setState(() {
        _otherUserRole = role;
      });
      // After getting role, check aliases
      _checkAliases();
    }
  }

  Future<void> _initializeAliasMonitoring() async {
    // Wait a bit for role to be determined
    await Future.delayed(const Duration(milliseconds: 500));
    _checkAliases();
  }

  Future<void> _checkAliases() async {
    final currentUserRole =
        await _chatService.getUserRole(widget.currentUserId);

    // Always subscribe to alias stream for patient, regardless of other user's role
    if (currentUserRole == 'patient') {
      debugPrint(
          '🔍 PATIENT MODE - Monitoring alias from other user (healthcare or doctor)');
      _aliasService
          .streamPatientAlias(
        healthcareId: widget.otherUserId,
        patientId: widget.currentUserId,
      )
          .listen((alias) {
        if (mounted) {
          setState(() {
            _myAliasFromHealthcare = alias;
          });
          if (alias != null) {
            debugPrint('🏷️ Patient received alias update: $alias');
          }
        }
      });
    }

    // If current user is HEALTHCARE and other user is PATIENT
    // Monitor the alias I've given to the patient
    if (currentUserRole == 'healthcare' && _otherUserRole == 'patient') {
      debugPrint('🔍 HEALTHCARE MODE - Monitoring alias for patient');
      _aliasService
          .streamPatientAlias(
        healthcareId: widget.currentUserId,
        patientId: widget.otherUserId,
      )
          .listen((alias) {
        if (mounted) {
          setState(() {
            if (alias != null) {
              _otherUserName = alias;
            }
          });
          if (alias != null) {
            debugPrint('🏷️ Healthcare worker - patient alias updated: $alias');
          }
        }
      });
    }
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

  // Check if current user is a healthcare worker
  Future<bool> _isCurrentUserHealthcare() async {
    try {
      final role = await _chatService.getUserRole(widget.currentUserId);
      return role == 'healthcare';
    } catch (e) {
      return false;
    }
  }

  // Get other user's profile picture
  Future<String?> _getOtherUserProfilePicture() async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.otherUserId)
          .get();
      return userDoc.data()?['profilePicture'] as String?;
    } catch (e) {
      print('Error getting profile picture: $e');
      return null;
    }
  }

  // Show menu options dialog with avatar, rename, view photos, delete
  void _showMenuOptions() async {
    final isHealthcare = await _isCurrentUserHealthcare();
    final profilePicture = await _getOtherUserProfilePicture();

    if (!mounted) return;

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 340),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header Section with Avatar and Name
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                  child: Column(
                    children: [
                      // Avatar with gradient border
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              Colors.red.shade400,
                              Colors.red.shade600,
                            ],
                          ),
                        ),
                        child: Container(
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                          ),
                          padding: const EdgeInsets.all(3),
                          child: CircleAvatar(
                            radius: 48,
                            backgroundColor: Colors.red.shade100,
                            backgroundImage: profilePicture != null
                                ? NetworkImage(profilePicture)
                                : null,
                            child: profilePicture == null
                                ? Text(
                                    _otherUserName.isNotEmpty
                                        ? _otherUserName[0].toUpperCase()
                                        : '?',
                                    style: TextStyle(
                                      fontSize: 36,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.red.shade700,
                                    ),
                                  )
                                : null,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Name
                      Text(
                        _otherUserName.isEmpty
                            ? widget.otherUserId
                            : _otherUserName,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1C1C1E),
                          letterSpacing: -0.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      // Status indicator
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _isOtherUserOnline
                                  ? Colors.green.shade500
                                  : Colors.grey.shade400,
                              boxShadow: _isOtherUserOnline
                                  ? [
                                      BoxShadow(
                                        color: Colors.green.withOpacity(0.4),
                                        blurRadius: 4,
                                        spreadRadius: 1,
                                      ),
                                    ]
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _otherUserStatus,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Divider
                Container(
                  height: 1,
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        Colors.grey.shade200,
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),

                // Menu options
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    children: [
                      if (isHealthcare) ...[
                        _buildModernMenuOption(
                          icon: Icons.edit_rounded,
                          label: 'Rename Patient',
                          subtitle: 'Set a custom name',
                          gradient: [
                            Colors.blue.shade400,
                            Colors.blue.shade600
                          ],
                          onTap: () {
                            Navigator.pop(context);
                            _showRenameDialog();
                          },
                        ),
                      ],
                      _buildModernMenuOption(
                        icon: Icons.photo_library_rounded,
                        label: 'View Photos',
                        subtitle: 'See all shared images',
                        gradient: [
                          Colors.purple.shade400,
                          Colors.purple.shade600
                        ],
                        onTap: () {
                          Navigator.pop(context);
                          _showPhotoGallery();
                        },
                      ),
                      _buildModernMenuOption(
                        icon: Icons.delete_outline_rounded,
                        label: 'Delete Chat',
                        subtitle: 'Remove conversation',
                        gradient: [Colors.red.shade400, Colors.red.shade600],
                        onTap: () {
                          Navigator.pop(context);
                          _showDeleteConversationDialog();
                        },
                      ),
                    ],
                  ),
                ),

                // Close button
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.grey.shade100,
                      foregroundColor: Colors.grey.shade700,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    child: const Text(
                      'Close',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Modern menu option widget (Messenger style)
  Widget _buildModernMenuOption({
    required IconData icon,
    required String label,
    required String subtitle,
    required List<Color> gradient,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.mediumImpact();
            onTap();
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: Colors.grey.shade50,
            ),
            child: Row(
              children: [
                // Icon with gradient background
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: gradient,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: gradient[0].withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    icon,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                // Text content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1C1C1E),
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
                // Arrow icon
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: Colors.grey.shade400,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMenuOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 16),
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Show rename patient dialog (healthcare workers only)
  void _showRenameDialog() async {
    final controller = TextEditingController();
    final currentAlias = await _aliasService.getPatientAlias(
      healthcareId: widget.currentUserId,
      patientId: widget.otherUserId,
    );

    if (currentAlias != null) {
      controller.text = currentAlias;
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(Icons.edit_rounded, color: Colors.blue, size: 24),
              SizedBox(width: 12),
              Text(
                'Rename Patient',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2C2C2C),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Set a privacy-friendly name for this patient (e.g., "Patient 1", "John", etc.)',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Enter patient name',
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.blue, width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
              ),
            ],
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
            ElevatedButton(
              onPressed: () async {
                HapticFeedback.lightImpact();
                final newName = controller.text.trim();
                if (newName.isNotEmpty) {
                  debugPrint('🔍 Updating patient alias to: $newName');
                  final success = await _aliasService.updatePatientAlias(
                    healthcareId: widget.currentUserId,
                    patientId: widget.otherUserId,
                    newAlias: newName,
                  );

                  if (mounted) {
                    Navigator.of(context).pop();
                    if (success) {
                      // Don't manually set _otherUserName here
                      // The stream listener will automatically update it
                      debugPrint(
                          '✅ Alias update successful, waiting for stream update...');

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Row(
                            children: [
                              const Icon(Icons.check_circle,
                                  color: Colors.white),
                              const SizedBox(width: 12),
                              Text('Patient renamed to "$newName"'),
                            ],
                          ),
                          backgroundColor: Colors.green,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          margin: const EdgeInsets.all(16),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Row(
                            children: [
                              Icon(Icons.error_outline, color: Colors.white),
                              SizedBox(width: 12),
                              Text('Failed to rename patient'),
                            ],
                          ),
                          backgroundColor: Colors.red,
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
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
              ),
              child: const Text(
                'Save',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // Show photo gallery of all images in conversation
  void _showPhotoGallery() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(20),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
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
                      colors: [Colors.red.shade400, Colors.red.shade600],
                    ),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Shared Photos',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, color: Colors.white),
                      ),
                    ],
                  ),
                ),
                // Photos grid
                Expanded(
                  child: StreamBuilder<List<Message>>(
                    stream: _chatService.getMessages(
                      widget.currentUserId,
                      widget.otherUserId,
                    ),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(
                          child: CircularProgressIndicator(),
                        );
                      }

                      final messages = snapshot.data!
                          .where((msg) => msg.type == 'image')
                          .toList();

                      if (messages.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.photo_library_outlined,
                                size: 64,
                                color: Colors.grey.shade300,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No photos shared yet',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      return GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final message = messages[index];
                          return GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ZoomableImageViewer(
                                    imageUrl: message.imageUrl ?? '',
                                  ),
                                ),
                              );
                            },
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                message.imageUrl ?? '',
                                fit: BoxFit.cover,
                                loadingBuilder: (context, child, progress) {
                                  if (progress == null) return child;
                                  return Container(
                                    color: Colors.grey.shade200,
                                    child: const Center(
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  );
                                },
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    color: Colors.grey.shade200,
                                    child: Icon(
                                      Icons.broken_image,
                                      color: Colors.grey.shade400,
                                    ),
                                  );
                                },
                              ),
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

  void _showDeleteConversationDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
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

    // Get current user's role
    final currentUserRole =
        await _chatService.getUserRole(widget.currentUserId);

    try {
      // Only apply blocking restrictions if patient/guest chatting with healthcare
      if ((currentUserRole == 'patient' || currentUserRole == 'guest') &&
          _otherUserRole == 'healthcare') {
        // Check if blocked
        if (_isBlocked) {
          print('🚫 Patient is blocked - cannot send message');
          return;
        }
      }

      // Mark current user as active when sending a message
      await _presenceService.markAsActive();

      print('🚀 CHAT_SCREEN: About to send message');
      print('   Current User ID: ${widget.currentUserId}');
      print('   Current User Role: $currentUserRole');
      print('   Other User ID: ${widget.otherUserId}');
      print('   Other User Role: $_otherUserRole');
      print('   Text: $text');

      // ALWAYS send the user's message first
      print('📤 Sending user message');
      await _chatService.sendTextMessage(
        senderId: widget.currentUserId,
        receiverId: widget.otherUserId,
        text: text,
        senderRole: currentUserRole, // Patient, doctor, healthcare, etc.
        receiverRole: _otherUserRole, // Role of the person receiving
      );

      print('✅ CHAT_SCREEN: Message sent successfully');
      _controller.clear();

      // Only apply working hours restrictions if patient/guest chatting with healthcare
      if ((currentUserRole == 'patient' || currentUserRole == 'guest') &&
          _otherUserRole == 'healthcare') {
        // Increment patient message count
        await WorkingHoursService.incrementPatientMessageCount(_chatId);
        
        // Check if now blocked
        _checkBlockStatus();

        // Check if within working hours to send auto-reply
        final isWithinHours = WorkingHoursService.isWithinWorkingHours();
        print('🕐 Working Hours Check:');
        print('   Current time: ${DateTime.now()}');
        print('   Is within working hours: $isWithinHours');

        if (!isWithinHours) {
          print('   ⚠️ OUTSIDE working hours - sending auto-reply');
          final autoReplyMsg = WorkingHoursService.getAvailabilityMessage();
          await _sendAutoReply(autoReplyMsg);
        }
      }

      // Update the other user's status after sending message
      _updateOtherUserStatus();
    } catch (e) {
      print('❌ CHAT_SCREEN: Error sending message: $e');
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

  // Send automated reply message as a chat bubble
  Future<void> _sendAutoReply(String message) async {
    try {
      print('🤖 Sending auto-reply message...');
      print('   From: ${widget.otherUserId} (healthcare)');
      print('   To: ${widget.currentUserId} (patient/guest)');
      print('   Message: 🤖 Automated Reply:\n\n$message');

      // Send auto-reply as if healthcare worker sent it
      await _chatService.sendTextMessage(
        senderId: widget.otherUserId, // From healthcare worker
        receiverId: widget.currentUserId, // To patient/guest
        text: '🤖 Automated Reply:\n\n$message',
        senderRole: 'healthcare',
        receiverRole: await _chatService.getUserRole(widget.currentUserId),
      );

      print('   ✅ Auto-reply sent successfully');
    } catch (e) {
      print('   ❌ Error sending auto-reply: $e');
    }
  }

  void _showImagePickerOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.white.withOpacity(0.95),
                Colors.white,
              ],
            ),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(30),
              topRight: Radius.circular(30),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: Wrap(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                child: Column(
                  children: [
                    // Modern drag handle
                    Container(
                      width: 50,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    const SizedBox(height: 24),

                    Text(
                      'Choose how you want to add an image',
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Modern option cards
                    Row(
                      children: [
                        Expanded(
                          child: _buildModernImageOption(
                            icon: Icons.camera_alt_rounded,
                            label: 'Camera',
                            subtitle: 'Take a photo',
                            gradient: [
                              const Color(0xFF4F46E5),
                              const Color(0xFF7C3AED),
                            ],
                            onTap: () {
                              HapticFeedback.mediumImpact();
                              Navigator.pop(context);
                              _pickImage(ImageSource.camera);
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildModernImageOption(
                            icon: Icons.photo_library_rounded,
                            label: 'Gallery',
                            subtitle: 'Choose from photos',
                            gradient: [
                              const Color(0xFFEC4899),
                              const Color(0xFFEF4444),
                            ],
                            onTap: () {
                              HapticFeedback.mediumImpact();
                              Navigator.pop(context);
                              _pickImage(ImageSource.gallery);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Cancel button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: TextButton(
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          Navigator.pop(context);
                        },
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.grey.shade100,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildModernImageOption({
    required IconData icon,
    required String label,
    required String subtitle,
    required List<Color> gradient,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradient,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: gradient[0].withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                icon,
                size: 32,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              label,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.white.withOpacity(0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      print('🔍 DEBUG: Starting image picker with source: $source');
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      print('🔍 DEBUG: Picked file: ${pickedFile?.path}');

      if (pickedFile != null) {
        print(
            '🔍 DEBUG: Image selected successfully, file size: ${await File(pickedFile.path).length()} bytes');
        // Show enhanced loading indicator
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Uploading image...',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        'Please wait while we process your photo',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 5),
          ),
        );

        // Mark current user as active when sending an image
        print('🔍 DEBUG: Marking user as active');
        await _presenceService.markAsActive();

        // Check Firebase Authentication first
        print('🔍 DEBUG: Checking Firebase Authentication...');
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) {
          throw Exception('User not authenticated. Please log in again.');
        }
        print('🔍 DEBUG: User authenticated: ${user.uid}');

        // Send image message
        print('🔍 DEBUG: About to send image message');
        print('🔍 DEBUG: Sender ID: ${widget.currentUserId}');
        print('🔍 DEBUG: Receiver ID: ${widget.otherUserId}');
        print('🔍 DEBUG: Image file path: ${pickedFile.path}');

        await _chatService.sendImageMessage(
          senderId: widget.currentUserId,
          receiverId: widget.otherUserId,
          imageFile: File(pickedFile.path),
        );

        print('🔍 DEBUG: Image message sent successfully!');

        // Hide loading indicator and show success
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Container(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.check_circle_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Image sent successfully!',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 2),
          ),
        );

        // Update the other user's status after sending message
        _updateOtherUserStatus();
      }
    } catch (e, stackTrace) {
      print('❌ CHAT_SCREEN ERROR: Failed to pick/send image');
      print('❌ CHAT_SCREEN ERROR: $e');
      print('❌ CHAT_SCREEN STACK TRACE: $stackTrace');
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Container(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.error_outline_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Failed to send image',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        'Please try again',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
          action: SnackBarAction(
            label: 'Retry',
            textColor: Colors.white,
            onPressed: () => _pickImage(ImageSource.gallery),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Debug: Print the alias state
    debugPrint(
        '🔍 CHAT_SCREEN BUILD - _myAliasFromHealthcare: $_myAliasFromHealthcare');
    debugPrint('🔍 CHAT_SCREEN BUILD - _otherUserRole: $_otherUserRole');
    debugPrint(
        '🔍 CHAT_SCREEN BUILD - Should show banner: ${_myAliasFromHealthcare != null}');

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
                              _otherUserName.isNotEmpty
                                  ? _otherUserName[0].toUpperCase()
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
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        icon: const Icon(
                          Icons.more_vert_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          _showMenuOptions();
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // 🔹 Always show Nickname Notice (Pinned Banner) if alias exists and _showAliasBanner is true
          if (_myAliasFromHealthcare != null && _showAliasBanner)
            Container(
              margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 24),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color.fromARGB(255, 67, 67, 67),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color.fromARGB(255, 67, 67, 67),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color.fromARGB(255, 255, 255, 255)
                        .withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        RichText(
                          text: TextSpan(
                            style: TextStyle(
                              color: const Color.fromARGB(255, 255, 255, 255),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                            children: [
                              const TextSpan(text: 'You are identified as '),
                              TextSpan(
                                text: _myAliasFromHealthcare ?? '',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'This helps protect your identity and privacy.',
                          style: TextStyle(
                            color: const Color.fromARGB(255, 255, 255, 255),
                            fontSize: 10,
                            fontStyle: FontStyle.italic,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded,
                        color: const Color.fromARGB(255, 255, 255, 255),
                        size: 18),
                    tooltip: 'Hide banner',
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(),
                    onPressed: () {
                      setState(() {
                        _showAliasBanner = false;
                      });
                    },
                  ),
                ],
              ),
            ),

          // Block warning banner (only for patients/guests chatting with healthcare)
          if ((_currentUserRole == 'patient' || _currentUserRole == 'guest') &&
              _otherUserRole == 'healthcare' &&
              _isBlocked)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.block_outlined,
                      color: Colors.red.shade700, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      WorkingHoursService.getBlockMessage(),
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.red.shade900,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Message count indicator (only for patients/guests chatting with healthcare) - HIDDEN
          // if ((_currentUserRole == 'patient' || _currentUserRole == 'guest') &&
          //     _otherUserRole == 'healthcare' &&
          //     !_isBlocked &&
          //     _remainingMessages < WorkingHoursService.maxMessagesBeforeBlock)
          //   Container(
          //     margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          //     padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          //     decoration: BoxDecoration(
          //       color: Colors.blue.shade50,
          //       borderRadius: BorderRadius.circular(12),
          //       border: Border.all(color: Colors.blue.shade200),
          //     ),
          //     child: Row(
          //       mainAxisSize: MainAxisSize.min,
          //       children: [
          //         Icon(Icons.info_outline,
          //             color: Colors.blue.shade700, size: 16),
          //         const SizedBox(width: 6),
          //         Text(
          //           '$_remainingMessages message${_remainingMessages != 1 ? 's' : ''} remaining before block',
          //           style: TextStyle(
          //             fontSize: 12,
          //             color: Colors.blue.shade900,
          //             fontWeight: FontWeight.w500,
          //           ),
          //         ),
          //       ],
          //     ),
          //   ),

          // ...existing code...
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
                  reverse: true, // Show newest messages at bottom
                  itemCount: messages.length,
                  itemBuilder: (context, i) {
                    // Since we're using reverse: true, we need to reverse the index
                    final reverseIndex = messages.length - 1 - i;
                    final m = messages[reverseIndex];
                    final isMe = m.senderId == widget.currentUserId;
                    final showAvatar = reverseIndex == 0 ||
                        messages[reverseIndex - 1].senderId != m.senderId;

                    // Check if we need to show date separator (previous message is now next in reversed list)
                    final previousMessage = reverseIndex < messages.length - 1
                        ? messages[reverseIndex + 1]
                        : null;
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
                                      _otherUserName.isNotEmpty
                                          ? _otherUserName[0].toUpperCase()
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
                                        padding: m.isImage
                                            ? const EdgeInsets.all(4)
                                            : const EdgeInsets.symmetric(
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
                                        child: m.isImage
                                            ? GestureDetector(
                                                onTap: () {
                                                  HapticFeedback.lightImpact();
                                                  showZoomableImage(
                                                    context,
                                                    m.imageUrl!,
                                                    heroTag:
                                                        'chat_image_${m.id}',
                                                  );
                                                },
                                                child: Hero(
                                                  tag: 'chat_image_${m.id}',
                                                  child: ClipRRect(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            16),
                                                    child: Image.network(
                                                      m.imageUrl!,
                                                      width: 200,
                                                      height: 200,
                                                      fit: BoxFit.cover,
                                                      loadingBuilder: (context,
                                                          child, progress) {
                                                        if (progress == null)
                                                          return child;
                                                        return Container(
                                                          width: 200,
                                                          height: 200,
                                                          decoration:
                                                              BoxDecoration(
                                                            color: Colors
                                                                .grey[200],
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        16),
                                                          ),
                                                          child: const Center(
                                                            child:
                                                                CircularProgressIndicator(
                                                              color: Colors
                                                                  .redAccent,
                                                            ),
                                                          ),
                                                        );
                                                      },
                                                      errorBuilder: (context,
                                                          error, stackTrace) {
                                                        return Container(
                                                          width: 200,
                                                          height: 200,
                                                          decoration:
                                                              BoxDecoration(
                                                            color: Colors
                                                                .grey[200],
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        16),
                                                          ),
                                                          child: const Center(
                                                            child: Icon(
                                                              Icons
                                                                  .error_outline,
                                                              color:
                                                                  Colors.grey,
                                                              size: 40,
                                                            ),
                                                          ),
                                                        );
                                                      },
                                                    ),
                                                  ),
                                                ),
                                              )
                                            : Text(
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

          // Compact Input Area
          Builder(builder: (context) {
            final bool isInputDisabled = _isBlocked &&
                (_currentUserRole == 'patient' ||
                    _currentUserRole == 'guest') &&
                _otherUserRole == 'healthcare';

            return Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              decoration: BoxDecoration(
                color: isInputDisabled ? Colors.grey.shade100 : Colors.white,
                borderRadius: BorderRadius.circular(25),
                border: Border.all(
                  color: isInputDisabled
                      ? Colors.grey.shade300
                      : Colors.grey.shade200,
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color:
                        Colors.black.withOpacity(isInputDisabled ? 0.03 : 0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    // Camera Button
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        icon: Icon(
                          Icons.camera_alt_outlined,
                          color: isInputDisabled
                              ? Colors.grey.shade400
                              : const Color(0xFF6B7280),
                          size: 20,
                        ),
                        onPressed: isInputDisabled
                            ? null
                            : () {
                                HapticFeedback.lightImpact();
                                _showImagePickerOptions();
                              },
                      ),
                    ),
                  const SizedBox(width: 8),

                    // Input Field
                    Expanded(
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 36),
                        child: TextField(
                          controller: _controller,
                          enabled: !isInputDisabled,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _send(),
                          maxLines: 4,
                          minLines: 1,
                          textAlignVertical: TextAlignVertical.center,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: InputDecoration(
                            hintText: isInputDisabled
                                ? 'Blocked - wait for healthcare worker reply'
                                : 'Type a message...',
                            hintStyle: TextStyle(
                              color: isInputDisabled
                                  ? Colors.grey.shade400
                                  : const Color(0xFF9CA3AF),
                              fontSize: 15,
                              fontWeight: FontWeight.w400,
                            ),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w400,
                            color: isInputDisabled
                                ? Colors.grey.shade500
                                : const Color(0xFF1F2937),
                            height: 1.4,
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),

                    // Send Button
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        gradient: isInputDisabled
                            ? null
                            : LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Colors.redAccent,
                                  Colors.red.shade400,
                                ],
                              ),
                        color: isInputDisabled ? Colors.grey.shade300 : null,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: isInputDisabled
                            ? null
                            : [
                                BoxShadow(
                                  color: Colors.redAccent.withOpacity(0.25),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(18),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: isInputDisabled
                              ? null
                              : () {
                                  HapticFeedback.lightImpact();
                                  _send();
                                },
                          child: Center(
                            child: Icon(
                              Icons.send_rounded,
                              color: isInputDisabled
                                  ? Colors.grey.shade500
                                  : Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          })
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _messageSubscription?.cancel();
    super.dispose();
  }
}
