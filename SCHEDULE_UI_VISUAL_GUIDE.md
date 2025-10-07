# 🎨 Visual Guide - Schedule UI with Day Ranges

## Complete Dialog Flow

### Step 1: Open "Add Hospital/Clinic"
```
┌──────────────────────────────────────────────────────────┐
│  Add Hospital/Clinic                                  ✕  │
├──────────────────────────────────────────────────────────┤
│                                                          │
│  ┌────────────────────────────────────────────────────┐ │
│  │  ◉  Facility Information                          │ │
│  │                                                    │ │
│  │  🏥  Select TB DOTS Facility ▼                     │ │
│  │     ┌────────────────────────────┐                │ │
│  │     │ DAVAO CHEST CENTER        │                 │ │
│  │     └────────────────────────────┘                │ │
│  │                                                    │ │
│  │  ┌──────────────────────────────────────────────┐ │ │
│  │  │ Address                                      │ │ │
│  │  │ Villa Abrille St., Brgy 30-C, Davao City    │ │ │
│  │  └──────────────────────────────────────────────┘ │ │
│  └────────────────────────────────────────────────────┘ │
│                                                          │
│  ◉  Work Schedules                                      │
│                                                          │
│  ┌────────────────────────────────────────────────────┐ │
│  │ ℹ️  Default schedule: Monday-Friday, 9 AM - 5 PM  │ │
│  │    Doctor can update these later                  │ │
│  └────────────────────────────────────────────────────┘ │
│                                                          │
│  ▼ See Schedule Card Below ▼                             │
│                                                          │
└──────────────────────────────────────────────────────────┘
```

---

### Step 2: Default Schedule Card (Auto-loaded)

```
┌──────────────────────────────────────────────────────────┐
│  ◉ Schedule 1                                       🗑️  │
├──────────────────────────────────────────────────────────┤
│                                                          │
│  ☑️ Day Range                                            │
│     Apply to multiple consecutive days                  │
│                                                          │
│  Starts                Ends                              │
│  ┌──────────────┐     ┌──────────────┐                  │
│  │ Monday      ▼│     │ Friday      ▼│                  │
│  └──────────────┘     └──────────────┘                  │
│                                                          │
│  ┌────────────────────────────────────────────────────┐ │
│  │ Working Hours                                      │ │
│  │                                                    │ │
│  │ Start                                              │ │
│  │ ┌──┐ : ┌──┐ ┌─────┐                              │ │
│  │ │09│ : │00│ │AM ▼│                                │ │
│  │ └──┘   └──┘ └─────┘                               │ │
│  │                                                    │ │
│  │ End                                                │ │
│  │ ┌──┐ : ┌──┐ ┌─────┐                              │ │
│  │ │05│ : │00│ │PM ▼│                                │ │
│  │ └──┘   └──┘ └─────┘                               │ │
│  └────────────────────────────────────────────────────┘ │
│                                                          │
│  ┌────────────────────────────────────────────────────┐ │
│  │ Break Time                                         │ │
│  │                                                    │ │
│  │ Start                                              │ │
│  │ ┌──┐ : ┌──┐ ┌─────┐                              │ │
│  │ │11│ : │00│ │AM ▼│                                │ │
│  │ └──┘   └──┘ └─────┘                               │ │
│  │                                                    │ │
│  │ End                                                │ │
│  │ ┌──┐ : ┌──┐ ┌─────┐                              │ │
│  │ │12│ : │00│ │PM ▼│                                │ │
│  │ └──┘   └──┘ └─────┘                               │ │
│  └────────────────────────────────────────────────────┘ │
│                                                          │
│  ┌────────────────────────────────────────────────────┐ │
│  │ Session Duration                                   │ │
│  │                                                    │ │
│  │ 🕐 Duration per session ▼                          │ │
│  │    ┌────────────────┐                             │ │
│  │    │ 30 min        │                              │ │
│  │    └────────────────┘                             │ │
│  └────────────────────────────────────────────────────┘ │
│                                                          │
└──────────────────────────────────────────────────────────┘

               [ + Add Schedule ]
```

---

### Step 3: Uncheck "Day Range" (Single Day Mode)

```
┌──────────────────────────────────────────────────────────┐
│  ◉ Schedule 1                                       🗑️  │
├──────────────────────────────────────────────────────────┤
│                                                          │
│  ☐ Day Range                                             │
│     Apply to multiple consecutive days                  │
│                                                          │
│  Day                                                     │
│  ┌──────────────────────────────────────┐               │
│  │ Monday                              ▼│               │
│  └──────────────────────────────────────┘               │
│                                                          │
│  (Working Hours, Break Time, Session Duration...)       │
│                                                          │
└──────────────────────────────────────────────────────────┘
```

---

### Step 4: Click "Add Schedule" Button

```
┌──────────────────────────────────────────────────────────┐
│  ◉ Schedule 1                                       🗑️  │
│  (Monday to Friday, 9-5, shown above...)                 │
└──────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────┐
│  ◉ Schedule 2                                       🗑️  │  ← NEW!
├──────────────────────────────────────────────────────────┤
│                                                          │
│  ☐ Day Range                                             │
│     Apply to multiple consecutive days                  │
│                                                          │
│  Day                                                     │
│  ┌──────────────────────────────────────┐               │
│  │ Monday                              ▼│               │
│  └──────────────────────────────────────┘               │
│                                                          │
│  ┌────────────────────────────────────────────────────┐ │
│  │ Working Hours                                      │ │
│  │ Start: 09:00 AM                                    │ │
│  │ End: 05:00 PM                                      │ │
│  └────────────────────────────────────────────────────┘ │
│                                                          │
│  ┌────────────────────────────────────────────────────┐ │
│  │ Break Time                                         │ │
│  │ Start: 11:00 AM                                    │ │
│  │ End: 12:00 PM                                      │ │
│  └────────────────────────────────────────────────────┘ │
│                                                          │
│  ┌────────────────────────────────────────────────────┐ │
│  │ Session Duration: 30 min                           │ │
│  └────────────────────────────────────────────────────┘ │
│                                                          │
└──────────────────────────────────────────────────────────┘

               [ + Add Schedule ]
```

