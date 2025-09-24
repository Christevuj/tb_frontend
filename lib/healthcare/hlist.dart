import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ChatScreen extends StatefulWidget {
	final String workerId;
	final String workerName;
	final String currentUserId;
	final String currentUserType; // 'patient' or 'guest'
	const ChatScreen({super.key, required this.workerId, required this.workerName, required this.currentUserId, required this.currentUserType});

	@override
	State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
	final TextEditingController _controller = TextEditingController();

	Stream<QuerySnapshot> getMessagesStream() {
		return FirebaseFirestore.instance
				.collection('messages')
				.where('participants', arrayContains: widget.currentUserId)
				.where('workerId', isEqualTo: widget.workerId)
				.orderBy('timestamp', descending: false)
				.snapshots();
	}

	void sendMessage() async {
		final text = _controller.text.trim();
		if (text.isEmpty) return;
		await FirebaseFirestore.instance.collection('messages').add({
			'workerId': widget.workerId,
			'workerName': widget.workerName,
			'senderId': widget.currentUserId,
			'senderType': widget.currentUserType,
			'text': text,
			'timestamp': FieldValue.serverTimestamp(),
			'participants': [widget.currentUserId, widget.workerId],
		});
		_controller.clear();
	}

	@override
	Widget build(BuildContext context) {
		return Scaffold(
			appBar: AppBar(
				title: Text(widget.workerName),
				backgroundColor: Colors.redAccent,
			),
			body: Column(
				children: [
					Expanded(
						child: StreamBuilder<QuerySnapshot>(
							stream: getMessagesStream(),
							builder: (context, snapshot) {
								if (snapshot.connectionState == ConnectionState.waiting) {
									return const Center(child: CircularProgressIndicator());
								}
								final messages = snapshot.data?.docs ?? [];
								return ListView.builder(
									padding: const EdgeInsets.all(8),
									itemCount: messages.length,
									itemBuilder: (context, index) {
										final msg = messages[index].data() as Map<String, dynamic>;
										final isMe = msg['senderId'] == widget.currentUserId;
										return Align(
											alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
											child: Container(
												margin: const EdgeInsets.symmetric(vertical: 4),
												padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
												decoration: BoxDecoration(
													color: isMe ? Colors.redAccent : Colors.grey.shade300,
													borderRadius: BorderRadius.circular(12),
												),
												child: Text(
													msg['text'] ?? '',
													style: TextStyle(color: isMe ? Colors.white : Colors.black),
												),
											),
										);
									},
								);
							},
						),
					),
					Container(
						padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
						decoration: BoxDecoration(
							color: Colors.grey.shade100,
							border: const Border(top: BorderSide(color: Colors.grey)),
						),
						child: Row(
							children: [
								Expanded(
									child: TextField(
										controller: _controller,
										decoration: const InputDecoration(
											hintText: "Type a message...",
											border: InputBorder.none,
										),
									),
								),
								IconButton(
									icon: const Icon(Icons.send, color: Colors.redAccent),
									onPressed: sendMessage,
								),
							],
						),
					),
				],
			),
		);
	}
}

class HList extends StatelessWidget {
	final String facilityId;
	final String facilityName;
	const HList({super.key, required this.facilityId, required this.facilityName});

	@override
	Widget build(BuildContext context) {
		return Scaffold(
			appBar: AppBar(
				title: Text(facilityName),
				backgroundColor: Colors.redAccent,
			),
			body: StreamBuilder<QuerySnapshot>(
				stream: FirebaseFirestore.instance
						.collection('healthcare')
						.where('affiliationId', isEqualTo: facilityId)
						.snapshots(),
				builder: (context, snapshot) {
					if (snapshot.connectionState == ConnectionState.waiting) {
						return const Center(child: CircularProgressIndicator());
					}
					if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
						return const Center(child: Text('No health workers found.'));
					}
					final workers = snapshot.data!.docs;
					return ListView.builder(
						itemCount: workers.length,
						itemBuilder: (context, index) {
							final worker = workers[index].data() as Map<String, dynamic>;
							final name = '${worker['firstName'] ?? ''} ${worker['lastName'] ?? ''}'.trim();
							final position = worker['position'] ?? '';
							final workerId = workers[index].id;
							return ListTile(
								leading: const Icon(Icons.person, color: Colors.redAccent),
								title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
								subtitle: Text(position),
								trailing: IconButton(
									icon: const Icon(Icons.message, color: Colors.redAccent),
									onPressed: () {
										// For demo, use a placeholder user id and type. Replace with actual patient/guest id and type.
										Navigator.push(
											context,
											MaterialPageRoute(
												builder: (_) => ChatScreen(
													workerId: workerId,
													workerName: name,
													currentUserId: 'demo_patient_id', // TODO: Replace with actual user id
													currentUserType: 'patient', // or 'guest'
												),
											),
										);
									},
								),
							);
						},
					);
				},
			),
		);
	}
}
