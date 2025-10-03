import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/message.dart';

class ChatService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

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