---

## Color Coding

### Facility Section
```
┌────────────────────────────────┐
│ WHITE background               │
│ GREY border                    │
│ RED ACCENT badge               │
└────────────────────────────────┘
```

### Working Hours Section
```
┌────────────────────────────────┐
│ LIGHT BLUE background          │
│ BLUE border                    │
│ BLUE text headers              │
└────────────────────────────────┘
```

### Break Time Section
```
┌────────────────────────────────┐
│ LIGHT ORANGE background        │
│ ORANGE border                  │
│ ORANGE text headers            │
└────────────────────────────────┘
```

### Session Duration Section
```
┌────────────────────────────────┐
│ LIGHT GREEN background         │
│ GREEN border                   │
│ GREEN text headers             │
└────────────────────────────────┘
```

---

## Interactive Elements

### Time Picker Fields
```
Hover:
┌──┐ : ┌──┐ ┌─────┐
│09│ : │00│ │AM ▼│  ← All fields editable
└──┘   └──┘ └─────┘

Type to change:
┌──┐ : ┌──┐ ┌─────┐
│10│ : │30│ │PM ▼│  ← Updated!
└──┘   └──┘ └─────┘
```

### Day Range Toggle
```
Unchecked (Single Day):
☐ Day Range
  Apply to multiple consecutive days

Checked (Range):
☑️ Day Range
  Apply to multiple consecutive days
```

### Delete Button
```
Normal:                  Hover:
    🗑️                      🗑️  (darker red)
```

---

## Complete Example: Saturday Schedule

Admin wants to add Saturday with different hours:

```
1. Click "Add Schedule"

2. Keep Day Range unchecked

3. Select Day: Saturday

4. Set Working Hours:
   Start: 10:00 AM
   End: 02:00 PM

5. Set Break Time:
   Start: 12:00 PM
   End: 12:30 PM

6. Set Session Duration: 30 min

Result:
┌──────────────────────────────────────────────────────────┐
│  ◉ Schedule 2                                       🗑️  │
├──────────────────────────────────────────────────────────┤
│  ☐ Day Range                                             │
│                                                          │
│  Day: Saturday                                           │
│                                                          │
│  Working Hours: 10:00 AM - 02:00 PM                      │
│  Break Time: 12:00 PM - 12:30 PM                         │
│  Session Duration: 30 min                                │
└──────────────────────────────────────────────────────────┘
```

---

## Firestore Result

### What Admin Sees (2 schedules)
```
Schedule 1: Monday to Friday (range)
Schedule 2: Saturday (single day)
```

### What Gets Saved (6 individual schedules)
```json
{
  "schedules": [
    {"day": "Monday", "start": "9:00 AM", "end": "5:00 PM", ...},
    {"day": "Tuesday", "start": "9:00 AM", "end": "5:00 PM", ...},
    {"day": "Wednesday", "start": "9:00 AM", "end": "5:00 PM", ...},
    {"day": "Thursday", "start": "9:00 AM", "end": "5:00 PM", ...},
    {"day": "Friday", "start": "9:00 AM", "end": "5:00 PM", ...},
    {"day": "Saturday", "start": "10:00 AM", "end": "2:00 PM", ...}
  ]
}
```

### What Doctor Sees in Edit (Grouped back)
```
Schedule 1: Monday to Friday (auto-grouped because consecutive & same times)
Schedule 2: Saturday (standalone)
```

---

## Mobile vs Desktop Layout

### Desktop (Wide Screen)
```
┌─────────────┬─────────────┐
│ Start Day   │  End Day    │
│ ┌─────────┐ │ ┌─────────┐ │
│ │Monday  ▼│ │ │Friday  ▼│ │
│ └─────────┘ │ └─────────┘ │
└─────────────┴─────────────┘
```

### Mobile (Narrow Screen)
```
┌───────────────────────────┐
│ Start Day                 │
│ ┌───────────────────────┐ │
│ │ Monday              ▼│ │
│ └───────────────────────┘ │
└───────────────────────────┘
┌───────────────────────────┐
│ End Day                   │
│ ┌───────────────────────┐ │
│ │ Friday              ▼│ │
│ └───────────────────────┘ │
└───────────────────────────┘
```

---

## Error States

### No Facility Selected
```
┌────────────────────────────────┐
│ ⚠️ Please select a facility   │
└────────────────────────────────┘
```

### No Schedule Added (After deleting default)
```
┌────────────────────────────────────────┐
│ ⚠️ Please add at least one schedule   │
└────────────────────────────────────────┘
```

### Invalid Time Range (End before Start)
```
┌────────────────────────────────────────────┐
│ ⚠️ End time must be after start time      │
└────────────────────────────────────────────┘
```

---

## Summary: Key UI Features

✅ **Color-coded sections** - Blue (working), Orange (break), Green (duration)  
✅ **Inline time editing** - Hour:Min:AM/PM fields  
✅ **Day range toggle** - Checkbox to enable/disable  
✅ **Range dropdowns** - Start/End day selection  
✅ **Delete buttons** - Per schedule removal  
✅ **Add button** - Creates new schedule with defaults  
✅ **Info banner** - Explains default schedule  
✅ **Badges** - Schedule numbers and section headers  
✅ **Shadows** - Modern depth effect  
✅ **Responsive** - Works on mobile and desktop  

**Result:** Professional, intuitive UI that matches doctor account editing! 🎨

