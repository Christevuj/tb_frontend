# 🔐 Password Encryption Guide for TBisita Email System

## Overview

This guide explains how to securely encrypt and store Gmail App Passwords in Firestore for the TBisita email system. The encryption ensures that sensitive email credentials are never stored in plain text.

## 🏗️ Architecture

### 1. **Encryption Components**
- **EncryptionHelper** (`lib/utils/encryption_helper.dart`): AES-256 encryption utility
- **EmailConfig** (`lib/admin/email_config.dart`): Dynamic email configuration with encryption support
- **EmailCredentialsPage** (`lib/admin/email_credentials_page.dart`): UI for managing email credentials

### 2. **How It Works**
1. Admin enters Gmail credentials in the UI
2. Password is encrypted using AES-256 before storage
3. Encrypted password is stored in Firestore admin document
4. When sending emails, password is decrypted on-the-fly
5. Decrypted password is used temporarily and discarded

## 🔧 Setup Instructions

### Step 1: Generate Gmail App Password

1. **Enable 2-Factor Authentication** on your Gmail account
2. Go to **Google Account → Security → 2-Step Verification → App passwords**
3. Select **"Mail"** and generate password
4. Copy the **16-character password** (format: `abcd efgh ijkl mnop`)

### Step 2: Encrypt the Password

#### Option A: Using the Admin UI (Recommended)
1. Login as admin in the TBisita app
2. Open the drawer menu and tap **"Email Settings"**
3. Enter your Gmail address and App Password
4. The app will automatically encrypt and store the password

#### Option B: Using the Encryption Utility
1. Open `tool/encrypt_password.dart`
2. Replace the example password with your actual Gmail App Password:
   ```dart
   const String examplePassword = 'your-actual-app-password'; // 16 characters
   ```
3. Run the encryption script:
   ```bash
   dart run tool/encrypt_password.dart
   ```
4. Copy the encrypted output

### Step 3: Store in Firestore

Add these fields to your admin document in the `admins` collection:

```json
{
  "email": "admin@email.com",
  "emailAddress": "your.gmail@gmail.com",
  "emailPassword": "BASE64_ENCRYPTED_PASSWORD_HERE",
  "displayName": "Your Display Name",
  "emailUpdatedAt": "2024-10-02T12:00:00Z"
}
```

## 🔒 Security Features

### 1. **AES-256 Encryption**
- Uses industry-standard AES-256 encryption
- Unique initialization vectors (IV) for each encryption
- Secure key derivation from app identifier

### 2. **Base64 Encoding**
- Encrypted data is Base64 encoded for Firestore compatibility
- Safe for storage in NoSQL databases

### 3. **No Plain Text Storage**
- Passwords are never stored in plain text
- Temporary decryption only during email sending
- Encrypted data is unreadable without the encryption key

### 4. **Legacy Support**
- Automatically detects plain text passwords for migration
- Gradual migration from plain text to encrypted storage

## 📧 Usage Examples

### Encrypting a Password Programmatically

```dart
import 'package:your_app/utils/encryption_helper.dart';

void encryptPassword() {
  final plainPassword = 'abcd efgh ijkl mnop';
  final encrypted = EncryptionHelper.encryptPassword(plainPassword);
  print('Encrypted: $encrypted');
}
```

### Decrypting a Password

```dart
void decryptPassword() {
  final encryptedPassword = 'BASE64_ENCRYPTED_STRING';
  final decrypted = EncryptionHelper.decryptPassword(encryptedPassword);
  print('Decrypted: $decrypted');
}
```

### Setting Admin Email Credentials

```dart
await EmailConfig.setAdminEmailCredentials(
  adminEmail: 'admin@uic.edu.ph',
  gmailAddress: 'tbisita.system@gmail.com',
  gmailPassword: 'abcd efgh ijkl mnop', // Will be encrypted automatically
  displayName: 'TBisita System',
);
```

## 🛠️ Admin Management UI

### Accessing Email Settings
1. Login as admin
2. Open the drawer menu (hamburger icon)
3. Tap **"Email Settings"**

### Features
- **Add Credentials**: Set up new email configuration
- **Update Credentials**: Modify existing email settings
- **Remove Credentials**: Delete email configuration for security
- **Validation**: Checks Gmail format and App Password length
- **Visual Feedback**: Success/error messages with clear instructions

