import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

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
  final FocusNode _focusNode = FocusNode();
  final List<Map<String, String>> _messages = [
    {
      "role": "system",
      "content":
          "You are a helpful and knowledgeable TB (Tuberculosis) consultant. Greet the user as a TB consultant and only answer questions related to TB. If a question is not related to TB, politely redirect the user to ask about TB or medical topics."
    },
  ];
  bool _serviceAvailable = true;
  String? _serviceError;
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();

  bool _loading = false;
  bool _greetingDone = false;
  bool _isKeyboardVisible = false;

  late final AnimationController _quickFadeController;
  late final Animation<Offset> _quickSlideAnimation;

  // List of Gemini models to try in order
  final List<String> _geminiModels = [
    'models/gemini-2.5-pro',
    'models/gemini-2.5-flash',
    'models/gemini-2.5-flash-lite',
    'models/gemini-2.0-flash',
    'models/gemini-2.0-flash-exp',
    'models/gemini-2.0-flash-lite',
  ];
  final String _apiKey = 'AIzaSyDwzLT5nxbepTR5wQgwo3l3gL_0IYNhEQg';

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

    // No longer create a single model instance; will use fallback logic

    // Check Gemini service availability
    _checkGeminiService();
    if (!_serviceAvailable) return;

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
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _showTypingGreeting() async {
    // Always greet as a TB consultant
    const greeting =
        "👋 Hello! I am your TB consultant. How can I assist you with your medical or TB-related questions today?";
    _addMessage(
        {"role": "greeting", "content": ""}); // Mark as greeting, not assistant
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
    if (!_serviceAvailable) {
      setState(() {
        _serviceError =
            'The AI service is currently unavailable. Please try again later.';
      });
      return;
    }
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
      // Compose the conversation for Gemini, including system prompt and all previous messages
      // Exclude greeting messages to prevent repetition
      final content = _messages
          .where((m) =>
              m['role'] != null &&
              m['content'] != null &&
              m['role'] != 'greeting')
          .map((m) {
            if (m['role'] == 'user') return Content.text(m['content']!);
            if (m['role'] == 'assistant') return Content.text(m['content']!);
            // For system prompt, prepend as plain text (Gemini API doesn't support system role directly)
            if (m['role'] == 'system') return Content.text(m['content']!);
            return null;
          })
          .whereType<Content>()
          .toList();

      bool success = false;
      String lastError = '';
      for (final modelName in _geminiModels) {
        try {
          final model = GenerativeModel(model: modelName, apiKey: _apiKey);
          final response = await model.generateContent(content);
          final aiText = response.text ?? "(No response)";
          _messages[botIndex]['content'] = "";
          for (int i = 0; i < aiText.length; i++) {
            await Future.delayed(const Duration(milliseconds: 18));
            setState(() {
              _messages[botIndex]['content'] =
                  (_messages[botIndex]['content'] ?? '') + aiText[i];
            });
          }
          success = true;
          break;
        } catch (e) {
          lastError = e.toString();
          // If quota error, try next model
          continue;
        }
      }
      if (!success) {
        setState(() {
          _messages[botIndex]['content'] = "⚠️ Error: $lastError";
        });
      }
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
    if (message['role'] == 'system') {
      return const SizedBox.shrink(); // Hide system prompt
    }
    // Treat greeting as assistant message for display purposes
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
    if (!_greetingDone || _isKeyboardVisible) return const SizedBox.shrink();

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
                onPressed: () {
                  _focusNode
                      .unfocus(); // Close keyboard when quick question is tapped
                  _sendMessage(question);
                },
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
                focusNode: _focusNode,
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
    // Detect keyboard visibility
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    _isKeyboardVisible = keyboardHeight > 0;

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
                // Modern Back Button
                Container(
                  height: 48,
                  width: 48,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.shade300,
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new,
                        color: Color.fromARGB(223, 107, 107, 107), size: 20),
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
          if (!_serviceAvailable && _serviceError != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                _serviceError!,
                style: const TextStyle(
                    color: Colors.red, fontWeight: FontWeight.bold),
              ),
            ),
          _buildQuickQuestions(),
          _buildInputArea(),
        ],
      ),
    );
  }

  Future<void> _checkGeminiService() async {
    // Try each configured Gemini model until one responds successfully.
    for (final modelName in _geminiModels) {
      try {
        final model = GenerativeModel(model: modelName, apiKey: _apiKey);
        final response = await model.generateContent([Content.text('ping')]);
        final text = response.text;
        if (text != null && !text.toLowerCase().contains('error')) {
          setState(() {
            _serviceAvailable = true;
            _serviceError = null;
          });
          return;
        }
        // otherwise try next model
      } catch (e) {
        // ignore and try next model
        continue;
      }
    }

    // If none of the models worked, mark service as unavailable.
    setState(() {
      _serviceAvailable = false;
      _serviceError =
          'The AI service is currently unavailable. Please try again later.';
    });
  }
}
