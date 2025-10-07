# System Architecture - Facility Sync Flow

## 🏗️ Overall Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Firebase Firestore                      │
│                                                             │
│  ┌─────────────────┐         ┌────────────────────────┐   │
│  │   facilities    │         │      doctors           │   │
│  │                 │         │                        │   │
│  │  • AGDAO        │         │  doctorId/            │   │
│  │  • BAGUIO       │         │    affiliations: [    │   │
│  │  • DAVAO CHEST  │         │      {                │   │
│  │  • ...          │         │        name: "AGDAO"  │   │
│  │                 │         │        address: "..."  │   │
│  │  [name]         │         │        schedules: []  │   │
│  │  [address]      │         │      }                │   │
│  │  [email]        │         │    ]                  │   │
│  └─────────────────┘         └────────────────────────┘   │
│         ▲                              ▲                   │
│         │                              │                   │
└─────────┼──────────────────────────────┼───────────────────┘
          │                              │
          │                              │
    ┌─────┴──────┐                ┌─────┴──────┐
    │   READ     │                │ READ/WRITE │
    │            │                │            │
    └─────┬──────┘                └─────┬──────┘
          │                              │
          │                              │
┌─────────┴──────────────────────────────┴───────────────────┐
│                   Flutter Application                       │
│                                                             │
│  ┌────────────────────────┐    ┌─────────────────────────┐│
│  │  Admin Registration    │    │   Doctor Account        ││
│  │  medical_staff_create  │    │   daccount.dart         ││
│  │                        │    │                         ││
│  │  _loadFacilities() {   │    │   _loadFacilities() {  ││
│  │    • Load from         │    │     • Load from        ││
│  │      Firebase          │    │       Firebase         ││
│  │    • Store in          │    │     • Store in         ││
│  │      facilities Map    │    │       facilities Map   ││
│  │    • Show in dropdown  │    │     • Show in dropdown ││
│  │  }                     │    │   }                    ││
│  │                        │    │                         ││
│  │  ┌──────────────────┐ │    │   ┌──────────────────┐ ││
│  │  │ Facility UI      │ │    │   │ Facility UI      │ ││
│  │  │ • Header Badge   │ │    │   │ • Header Badge   │ ││
│  │  │ • Loading State  │◄┼────┼───┤ • Loading State  │ ││
│  │  │ • Dropdown       │ │SAME│   │ • Dropdown       │ ││
│  │  │ • Address Card   │ │ UI │   │ • Address Card   │ ││
│  │  └──────────────────┘ │    │   └──────────────────┘ ││
│  │                        │    │                         ││
│  │  Save Doctor {         │    │   Update Doctor {      ││
│  │    affiliations: [{    │    │     affiliations: [{   ││
│  │      name: String ──────────────► name: String       ││
│  │      address: String ───────────► address: String    ││
│  │      schedules: []     │    │       schedules: []    ││
│  │    }]                  │    │     }]                 ││
│  │  }                     │    │   }                    ││
│  └────────────────────────┘    └─────────────────────────┘│
│                                                             │
│  ┌──────────────────────────────────────────────────────┐ │
│  │            Patient Booking (pbooking1.dart)          │ │
│  │                                                       │ │
│  │  • Reads doctor affiliations from Firestore         │ │
│  │  • Displays facility name                           │ │
│  │  • Generates time slots from schedules              │ │
│  │  • Books appointments                               │ │
│  └──────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

---

## 🔄 Data Flow - Create Doctor

```
1. Admin Opens Registration
          │
          ▼
2. initState() calls _loadFacilities()
          │
          ▼
3. Firebase Query: facilities.get()
          │
          ├─ Success → Load data
          │             │
          │             ▼
          │        Store in Map<String, String>
          │        facilities = {
          │          "AGDAO": "Agdao Public Market...",
          │          "BAGUIO": "Baguio District...",
          │          ...
          │        }
          │
          └─ Fail → Use fallback defaults
          
4. Admin Fills Form
   • Name: Dr. Juan
   • Email: juan@test.com
   • Role: Doctor
          │
          ▼
5. Admin Clicks "Add Hospital/Clinic"
          │
          ▼
6. Dialog Opens
   ┌──────────────────────────────┐
   │ Facility Information         │
   │                              │
   │ 🏥 Select Facility ▼         │
   │    AGDAO                     │
   │    BAGUIO                    │
   │    DAVAO CHEST CENTER ◄──    │
   │                              │
   │ Address                      │
   │ Villa Abrille St...          │
   └──────────────────────────────┘
          │
          ▼
7. Admin Selects "DAVAO CHEST CENTER"
   • selectedFacility = "DAVAO CHEST CENTER"
   • facilityAddress = facilities["DAVAO CHEST CENTER"]
   • Address card updates automatically
          │
          ▼
8. Admin Adds Schedules
   • Monday: 9:00 AM - 5:00 PM
   • Break: 12:00 PM - 1:00 PM
   • Session: 30 min
          │
          ▼
9. Save Affiliation
   affiliations.add({
     "name": "DAVAO CHEST CENTER",
     "address": "Villa Abrille St., Brgy 30-C, Davao City",
     "schedules": [{
       "day": "Monday",
       "start": "9:00 AM",
       "end": "5:00 PM",
       "breakStart": "12:00 PM",
       "breakEnd": "1:00 PM",
       "sessionDuration": "30"
     }]
   })
          │
          ▼
10. Complete Registration
          │
          ▼
11. Save to Firestore
    doctors/drjuan123/
      {
        fullName: "Dr. Juan",
        email: "juan@test.com",
        affiliations: [
          {
            name: "DAVAO CHEST CENTER",
            address: "Villa Abrille St., Brgy 30-C, Davao City",
            schedules: [...]
          }
        ]
      }
```

