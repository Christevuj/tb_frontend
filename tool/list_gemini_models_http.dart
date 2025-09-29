import 'package:http/http.dart' as http;
import 'dart:convert';

void main() async {
  // Replace with your actual Gemini API key
  const apiKey = 'AIzaSyDwzLT5nxbepTR5wQgwo3l3gL_0IYNhEQg';
  final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models?key=$apiKey');
  print('Fetching available Gemini models via HTTP...');
  final response = await http.get(url);
  if (response.statusCode == 200) {
    final data = json.decode(response.body);
    final models = data['models'] ?? [];
    for (final model in models) {
      print('Model: ${model['name']}');
      print('  Description: ${model['description'] ?? "No description"}');
      print(
          '  Supported methods: ${model['supportedGenerationMethods'] ?? "Unknown"}');
      print('---');
    }
  } else {
    print('Failed to fetch models. Status: ${response.statusCode}');
    print(response.body);
  }
}
