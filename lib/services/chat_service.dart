import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';
import '../models/message.dart';
import 'cloudinary_service.dart';
import 'auto_reply_service.dart';

class ChatService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final CloudinaryService _cloudinaryService = CloudinaryService.instance;
  final AutoReplyService _autoReplyService = AutoReplyService();

  /// --------------------------
  /// 🔹 Generate a unique chatId
  /// --------------------------
  /// Ensures both participants always get the same chatId
  /// Example: patient123 + doctor456 => chatId = doctor456_patient123
  String generateChatId(String userA, String userB) {
    return userA.compareTo(userB) < 0 ? '${userA}_$userB' : '${userB}_$userA';
  }

  /// --------------------------
  /// 🔹 Send a text message
  /// --------------------------
  Future<void> sendTextMessage({
    required String senderId,
    required String receiverId,
    required String text,
    String? senderRole, // 'patient', 'doctor', 'healthcare', 'guest'
    String? receiverRole, // Role of the receiver
  }) async {
    final chatId = generateChatId(senderId, receiverId);

    final msg = {
      'senderId': senderId,
      'receiverId': receiverId,
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),
      'type': 'text',
      'isRead': false, // for read receipts (future use)
    };

    // Save message inside: /chats/{chatId}/messages/{messageId}
    await _db.collection('chats').doc(chatId).collection('messages').add(msg);

    // Update chat document (for displaying in chat list)
    await _db.collection('chats').doc(chatId).set({
      'lastMessage': text,
      'lastTimestamp': FieldValue.serverTimestamp(),
      'participants': [senderId, receiverId],
    }, SetOptions(merge: true));

    // 🤖 TRIGGER AUTO-REPLY if patient/guest is messaging a health worker or doctor
    print('🔍 AUTO-REPLY CHECK:');
    print('   Sender Role: $senderRole');
    print('   Receiver Role: $receiverRole');
    print('   Should trigger: ${(senderRole == 'patient' || senderRole == 'guest') && (receiverRole == 'doctor' || receiverRole == 'healthcare')}');
    
    if ((senderRole == 'patient' || senderRole == 'guest') &&
        (receiverRole == 'doctor' || receiverRole == 'healthcare')) {
      try {
        print('🤖 Triggering auto-reply...');
        await _autoReplyService.handleIncomingMessage(
          chatId: chatId,
          patientId: senderId,
          healthWorkerId: receiverId,
          healthWorkerType: receiverRole ?? 'healthcare',
        );
        print('✅ Auto-reply completed successfully');
      } catch (e) {
        print('❌ Auto-reply error: $e');
        // Don't throw error, just log it - auto-reply failure shouldn't block messaging
      }
    } else {
      print('⏭️ Auto-reply skipped (role mismatch)');
    }
  }

  /// --------------------------
  /// 🔹 Send an image message using Cloudinary
  /// --------------------------
  Future<void> sendImageMessage({
    required String senderId,
    required String receiverId,
    required File imageFile,
  }) async {
    // Verify authentication
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      throw Exception('User not authenticated');
    }
    
    final chatId = generateChatId(senderId, receiverId);
    print('🔍 CHAT_SERVICE: Starting Cloudinary image upload');
    print('🔍 CHAT_SERVICE: Authenticated user: ${currentUser.uid}');
    print('🔍 CHAT_SERVICE: Chat ID: $chatId');
    print('🔍 CHAT_SERVICE: Image file exists: ${await imageFile.exists()}');
    print('🔍 CHAT_SERVICE: Image file size: ${await imageFile.length()} bytes');
    
    try {
      // Upload image to Cloudinary (same approach as pbooking1.dart)
      print('🔍 CHAT_SERVICE: Starting Cloudinary upload...');
      final String? imageUrl = await _cloudinaryService.uploadImage(
        imageFile: imageFile,
        folder: 'tb_chat_images', // Organize chat images in a specific folder
      );
      
      if (imageUrl == null || imageUrl.isEmpty) {
        throw Exception('Failed to upload image to Cloudinary');
      }
      
      print('🔍 CHAT_SERVICE: Cloudinary upload successful!');
      print('🔍 CHAT_SERVICE: Image URL: $imageUrl');

      // Create message with image URL
      final msg = {
        'senderId': senderId,
        'receiverId': receiverId,
        'text': '', // Empty text for image messages
        'imageUrl': imageUrl,
        'type': 'image',
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
      };
      print('🔍 CHAT_SERVICE: Message object created: $msg');

      // Save message inside: /chats/{chatId}/messages/{messageId}
      print('🔍 CHAT_SERVICE: Saving message to Firestore...');
      final docRef = await _db.collection('chats').doc(chatId).collection('messages').add(msg);
      print('🔍 CHAT_SERVICE: Message saved with ID: ${docRef.id}');

      // Update chat document (for displaying in chat list)
      print('🔍 CHAT_SERVICE: Updating chat document...');
      await _db.collection('chats').doc(chatId).set({
        'lastMessage': '📷 Image',
        'lastTimestamp': FieldValue.serverTimestamp(),
        'participants': [senderId, receiverId],
      }, SetOptions(merge: true));
      print('🔍 CHAT_SERVICE: Chat document updated successfully');
    } catch (e, stackTrace) {
      print('❌ CHAT_SERVICE ERROR: Failed to upload image');
      print('❌ CHAT_SERVICE ERROR: $e');
      print('❌ CHAT_SERVICE ERROR TYPE: ${e.runtimeType}');
      
      // Provide specific error messages for common issues
      String errorMessage = 'Failed to upload image';
      if (e.toString().contains('Upload failed')) {
        errorMessage = 'Failed to upload image to Cloudinary. Please try again.';
      } else if (e.toString().contains('network') || e.toString().contains('internet')) {
        errorMessage = 'Network error. Please check your internet connection.';
      } else if (e.toString().contains('No secure_url')) {
        errorMessage = 'Cloudinary upload failed. Please try again.';
      }
      
      print('❌ CHAT_SERVICE ERROR MESSAGE: $errorMessage');
      print('❌ CHAT_SERVICE STACK TRACE: $stackTrace');
      throw Exception(errorMessage);
    }
  }

  /// --------------------------
  /// 🔹 Stream messages (real-time updates)
  /// --------------------------
  Stream<List<Message>> getMessages(String senderId, String receiverId) {
    final chatId = generateChatId(senderId, receiverId);

    return _db
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snap) => snap.docs.map((d) => Message.fromDoc(d)).toList());
  }

  /// --------------------------
  /// 🔹 Mark messages as read
  /// --------------------------
  Future<void> markMessagesAsRead(String senderId, String receiverId) async {
    final chatId = generateChatId(senderId, receiverId);
    final unread = await _db
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .where('receiverId', isEqualTo: senderId)
        .where('isRead', isEqualTo: false)
        .get();

    for (var doc in unread.docs) {
      await doc.reference.update({'isRead': true});
    }
  }

  /// --------------------------
  /// 🔹 Get unread messages count for a conversation
  /// --------------------------
  Future<int> getUnreadMessagesCount(String currentUserId, String otherUserId) async {
    final chatId = generateChatId(currentUserId, otherUserId);
    final unread = await _db
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .where('receiverId', isEqualTo: currentUserId)
        .where('isRead', isEqualTo: false)
        .get();

    return unread.docs.length;
  }

  /// --------------------------
  /// 🔹 Stream unread messages count for a conversation
  /// --------------------------
  Stream<int> streamUnreadMessagesCount(String currentUserId, String otherUserId) {
    final chatId = generateChatId(currentUserId, otherUserId);
    
    return _db
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .where('receiverId', isEqualTo: currentUserId)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  /// --------------------------
  /// 🔹 Create or update a user document
  /// --------------------------
  Future<void> createUserDoc({
    required String userId,
    required String name,
    required String role, // patient | doctor | healthcare
  }) async {
    await _db.collection('users').doc(userId).set({
      'name': name,
      'role': role,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// --------------------------
  /// 🔹 Get a single user’s role
  /// --------------------------
  Future<String?> getUserRole(String userId) async {
    final doc = await _db.collection('users').doc(userId).get();
    if (!doc.exists) return null;
    return doc.data()!['role'] as String?;
  }

  /// --------------------------
  /// 🔹 Stream list of users
  /// --------------------------
  Stream<List<Map<String, dynamic>>> streamUsers({String? role}) {
    Query q = _db.collection('users');
    if (role != null) q = q.where('role', isEqualTo: role);

    return q.snapshots().map(
          (snap) => snap.docs
              .map((d) => {
                    'id': d.id,
                    'name': d['name'],
                    'role': d['role'],
                  })
              .toList(),
        );
  }

  /// --------------------------
  /// 🔹 Stream chat list for a user
  /// --------------------------
  Stream<List<Map<String, dynamic>>> streamUserChats(String userId) {
    return _db
        .collection('chats')
        .where('participants', arrayContains: userId)
        .orderBy('lastTimestamp', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) {
              final data = d.data();
              return {
                'chatId': d.id,
                'lastMessage': data['lastMessage'],
                'lastTimestamp': data['lastTimestamp'],
                'participants': data['participants'],
              };
            }).toList());
  }

  /// --------------------------
  /// 🔹 Delete entire conversation
  /// --------------------------
  Future<void> deleteConversation(String userA, String userB) async {
    final chatId = generateChatId(userA, userB);

    try {
      // Delete all messages in the conversation
      final messagesQuery = await _db
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .get();

      // Delete each message document
      final batch = _db.batch();
      for (var doc in messagesQuery.docs) {
        batch.delete(doc.reference);
      }

      // Delete the chat document itself
      batch.delete(_db.collection('chats').doc(chatId));

      // Execute all deletions
      await batch.commit();

      print('Successfully deleted conversation: $chatId');
    } catch (e) {
      print('Error deleting conversation $chatId: $e');
      rethrow; // Re-throw so the UI can handle the error
    }
  }
}