---

## 🔄 Data Flow - Edit Doctor Schedule

```
1. Doctor Logs In
          │
          ▼
2. Opens Account → Affiliations
          │
          ▼
3. Sees: "DAVAO CHEST CENTER"
          │
          ▼
4. Clicks Edit Icon
          │
          ▼
5. initState() calls _loadFacilities()
          │
          ▼
6. Firebase Query: facilities.get()
          │
          ▼
7. Load facilities into Map
   facilities = {
     "AGDAO": "Agdao Public...",
     "DAVAO CHEST CENTER": "Villa Abrille...",
     ...
   }
          │
          ▼
8. Dialog Opens
   ┌──────────────────────────────┐
   │ Edit Schedule                │
   │                              │
   │ Facility Information         │
   │ 🏥 DAVAO CHEST CENTER ▼      │ ← Pre-selected
   │                              │
   │ Address                      │
   │ Villa Abrille St...          │ ← Auto-filled
   │                              │
   │ Schedules...                 │
   └──────────────────────────────┘
          │
          ▼
9. Doctor Changes to "AGDAO"
   • selectedFacility = "AGDAO"
   • facilityAddress = facilities["AGDAO"]
   • Address updates → "Agdao Public Market..."
          │
          ▼
10. Doctor Clicks Save
          │
          ▼
11. _expandScheduleRanges(schedules)
    • Converts any day ranges to individual days
          │
          ▼
12. Update Firestore
    doctors/drjuan123/
      affiliations: [
        {
          name: "AGDAO",  ← Changed!
          address: "Agdao Public Market...",  ← Changed!
          schedules: [...]  ← Preserved
        }
      ]
          │
          ▼
13. Success Message
    ✅ "Schedule updated successfully!"
```

---

## 🔄 Data Flow - Patient Books Appointment

```
1. Patient Opens Booking
          │
          ▼
2. Selects Doctor: "Dr. Juan"
          │
          ▼
3. Load Doctor from Firestore
   doctors/drjuan123/
     affiliations: [{
       name: "AGDAO",
       address: "Agdao Public Market...",
       schedules: [...]
     }]
          │
          ▼
4. Display Facility
   "Dr. Juan at AGDAO"
          │
          ▼
5. Patient Selects Date: Monday
          │
          ▼
6. _getDoctorScheduleForDay("Monday")
   • Finds Monday in schedules
   • Returns: 9:00 AM - 5:00 PM, Break 12-1, 30min sessions
          │
          ▼
7. _getAvailableTimeSlots()
   • Generates slots: 9:00, 9:30, 10:00, ..., 11:30
   • Skip break: 12:00 PM - 1:00 PM
   • Continue: 1:00, 1:30, ..., 4:30 PM
          │
          ▼
8. Display Time Slots
   ┌────┬────┬────┬────┐
   │9:00│9:30│10:00│... │
   └────┴────┴────┴────┘
          │
          ▼
9. Patient Selects 9:30 AM
          │
          ▼
10. Book Appointment ✅
```

---

## 🎯 Synchronization Points

```
┌──────────────────────────────────────────────────────────┐
│                  SYNCHRONIZATION FLOW                    │
└──────────────────────────────────────────────────────────┘

Admin Creates          Doctor Edits           Patient Books
     │                      │                      │
     ├─ Load facilities ────┼─ Load facilities    │
     │  from Firebase       │  from Firebase      │
     │                      │                      │
     ├─ Same UI ────────────┼─ Same UI            │
     │                      │                      │
     ├─ Save to Firestore ──┤                     │
     │                      │                      │
     │                      ├─ Update Firestore ──┤
     │                      │                      │
     │                      │                      ├─ Read from Firestore
     │                      │                      │
     └──────────────────────┴──────────────────────┘
              ▲                    ▲                ▲
              │                    │                │
           PERFECT SYNC - Same data structure everywhere!
```

---

## 📊 Component Hierarchy

