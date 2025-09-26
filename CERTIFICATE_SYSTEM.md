# TB Treatment Certificate System

## Overview
The certificate system allows doctors to create professional TB treatment completion certificates with fillable forms and PDF generation, exactly matching the format you provided.

## Features Implemented

### ✅ Interactive Certificate Form
- **Patient Name Field**: Pre-filled from appointment data, editable
- **Treatment Type Checkboxes**: 
  - ☐ DS - TB Treatment
  - ☐ DR - TB Treatment  
  - ☐ TB Preventive Treatment
- **Facility Name Field**: Pre-filled from doctor's affiliations, editable
- **Date Fields**: Pre-filled with current date, editable (day, month, year)
- **Doctor Signature**: Integrated with existing signature system

### ✅ Professional PDF Generation
- **Exact Format**: Matches the certificate design you provided
- **Fillable Elements**: All underlined areas filled with form data
- **Checkbox Rendering**: Shows ☑ for selected, ☐ for unselected
- **Professional Layout**: Clean, official document formatting

### ✅ Cloud Storage & Distribution
- **PDF Generation**: Creates professional PDF certificates
- **Cloudinary Upload**: Automatic cloud storage (same as prescriptions)
- **Patient Notifications**: Automatic notification to patients
- **Download Access**: Patients can view and download certificates

## How to Use

### For Doctors:
1. Complete an appointment and press "Done Meeting"
2. In the post-appointment view, click "Send Certificate to Patient"
3. Fill out the certificate form:
   - Verify/edit patient name
   - Select treatment type(s) with checkboxes
   - Verify/edit facility name
   - Verify/edit issuance date
4. Click "Preview PDF" to review the certificate
5. Click "Save & Send Certificate" to generate and send to patient

### For Patients:
1. Receive notification about certificate availability
2. Go to "My Appointments & Notifications"
3. Click "View Certificate" to see the PDF
4. Click "Download" to save locally

## File Structure

### New Files Created:
- `lib/doctor/certificate.dart` - Interactive certificate creation form

### Updated Files:
- `lib/doctor/viewpost.dart` - Integration with certificate system
- `lib/patient/ppatient_notifications_clean.dart` - Certificate notification handling

### Database Collections:
- `certificates` - Stores certificate data and PDF metadata
- `patient_notifications` - Certificate availability notifications

## Certificate Data Structure

```dart
{
  'appointmentId': 'appointment_id',
  'patientId': 'patient_uid',
  'doctorId': 'doctor_uid',
  'patientName': 'Patient Full Name',
  'facilityName': 'DOTS Facility Name',
  'dsTreatment': true/false,
  'drTreatment': true/false,
  'preventiveTreatment': true/false,
  'issuanceDay': '26',
  'issuanceMonth': 'September',
  'issuanceYear': '25',
  'pdfPath': 'local/file/path.pdf',
  'pdfUrl': 'https://cloudinary.com/secure_url',
  'pdfPublicId': 'cloudinary_public_id',
  'doctorName': 'Dr. Doctor Name',
  'createdAt': timestamp,
  'updatedAt': timestamp
}
```

## Cloudinary Setup

Use the same Cloudinary credentials as the prescription system:

1. Update `lib/doctor/certificate.dart` line ~645:
```dart
const cloudName = 'YOUR_CLOUD_NAME';
const apiKey = 'YOUR_API_KEY';
const apiSecret = 'YOUR_API_SECRET';
```

## Testing

1. Create an appointment
2. As doctor: Create a prescription and complete meeting
3. As doctor: Go to completed appointments and create certificate
4. As patient: Check notifications for certificate availability
5. As patient: View and download the certificate PDF

## UI Matching

The certificate form exactly matches your provided UI:
- ✅ "Certification of Treatment Completion" header
- ✅ Fillable patient name with underline
- ✅ Treatment type checkboxes (DS-TB, DR-TB, Preventive)
- ✅ Fillable facility name with underline  
- ✅ Fillable date fields (day, month, year)
- ✅ Signature section with "Physician (Signature over Printed Name)"
- ✅ Professional formatting and layout

The generated PDF preserves all form data with proper formatting and official appearance suitable for medical documentation.
