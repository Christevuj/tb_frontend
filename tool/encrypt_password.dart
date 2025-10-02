// Password Encryption Utility
//
// This script demonstrates how to encrypt Gmail App Passwords before storing
// them in Firestore. Run this with: dart run tool/encrypt_password.dart

import '../lib/utils/encryption_helper.dart';

void main() {
  print('🔐 Password Encryption Utility for TBisita');
  print('==========================================\n');

  // Your current password from Firestore
  const String yourPassword = 'lolface123'; // Your current password

  try {
    print('Original Password: $yourPassword');

    // Encrypt the password
    final encryptedPassword = EncryptionHelper.encryptPassword(yourPassword);
    print('Encrypted Password: $encryptedPassword\n');

    // Verify decryption works
    final decryptedPassword =
        EncryptionHelper.decryptPassword(encryptedPassword);
    print('Decrypted Password: $decryptedPassword');

    // Verify they match
    if (yourPassword == decryptedPassword) {
      print('✅ Encryption/Decryption successful!');
    } else {
      print('❌ Encryption/Decryption failed!');
    }

    print('\n� SMTP Configuration for UIC.edu.ph:');
    print('Server: mail.uic.edu.ph');
    print('Port: 587');
    print('Email: karellano_220000001473@uic.edu.ph');
    print(
        'Password Length: ${yourPassword.length} characters (✅ Valid for UIC)');

    print('\n🔧 Next Steps:');
    print('1. Copy the encrypted password above');
    print(
        '2. In Firestore admin document, add field: "smtpPasswordCredentials" = "$encryptedPassword"');
    print(
        '3. Add field: "smtpEmailCredentials" = "karellano_220000001473@uic.edu.ph"');
    print('4. The app will now use your UIC email for sending!');
  } catch (e) {
    print('❌ Error: $e');
  }
}
