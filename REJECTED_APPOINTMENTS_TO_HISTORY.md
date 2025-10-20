# Rejected Appointments Now Show in History 🚫📋

## Issue
When appointments were rejected, they were only stored in the `rejected_appointments` collection but did NOT appear in the doctor's history view (`dhistory.dart`), making it hard for doctors to review past rejected appointments and their reasons.

---

## Solution Implemented

### **Changes Made to `viewpending.dart`**

Modified the `_rejectAppointment()` function to also add rejected appointments to the `appointment_history` collection, which is the collection that `dhistory.dart` reads from.

#### **Before:**
```dart
Future<void> _rejectAppointment(String reason) async {
  try {
    final rejectedAppointmentData = {
      ...widget.appointment,
      'rejectionReason': reason,
      'rejectedAt': FieldValue.serverTimestamp(),
      'status': 'rejected',
    };

    // Add to rejected collection with reason
    await firestore
        .collection('rejected_appointments')
        .add(rejectedAppointmentData);

    // Note: Rejected appointments will be moved to history only if needed for reporting
    // ❌ This was a comment, but NOT implemented!

    // Also update the patient's profile
    if (widget.appointment['patientUid'] != null) {
      await firestore
          .collection('users')
          .doc(widget.appointment['patientUid'])
          .collection('appointments')
          .add(rejectedAppointmentData);
    }

    // Delete from pending collection
    await firestore
        .collection('pending_patient_data')
        .doc(appointmentId)
        .delete();
  } catch (e) {
    // Error handling
  }
}
```

#### **After (Fixed):**
```dart
Future<void> _rejectAppointment(String reason) async {
  try {
    final rejectedAppointmentData = {
      ...widget.appointment,
      'rejectionReason': reason,
      'rejectedAt': FieldValue.serverTimestamp(),
      'status': 'rejected',
    };

    // Add to rejected collection with reason
    await firestore
        .collection('rejected_appointments')
        .add(rejectedAppointmentData);

    // ✅ ADD TO APPOINTMENT HISTORY - So it shows up in dhistory.dart with rejection reason
    await firestore
        .collection('appointment_history')
        .add(rejectedAppointmentData);

    // Also update the patient's profile
    if (widget.appointment['patientUid'] != null) {
      await firestore
          .collection('users')
          .doc(widget.appointment['patientUid'])
          .collection('appointments')
          .add(rejectedAppointmentData);
    }

    // Delete from pending collection
    await firestore
        .collection('pending_patient_data')
        .doc(appointmentId)
        .delete();
  } catch (e) {
    // Error handling
  }
}
```

---

## How It Works Now

### **Workflow:**

1. **Doctor Opens Pending Appointment** (`viewpending.dart`)
   - Views appointment details
   - Clicks "Reject Appointment" button

2. **Rejection Dialog Appears**
   - Doctor enters rejection reason (required)
   - Clicks "Reject" to confirm

3. **Backend Processing** (What happens when rejected):
   ```
   ✅ Save to 'rejected_appointments' collection (for admin tracking)
   ✅ Save to 'appointment_history' collection (for doctor history view) ← NEW!
   ✅ Save to patient's appointments subcollection (for patient to see)
   ❌ Delete from 'pending_patient_data' collection
   ```

4. **Rejected Appointment Now Shows in `dhistory.dart`**
   - Status: "rejected"
   - Rejection reason included
   - Timestamp: `rejectedAt`

5. **Doctor Can View Rejection Details** (`viewhistory.dart`)
   - Special red card UI for rejected appointments
   - Shows rejection reason prominently
   - Can review past rejection decisions

---

## Data Structure

### **Rejected Appointment Document Structure:**

```javascript
{
  // Original appointment data
  "appointmentId": "appt_12345",
  "patientName": "John Doe",
  "patientUid": "patient_uid_123",
  "doctorId": "doctor_uid_456",
  "appointmentDate": "2025-10-20",
  "appointmentTime": "10:00 AM",
  
  // Rejection-specific fields
  "status": "rejected",                      // ✅ Status set to 'rejected'
  "rejectionReason": "Patient did not meet screening criteria for TB treatment", // ✅ Doctor's reason
  "rejectedAt": Timestamp(2025, 10, 20),    // ✅ When it was rejected
  
  // All other original fields preserved...
}
```

---

## Collections Updated

### **When an appointment is rejected:**

| Collection | Action | Purpose |
|------------|--------|---------|
| `rejected_appointments` | ✅ Add document | Admin tracking, reporting |
| `appointment_history` | ✅ Add document | **Shows in dhistory.dart** |
| `users/{patientUid}/appointments` | ✅ Add document | Patient can see rejection |
| `pending_patient_data` | ❌ Delete document | Remove from pending queue |

---

## UI Display in History

### **In `dhistory.dart` (History List):**
- Rejected appointments appear with status badge: **"Rejected"** (red)
- Sorted by date like other history items
- Can be selected, archived, or exported

### **In `viewhistory.dart` (Detailed View):**
When doctor clicks on a rejected appointment, they see:

