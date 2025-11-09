# Patient Address Field Implementation

## Overview
This implementation adds a **Complete Address** field to the patient booking form and ensures it's:
1. Saved to the database with each appointment
2. Stored in the user's profile for future reuse
3. Auto-filled for returning patients
4. Displayed throughout the doctor's interface wherever patient information is shown

## Changes Made

### 1. Patient Booking Form (`lib/patient/pbooking1.dart`)

#### Added Address Controller
```dart
final TextEditingController _addressController = TextEditingController();
```

#### Updated Data Loading (initState)
- Address is now loaded from user profile and auto-filled
- Prefills along with name and email for returning patients

```dart
final address = details['address'] ?? '';
setState(() {
  _nameController.text = (firstName + ' ' + lastName).trim();
  _addressController.text = address;
});
```

#### Updated Validation
- Added address field to required fields validation
- Updated error message to mention address requirement

#### Updated Form UI
- Added address field immediately after Full Name
- Position: Between "Full Name" and "Email"
- Input type: `TextInputType.streetAddress`
- Label: "Complete Address"

```dart
_customTextField(_addressController, 'Complete Address',
    keyboardType: TextInputType.streetAddress),
```

#### Updated Database Submission
- Address is now included in appointment data
- Saved to user profile for future use

```dart
final appointmentData = {
  // ... other fields
  'patientAddress': _addressController.text.trim(),
  // ... other fields
};

// Update user profile with address
await FirebaseFirestore.instance
    .collection('users')
    .doc(currentUser.uid)
    .update({
  'address': _addressController.text.trim(),
});
```

### 2. Doctor's View - Pending Appointments (`lib/doctor/viewpending.dart`)

Updated patient information bullets to include address:
```dart
bullets: [
  'Full Name: ${appointment["patientName"] ?? "Unknown Patient"}',
  'Address: ${appointment["patientAddress"] ?? "No address provided"}',  // ← NEW
  'Email: ${appointment["patientEmail"] ?? "No email provided"}',
  'Phone: ${appointment["patientPhone"] ?? "No phone provided"}',
  'Gender/Age: ...',
],
```

### 3. Doctor's Landing Page (`lib/doctor/dlanding_page.dart`)

Updated appointment details modal to include address in patient information section.

### 4. Doctor's History View (`lib/doctor/viewhistory.dart`)

Updated historical appointment view to include address in patient information.

### 5. Doctor's Post-Consultation View (`lib/doctor/viewpost.dart`)

Updated post-consultation appointment view to include address in patient information.

## Database Schema

### Collections Updated

#### `pending_patient_data`
```json
{
  "patientName": "string",
  "patientAddress": "string",  // ← NEW FIELD
  "patientEmail": "string",
  "patientPhone": "string",
  "patientAge": "number",
  "patientGender": "string",
  // ... other fields
}
```

#### `approved_appointments`
(Automatically inherits from pending_patient_data when approved)
```json
{
  "patientAddress": "string",  // ← Carried over from pending
  // ... other fields
}
```

#### `completed_appointments`
```json
{
  "patientAddress": "string",  // ← Preserved throughout lifecycle
  // ... other fields
}
```

#### `appointment_history`
```json
{
  "patientAddress": "string",  // ← Stored in history
  // ... other fields
}
```

#### `rejected_appointments`
```json
{
  "patientAddress": "string",  // ← Stored even if rejected
  // ... other fields
}
```

#### `users` (Patient Profile)
```json
{
  "firstName": "string",
  "lastName": "string",
  "email": "string",
  "address": "string",  // ← NEW FIELD - Saved for reuse
  // ... other fields
}
```

## User Flow

### First-Time Patient Booking
1. Patient opens booking form
2. Fills in all required fields including **Complete Address**
3. Submits booking
4. Address is saved in:
   - The appointment document (pending_patient_data)
   - The user's profile document (users collection)

### Returning Patient Booking
1. Patient opens booking form
2. Address field is **automatically filled** from user profile
3. Patient can edit the address if needed
4. Updated address is saved to both appointment and user profile

### Doctor's View
1. Doctor views pending appointment
2. Sees patient address in "Patient Information" section
3. Address position: Between Full Name and Email
4. Address is visible in all appointment stages:
   - Pending appointments
   - Approved appointments (landing page)
   - Post-consultation appointments
   - Historical appointments
   - Rejected appointments (if applicable)

## Display Format

### In Patient Information Section
```
Patient Information
├── Full Name: [Patient Name]
├── Address: [Complete Address]          ← NEW
├── Email: [Email]
├── Phone: [Phone Number]
└── Gender: [Gender] | Age: [Age]
```

## Benefits

1. **Better Patient Records**: Complete address information for all patients
2. **Convenience**: Auto-fill for returning patients
3. **Data Consistency**: Address saved once, used everywhere
4. **Editability**: Patients can update their address anytime
5. **Complete Information**: Doctors have full patient contact information
6. **Emergency Use**: Address available if emergency contact is needed

## Testing Checklist

### Patient Side
- [ ] Address field appears in booking form (after Full Name)
- [ ] First-time booking saves address
- [ ] Address is saved to user profile
- [ ] Returning patient sees auto-filled address
- [ ] Address can be edited before submission
- [ ] Validation prevents submission without address
- [ ] Error message mentions address requirement

### Doctor Side
- [ ] Address shows in viewpending.dart (pending appointments)
- [ ] Address shows in dlanding_page.dart (approved appointments)
- [ ] Address shows in viewpost.dart (post-consultation)
- [ ] Address shows in viewhistory.dart (historical records)
- [ ] Address displays "No address provided" for old appointments
- [ ] Address is visible in collapsible Patient Information card

### Database
- [ ] patientAddress field in pending_patient_data
- [ ] patientAddress field in approved_appointments
- [ ] patientAddress field in completed_appointments
- [ ] patientAddress field in appointment_history
- [ ] address field in users collection
- [ ] Old appointments without address still work (fallback text)

## Migration Notes

### Existing Appointments
- Old appointments without address will display: "No address provided"
- No data migration needed - addresses will be collected going forward
- User profiles will be updated on next booking

### Future Enhancements
- Add address validation (e.g., minimum length)
- Add address format suggestions
- Implement address autocomplete (Google Places API)
- Add separate fields for street, city, province, zip code
- Add map view of patient location

## Files Modified

1. `lib/patient/pbooking1.dart` - Booking form with address field
2. `lib/doctor/viewpending.dart` - Pending appointments view
3. `lib/doctor/dlanding_page.dart` - Doctor landing page
4. `lib/doctor/viewhistory.dart` - Historical appointments view
5. `lib/doctor/viewpost.dart` - Post-consultation view

## No Changes Required

These files already inherit the address field through data flow:
- `lib/doctor/dhistory.dart` - Uses viewhistory.dart
- `lib/doctor/dpost.dart` - Uses viewpost.dart
- `lib/doctor/dappointment.dart` - No patient detail display
- `lib/doctor/prescription.dart` - No patient detail display
- `lib/doctor/certificate.dart` - No patient detail display
