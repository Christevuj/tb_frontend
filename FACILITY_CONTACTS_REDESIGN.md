# Facility Contacts Popup Redesign - Implementation Guide

## Overview
This document describes how to change the "Contacts" popup in `lib/patient/ptbfacility.dart` from displaying health workers to displaying facility information with TB Day schedules.

## Changes Required

### 1. Add TB Day Schedule Mapping Method
Add this method before `_onViewContactsPressed()` (around line 809):

```dart
// TB Day schedule mapping
String _getTBDaySchedule(String facilityName) {
  final schedules = {
    'AGDAO': 'Mon, Tues, Thurs, Fri\n8:00 AM-12:00 NN',
    'BAGUIO (MALAGOS HC)': 'Tuesday\n8:00 AM-12:00 NN',
    'BUHANGIN (NHA BUHANGIN HC)': 'Thursday\n8:00 AM-12:00 NN',
    'BUNAWAN': 'Monday - Friday\n8:00 AM-5:00 PM',
    'CALINAN': 'Thursday\n8:00 AM-12:00 NN',
    'DAVAO CHEST CENTER': 'Daily\n8:00 AM-5:00 PM',
    'DISTRICT A (TOMAS CLAUDIO HC)': 'Monday-Tuesday, Thurs\n8:00 AM-5:00 PM',
    'DISTRICT B (EL RIO HC)': 'Thursday\n8:00 AM-12:00 NN',
    'DISTRICT C (MINIFOREST HC)': 'Tuesday\n8:00 AM-5:00 PM',
    'DISTRICT D (JACINTO HC)': 'Tuesday\n8:00 AM-12:00 NN',
    'MARILOG (MARAHAN HC)': 'Mon-Wed, Fri\n8:00 AM-12:00 NN',
    'PAQUIBATO (MALABOG HC)': 'Tuesday\n8:00 AM-12:00 NN',
    'SASA': 'Daily\n8:00 AM-5:00 PM',
    'TALOMO CENTRAL (GSIS HC)': 'Daily\n8:00 AM-12:00 NN',
    'TALOMO NORTH (SIR HC)': 'Mon-Wed, Fri\n8:00 AM-12:00 NN',
    'TALOMO SOUTH (PUAN HC)': 'Mon-Tues, Thurs-Fri\n8:00 AM-12:00 NN',
    'TORIL A': 'Wednesday\n1:00 PM-5:00 PM',
    'TORIL B': 'Thursday\n8:00 AM-12:00 NN',
    'TUGBOK (MINTAL HC)': 'Daily\n8:00 AM-4:00 PM',
  };
  
  return schedules[facilityName.toUpperCase()] ?? 'Schedule not available';
}
```

### 2. Update Dialog Header
In `_onViewContactsPressed()`, around line 883, change the header title:

**OLD:**
```dart
const Text(
  'Health Workers',
  style: TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.bold,
    color: Color(0xFF1F2937),
  ),
),
```

**NEW:**
```dart
const Text(
  'Facility Information',
  style: TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.bold,
    color: Color(0xFF1F2937),
  ),
),
```

### 3. Remove Search Bar
Delete the entire search bar Container (lines ~903-940) that contains the TextField with `_contactsSearchController`.

### 4. Replace Content with Facility Information
Replace the entire `Expanded(child: StreamBuilder<QuerySnapshot>(` section (lines ~941-1150) with:

```dart
// Content
Expanded(
  child: SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Facility Name Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Color(0xE0F44336),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Text(
              facility.name.toUpperCase(),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          // Facility Details
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Address
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.location_on,
                      color: Color(0xE0F44336),
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Address',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF6B7280),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            facility.address,
                            style: const TextStyle(
                              fontSize: 16,
                              color: Color(0xFF1F2937),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // TB Day Schedule
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.calendar_today,
                      color: Color(0xE0F44336),
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'TB Day',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF6B7280),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _getTBDaySchedule(facility.name),
                            style: const TextStyle(
                              fontSize: 16,
                              color: Color(0xFF1F2937),
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  ),
),
```

### 5. Clean Up Unused Variables
Remove these unused variables from the class (around lines 62-64):

```dart
final TextEditingController _contactsSearchController = TextEditingController();
String _contactsSearchQuery = '';
```

And remove the dispose call (around line 1434):

```dart
_contactsSearchController.dispose();
```

### 6. Remove Unused Imports (if not used elsewhere)
If these are no longer needed after removing health worker functionality:
- `import 'package:tb_frontend/services/chat_service.dart';`
- `import 'package:tb_frontend/chat_screens/health_chat_screen.dart';`

## Result
The "Contacts" button will now show:
- **Header:** "Facility Information" with facility name subtitle
- **Content:** A clean card displaying:
  - Facility name in uppercase (red header)
  - Address with location icon
  - TB Day schedule with calendar icon

The health workers list, search bar, and messaging functionality are completely removed.

## Testing Checklist
- [ ] Tap "Contacts" button on any facility card
- [ ] Verify dialog shows "Facility Information" title
- [ ] Verify facility name appears in uppercase in red header
- [ ] Verify address displays correctly
- [ ] Verify TB Day schedule shows correctly for each of the 19 facilities
- [ ] Verify "Schedule not available" shows for facilities not in the mapping
- [ ] Verify no errors in console
- [ ] Verify no unused variable warnings