```
┌─────────────────────────────────────────────┐
│ � Patient Information                      │
│    Basic patient details                    │
├─────────────────────────────────────────────┤
│ 🆔 Uploaded ID                              │
│    Patient identification documents         │
├─────────────────────────────────────────────┤
│ 📅 Schedule Information                     │
│    Appointment date and time details        │
├─────────────────────────────────────────────┤
│                                             │
│ �🔴 Appointment Rejected                     │
│    Reason for rejection                     │
├─────────────────────────────────────────────┤
│                                             │
│  ℹ️  Rejection Reason:                      │
│                                             │
│  Patient did not meet screening criteria   │
│  for TB treatment. Advised to consult      │
│  general physician first.                  │
│                                             │
└─────────────────────────────────────────────┘
```

**What IS Shown for Rejected Appointments:**
- ✅ Patient information (name, age, gender, address, etc.)
- ✅ Uploaded ID documents
- ✅ Schedule information (date, time)
- ✅ Rejection card with reason (red card)
- ✅ Timestamp showing when rejected

**What is NOT Shown for Rejected Appointments:**
- ❌ Electronic Prescription section
- ❌ Certificate of Completion section
- ❌ Patient Journey Timeline
- ❌ View Prescription PDF button
- ❌ View Certificate PDF button

**Reason:** These sections are only relevant for approved/completed appointments. Rejected appointments never reached the consultation stage, so these documents don't exist.

---

## Benefits

### **For Doctors:**
✅ **Complete History** - Can review all past decisions (approved, completed, rejected)  
✅ **Reason Tracking** - Remember why appointments were rejected  
✅ **Accountability** - Documented rejection reasons for reference  
✅ **Pattern Recognition** - See trends in rejections  
✅ **Export Capability** - Rejected appointments included in CSV exports  

### **For Patients:**
✅ **Transparency** - See why their appointment was rejected  
✅ **Clear Communication** - Understand next steps  
✅ **Record Keeping** - Have documentation of rejection  

### **For System:**
✅ **Data Completeness** - All appointments tracked  
✅ **Reporting** - Better analytics and insights  
✅ **Audit Trail** - Complete appointment lifecycle  

---

## Visual Comparison: Rejected vs Completed Appointments

### **Rejected Appointment View:**
```
┌────────────────────────────────────────┐
│ ✅ Patient Information (SHOWN)         │
├────────────────────────────────────────┤
│ ✅ Uploaded ID (SHOWN)                 │
├────────────────────────────────────────┤
│ ✅ Schedule Information (SHOWN)        │
├────────────────────────────────────────┤
│ ✅ Rejection Reason Card (SHOWN)       │
│    🔴 Red card with reason             │
└────────────────────────────────────────┘

❌ Electronic Prescription (HIDDEN)
❌ Certificate of Completion (HIDDEN)
❌ Patient Journey Timeline (HIDDEN)
```

### **Completed Appointment View:**
```
┌────────────────────────────────────────┐
│ ✅ Patient Information (SHOWN)         │
├────────────────────────────────────────┤
│ ✅ Uploaded ID (SHOWN)                 │
├────────────────────────────────────────┤
│ ✅ Schedule Information (SHOWN)        │
├────────────────────────────────────────┤
│ ✅ Electronic Prescription (SHOWN)     │
│    📄 View Prescription PDF            │
├────────────────────────────────────────┤
│ ✅ Certificate of Completion (SHOWN)   │
│    📜 View Certificate PDF             │
├────────────────────────────────────────┤
│ ✅ Patient Journey Timeline (SHOWN)    │
│    🛤️ Step-by-step progress           │
└────────────────────────────────────────┘

❌ Rejection Reason Card (HIDDEN)
```

---

## Testing Checklist

### **To Verify This Works:**

1. **Open Pending Appointment**
   - [ ] Go to doctor's pending appointments
   - [ ] Click on any appointment

2. **Reject Appointment**
   - [ ] Click "Reject Appointment" button
   - [ ] Enter rejection reason: "Test rejection - screening criteria not met"
   - [ ] Click "Reject"

3. **Verify in History List**
   - [ ] Go to History tab (`dhistory.dart`)
   - [ ] Should see rejected appointment in the list
   - [ ] Status badge should show "Rejected" in red
   - [ ] Click on rejected appointment

4. **Verify Rejected Appointment Details**
   - [ ] ✅ Patient information IS visible
   - [ ] ✅ Uploaded ID IS visible
   - [ ] ✅ Schedule information IS visible
   - [ ] ✅ Red rejection card IS visible with reason
   - [ ] ❌ Electronic Prescription section is HIDDEN
   - [ ] ❌ Certificate of Completion section is HIDDEN
   - [ ] ❌ Patient Journey Timeline is HIDDEN

5. **Compare with Completed Appointment**
   - [ ] Go back to history list
   - [ ] Click on a completed appointment
   - [ ] ✅ Should see prescription section
   - [ ] ✅ Should see certificate section
   - [ ] ✅ Should see patient journey timeline

