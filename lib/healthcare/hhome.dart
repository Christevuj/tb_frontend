import 'package:flutter/material.dart';

class Hhome extends StatefulWidget {
  const Hhome({super.key});

  @override
  State<Hhome> createState() => _HhomeState();
}

class _HhomeState extends State<Hhome> {
  final List<Map<String, String>> conversations = [
    {"name": "Juan Dela Cruz", "message": "Kumusta ka na?"},
    {"name": "Cardo Dalisay", "message": "Magkita tayo bukas."},
    {"name": "Maria Clara", "message": "Salamat sa tulong mo."},
    {"name": "Andres Bonifacio", "message": "Nasaan ka ngayon?"},
    {"name": "Jose Rizal", "message": "May balita ka na ba?"},
  ];

  String searchQuery = "";

  @override
  Widget build(BuildContext context) {
    final filteredConversations = conversations
        .where((convo) =>
            convo["name"]!.toLowerCase().contains(searchQuery.toLowerCase()) ||
            convo["message"]!.toLowerCase().contains(searchQuery.toLowerCase()))
        .toList();

    return Scaffold(
      backgroundColor: Colors.white,
      // AppBar with logo like landing page
     appBar: PreferredSize(
  preferredSize: const Size.fromHeight(100),
  child: AppBar(
    automaticallyImplyLeading: false,
    backgroundColor: Colors.white,
    elevation: 0,
    flexibleSpace: SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(left: 16, top: 16), // aligns with search bar
        child: Align(
          alignment: Alignment.centerLeft,
          child: Image.asset(
            'assets/images/tbisita_logo2.png',
            height: 44,
            fit: BoxFit.contain,
          ),
        ),
      ),
    ),
  ),
),


      body: Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    // Reduced vertical spacing between logo and search bar
    const SizedBox(height: 8), // <-- less space than before

    // Search bar like landing page
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(25),
        ),
        child: TextField(
          onChanged: (value) {
            setState(() {
              searchQuery = value;
            });
          },
          decoration: const InputDecoration(
            icon: Icon(Icons.search, color: Colors.grey),
            hintText: 'Search messages...',
            border: InputBorder.none,
          ),
        ),
      ),
    ),

          // Messages list
          Expanded(
            child: ListView.builder(
              itemCount: filteredConversations.length,
              itemBuilder: (context, index) {
                final convo = filteredConversations[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.redAccent,
                    child: Text(
                      convo['name']![0],
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  title: Text(
                    convo['name']!,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    convo['message']!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatScreen(name: convo['name']!),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// Chat screen remains the same
class ChatScreen extends StatefulWidget {
  final String name;
  const ChatScreen({super.key, required this.name});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final List<Map<String, String>> _messages = [
    {"sender": "other", "text": "Hello!"},
    {"sender": "me", "text": "Hi, kumusta?"},
    {"sender": "other", "text": "Ayos lang, ikaw?"},
  ];
  final TextEditingController _controller = TextEditingController();

  void _sendMessage() {
    if (_controller.text.trim().isEmpty) return;
    setState(() {
      _messages.add({"sender": "me", "text": _controller.text.trim()});
      _controller.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.redAccent,
        title: Text(widget.name),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isMe = msg['sender'] == 'me';
                return Align(
                  alignment:
                      isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding:
                        const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    decoration: BoxDecoration(
                      color: isMe ? Colors.redAccent : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      msg['text']!,
                      style: TextStyle(
                        color: isMe ? Colors.white : Colors.black,
                      ),
                    ),
                  ),
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
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
