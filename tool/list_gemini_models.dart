import 'package:google_generative_ai/google_generative_ai.dart';

void main() async {
  // Replace with your actual Gemini API key
  const apiKey = 'AIzaSyANBwDBHupipVYI3lAgNFs4QIm4OluEM5A';
  print('Fetching available Gemini models...');
  try {
    // Try ModelService API (newer versions)
    final models = await ModelService(apiKey: apiKey).list();
    for (final model in models) {
      print('Model: ${model.name}');
      print('  Description: ${model.description}');
      print('  Supported methods: ${model.supportedGenerationMethods}');
      print('---');
    }
  } catch (e) {
    print('ModelService.list() failed: $e');
    // Try GenerativeModel.list API (older versions)
    try {
      final models = await GenerativeModel.list(apiKey: apiKey);
      for (final model in models) {
        print('Model: ${model.name}');
        print('  Description: ${model.description}');
        print('  Supported methods: ${model.supportedGenerationMethods}');
        print('---');
      }
    } catch (e2) {
      print('GenerativeModel.list() also failed: $e2');
      print(
          'Please check your google_generative_ai package version and documentation.');
    }
  }
}
