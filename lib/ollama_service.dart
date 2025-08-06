import 'dart:convert';
import 'package:http/http.dart' as http;

Stream<String> streamMessageFromOllama(String userMessage) async* {
  // Use 10.0.2.2 to access localhost from Android emulator
  final url = Uri.parse('http://10.0.2.2:11434/api/chat');
  final headers = {'Content-Type': 'application/json'};

  final request = http.Request('POST', url)
    ..headers.addAll(headers)
    ..body = jsonEncode({
      "model": "llama3.1",
      "stream": true,
      "messages": [
        {"role": "user", "content": userMessage}
      ]
    });

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
}
