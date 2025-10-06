import 'package:cloud_firestore/cloud_firestore.dart';

class Message {
  final String id;
  final String senderId;
  final String receiverId;
  final String text;
  final String? imageUrl; // For image messages
  final String type; // 'text' or 'image'
  final DateTime timestamp;

  Message({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.text,
    this.imageUrl,
    required this.type,
    required this.timestamp,
  });

  bool get isImage => type == 'image';
  bool get isText => type == 'text';

  Map<String, dynamic> toMapForSend() {
    return {
      'senderId': senderId,
      'receiverId': receiverId,
      'text': text,
      'imageUrl': imageUrl,
      'type': type,
      // use server timestamp on send
      'timestamp': FieldValue.serverTimestamp(),
    };
  }

  factory Message.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final ts = data['timestamp'];
    final DateTime time =
        ts is Timestamp ? ts.toDate() : DateTime.now(); // fallback
    return Message(
      id: doc.id,
      senderId: data['senderId'] ?? '',
      receiverId: data['receiverId'] ?? '',
      text: data['text'] ?? '',
      imageUrl: data['imageUrl'],
      type: data['type'] ?? 'text',
      timestamp: time,
    );
  }
}
