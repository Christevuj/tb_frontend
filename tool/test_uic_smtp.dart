// UIC SMTP Server Testing Utility
//
// This script helps test different SMTP configurations for UIC.edu.ph
// Run this with: dart run tool/test_uic_smtp.dart

import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

void main() async {
  print('🔧 UIC SMTP Server Testing Utility');
  print('===================================\n');

  const String testEmail = 'karellano_220000001473@uic.edu.ph';
  const String testPassword = ''; // Your actual password
  const String testRecipient =
      'karellano_220000001473@uic.edu.ph'; // Send to yourself for testing

  // Different SMTP configurations to test for UIC.edu.ph
  final List<Map<String, dynamic>> smtpConfigs = [
    {
      'name': 'Office 365 (Primary)',
      'server': 'smtp.office365.com',
      'port': 587,
      'ssl': false,
      'allowInsecure': false,
    },
    {
      'name': 'Office 365 Alternative',
      'server': 'smtp-mail.outlook.com',
      'port': 587,
      'ssl': false,
      'allowInsecure': false,
    },
    {
      'name': 'Google Workspace (if UIC uses Gmail)',
      'server': 'smtp.gmail.com',
      'port': 587,
      'ssl': false,
      'allowInsecure': false,
    },
    {
      'name': 'Office 365 with SSL',
      'server': 'smtp.office365.com',
      'port': 465,
      'ssl': true,
      'allowInsecure': false,
    },
    {
      'name': 'Direct UIC Server (if exists)',
      'server': 'mail.uic.edu.ph',
      'port': 587,
      'ssl': false,
      'allowInsecure': true, // Allow insecure for testing
    },
    {
      'name': 'UIC SMTP (alternative naming)',
      'server': 'smtp.uic.edu.ph',
      'port': 587,
      'ssl': false,
      'allowInsecure': true,
    },
  ];

  print('Testing SMTP configurations for: $testEmail\n');

  for (final config in smtpConfigs) {
    await testSmtpConfig(config, testEmail, testPassword, testRecipient);
    print(''); // Add spacing between tests
  }

  print('\n📋 SUMMARY:');
  print('• If Office 365 works: UIC uses Microsoft email services');
  print('• If Gmail works: UIC uses Google Workspace');
  print('• If direct UIC servers work: UIC has custom email infrastructure');
  print('• If none work: Contact UIC IT support for correct SMTP settings');
  print(
      '\n• You may also need to enable "Less secure app access" or use App Passwords');
  print('• Some institutions require VPN access for SMTP');
}

Future<void> testSmtpConfig(Map<String, dynamic> config, String email,
    String password, String recipient) async {
  print('🔍 Testing: ${config['name']}');
  print('   Server: ${config['server']}:${config['port']}');
  print('   SSL: ${config['ssl']}, Allow Insecure: ${config['allowInsecure']}');

  try {
    final smtpServer = SmtpServer(
      config['server'],
      port: config['port'],
      ssl: config['ssl'],
      allowInsecure: config['allowInsecure'],
      username: email,
      password: password,
    );

    final message = Message()
      ..from = Address(email, 'TBisita Test')
      ..recipients.add(recipient)
      ..subject = 'SMTP Test - ${config['name']}'
      ..text =
          'This is a test email from TBisita SMTP configuration testing.\n\n'
              'Configuration: ${config['name']}\n'
              'Server: ${config['server']}:${config['port']}\n'
              'If you receive this, the SMTP configuration works!';

    print('   Status: Attempting to send test email...');
    await send(message, smtpServer);
    print('   ✅ SUCCESS! This configuration works.');
    print('   📧 Test email sent successfully.');
  } catch (e) {
    print('   ❌ FAILED: $e');

    if (e.toString().contains('BadCredentialsException') ||
        e.toString().contains('Authentication')) {
      print('      → Wrong username/password or authentication method');
    } else if (e.toString().contains('host lookup') ||
        e.toString().contains('Unknown host')) {
      print('      → Server address does not exist');
    } else if (e.toString().contains('Connection refused') ||
        e.toString().contains('Network')) {
      print('      → Network connection failed (check port/firewall)');
    } else if (e.toString().contains('SSL') || e.toString().contains('TLS')) {
      print('      → SSL/TLS configuration issue');
    }
  }
}
