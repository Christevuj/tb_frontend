// Dynamic Email Configuration Helper
// This file manages email credentials from Firestore admin collection
//
// 📧 ADMIN COLLECTION SETUP:
// Each admin document in Firestore should have these fields for email:
// - smtpEmailCredentials: The email address for sending emails (any provider)
// - smtpPasswordCredentials: The ENCRYPTED email password (use EncryptionHelper)
// - displayName: Name to show as sender (optional, defaults to 'TBisita Admin')
// - smtpServer: SMTP server (optional, auto-detected from email domain)
// - smtpPort: SMTP port (optional, defaults based on provider)
//
// 📧 SUPPORTED EMAIL PROVIDERS:
// - Gmail: smtp.gmail.com:587
// - UIC.edu.ph: smtp.office365.com:587 (primary) - Most .edu.ph institutions use Office 365
// - Outlook: smtp-mail.outlook.com:587
// - Yahoo: smtp.mail.yahoo.com:587
// - Custom SMTP servers
//
// 📧 UIC.edu.ph SMTP SERVER OPTIONS:
// If smtp.office365.com doesn't work, try these alternatives:
// 1. smtp.gmail.com:587 (if UIC uses Google Workspace)
// 2. mail.uic.edu.ph:587 (direct UIC server, if available)
// 3. smtp.uic.edu.ph:587 (standard naming convention)
// 4. mail.office365.com:587 (Office 365 alternative)
// Contact UIC IT support for the correct SMTP server.
//
// 📧 SETUP INSTRUCTIONS:
// 1. For Gmail: Enable 2FA and generate App Password (16 chars)
// 2. For UIC.edu.ph: Use your institutional email credentials
// 3. For others: Check provider's SMTP settings
// 4. Encrypt the password using EncryptionHelper.encryptPassword()
// 5. Store the encrypted password in the admin document in Firestore

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/encryption_helper.dart';

class EmailConfig {
  // Default SMTP Configuration
  static const String defaultSmtpServer = 'smtp.gmail.com';
  static const int defaultSmtpPort = 587;
  static const bool useSSL = false;
  static const bool allowInsecure = false;

  // SMTP server configurations for different email providers
  static const Map<String, Map<String, dynamic>> smtpConfigs = {
    'gmail.com': {
      'server': 'smtp.gmail.com',
      'port': 587,
      'requiresAppPassword': true,
      'minPasswordLength': 16,
    },
    'uic.edu.ph': {
      'server':
          'smtp.office365.com', // Primary: Office 365 (most common for .edu.ph)
      'port': 587,
      'requiresAppPassword': false, // Try regular password first
      'minPasswordLength': 6,
      'alternativeServers': [
        'smtp.gmail.com', // Alternative 1: If UIC uses Google Workspace
        'smtp-mail.outlook.com', // Alternative 2: Outlook SMTP
        'mail.uic.edu.ph', // Alternative 3: Direct UIC server (if exists)
        'smtp.uic.edu.ph', // Alternative 4: Standard SMTP naming
      ],
      'authenticationOptions': [
        'regular', // Standard username/password
        'app_password', // If UIC requires App Passwords for Office 365
        'oauth2', // If UIC uses OAuth2 authentication
      ],
      'troubleshootingNotes': [
        'UIC may require enabling "Less secure app access"',
        'Some UIC accounts may need App Passwords for Office 365',
        'Check if VPN access is required for SMTP',
        'Contact UIC IT: support@uic.edu.ph for SMTP settings',
      ],
    },
    'outlook.com': {
      'server': 'smtp-mail.outlook.com',
      'port': 587,
      'requiresAppPassword': false,
      'minPasswordLength': 6,
    },
    'hotmail.com': {
      'server': 'smtp-mail.outlook.com',
      'port': 587,
      'requiresAppPassword': false,
      'minPasswordLength': 6,
    },
    'yahoo.com': {
      'server': 'smtp.mail.yahoo.com',
      'port': 587,
      'requiresAppPassword': true,
      'minPasswordLength': 16,
    },
  };

