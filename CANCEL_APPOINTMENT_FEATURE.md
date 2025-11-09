# Cancel Appointment Feature Implementation

## Overview
This feature allows patients to cancel appointments that are in "approved" (ready for consultation) status. When an appointment is canceled, it moves to the history with a "canceled" status and displays the cancellation reason provided by the patient.

## Features Implemented

### 1. Patient Side (`pmyappointment.dart`)

#### Cancel Button
- Added "Cancel Appointment" button for appointments with `status == 'approved'`
- Button appears after the video call card in the appointment details modal
- Styled with red accent border to indicate a destructive action

#### Cancellation Dialog
- Shows a modal dialog when patient clicks "Cancel Appointment"
- Requires patient to provide a cancellation reason
- Dialog includes:
  - Title: "Cancel Appointment" with cancel icon
  - Text field for entering cancellation reason (3 lines, multiline)
  - Two buttons: "Cancel" (gray) and "Confirm" (red)
  - Validation: Reason must not be empty before confirming

#### Cancellation Process
When confirmed, the system:
1. Shows loading snackbar: "Canceling appointment..."
2. Creates history entry with:
   - `status: 'canceled'`
   - `canceledAt: FieldValue.serverTimestamp()`
   - `cancellationReason: <patient's reason>`
   - `canceledBy: 'patient'`
   - `statusBeforeCancellation: 'approved'`
   - `movedToHistoryAt: FieldValue.serverTimestamp()`
3. Moves appointment to `appointment_history` collection
4. Deletes appointment from `approved_appointments` collection
5. Removes related notifications from both `patient_notifications` and `doctor_notifications`
6. Shows success message and closes the details modal

### 2. Doctor Side (`dlanding_page.dart`)

#### Automatic Removal
- When patient cancels an appointment, it's automatically removed from doctor's landing page
- The appointment no longer appears in the approved appointments list
- This happens because the appointment is deleted from `approved_appointments` collection

### 3. Doctor History (`dhistory.dart`)

#### Display Canceled Appointments
Updated the history filter to include canceled appointments:
- Added checks for `canceledAt` field
- Added checks for `status == 'canceled'`
- Filter comment updated to: "Only show items that are either Treatment Completed, Rejected, or Canceled"

#### Status Display
Added status display logic for canceled appointments:
- Status text: "Canceled by Patient"
- Status color: Orange (`Colors.orange.shade700`)
- Appears in the appointment card with appropriate styling

### 4. View History (`viewhistory.dart`)

#### Timeline Card Update
Enhanced the timeline card to handle canceled appointments:
- Added `isCanceled` flag detection
- Added `statusBeforeCancellation` field check
- Color scheme for canceled appointments:
  - Main color: `Colors.orange.shade700`
  - Background: `Colors.orange.shade50`
  - Border: `Colors.orange.shade200`

#### Timeline Steps
For canceled appointments:
- Step 1 (Requested): ✓ Completed
- Step 2 (Approved): ✓ Completed (shows the appointment was approved before cancellation)
- Step 3 (Consultation): ✗ Not completed
- Step 4 (Treatment): ✗ Not completed

#### Cancellation Information Card
Added a new card section to display cancellation details:
- Header with orange accent strip
- Title: "Appointment Canceled by Patient"
- Subtitle: "Reason for cancellation"
- Icon: `Icons.event_busy` with orange background
- Content section displays:
  - Label: "Cancellation Reason:"
  - Reason text from `cancellationReason` field
  - Fallback: "No specific reason provided"
- Styling:
  - Orange theme matching the canceled status
  - Same modern card design as rejection section

## Database Schema

### Fields Added to `appointment_history` Collection
```dart
{
  'status': 'canceled',
  'canceledAt': Timestamp,
  'cancellationReason': String,
  'canceledBy': 'patient',
  'statusBeforeCancellation': 'approved',
  'movedToHistoryAt': Timestamp,
  // ... all other appointment fields
}
```

## User Flow

### Patient Perspective
1. Patient views appointment with "approved" status (ready for consultation)
2. Patient sees "Cancel Appointment" button
3. Patient clicks button → dialog appears
4. Patient enters cancellation reason
5. Patient clicks "Confirm"
6. Appointment disappears from patient's active appointments
7. Appointment appears in patient's history with "Canceled" status

### Doctor Perspective
1. Doctor had appointment in their landing page (approved appointments list)
2. When patient cancels → appointment automatically disappears from landing page
3. Appointment appears in doctor's history (`dhistory.dart`)
4. Doctor can view cancellation details including:
   - Status: "Canceled by Patient"
   - Cancellation reason provided by patient
   - Timeline showing appointment was approved before cancellation

## Color Scheme

### Canceled Status Colors
- **Main Color**: Orange (`Colors.orange.shade700`)
- **Background**: Light Orange (`Colors.orange.shade50`)
- **Border**: Medium Orange (`Colors.orange.shade200`)
- **Icon Background**: Light Orange (`Colors.orange.shade100`)

### Comparison with Other Statuses
- **Rejected**: Red (`Colors.red.shade600`)
- **Incomplete**: Amber (`Colors.amber.shade600`)
- **Completed**: Green (`Colors.green.shade600`)
- **Canceled**: Orange (`Colors.orange.shade700`)

## Files Modified

1. **lib/patient/pmyappointment.dart**
   - Added `_cancelApprovedAppointment()` method
   - Added cancel button in appointment details for approved status

2. **lib/doctor/dhistory.dart**
   - Updated history filter to include canceled appointments
   - Added status display logic for canceled status

3. **lib/doctor/viewhistory.dart**
   - Updated timeline card to handle canceled appointments
   - Added cancellation information card section
   - Updated color scheme for canceled status

## Testing Checklist

### Patient Side
- [ ] Cancel button appears only for approved appointments
- [ ] Cancel button does NOT appear for pending, completed, or rejected appointments
- [ ] Dialog opens when cancel button is clicked
- [ ] Cannot submit empty reason
- [ ] "Cancel" button in dialog closes dialog without changes
- [ ] "Confirm" button processes cancellation
- [ ] Loading message appears during processing
- [ ] Success message appears after cancellation
- [ ] Appointment disappears from active appointments
- [ ] Appointment appears in patient's history with "Canceled" status

### Doctor Side
- [ ] Canceled appointment disappears from landing page
- [ ] Canceled appointment appears in history
- [ ] Status shows as "Canceled by Patient" with orange color
- [ ] Cancellation reason is displayed correctly
- [ ] Timeline shows steps 1-2 completed, 3-4 not completed
- [ ] Orange color scheme is consistent throughout
- [ ] Can export canceled appointments in CSV

### Notifications
- [ ] Patient notifications are deleted when appointment is canceled
- [ ] Doctor notifications are deleted when appointment is canceled

## Future Enhancements

Potential improvements for future versions:
1. Add option to reschedule instead of cancel
2. Send push notification to doctor when appointment is canceled
3. Add analytics to track cancellation reasons
4. Implement cancellation deadline (e.g., can't cancel within 2 hours of appointment)
5. Allow doctor to view patient's cancellation history
6. Add automatic availability slot update when appointment is canceled
