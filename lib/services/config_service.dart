import 'package:flutter_dotenv/flutter_dotenv.dart';

class ConfigService {
  static const String _defaultOllamaUrl = 'http://localhost:11434';
  static const String _defaultOllamaModel = 'llama3.1';

  // Initialize the configuration service
  static Future<void> initialize() async {
    await dotenv.load(fileName: ".env");
  }

  // Ollama Configuration
  static String get ollamaBaseUrl =>
      dotenv.env['OLLAMA_BASE_URL'] ?? _defaultOllamaUrl;

  static String get ollamaModel =>
      dotenv.env['OLLAMA_MODEL'] ?? _defaultOllamaModel;

  // Google Maps Configuration
  static String? get googleMapsApiKey => dotenv.env['GOOGLE_MAPS_API_KEY'];

  // Firebase Configuration
  static String? get firebaseProjectId => dotenv.env['FIREBASE_PROJECT_ID'];

  // General API Keys
  static String? get apiKey => dotenv.env['API_KEY'];

  static String? get secretKey => dotenv.env['SECRET_KEY'];

  // Environment
  static String get environment => dotenv.env['ENVIRONMENT'] ?? 'development';

  // Helper method to check if we're in development mode
  static bool get isDevelopment => environment == 'development';

  static bool get isProduction => environment == 'production';
}
