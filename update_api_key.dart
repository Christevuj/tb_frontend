import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  // Load environment variables
  await dotenv.load(fileName: ".env");

  final apiKey = dotenv.env['GOOGLE_MAPS_API_KEY'];

  if (apiKey == null || apiKey == 'your_google_maps_api_key_here') {
    print(
      '⚠️  Warning: Google Maps API key not set or still using placeholder value',
    );
    print('Please update your .env file with a valid Google Maps API key');
    print('');
    print('Example:');
    print('GOOGLE_MAPS_API_KEY=AIzaSyYourActualApiKeyHere');
    return;
  }

  // Read the strings.xml file
  final stringsPath = 'android/app/src/main/res/values/strings.xml';
  final stringsFile = File(stringsPath);

  if (!stringsFile.existsSync()) {
    print('❌ Error: strings.xml not found at $stringsPath');
    return;
  }

  String content = stringsFile.readAsStringSync();

  // Replace the placeholder API key with the actual key
  content = content.replaceAll('YOUR_GOOGLE_MAPS_API_KEY_HERE', apiKey);

  // Write the updated content back to the file
  stringsFile.writeAsStringSync(content);

  print('✅ Successfully updated strings.xml with Google Maps API key');
  print('API Key: ${apiKey.substring(0, 10)}...');
  print('');
  print('Next steps:');
  print('1. Clean and rebuild your project: flutter clean && flutter pub get');
  print('2. Run the app again: flutter run');
}