### Form Fields
- **Gmail Address**: Must end with `@gmail.com`
- **Gmail App Password**: 16-character App Password from Google
- **Display Name**: Name shown as email sender (optional)

## 🔧 API Reference

### EncryptionHelper Class

#### Methods
- `encryptPassword(String password)` → `String`
  - Encrypts a password for storage
  - Returns Base64 encoded encrypted string

- `decryptPassword(String encryptedPassword)` → `String`
  - Decrypts a password from storage
  - Returns original plain text password

- `isValidEncryptedString(String encryptedString)` → `bool`
  - Validates if string is properly encrypted
  - Useful for detecting legacy plain text passwords

### EmailConfig Class

#### Methods
- `getCurrentAdminEmailConfig()` → `Future<Map<String, String>?>`
  - Gets current admin's email configuration
  - Automatically decrypts password

- `isCurrentAdminConfigured()` → `Future<bool>`
  - Checks if current admin has email configured
  - Validates email format and password length

- `setAdminEmailCredentials({...})` → `Future<bool>`
  - Sets email credentials for an admin
  - Automatically encrypts password before storage

## 🚨 Security Best Practices

### 1. **Key Management**
- The encryption key is embedded in the app code
- Consider using device-specific keys for enhanced security
- Regularly rotate encryption keys in production

### 2. **Access Control**
- Only authenticated admins can access email settings
- Email credentials are tied to specific admin accounts
- No shared or global email configurations

### 3. **Data Protection**
- Passwords are encrypted before network transmission
- Firestore rules should restrict admin document access
- Consider additional field-level encryption for sensitive data

### 4. **Monitoring**
- Log email configuration changes with timestamps
- Monitor for unauthorized access attempts
- Implement admin action audit trails

## 🔄 Migration from Plain Text

If you have existing plain text passwords in Firestore:

1. The system automatically detects plain text passwords
2. A warning is logged when plain text is detected
3. Use the admin UI to re-enter credentials (will encrypt automatically)
4. Or use the `setAdminEmailCredentials()` method to update programmatically

## 🐛 Troubleshooting

### Common Issues

1. **"Failed to decrypt password"**
   - Password may be corrupted or use different encryption
   - Re-enter credentials through admin UI

2. **"Invalid email configuration"**
   - Check Gmail address format (@gmail.com required)
   - Verify App Password is exactly 16 characters

3. **"Email authentication failed"**
   - Verify 2FA is enabled on Gmail account
   - Generate new App Password if current one expired

### Debug Steps

1. Check Firestore admin document structure
2. Verify encryption/decryption with test utility
3. Test Gmail SMTP connection with credentials
4. Review Flutter debug logs for detailed error messages

## 📋 Firestore Document Structure

### Complete Admin Document Example

```json
{
  "email": "admin@uic.edu.ph",
  "name": "Admin User",
  "role": "admin",
  "createdAt": "2024-01-01T00:00:00Z",
  
  // Email Configuration (Encrypted)
  "emailAddress": "tbisita.system@gmail.com",
  "emailPassword": "eyJpdiI6InNvbWVfaXZfaGVyZSIsImVuY3J5cHRlZCI6InNvbWVfZW5jcnlwdGVkX2RhdGFfaGVyZSJ9",
  "displayName": "TBisita System",
  "emailUpdatedAt": "2024-10-02T12:00:00Z"
}
```

### Required Fields for Email
- `emailAddress`: Gmail address for sending emails
- `emailPassword`: **Encrypted** Gmail App Password
- `displayName`: Name shown as email sender (optional)

## 🔐 Security Summary

✅ **What's Protected**
- Gmail App Passwords encrypted with AES-256
- Unique encryption per password instance
- Base64 encoding for safe storage
- Automatic plain text detection and warnings

✅ **What's NOT Plain Text**
- Email passwords in Firestore
- Passwords in app memory (except during use)
- Passwords in network transmission

⚠️ **Security Considerations**
- Encryption key is in app code (consider external key management)
- Admin authentication required for access
- Regular security audits recommended

This encryption system provides a robust foundation for securing email credentials while maintaining usability for administrators.
