import 'package:flutter/material.dart';
import 'package:tb_frontend/ollama_service.dart';
import 'dart:math';

class PConsultant extends StatelessWidget {
  const PConsultant({super.key});

  @override
  Widget build(BuildContext context) {
    return const ChatScreen();
  }
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, String>> _messages = [];
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();

  bool _loading = false;
  bool _greetingDone = false;

  late final AnimationController _quickFadeController;
  late final Animation<Offset> _quickSlideAnimation;

  late final OllamaService _ollamaService;

  final List<String> _greetings = [
    "👋 Hello! I'm your AI consultant. How can I help you today?",
    "🤖 Hi there! Ask me anything about TB care or general health concerns.",
    "💬 Welcome! I’m here to assist you. What would you like to talk about?",
    "🧠 Hello! Got questions? I’ve got answers. Let’s chat!",
    "✨ Hi! I'm here to support your TB journey. How can I help?",
  ];

  final List<String> _quickQuestions = [
    "What are the symptoms of TB?",
    "How is TB transmitted?",
    "Can TB be cured?",
    "What should I do if I have TB symptoms?",
    "What are the side effects of TB medicine?",
  ];

  static const Duration animatedGreetingSpeed = Duration(milliseconds: 40);

  @override
  void initState() {
    super.initState();

    _ollamaService = OllamaService();
    _ollamaService.start();

    _quickFadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _quickSlideAnimation = Tween<Offset>(
      begin: const Offset(-0.5, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _quickFadeController,
      curve: Curves.easeOut,
    ));

    _showTypingGreeting();
  }

  @override
  void dispose() {
    _quickFadeController.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _showTypingGreeting() async {
    final random = Random();
    final greeting = _greetings[random.nextInt(_greetings.length)];

    _addMessage({"role": "assistant", "content": ""});
    final int botIndex = _messages.length - 1;

    for (int i = 0; i < greeting.length; i++) {
      await Future.delayed(animatedGreetingSpeed, () {
        setState(() {
          _messages[botIndex]['content'] =
              (_messages[botIndex]['content'] ?? '') + greeting[i];
        });
      });
    }

    await Future.delayed(const Duration(milliseconds: 500));
    setState(() {
      _greetingDone = true;
    });

    _quickFadeController.forward();
  }

  void _addMessage(Map<String, String> message) {
    _messages.add(message);
    _listKey.currentState?.insertItem(_messages.length - 1);
  }

  void _sendMessage([String? customText]) async {
    final text = customText ?? _controller.text.trim();
    if (text.isEmpty) return;

    _addMessage({"role": "user", "content": text});
    _addMessage({"role": "assistant", "content": ""});
    _controller.clear();

    setState(() {
      _loading = true;
      _greetingDone = false;
    });

    final int botIndex = _messages.length - 1;

    try {
      await for (final chunk in _ollamaService.streamMessage(text)) {
        setState(() {
          _messages[botIndex]['content'] =
              (_messages[botIndex]['content'] ?? '') + chunk;
        });
      }
    } catch (e) {
      setState(() {
        _messages[botIndex]['content'] = "⚠️ Error: $e";
      });
    } finally {
      setState(() {
        _loading = false;
        _greetingDone = true;
      });
      _quickFadeController.forward(from: 0);
    }
  }

  Widget _buildMessage(
      Map<String, String> message, Animation<double> animation) {
    final isUser = message['role'] == 'user';
    final isTyping = message['content'] == '' && !isUser;

    final offsetTween = Tween<Offset>(
      begin: isUser ? const Offset(1, 0) : const Offset(-1, 0),
      end: Offset.zero,
    );

    return SizeTransition(
      sizeFactor: animation,
      axisAlignment: 0.0,
      child: SlideTransition(
        position: animation.drive(offsetTween),
        child: FadeTransition(
          opacity: animation,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment:
                isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              if (!isUser) ...[
                // AI Avatar
                CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.pink.shade100,
                  child: const Icon(Icons.smart_toy,
                      color: Colors.white, size: 18),
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  padding: const EdgeInsets.all(12),
                  constraints: const BoxConstraints(maxWidth: 280),
                  decoration: BoxDecoration(
                    color: isUser
                        ? const Color(
                            0xFFFFCDD2) // 👈 pastel/light pink for user bubble
                        : Colors.grey[300],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: isTyping
                      ? const Text('...')
                      : Text(
                          message['content'] ?? '',
                          style: TextStyle(
                            color: isUser
                                ? Colors.black87
                                : Colors.black, // darker text for readability
                            fontSize: 14,
                          ),
                        ),
                ),
              ),
              if (isUser) ...[
                const SizedBox(width: 8),
                // User Avatar
                CircleAvatar(
                  radius: 16,
                  backgroundColor: const Color.fromARGB(
                      255, 197, 143, 244), // 👈 pastel pink avatar
                  child:
                      const Icon(Icons.person, color: Colors.white, size: 18),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickQuestions() {
    if (!_greetingDone) return const SizedBox.shrink();

    return SlideTransition(
      position: _quickSlideAnimation,
      child: FadeTransition(
        opacity: _quickFadeController,
        child: Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 8),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            alignment: WrapAlignment.start,
            children: _quickQuestions.map((question) {
              return ElevatedButton(
                onPressed: () => _sendMessage(question),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xE0F44336),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  textStyle: const TextStyle(fontSize: 12),
                ),
                child: Text(question),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  // 👈 thin border added
                  color: Colors.grey.shade400,
                  width: 0.8,
                ),
              ),
              child: TextField(
                controller: _controller,
                onSubmitted: (_) => _sendMessage(),
                decoration: const InputDecoration(
                  hintText: 'Type your message...',
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: _loading ? null : _sendMessage,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xE0F44336),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            ),
            child: const Text(
              "Send",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F3F5),
      body: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 40, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Back Button
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.shade300,
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon:
                        const Icon(Icons.arrow_back, color: Color(0xE0F44336)),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                const Text(
                  "AI Consultant",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xE0F44336),
                  ),
                ),
                const SizedBox(width: 48), // spacing balance
              ],
            ),
          ),

          // Chat content
          Expanded(
            child: ShaderMask(
              shaderCallback: (Rect bounds) {
                return const LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Colors.transparent,
                    Colors.black,
                    Colors.black,
                    Colors.transparent,
                  ],
                  stops: [0.0, 0.05, 0.95, 1.0],
                ).createShader(bounds);
              },
              blendMode: BlendMode.dstIn,
              child: AnimatedList(
                key: _listKey,
                initialItemCount: _messages.length,
                padding: const EdgeInsets.all(16),
                itemBuilder: (context, index, animation) =>
                    _buildMessage(_messages[index], animation),
              ),
            ),
          ),
          if (_loading) const LinearProgressIndicator(),
          _buildQuickQuestions(),
          _buildInputArea(),
        ],
      ),
    );
  }
}