6. **Verify in Database** (Firebase Console):
   ```
   Collections to check:
   ✅ rejected_appointments/{docId}  - Should have the document
   ✅ appointment_history/{docId}    - Should have the document ← KEY!
   ✅ users/{patientUid}/appointments/{docId} - Should have the document
   ❌ pending_patient_data/{docId}   - Should be deleted
   ```

---

## Example Rejection Reasons

### **Good Examples:**
```
✅ "Patient does not meet TB screening criteria. Referred to general physician."
✅ "Invalid ID document provided. Patient needs to resubmit valid identification."
✅ "Duplicate appointment request. Patient already has active appointment."
✅ "Outside service area. Patient advised to contact local health center."
✅ "Incomplete medical information. Patient needs to provide test results first."
```

### **Bad Examples:**
```
❌ "No" - Too vague, not helpful
❌ "Rejected" - Doesn't explain why
❌ "Wrong" - Not informative
❌ "N/A" - Defeats the purpose of requiring a reason
```

---

## Code Changes in Detail

### **1. `lib/doctor/viewpending.dart` - Add to History**

**Location:** Line ~44-95: `_rejectAppointment()` function

**Change Added:**
```dart
// ADD TO APPOINTMENT HISTORY - So it shows up in dhistory.dart with rejection reason
await firestore
    .collection('appointment_history')
    .add(rejectedAppointmentData);
```

**Purpose:** Makes rejected appointments appear in the doctor's history view.

---

### **2. `lib/doctor/viewhistory.dart` - Hide Irrelevant Sections**

**Location:** Line ~27-42: `_shouldShowPrescriptionAndCertificate()` function

**Before:**
```dart
bool _shouldShowPrescriptionAndCertificate() {
  final status = widget.appointment["status"]?.toString().toLowerCase();

  // Show for appointments that have completed consultation or treatment
  return status == "approved" ||
      status == "completed" ||
      status == "consultation_completed" ||
      status == "treatment_completed" ||
      widget.appointment["source"] == "completed_appointments" ||
      widget.appointment["source"] == "appointment_history" ||
      widget.appointment["prescriptionData"] != null ||
      widget.appointment["completedAt"] != null ||
      widget.appointment["treatmentCompletedAt"] != null;
}
```

**After:**
```dart
bool _shouldShowPrescriptionAndCertificate() {
  final status = widget.appointment["status"]?.toString().toLowerCase();

  // ❌ NEVER show for rejected appointments
  if (status == "rejected") {
    return false;
  }

  // Show for appointments that have completed consultation or treatment
  return status == "approved" ||
      status == "completed" ||
      status == "consultation_completed" ||
      status == "treatment_completed" ||
      widget.appointment["source"] == "completed_appointments" ||
      widget.appointment["source"] == "appointment_history" ||
      widget.appointment["prescriptionData"] != null ||
      widget.appointment["completedAt"] != null ||
      widget.appointment["treatmentCompletedAt"] != null;
}
```

**Purpose:** 
- Prevents showing prescription, certificate, and timeline for rejected appointments
- These sections are controlled by the `if (_shouldShowPrescriptionAndCertificate())` condition
- Adding the rejection check ensures rejected appointments only show basic info + rejection reason

**What This Method Controls:**
```dart
// These sections are wrapped with: if (_shouldShowPrescriptionAndCertificate()) ...
- Electronic Prescription section
- Certificate of Completion section  
- Patient Journey Timeline section
```

---

## Files Modified

### **1. `lib/doctor/viewpending.dart`**
- Modified: `_rejectAppointment()` function
- Added: Save to `appointment_history` collection
- Status: ✅ Complete

### **2. `lib/doctor/viewhistory.dart`**
- Modified: `_shouldShowPrescriptionAndCertificate()` function
- Added: Check to exclude rejected appointments from showing prescription/certificate/timeline
- Status: ✅ Complete

### **3. `lib/doctor/dhistory.dart`**
- Already reads from `appointment_history` collection
- Already filters and displays appointments by status
- No changes needed ✅

---

## Summary

### **Changes Made:**
✅ **`viewpending.dart`** - Added line to save rejected appointments to history  
✅ **`viewhistory.dart`** - Modified to hide prescription/certificate/timeline for rejected appointments  

### **Results:**
✅ **Rejected appointments now appear in history** (`dhistory.dart`)  
✅ **Rejection reason displayed prominently** in red card  
✅ **Irrelevant sections hidden** (prescription, certificate, timeline)  
✅ **Only relevant info shown** (patient info, ID, schedule, rejection reason)  
✅ **Complete appointment lifecycle tracking**  

### **Before vs After:**

**BEFORE:**
- ❌ Rejected appointments did NOT appear in history
- ❌ No way to review past rejection decisions
- ❌ If they appeared, would show prescription/certificate sections (incorrect)

**AFTER:**
- ✅ Rejected appointments appear in history with proper status
- ✅ Doctor can review all past rejections and reasons
- ✅ Only shows relevant sections (no prescription/certificate/timeline)
- ✅ Clean, appropriate UI for rejected appointments

**That's it!** Rejected appointments now show up in `dhistory.dart` with their rejection reasons, and only display relevant information! 🎉
