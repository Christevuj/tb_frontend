import 'dart:convert';
import 'package:http/http.dart' as http;
import 'services/config_service.dart';

class OllamaService {
  // Optional: startup logic
  void start() {
    print('Ollama service started');
    // You can add any initialization logic here
  }

  // Stream messages from Ollama API
  Stream<String> streamMessage(String userMessage) async* {
    final url = Uri.parse('${ConfigService.ollamaBaseUrl}/api/chat');
    final headers = {'Content-Type': 'application/json'};

    final request = http.Request('POST', url)
      ..headers.addAll(headers)
      ..body = jsonEncode({
        "model": ConfigService.ollamaModel,
        "stream": true,
        "messages": [
          {
            "role": "system",
            "content":
                "You are a helpful assistant. Keep all your responses short but still full of content"
          },
          {"role": "user", "content": userMessage}
        ]
      });

    try {
      final response = await request.send();

      if (response.statusCode != 200) {
        throw Exception('Failed to stream response: ${response.statusCode}');
      }

      await for (var chunk in response.stream.transform(utf8.decoder)) {
        for (var line in LineSplitter.split(chunk)) {
          if (line.trim().isEmpty) continue;
          final jsonData = jsonDecode(line);
          final content = jsonData['message']?['content'];
          if (content != null) {
            yield content;
          }
        }
      }
    } catch (e) {
      print('Error connecting to Ollama: $e');
      yield '❌ Error: Could not connect to Ollama server.';
    }
  }
}
