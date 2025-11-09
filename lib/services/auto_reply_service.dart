import 'package:cloud_firestore/cloud_firestore.dart';

class AutoReplyService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Check if current time is within working hours
  /// Working hours: Monday-Friday, 7:00 AM - 3:00 PM
  bool isWithinWorkingHours() {
    final now = DateTime.now();
    final dayOfWeek = now.weekday; // 1 = Monday, 7 = Sunday
    final hour = now.hour;

    print('⏰ Working Hours Check:');
    print('   Current Time: ${now.toString()}');
    print('   Day of Week: $dayOfWeek (1=Mon, 7=Sun)');
    print('   Hour: $hour');

    // Check if it's a weekend (Saturday = 6, Sunday = 7)
    if (dayOfWeek == DateTime.saturday || dayOfWeek == DateTime.sunday) {
      print('   Result: Weekend - NOT within working hours');
      return false;
    }

    // Check if it's within working hours (7 AM to 3 PM)
    if (hour < 7 || hour >= 15) {
      print('   Result: Outside 7AM-3PM - NOT within working hours');
      return false;
    }

    print('   Result: Within working hours');
    return true;
  }

  /// Get appropriate auto-reply message based on time
  String getOutOfOfficeMessage() {
    final now = DateTime.now();
    final dayOfWeek = now.weekday;
    final hour = now.hour;

    // Weekend message
    if (dayOfWeek == DateTime.saturday || dayOfWeek == DateTime.sunday) {
      return "🏥 Thank you for your message!\n\n"
          "Our health workers are currently unavailable during weekends.\n\n"
          "📅 Working Hours:\n"
          "Monday - Friday\n"
          "7:00 AM - 3:00 PM\n\n"
          "We will respond to your message on the next working day. For medical emergencies, please visit the nearest health center or call emergency services.";
    }

    // After hours (after 3 PM)
    if (hour >= 15) {
      return "🏥 Thank you for your message!\n\n"
          "Our health workers have ended their shift for today.\n\n"
          "📅 Working Hours:\n"
          "Monday - Friday\n"
          "7:00 AM - 3:00 PM\n\n"
          "We will respond to your message during working hours. For medical emergencies, please visit the nearest health center or call emergency services.";
    }

    // Before hours (before 7 AM)
    if (hour < 7) {
      return "🏥 Thank you for your message!\n\n"
          "Our health workers will be available starting at 7:00 AM.\n\n"
          "📅 Working Hours:\n"
          "Monday - Friday\n"
          "7:00 AM - 3:00 PM\n\n"
          "We will respond to your message during working hours. For medical emergencies, please visit the nearest health center or call emergency services.";
    }

    return "";
  }

  /// Welcome message for first-time conversation
  String getWelcomeMessage(String healthWorkerType) {
    if (healthWorkerType.toLowerCase() == 'doctor') {
      return "👨‍⚕️ Welcome!\n\n"
          "Thank you for reaching out to our doctor. Please describe your concern and we will respond as soon as possible.\n\n"
          "📅 Working Hours:\n"
          "Monday - Friday, 7:00 AM - 3:00 PM\n\n"
          "⏱️ Expected response time: Within 24 hours during working days.\n\n"
          "For medical emergencies, please visit the nearest health center immediately.";
    } else {
      return "👩‍⚕️ Welcome!\n\n"
          "Thank you for reaching out to our health worker. Please describe your concern and we will respond as soon as possible.\n\n"
          "📅 Working Hours:\n"
          "Monday - Friday, 7:00 AM - 3:00 PM\n\n"
          "⏱️ Expected response time: Within 24 hours during working days.\n\n"
          "For medical emergencies, please visit the nearest health center immediately.";
    }
  }

  /// Check if this is the first message in the conversation
  Future<bool> isFirstMessage(String chatId) async {
    final messages = await _db
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .limit(2) // Check if there are less than 2 messages
        .get();

    return messages.docs.length <= 1;
  }

  /// Send auto-reply message
  Future<void> sendAutoReply({
    required String chatId,
    required String senderId, // Health worker ID
    required String receiverId, // Patient ID
    required String message,
  }) async {
    print('📤 SENDING AUTO-REPLY:');
    print('   Chat ID: $chatId');
    print('   From (Health Worker): $senderId');
    print('   To (Patient): $receiverId');
    print('   Message length: ${message.length} characters');
    
    final autoReplyMsg = {
      'senderId': senderId,
      'receiverId': receiverId,
      'text': message,
      'timestamp': FieldValue.serverTimestamp(),
      'type': 'text',
      'isRead': false,
      'isAutoReply': true, // Flag to identify auto-replies
    };

    print('   Saving to Firestore...');
    // Save auto-reply message
    await _db
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .add(autoReplyMsg);
    
    print('   ✅ Message saved to Firestore');

    // Update chat document
    await _db.collection('chats').doc(chatId).set({
      'lastMessage': '🤖 Auto-reply sent',
      'lastTimestamp': FieldValue.serverTimestamp(),
      'participants': [senderId, receiverId],
    }, SetOptions(merge: true));
    
    print('   ✅ Chat document updated');
    print('📤 AUTO-REPLY SENT SUCCESSFULLY');
  }

  /// Check if auto-reply was already sent in this session
  Future<bool> hasRecentAutoReply(String chatId, String type) async {
    final now = DateTime.now();
    final fourHoursAgo = now.subtract(const Duration(hours: 4));

    print('   Checking for recent auto-reply (type: $type)...');

    try {
      // Simplified query - just check by isAutoReply field
      final recentAutoReplies = await _db
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .where('isAutoReply', isEqualTo: true)
          .orderBy('timestamp', descending: true)
          .limit(5) // Only check last 5 auto-replies
          .get();

      print('   Found ${recentAutoReplies.docs.length} recent auto-replies');

      // Check if there's already an auto-reply of this type in the last 4 hours
      for (var doc in recentAutoReplies.docs) {
        final data = doc.data();
        final text = data['text'] as String? ?? '';
        final timestamp = data['timestamp'] as Timestamp?;
        
        // Skip if no timestamp yet (just added)
        if (timestamp == null) continue;
        
        final messageTime = timestamp.toDate();
        
        // Check if message is within last 4 hours
        if (messageTime.isAfter(fourHoursAgo)) {
          if ((type == 'welcome' && text.contains('Welcome')) ||
              (type == 'out_of_office' && text.contains('Working Hours'))) {
            print('   Found recent $type auto-reply from ${messageTime}');
            return true;
          }
        }
      }

      print('   No recent $type auto-reply found');
      return false;
    } catch (e) {
      print('   Error checking recent auto-replies: $e');
      // If error, assume no recent auto-reply to allow sending
      return false;
    }
  }

  /// Handle auto-reply logic when patient sends a message
  Future<void> handleIncomingMessage({
    required String chatId,
    required String patientId,
    required String healthWorkerId,
    required String healthWorkerType, // 'doctor' or 'healthcare'
  }) async {
    print('🤖 AUTO-REPLY SERVICE: handleIncomingMessage called');
    print('   Chat ID: $chatId');
    print('   Patient ID: $patientId');
    print('   Health Worker ID: $healthWorkerId');
    print('   Health Worker Type: $healthWorkerType');
    
    // Check if it's the first message
    final isFirst = await isFirstMessage(chatId);
    print('   Is First Message: $isFirst');

    if (isFirst) {
      // Send welcome message
      final hasWelcome = await hasRecentAutoReply(chatId, 'welcome');
      print('   Has Recent Welcome: $hasWelcome');
      
      if (!hasWelcome) {
        final welcomeMsg = getWelcomeMessage(healthWorkerType);
        print('   Sending welcome message...');
        await sendAutoReply(
          chatId: chatId,
          senderId: healthWorkerId,
          receiverId: patientId,
          message: welcomeMsg,
        );
        print('   ✅ Welcome message sent');
      }
    }

    // Check if message is sent outside working hours
    final withinHours = isWithinWorkingHours();
    print('   Within Working Hours: $withinHours');
    
    if (!withinHours) {
      final hasOutOfOffice = await hasRecentAutoReply(chatId, 'out_of_office');
      print('   Has Recent Out-of-Office: $hasOutOfOffice');
      
      if (!hasOutOfOffice) {
        final outOfOfficeMsg = getOutOfOfficeMessage();
        print('   Sending out-of-office message...');
        print('   Message: $outOfOfficeMsg');
        await sendAutoReply(
          chatId: chatId,
          senderId: healthWorkerId,
          receiverId: patientId,
          message: outOfOfficeMsg,
        );
        print('   ✅ Out-of-office message sent');
      }
    }
    
    print('🤖 AUTO-REPLY SERVICE: handleIncomingMessage completed');
  }
}
