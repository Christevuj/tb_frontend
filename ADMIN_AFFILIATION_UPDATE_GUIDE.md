# Admin Affiliation Form Update Guide

## Problem
The admin creates affiliations with a day range string like "Monday to Friday", but the booking system needs individual day schedules with breaks and session durations.

## Solution
Update the admin form to create proper schedule structures with smart defaults.

## Updated Admin Form Structure

### Form Fields

1. **Facility Name** (text input)
   - Example: "TB DOTS Center - Quezon City"

2. **Facility Address** (text input)
   - Example: "123 Main Street, Quezon City"

3. **Working Days** (multi-select checkboxes)
   ```
   ☑ Monday
   ☑ Tuesday
   ☑ Wednesday
   ☑ Thursday
   ☑ Friday
   ☐ Saturday
   ☐ Sunday
   ```

4. **Working Hours**
   - Start Time: Dropdown (9:00 AM default)
   - End Time: Dropdown (5:00 PM default)

5. **Break Time** (optional, with "No Break" checkbox)
   - Break Start: Dropdown (12:00 PM default)
   - Break End: Dropdown (1:00 PM default)

6. **Session Duration** (dropdown)
   - Options: 15 min, 30 min, 45 min, 60 min
   - Default: 30 min

### Smart Features

1. **Apply to All Days**: One checkbox to use same hours for all selected days
2. **Quick Presets**: Buttons like "Standard Hours (9-5)", "Half Day (9-1)"
3. **Copy Schedule**: If adding multiple affiliations, copy from previous

### Data Structure Saved

```dart
{
  "name": "TB DOTS Center - Quezon City",
  "address": "123 Main Street, Quezon City",
  "schedules": [
    {
      "day": "Monday",
      "start": "9:00 AM",
      "end": "5:00 PM",
      "breakStart": "12:00 PM",
      "breakEnd": "1:00 PM",
      "sessionDuration": "30"
    },
    {
      "day": "Tuesday",
      "start": "9:00 AM",
      "end": "5:00 PM",
      "breakStart": "12:00 PM",
      "breakEnd": "1:00 PM",
      "sessionDuration": "30"
    }
    // ... one object for each selected day
  ]
}
```

## Migration Strategy for Existing Data

If you already have doctors with the old format, you need to migrate them:

### Option A: Manual Update (Small number of doctors)
1. Admin goes to each doctor
2. Edit affiliations
3. Re-save with new format

### Option B: Automated Migration Script (Many doctors)
Create a migration function that:
1. Reads old format: "Monday to Friday"
2. Parses it into individual days
3. Creates schedule objects with default values
4. Updates Firestore

### Migration Script Example

```dart
Future<void> migrateOldAffiliations() async {
  final doctorsSnapshot = await FirebaseFirestore.instance
      .collection('doctors')
      .get();

  for (var doc in doctorsSnapshot.docs) {
    final data = doc.data();
    if (data['affiliations'] != null) {
      List<dynamic> affiliations = data['affiliations'];
      List<Map<String, dynamic>> updatedAffiliations = [];

      for (var affiliation in affiliations) {
        // Check if it's old format (has dayRange string)
        if (affiliation['dayRange'] != null) {
          // Parse "Monday to Friday" into individual days
          List<String> days = parseDayRange(affiliation['dayRange']);
          
          // Create schedules for each day
          List<Map<String, dynamic>> schedules = days.map((day) => {
            'day': day,
            'start': affiliation['start'] ?? '9:00 AM',
            'end': affiliation['end'] ?? '5:00 PM',
            'breakStart': '12:00 PM', // Default
            'breakEnd': '1:00 PM',     // Default
            'sessionDuration': '30'     // Default
          }).toList();

          // Create new affiliation structure
          updatedAffiliations.add({
            'name': affiliation['name'],
            'address': affiliation['address'],
            'schedules': schedules,
          });
        } else {
          // Already in new format, keep as is
          updatedAffiliations.add(affiliation);
        }
      }

      // Update the document
      await doc.reference.update({
        'affiliations': updatedAffiliations,
      });

      print('Migrated doctor: ${doc.id}');
    }
  }
}

List<String> parseDayRange(String dayRange) {
  // Parse "Monday to Friday" into ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"]
  final allDays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
  
  // Simple implementation - you can make this more sophisticated
  if (dayRange.toLowerCase().contains('monday to friday')) {
    return ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'];
  } else if (dayRange.toLowerCase().contains('weekdays')) {
    return ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'];
  } else if (dayRange.toLowerCase().contains('everyday')) {
    return allDays;
  }
  
  // If can't parse, default to weekdays
  return ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'];
}
```

