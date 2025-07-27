import 'package:flutter/material.dart';
import 'package:tb_frontend/guest/gmenu.dart';

class GConsultant extends StatelessWidget {
  const GConsultant({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const CustomDrawer(currentRoute: 'consultant'), // ✅ Use external drawer
      appBar: AppBar(
        title: const Text('AI Consultant'),
        centerTitle: true,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: Colors.redAccent),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      backgroundColor: Colors.white,
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: Colors.orange[100],
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 10),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, color: Colors.black),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Attention! TBAI Consultant responses does not guarantee accurate diagnosis. '
                    'Please see your doctor for proper diagnosis and treatment recommendations.',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          const ChatBubble(
            text:
                'You can ask me any questions. Things like “What are the symptoms?”, “What can I do at home?”, or “How do I prevent TB?” I’m here to help!',
            isUser: false,
          ),
          const ChatBubble(
            text: 'What are the symptoms of TB?',
            isUser: true,
          ),
          const ChatBubble(
            text:
                'TB symptoms include a cough lasting more than 2 weeks, chest pain, fever, night sweats, weight loss, and feeling weak or tired.',
            isUser: false,
          ),
          const ChatBubble(
            text: 'Are there any remedies I can try at home?',
            isUser: true,
          ),
          const ChatBubble(
            text:
                'Yes! Get plenty of rest, eat healthy food, drink water, and stay in a clean, airy space. But remember, home care doesn’t replace medical treatment.',
            isUser: false,
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    maxLines: 1,
                    decoration: InputDecoration(
                      hintText: 'Type your message here',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 20),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                const Icon(Icons.send, color: Colors.pinkAccent),
              ],
            ),
          )
        ],
      ),
    );
  }
}

class ChatBubble extends StatelessWidget {
  final String text;
  final bool isUser;

  const ChatBubble({super.key, required this.text, required this.isUser});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: const EdgeInsets.all(12),
        constraints: const BoxConstraints(maxWidth: 300),
        decoration: BoxDecoration(
          color: isUser ? Colors.pinkAccent : Colors.pink[100],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isUser ? Colors.white : Colors.black,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}
