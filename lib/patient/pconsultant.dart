import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, String>> _messages = [];
  String _userLanguageCode = 'en';
  String _visibleGreeting =
      "👋 Hello! I am your TB consultant. How can I assist you with your medical or TB-related questions today?";
  bool _serviceAvailable = true;
  String? _serviceError;
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();

  bool _loading = false;
  bool _greetingDone = false;
  bool _isInitializing = true; // Track if we're loading history

  late final AnimationController _quickFadeController;
  late final Animation<Offset> _quickSlideAnimation;

  // List of Gemini models to try in order (from screenshot)
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

    // Detect locale and prepare localized greeting/system prompt
    try {
      final locale = WidgetsBinding.instance.window.locale;
      _userLanguageCode = locale.languageCode.toLowerCase();
    } catch (_) {
      _userLanguageCode = 'en';
    }

    final greetings = {
      'en':
          '👋 Hello! I am your TB consultant. How can I assist you with your medical or TB-related questions today?',
      'tl':
          '👋 Kamusta! Ako ang iyong TB consultant. Paano kita matutulungan tungkol sa TB o medikal na katanungan?',
      'fil':
          '👋 Kamusta! Ako ang iyong TB consultant. Paano kita matutulungan tungkol sa TB o medikal na katanungan?',
      'es':
          '👋 ¡Hola! Soy su consultor de TB. ¿En qué puedo ayudarle sobre tuberculosis o preguntas médicas?',
      'fr':
          '👋 Bonjour! Je suis votre consultant TB. Comment puis-je vous aider concernant la tuberculose ou des questions médicales?',
      'pt':
          '👋 Olá! Sou seu consultor de TB. Como posso ajudá-lo sobre TB ou perguntas médicas?',
    };

    _visibleGreeting = greetings[_userLanguageCode] ?? greetings['en']!;

    // We rely on per-request language instructions provided at runtime.
    final systemPrompt =
        'You are a helpful and knowledgeable TB (Tuberculosis) consultant. Prioritize TB-related information and clearly indicate when a question falls outside TB expertise. You may answer other medical questions when asked, but where appropriate tie answers back to TB relevance. Prefer to respond in the user\'s language; the client will provide a per-request instruction indicating the desired language — follow that instruction. Do not repeat the initial greeting on every reply.\n\nIMPORTANT FORMATTING RULES:\n1. NEVER use asterisks (*) or any markdown symbols for formatting\n2. For titles/headings: Use CAPITAL LETTERS (e.g., "PULMONARY TB (TB IN THE LUNGS)")\n3. For lists/enumerations: Use numbered format (1. 2. 3.) or lettered format (a. b. c.)\n4. For emphasis: Simply use capital letters or put text in parentheses\n5. Keep formatting clean and simple without special characters\n6. Use line breaks to separate sections clearly\n\nExample of correct formatting:\nQUESTION: What are TB symptoms?\n\nCOMMON SYMPTOMS OF TB:\n1. A cough that lasts for three weeks or longer\n2. Coughing up blood or sputum\n3. Chest pain\n4. Unintentional weight loss\n5. Fatigue\n6. Fever and night sweats\n\nPULMONARY TB (TB IN THE LUNGS) is the most common form.';

    _messages.add({"role": "system", "content": systemPrompt});

    // Load chat history from Firestore, then show greeting only if no history
    _initializeChatHistory();
  }

  @override
  void dispose() {
    _quickFadeController.dispose();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // Initialize chat history - load from Firestore or show greeting
  Future<void> _initializeChatHistory() async {
    setState(() {
      _isInitializing = true;
    });
    
    final hadHistory = await _loadChatHistory();
    
    setState(() {
      _isInitializing = false;
    });
    
    // Scroll to bottom after loading history
    if (hadHistory) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    }
    
    // Only show greeting if no history was loaded
    if (!hadHistory) {
      _showTypingGreeting();
    }
  }

  // Scroll to the bottom of the chat
  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _showTypingGreeting() async {
    if (_greetingDone) return;

    final greeting = _visibleGreeting;
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

  // Load chat history from Firestore - returns true if history was loaded
  Future<bool> _loadChatHistory() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      final doc = await FirebaseFirestore.instance
          .collection('ai_chat_history')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        final data = doc.data();
        if (data != null && data['messages'] != null) {
          final savedMessages = List<Map<String, dynamic>>.from(data['messages']);
          
          if (savedMessages.isNotEmpty) {
            // We have saved messages - load them
            final systemPrompt = _messages.isNotEmpty && _messages[0]['role'] == 'system' 
                ? _messages[0] 
                : null;
            
            _messages.clear();
            
            // Re-add system prompt
            if (systemPrompt != null) {
              _messages.add(systemPrompt);
            }
            
            // Add saved messages one by one to properly initialize the list
            for (var msg in savedMessages) {
              if (msg['role'] != 'system') {
                _messages.add(Map<String, String>.from(msg));
              }
            }
            
            // Mark greeting as done since we have history
            setState(() {
              _greetingDone = true;
            });
            
            // Forward the animation immediately
            _quickFadeController.forward();
            
            debugPrint('Loaded ${savedMessages.length} messages from history');
            return true; // History was loaded
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading chat history: $e');
    }
    return false; // No history loaded
  }

  // Save chat history to Firestore
  Future<void> _saveChatHistory() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Filter out system messages and empty messages
      final messagesToSave = _messages
          .where((msg) => msg['role'] != 'system' && (msg['content']?.isNotEmpty ?? false))
          .toList();

      await FirebaseFirestore.instance
          .collection('ai_chat_history')
          .doc(user.uid)
          .set({
        'messages': messagesToSave,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error saving chat history: $e');
    }
  }

  // Start a new chat (clear history)
  Future<void> _startNewChat() async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 520),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.redAccent.shade200, Colors.redAccent.shade700],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.refresh_rounded, color: Colors.white, size: 22),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Start New Chat',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Are you sure you want to start a new conversation?',
                      style: TextStyle(fontSize: 14, color: Colors.black87),
                    ),
                    const SizedBox(height: 12),
                    
                    // Warning message container
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'This will clear your current conversation history and cannot be undone.',
                              style: TextStyle(color: Colors.orange.shade900, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(dialogContext).pop(false),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              side: BorderSide(color: Colors.grey.shade300),
                            ),
                            child: const Text('Cancel', style: TextStyle(color: Colors.black87)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => Navigator.of(dialogContext).pop(true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.redAccent,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('Clear Chat', style: TextStyle(color: Colors.white)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed != true) return;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Delete chat history from Firestore
        await FirebaseFirestore.instance
            .collection('ai_chat_history')
            .doc(user.uid)
            .delete();
      }

      // Keep system prompt before clearing
      final systemPrompt = _messages.isNotEmpty && _messages[0]['role'] == 'system' 
          ? Map<String, String>.from(_messages[0]) 
          : null;

      // Remove all items from AnimatedList properly (except system prompt)
      final itemCount = _messages.length;
      for (int i = itemCount - 1; i >= 1; i--) { // Start from 1 to keep system prompt
        final removedMessage = _messages[i];
        _messages.removeAt(i);
        _listKey.currentState?.removeItem(
          i,
          (context, animation) => _buildMessage(removedMessage, animation),
          duration: const Duration(milliseconds: 150),
        );
      }

      // Wait for animations to complete
      await Future.delayed(const Duration(milliseconds: 200));

      if (!mounted) return;

      setState(() {
        // Ensure only system prompt remains
        _messages.clear();
        if (systemPrompt != null) {
          _messages.add(systemPrompt);
        }
        
        _greetingDone = false;
        _quickFadeController.reset();
      });

      // Show greeting again after a small delay
      await Future.delayed(const Duration(milliseconds: 100));
      if (mounted) {
        _showTypingGreeting();
      }
    } catch (e) {
      debugPrint('Error starting new chat: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error clearing chat. Please try again.')),
        );
      }
    }
  }

  String _detectLanguageFromText(String text) {
    final s = text.toLowerCase().replaceAll(RegExp(r'[^a-z0-9\s]'), ' ');
    final folded = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (folded.isEmpty) return _userLanguageCode;

    final padded = '  ' + folded + '  ';
    final Map<String, int> triCounts = {};
    for (int i = 0; i + 3 <= padded.length; i++) {
      final tri = padded.substring(i, i + 3);
      triCounts[tri] = (triCounts[tri] ?? 0) + 1;
    }

    const Map<String, double> tagalogProfile = {
      ' ng': 0.09,
      'ang': 0.08,
      'na ': 0.06,
      ' pa': 0.05,
      'pa ': 0.04,
      'po ': 0.03,
      'opo': 0.02,
      ' sa': 0.05,
      'sa ': 0.04,
      'ano': 0.03,
    };

    const Map<String, double> cebuanoProfile = {
      'ang': 0.07,
      'nga': 0.09,
      ' sa': 0.05,
      'sa ': 0.04,
      'uns': 0.04,
      'ng ': 0.03,
      'tao': 0.02,
    };

    double dot(Map<String, double> profile) {
      double sum = 0.0;
      for (final e in triCounts.entries) {
        final w = profile[e.key] ?? 0.0;
        if (w != 0.0) sum += w * e.value;
      }
      return sum;
    }

    double normInput = 0.0;
    for (final v in triCounts.values) {
      normInput += v * v;
    }
    normInput = normInput > 0 ? math.sqrt(normInput) : 1.0;

    double normProfile(Map<String, double> profile) {
      double s = 0.0;
      for (final v in profile.values) s += v * v;
      return s > 0 ? math.sqrt(s) : 1.0;
    }

    final dotTag = dot(tagalogProfile);
    final dotCeb = dot(cebuanoProfile);
    final scoreTag = dotTag / (normInput * normProfile(tagalogProfile));
    final scoreCeb = dotCeb / (normInput * normProfile(cebuanoProfile));

    if (scoreTag - scoreCeb > 0.03) return 'tl';
    if (scoreCeb - scoreTag > 0.03) return 'ceb';

    if (folded.contains(' po') ||
        folded.contains('opo') ||
        folded.contains(' po')) return 'tl';

    return _userLanguageCode;
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

    // Scroll to bottom when user sends message
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });

    setState(() {
      _loading = true;
      _greetingDone = false;
    });

    final int botIndex = _messages.length - 1;

    try {
      // Compose the conversation for Gemini, including system prompt and all previous messages
      // Add a short instruction asking the model to reply in the same language as the user's most recent message.
      // Detect language from last user message client-side first
      String detectedLang = _userLanguageCode;
      try {
        final lastUser = _messages.reversed.firstWhere(
            (m) => m['role'] == 'user',
            orElse: () => {})['content'];
        if (lastUser != null && lastUser.isNotEmpty) {
          detectedLang = _detectLanguageFromText(lastUser);
        }
      } catch (_) {
        detectedLang = _userLanguageCode;
      }

      final languageNames = {
        'tl': 'Tagalog',
        'ceb': 'Cebuano',
        'en': 'English'
      };
      final detectedName = languageNames[detectedLang] ?? detectedLang;

      String langInstruction =
          'Reply in the same language as the user (language code: $detectedLang, language: $detectedName). If you cannot detect the language, reply in ${_userLanguageCode}. Do not include thanks, greetings, or sign-offs unless the user explicitly requests them.';

      final List<Content> contents = [];
      contents.add(Content.text(langInstruction));

      final conversationContent = _messages
          .where((m) => m['role'] != null && m['content'] != null)
          .map((m) {
            if (m['role'] == 'user') return Content.text(m['content']!);
            if (m['role'] == 'assistant') return Content.text(m['content']!);
            // For system prompt, prepend as plain text (Gemini API doesn't support system role directly)
            if (m['role'] == 'system') return Content.text(m['content']!);
            return null;
          })
          .whereType<Content>()
          .toList();

      contents.addAll(conversationContent);

      final content = contents;

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
      
      // Save chat history after message is complete
      _saveChatHistory();
      
      // Scroll to bottom after new message
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    }
  }

  Widget _buildMessage(
      Map<String, String> message, Animation<double> animation) {
    if (message['role'] == 'system') {
      return const SizedBox.shrink(); // Hide system prompt
    }
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
                  width: 48,
                  height: 48,
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
                    icon: const Icon(Icons.arrow_back_ios,
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
                // New Chat Button
                Container(
                  width: 48,
                  height: 48,
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
                    icon: const Icon(Icons.add,
                        color: Color(0xE0F44336), size: 24),
                    onPressed: _startNewChat,
                    tooltip: 'New Chat',
                  ),
                ),
              ],
            ),
          ),

          // Warning Banner
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.orange.shade300,
                width: 1.5,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  color: Colors.orange.shade700,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: TextStyle(
                        color: Colors.orange.shade900,
                        fontSize: 13,
                        height: 1.4,
                      ),
                      children: [
                        TextSpan(
                          text: 'Attention! ',
                          style: TextStyle(
                            fontWeight: FontWeight.w900, // Extra bold
                          ),
                        ),
                        TextSpan(
                          text:
                              'The responses do not guarantee accurate diagnosis. Please see your doctor for proper diagnosis and treatment recommendations.',
                          style: TextStyle(
                            fontWeight: FontWeight.w400, // Light bold
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Chat content
          Expanded(
            child: _isInitializing
                ? const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xE0F44336)),
                    ),
                  )
                : ShaderMask(
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
                      controller: _scrollController,
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
    // Try models in order until one responds successfully.
    try {
      for (final modelName in _geminiModels) {
        try {
          final model = GenerativeModel(model: modelName, apiKey: _apiKey);
          final response = await model.generateContent([Content.text('ping')]);
          final text = response.text ?? '';
          if (text.isNotEmpty && !text.toLowerCase().contains('error')) {
            setState(() {
              _serviceAvailable = true;
              _serviceError = null;
            });
            return;
          }
        } catch (_) {
          // try next model on any error (quota, network, etc.)
          continue;
        }
      }
      // If none of the models succeeded:
      setState(() {
        _serviceAvailable = false;
        _serviceError =
            'The AI service is currently unavailable. Please try again later.';
      });
    } catch (e) {
      setState(() {
        _serviceAvailable = false;
        _serviceError =
            'The AI service is currently unavailable. Please try again later.';
      });
    }
  }
}