## UI/UX Recommendations

### Make it User-Friendly

1. **Visual Day Selection**
```
┌─────────────────────────────────────┐
│ Select Working Days:                │
│                                     │
│  [✓] Mon  [✓] Tue  [✓] Wed         │
│  [✓] Thu  [✓] Fri  [ ] Sat         │
│  [ ] Sun                            │
│                                     │
│  Quick Select:                      │
│  [Weekdays] [Weekend] [All] [None] │
└─────────────────────────────────────┘
```

2. **Time Pickers with Common Presets**
```
┌─────────────────────────────────────┐
│ Working Hours:                      │
│  Start: [9:00 AM ▼]                │
│  End:   [5:00 PM ▼]                │
│                                     │
│  Presets: [9-5] [9-6] [8-4]        │
└─────────────────────────────────────┘
```

3. **Optional Break Time**
```
┌─────────────────────────────────────┐
│ Break Time:                         │
│  [ ] No break time                  │
│                                     │
│  Break Start: [12:00 PM ▼]         │
│  Break End:   [1:00 PM ▼]          │
└─────────────────────────────────────┘
```

4. **Session Duration**
```
┌─────────────────────────────────────┐
│ Appointment Duration:               │
│  ○ 15 minutes                       │
│  ● 30 minutes (recommended)         │
│  ○ 45 minutes                       │
│  ○ 1 hour                           │
└─────────────────────────────────────┘
```

## Validation Rules

1. End time must be after start time
2. Break end must be after break start
3. Break time must be within working hours
4. At least one day must be selected
5. Session duration must be reasonable (15-120 minutes)

## Example Complete Form Flow

```
Step 1: Facility Information
  - Name: "TB DOTS Facility A"
  - Address: "123 Main St"

Step 2: Working Days
  - Selected: Mon, Tue, Wed, Thu, Fri

Step 3: Working Hours
  - Start: 9:00 AM
  - End: 5:00 PM

Step 4: Break Time
  - Enable break: Yes
  - Break Start: 12:00 PM
  - Break End: 1:00 PM

Step 5: Appointment Duration
  - Duration: 30 minutes

Save → Creates 5 schedule objects (one for each selected day)
```

## Benefits of This Approach

✅ **Immediate compatibility** with booking system
✅ **No parsing** required
✅ **Flexible** - each day can have different hours later
✅ **Clear data structure** - easy to query and display
✅ **Better UX** - doctors see exactly what patients will see
✅ **Future-proof** - easy to add more features (different hours per day, multiple breaks, etc.)

## Backward Compatibility

If you need to keep old affiliations working temporarily:

1. Keep the migration script ready
2. Update booking code to handle both formats:

```dart
List<Map<String, String>> _getDoctorScheduleForDay(String dayName) async {
  // ... existing code ...
  
  for (var affiliation in affiliations) {
    // NEW FORMAT (has schedules array)
    if (affiliation['schedules'] != null) {
      final schedules = affiliation['schedules'] as List<dynamic>;
      final daySchedules = schedules.where((s) => s['day'] == dayName).toList();
      if (daySchedules.isNotEmpty) return daySchedules;
    }
    // OLD FORMAT (has dayRange string) - FALLBACK
    else if (affiliation['dayRange'] != null) {
      final days = parseDayRange(affiliation['dayRange']);
      if (days.contains(dayName)) {
        return [{
          'day': dayName,
          'start': affiliation['start'] ?? '9:00 AM',
          'end': affiliation['end'] ?? '5:00 PM',
          'breakStart': '12:00 PM',
          'breakEnd': '1:00 PM',
          'sessionDuration': '30',
        }];
      }
    }
  }
}
```

But this is temporary - migrate all data as soon as possible!