```
medical_staff_create.dart
│
├── MedicalStaffCreatePage (StatefulWidget)
│   │
│   ├── State Variables
│   │   ├── Map<String, String> facilities
│   │   ├── bool isLoadingFacilities
│   │   ├── List<Map<String, dynamic>> affiliations
│   │   └── ... other form controllers
│   │
│   ├── Methods
│   │   ├── initState() → Calls _loadFacilities()
│   │   ├── _loadFacilities() → Loads from Firebase
│   │   ├── _showAddAffiliationDialog()
│   │   │   ├── Facility Selection Container
│   │   │   │   ├── Header Badge
│   │   │   │   ├── Loading State
│   │   │   │   ├── Empty State
│   │   │   │   ├── Dropdown (facilities map)
│   │   │   │   └── Address Card
│   │   │   │
│   │   │   └── Schedules Section
│   │   │       ├── Schedule List
│   │   │       └── Add Schedule Button
│   │   │           └── addScheduleDialog()
│   │   │               ├── Day Selector (checkboxes)
│   │   │               ├── Working Hours (time pickers)
│   │   │               ├── Break Time (toggle + pickers)
│   │   │               └── Session Duration (dropdown)
│   │   │
│   │   └── dispose()
│   │
│   └── build()
│       └── Form
│           ├── Name Field
│           ├── Email Field
│           ├── Password Fields
│           ├── Role Dropdown
│           └── Affiliations Section (if Doctor)
│               └── List of affiliation cards
```

---

## 🔐 Data Security Flow

```
┌─────────────────────────────────────────────────────────┐
│                  Firebase Security Rules                │
└─────────────────────────────────────────────────────────┘

facilities collection (READ ONLY for doctors/admins)
  │
  ├─ Allow read: if authenticated
  └─ Allow write: if admin only

doctors collection
  │
  ├─ Allow read: if owner or admin
  ├─ Allow write: if owner or admin
  └─ Validate data structure:
      • affiliations must be array
      • each affiliation must have name, address
      • schedules must be array with required fields

Flow:
  Admin creates → Write to doctors (admin permission)
       ↓
  Doctor edits → Update doctors (owner permission)
       ↓
  Patient reads → Read doctors (public doctor profiles)
```

---

## 🎨 UI State Machine

```
┌──────────────────────────────────────────────────────────┐
│           Facility Selection States                      │
└──────────────────────────────────────────────────────────┘

     [Initial]
        │
        ├─ initState()
        │
        ▼
   [LOADING]
   Show: Spinner + "Loading facilities..."
        │
        ├─ Success
        │    │
        │    ▼
        │ [LOADED]
        │ Show: Dropdown with facilities
        │    │
        │    ├─ No facility selected
        │    │   │
        │    │   └─ [IDLE]
        │    │      Show: Dropdown (no address)
        │    │
        │    └─ Facility selected
        │        │
        │        └─ [SELECTED]
        │           Show: Dropdown + Address Card
        │
        └─ Failure OR Empty
             │
             ▼
          [EMPTY]
          Show: Warning message
```

---

## 📈 Performance Optimization

```
┌──────────────────────────────────────────────────────────┐
│              Performance Considerations                  │
└──────────────────────────────────────────────────────────┘

1. Facility Loading
   • Load once on initState()
   • Cache in memory (facilities Map)
   • No repeated Firebase calls
   • Fallback to defaults if offline

2. UI Updates
   • Use setState() only when needed
   • StatefulBuilder for nested state
   • Dropdown updates address instantly
   • No unnecessary rebuilds

3. Data Storage
   • Store facility name as String (lightweight)
   • Store address as String (lightweight)
   • No object serialization overhead

4. Firebase Optimization
   • Single query for all facilities
   • Use .get() instead of streams (one-time load)
   • Minimal document reads
```

---

## ✅ Success Criteria

```
┌──────────────────────────────────────────────────────────┐
│              Validation Checkpoints                      │
└──────────────────────────────────────────────────────────┘

✓ Admin Registration
  ├─ Facilities load from Firebase
  ├─ Dropdown shows all facilities
  ├─ Address updates on selection
  ├─ Can add multiple affiliations
  └─ Data saves to Firestore correctly

✓ Doctor Editing
  ├─ Facilities load from Firebase (same list)
  ├─ Current facility pre-selected
  ├─ Can change facility
  ├─ Address updates automatically
  └─ Changes save to Firestore

✓ Data Consistency
  ├─ Admin created data = Doctor editable data
  ├─ Facility names match exactly
  ├─ Addresses match exactly
  ├─ Schedule structure preserved
  └─ No data loss on edit

✓ Patient Booking
  ├─ Reads updated facility
  ├─ Generates correct time slots
  ├─ No "No slots" errors
  └─ Booking successful
```

---

This architecture ensures **perfect synchronization** across all parts of the system! 🎯

