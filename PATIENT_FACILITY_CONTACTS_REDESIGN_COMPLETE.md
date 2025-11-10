# Patient Facility Contacts Popup Redesign - Complete Guide

## Overview
This guide documents the complete redesign of the contacts popup in `lib/patient/ptbfacility.dart` to show facility information (name, address, TB Day schedule) instead of health workers list.

## Changes Required

### 1. Add TB Day Schedules Mapping (After line 65)

Add this map after `static const double _zoomLevel = 15.0;`:

```dart
// TB Day schedules mapping  
final Map<String, Map<String, String>> _tbDaySchedules = {
  'AGDAO': {'days': 'Mon, Tues, Thurs, Fri', 'time': '8:00 AM-12:00 NN'},
  'BAGUIO': {'days': 'Tuesday', 'time': '8:00 AM-12:00 NN'},
  'BUHANGIN': {'days': 'Thursday', 'time': '8:00 AM-12:00 NN'},
  'BUNAWAN': {'days': 'Monday - Friday', 'time': '8:00 AM-5:00 PM'},
  'CALINAN': {'days': 'Thursday', 'time': '8:00 AM-12:00 NN'},
  'DAVAO CHEST CENTER': {'days': 'Daily', 'time': '8:00 AM-5:00 PM'},
  'DISTRICT A': {'days': 'Monday-Tuesday, Thurs', 'time': '8:00 AM-5:00 PM'},
  'DISTRICT B': {'days': 'Thursday', 'time': '8:00 AM-12:00 NN'},
  'DISTRICT C': {'days': 'Tuesday', 'time': '8:00 AM-5:00 PM'},
  'DISTRICT D': {'days': 'Tuesday', 'time': '8:00 AM-12:00 NN'},
  'MARILOG': {'days': 'Mon-Wed, Fri', 'time': '8:00 AM-12:00 NN'},
  'PAQUIBATO': {'days': 'Tuesday', 'time': '8:00 AM-12:00 NN'},
  'SASA': {'days': 'Daily', 'time': '8:00 AM-5:00 PM'},
  'TALOMO CENTRAL': {'days': 'Daily', 'time': '8:00 AM-12:00 NN'},
  'TALOMO NORTH': {'days': 'Mon-Wed, Fri', 'time': '8:00 AM-12:00 NN'},
  'TALOMO SOUTH': {'days': 'Mon-Tues, Thurs-Fri', 'time': '8:00 AM-12:00 NN'},
  'TORIL A': {'days': 'Wednesday', 'time': '1:00 PM-5:00 PM'},
  'TORIL B': {'days': 'Thursday', 'time': '8:00 AM-12:00 NN'},
  'TUGBOK': {'days': 'Daily', 'time': '8:00 AM-4:00 PM'},
};
```

### 2. Add Helper Method (Before `_getTotalWorkersByAddress` method around line 520)

```dart
Map<String, String>? _getTBDaySchedule(String facilityName) {
  // Try to find exact match first
  final upperName = facilityName.toUpperCase();
  if (_tbDaySchedules.containsKey(upperName)) {
    return _tbDaySchedules[upperName];
  }

  // Try partial matching for facility names
  for (var entry in _tbDaySchedules.entries) {
    if (upperName.contains(entry.key) || entry.key.contains(upperName)) {
      return entry.value;
    }
  }

  return null; // No schedule found
}
```

### 3. Replace `_onViewContactsPressed()` Method (Around line 849)

Replace the ENTIRE method from `void _onViewContactsPressed() {` to the closing `}` with:

```dart
void _onViewContactsPressed() {
  final facility = _filteredFacilities[_selectedIndex];
  final tbSchedule = _getTBDaySchedule(facility.name);

  showDialog(
    context: context,
    barrierDismissible: true,
    builder: (context) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.85,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.6,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with close button
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF3B82F6), Color(0xFF1E40AF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.local_hospital,
                    color: Colors.white,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Facility Information',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Facility Name
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF3B82F6).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.business,
                            color: Color(0xFF3B82F6),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'FACILITY NAME',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF6B7280),
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                facility.name.toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1F2937),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Divider
                    Divider(color: Colors.grey.shade300, height: 1),
                    const SizedBox(height: 20),
                    // Address
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.location_on,
                            color: Color(0xFF10B981),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'ADDRESS',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF6B7280),
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                facility.address,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF374151),
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Divider
                    Divider(color: Colors.grey.shade300, height: 1),
                    const SizedBox(height: 20),
                    // TB Day Schedule
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.calendar_today,
                            color: Color(0xFFF59E0B),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'TB DAY SCHEDULE',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF6B7280),
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 8),
                              if (tbSchedule != null) ...[
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEF3C7),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: const Color(0xFFF59E0B)
                                          .withOpacity(0.3),
                                      width: 1,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.event,
                                            color: Color(0xFFF59E0B),
                                            size: 18,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              tbSchedule['days']!,
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFF92400E),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.access_time,
                                            color: Color(0xFFF59E0B),
                                            size: 18,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            tbSchedule['time']!,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                              color: Color(0xFF92400E),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ] else ...[
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: Colors.grey.shade300,
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.info_outline,
                                        color: Colors.grey.shade600,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Schedule not available',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey.shade700,
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
```

### 4. Remove Unused Code

After replacing the contacts popup, remove these:

1. **Remove unused variables** (around lines 62-64):
   - Delete: `final TextEditingController _contactsSearchController = TextEditingController();`
   - Delete: `String _contactsSearchQuery = '';`

2. **Remove from dispose()** method (around line 1545):
   - Delete: `_contactsSearchController.dispose();`

3. **Remove unused methods**:
   - Delete: `Widget _buildHealthWorkerCard()` method (entire method, ~250 lines)
   - Delete: `Future<void> _handleMessageTap()` method (entire method, ~100 lines)  
   - Delete: `Future<String> _resolvePatientName()` method (entire method, ~15 lines)

## Visual Design

### Color Scheme
- **Header**: Blue gradient (0xFF3B82F6 → 0xFF1E40AF)
- **Facility Icon**: Blue (0xFF3B82F6)
- **Address Icon**: Green (0xFF10B981)
- **Schedule Icon/Box**: Amber (0xFFF59E0B)
- **Schedule Background**: Light amber (0xFFFEF3C7)

### Layout
- Modern card-based design with rounded corners (20px)
- Icon-label-content rows for each section
- Dividers between sections
- Conditional TB Day schedule display
- Responsive sizing (85% width, max 60% height)

## Testing Checklist

- [ ] Popup opens when clicking facility info button
- [ ] Facility name displays in UPPERCASE
- [ ] Address displays correctly
- [ ] TB Day schedule shows for facilities with schedules
- [ ] "Schedule not available" shows for facilities without schedules
- [ ] Close button works
- [ ] Tapping outside popup closes it
- [ ] No compilation errors
- [ ] No unused variable warnings

## Result

The contacts popup now displays:
1. **FACILITY NAME** (uppercase)
2. **Address** (full address)
3. **TB Day Schedule** (days and time, or "not available" message)

No health workers list, no search functionality - just clean facility information! 🎉