  // Get SMTP configuration for email domain
  static Map<String, dynamic> getSmtpConfig(String email) {
    final domain = email.split('@').last.toLowerCase();
    return smtpConfigs[domain] ??
        {
          'server': defaultSmtpServer,
          'port': defaultSmtpPort,
          'requiresAppPassword': false,
          'minPasswordLength': 6,
        };
  }

  // Dynamic email configuration from current admin
  static Future<Map<String, String>?> getCurrentAdminEmailConfig() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return null;

      final adminDoc = await FirebaseFirestore.instance
          .collection('admins')
          .where('email', isEqualTo: currentUser.email)
          .limit(1)
          .get();

      if (adminDoc.docs.isEmpty) return null;

      final adminData = adminDoc.docs.first.data();

      final encryptedPassword = adminData['smtpPasswordCredentials'] ??
          adminData['emailPassword'] ?? // Legacy support
          '';
      String decryptedPassword = '';

      // Decrypt password if it exists and is encrypted
      if (encryptedPassword.isNotEmpty) {
        try {
          if (EncryptionHelper.isValidEncryptedString(encryptedPassword)) {
            decryptedPassword =
                EncryptionHelper.decryptPassword(encryptedPassword);
          } else {
            // Handle legacy plain text passwords (for migration)
            decryptedPassword = encryptedPassword;
            print(
                'Warning: Plain text password detected. Consider encrypting it.');
          }
        } catch (e) {
          print('Error decrypting password: $e');
          return null;
        }
      }

      final emailAddress = adminData['smtpEmailCredentials'] ??
          adminData['emailAddress'] ?? // Legacy support
          adminData['email'] ??
          currentUser.email ??
          '';

      // Get SMTP configuration for the email domain
      final smtpConfig = getSmtpConfig(emailAddress);

