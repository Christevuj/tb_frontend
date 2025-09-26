# Cloudinary Setup Instructions

## Overview
The prescription PDF system now supports automatic upload to Cloudinary cloud storage. This ensures PDFs are accessible across all platforms and devices.

## Setup Steps

### 1. Create Cloudinary Account
1. Go to [cloudinary.com](https://cloudinary.com) and sign up for a free account
2. After signing in, go to your Dashboard
3. Note your account details:
   - Cloud name
   - API Key  
   - API Secret

### 2. Update Prescription.dart
Open `lib/doctor/prescription.dart` and find the `_uploadToCloudinary` method (around line 940).

Replace these placeholders with your actual Cloudinary credentials:
```dart
// Replace these with your actual Cloudinary credentials
const cloudName = 'YOUR_CLOUD_NAME';      // Replace with your cloud name
const apiKey = 'YOUR_API_KEY';            // Replace with your API key
const apiSecret = 'YOUR_API_SECRET';      // Replace with your API secret
```

### 3. Implement Proper Signature Generation (Recommended)
For production use, implement proper HMAC-SHA1 signature generation in the `_generateCloudinarySignature` method.

Add this dependency to `pubspec.yaml`:
```yaml
dependencies:
  crypto: ^3.0.3
```

Then update the signature method:
```dart
import 'dart:convert';
import 'package:crypto/crypto.dart';

String _generateCloudinarySignature(String publicId, String timestamp, String apiSecret) {
  final paramsToSign = 'public_id=$publicId&resource_type=raw&timestamp=$timestamp';
  final key = utf8.encode(apiSecret);
  final bytes = utf8.encode(paramsToSign);
  final hmacSha1 = Hmac(sha1, key);
  final digest = hmacSha1.convert(bytes);
  return digest.toString();
}
```

### 4. Test the Integration
1. Create a prescription in the doctor's interface
2. Press "Save Prescription"
3. Check that the PDF is uploaded to Cloudinary
4. Verify that both doctor and patient can view the PDF

## Features Implemented

### ✅ Automatic PDF Generation
- Professional prescription PDFs with clinic branding
- Patient information, prescription details, and doctor signature
- Generated automatically when saving prescriptions

### ✅ Cloud Storage Integration
- PDFs automatically uploaded to Cloudinary
- Fallback to local storage if upload fails
- Secure file URLs for cross-platform access

### ✅ Viewing Capabilities
- **Doctors**: Can view PDFs in post-appointment review
- **Patients**: Can view PDFs in notification center
- **Fallback**: Text-based viewing if PDF unavailable

### ✅ Data Management
- New prescriptions collection stores PDF metadata
- Backward compatibility with existing prescription data
- Automatic updates when prescriptions are modified

## File Locations

### Updated Files:
- `lib/doctor/prescription.dart` - PDF generation and Cloudinary upload
- `lib/doctor/viewpost.dart` - Doctor PDF viewing with cloud support
- `lib/patient/ppatient_notifications_clean.dart` - Patient PDF viewing

### Collections Used:
- `prescriptions` - New collection for PDF-enabled prescriptions
- `completed_appointments` - Legacy prescription data (backward compatibility)

## Troubleshooting

### PDF Not Uploading
- Check Cloudinary credentials are correct
- Ensure internet connection is stable
- Check Firebase console for error logs

### PDF Not Viewing
- Verify PDF was successfully generated and uploaded
- Check file permissions and paths
- Ensure proper collection data structure

### Signature Errors
- Implement proper HMAC-SHA1 signature for production
- Check parameter ordering in signature generation
- Verify API secret is correct

## Security Notes
- Store Cloudinary credentials securely (consider environment variables)
- Implement proper authentication for PDF access
- Use secure HTTPS URLs for all file operations
- Consider adding file expiration policies in Cloudinary
