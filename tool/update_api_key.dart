import 'dart:io';

void main() async {
  // Load the .env file
  final envFile = File('.env');
  if (!await envFile.exists()) {
    print("❌ .env file not found!");
    return;
  }

  final lines = await envFile.readAsLines();
  final apiKeyLine = lines.firstWhere(
      (line) => line.startsWith('GOOGLE_MAPS_API_KEY='),
      orElse: () => '');

  if (apiKeyLine.isEmpty) {
    print("❌ GOOGLE_MAPS_API_KEY not found in .env!");
    return;
  }

  final apiKey = apiKeyLine.split('=')[1].trim();

  // Target file for Android
  final valuesDir = Directory('android/app/src/main/res/values');
  if (!valuesDir.existsSync()) {
    valuesDir.createSync(recursive: true);
  }

  final xmlFile = File('${valuesDir.path}/google_maps_api.xml');

  final xmlContent = '''
<resources>
    <string name="google_maps_key" templateMergeStrategy="preserve" translatable="false">$apiKey</string>
</resources>
''';

  await xmlFile.writeAsString(xmlContent);
  print("✅ google_maps_api.xml created/updated with API key.");
}