      return {
        'email': emailAddress,
        'password': decryptedPassword,
        'name':
            adminData['displayName'] ?? adminData['name'] ?? 'TBisita Admin',
        'smtpServer': adminData['smtpServer'] ?? smtpConfig['server'],
        'smtpPort': (adminData['smtpPort'] ?? smtpConfig['port']).toString(),
      };
    } catch (e) {
      print('Error getting admin email config: $e');
      return null;
    }
  }

  // Check if current admin has email configured
  static Future<bool> isCurrentAdminConfigured() async {
    final config = await getCurrentAdminEmailConfig();
    if (config == null) return false;

    final email = config['email'] ?? '';
    final password = config['password'] ?? '';

    if (email.isEmpty || password.isEmpty) return false;

    // Get SMTP configuration for validation
    final smtpConfig = getSmtpConfig(email);
    final minPasswordLength = smtpConfig['minPasswordLength'] as int;

    // Validate email format and password length based on provider
    return email.contains('@') &&
        email.contains('.') &&
        password.length >= minPasswordLength;
  }

  /// Encrypts and stores email credentials for an admin
  ///
  /// [adminEmail] - The admin's email address
  /// [emailAddress] - The email address for sending emails (any provider)
  /// [emailPassword] - The plain text email password (will be encrypted)
  /// [displayName] - Display name for email sender (optional)
  /// [customSmtpServer] - Custom SMTP server (optional, auto-detected if not provided)
  /// [customSmtpPort] - Custom SMTP port (optional, auto-detected if not provided)
  static Future<bool> setAdminEmailCredentials({
    required String adminEmail,
    required String emailAddress,
    required String emailPassword,
    String? displayName,
    String? customSmtpServer,
    int? customSmtpPort,
  }) async {
    try {
      // Encrypt the password before storing
      final encryptedPassword = EncryptionHelper.encryptPassword(emailPassword);

      // Find admin document
      final adminQuery = await FirebaseFirestore.instance
          .collection('admins')
          .where('email', isEqualTo: adminEmail)
          .limit(1)
          .get();

      if (adminQuery.docs.isEmpty) {
        throw Exception('Admin not found');
      }

      // Prepare update data
      final updateData = {
        'smtpEmailCredentials': emailAddress,
        'smtpPasswordCredentials': encryptedPassword,
        'displayName': displayName ?? 'TBisita Admin',
        'emailUpdatedAt': FieldValue.serverTimestamp(),
      };

      // Add custom SMTP settings if provided
      if (customSmtpServer != null) {
        updateData['smtpServer'] = customSmtpServer;
      }
      if (customSmtpPort != null) {
        updateData['smtpPort'] = customSmtpPort;
      }

      // Update admin document with encrypted credentials
      await adminQuery.docs.first.reference.update(updateData);

      return true;
    } catch (e) {
      print('Error setting admin email credentials: $e');
      return false;
    }
  }

  /// Removes email credentials for an admin (for security purposes)
  ///
  /// [adminEmail] - The admin's email address
  static Future<bool> removeAdminEmailCredentials(String adminEmail) async {
    try {
      final adminQuery = await FirebaseFirestore.instance
          .collection('admins')
          .where('email', isEqualTo: adminEmail)
          .limit(1)
          .get();

      if (adminQuery.docs.isEmpty) {
        throw Exception('Admin not found');
      }

      await adminQuery.docs.first.reference.update({
        'smtpEmailCredentials': FieldValue.delete(),
        'smtpPasswordCredentials': FieldValue.delete(),
        'displayName': FieldValue.delete(),
        'emailRemovedAt': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      print('Error removing admin email credentials: $e');
      return false;
    }
  }

  // Get email template
  static String getEmailTemplate(
      String name, String email, String tempPassword) {
    return '''
    <div style="font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; background-color: #f8f9fa;">
      <div style="background-color: white; padding: 30px; border-radius: 12px; box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);">
        <div style="text-align: center; margin-bottom: 30px;">
          <h1 style="color: #ef4444; margin: 0; font-size: 28px; font-weight: bold;">TBisita</h1>
          <p style="color: #6b7280; margin: 5px 0 0 0; font-size: 14px;">Your Healthcare Platform</p>
        </div>
        
        <h2 style="color: #1f2937; margin-bottom: 20px; font-size: 24px;">Welcome to TBisita!</h2>
        
        <p style="color: #374151; font-size: 16px; line-height: 1.6; margin-bottom: 20px;">
          Dear <strong>$name</strong>,
        </p>
        
        <p style="color: #374151; font-size: 16px; line-height: 1.6; margin-bottom: 25px;">
          Your TBisita account has been created successfully. Here are your login credentials:
        </p>
        
        <div style="background-color: #f3f4f6; padding: 20px; border-radius: 8px; margin: 25px 0; border-left: 4px solid #ef4444;">
          <h3 style="color: #1f2937; margin: 0 0 15px 0; font-size: 18px;">Login Credentials</h3>
          <p style="margin: 8px 0; color: #374151; font-size: 14px;"><strong>Email:</strong> $email</p>
          <p style="margin: 8px 0; color: #374151; font-size: 14px;"><strong>Temporary Password:</strong> <code style="background-color: #e5e7eb; padding: 4px 8px; border-radius: 4px; font-family: monospace;">$tempPassword</code></p>
        </div>
        
        <div style="background-color: #fef3cd; border: 1px solid #fde68a; border-radius: 8px; padding: 15px; margin: 25px 0;">
          <p style="color: #92400e; margin: 0; font-size: 14px; font-weight: 600;">
            ⚠️ Important: Please change your password after your first login for security purposes.
          </p>
        </div>
        
        <p style="color: #374151; font-size: 16px; line-height: 1.6; margin: 25px 0;">
          If you have any questions or need assistance, please don't hesitate to contact our support team.
        </p>
        
        <p style="color: #374151; font-size: 16px; line-height: 1.6; margin-bottom: 30px;">
          Best regards,<br>
          <strong>TBisita Admin Team</strong>
        </p>
        
        <div style="text-align: center; padding-top: 20px; border-top: 1px solid #e5e7eb;">
          <p style="color: #9ca3af; font-size: 12px; margin: 0;">
            This is an automated message. Please do not reply to this email.
          </p>
        </div>
      </div>
    </div>
    ''';
  }
}
