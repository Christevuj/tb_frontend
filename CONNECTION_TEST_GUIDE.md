# 🧪 Quick Connection Test Guide

## Purpose
Verify that schedules created by admin are visible in patient booking.

---

## ✅ Test Steps

### 1️⃣ **Create Doctor via Admin**

```
1. Login as Admin
2. Go to Medical Staff Registration
3. Fill in details:
   - Name: Test Doctor
   - Role: Doctor
   - Email: testdoctor@test.com
   - Password: test123
4. Click "Add Hospital/Clinic" (+)
5. Select Facility: AGDAO (or any facility)
6. Verify default schedule appears:
   ☑️ Day Range: Monday to Friday
   🔵 Working: 9:00 AM - 5:00 PM
   🟠 Break: 11:00 AM - 12:00 PM
   🟢 Session: 30 min
7. Click "Add Affiliation"
8. Click "Continue"
9. Confirm registration
```

**Expected Result:** Doctor created with Mon-Fri 9-5 schedule

---

### 2️⃣ **Verify in Firestore** (Optional)

```
1. Open Firebase Console
2. Go to Firestore Database
3. Navigate to: doctors → {doctor_uid} → affiliations
4. Check schedule structure:
   ✅ Should have 5 schedules (one for each weekday)
   ✅ Each with: day, start, end, breakStart, breakEnd, sessionDuration
```

**Expected Data:**
```json
{
  "affiliations": [
    {
      "name": "AGDAO",
      "schedules": [
        {"day": "Monday", "start": "9:00 AM", ...},
        {"day": "Tuesday", "start": "9:00 AM", ...},
        {"day": "Wednesday", "start": "9:00 AM", ...},
        {"day": "Thursday", "start": "9:00 AM", ...},
        {"day": "Friday", "start": "9:00 AM", ...}
      ]
    }
  ]
}
```

---

### 3️⃣ **Check Doctor Account**

```
1. Logout from Admin
2. Login as the Test Doctor (testdoctor@test.com / test123)
3. Go to Account/Profile
4. Find the affiliation card
5. Click Edit (pencil icon)
6. Verify schedule shows:
   ☑️ Day Range: Monday to Friday
   (Should display as range for convenience)
7. Click Cancel or Save Changes
```

**Expected Result:** Doctor can view and edit the schedule

---

### 4️⃣ **Test Patient Booking**

```
1. Logout from Doctor
2. Login as Patient
3. Go to Book Appointment
4. Select the Test Doctor
5. Click on a WEEKDAY date (Monday-Friday)
6. Observe available time slots
```

**Expected Slots:**
```
Morning Slots (9:00 AM - 11:00 AM):
✅ 9:00 AM - 9:30 AM
✅ 9:30 AM - 10:00 AM
✅ 10:00 AM - 10:30 AM
✅ 10:30 AM - 11:00 AM

Break (11:00 AM - 12:00 PM):
❌ No slots (break time)

Afternoon Slots (12:00 PM - 5:00 PM):
✅ 12:00 PM - 12:30 PM
✅ 12:30 PM - 1:00 PM
✅ 1:00 PM - 1:30 PM
... (continuing every 30 minutes)
✅ 4:30 PM - 5:00 PM

Total: ~14 available slots
```

---

### 5️⃣ **Test Weekend (No Schedule)**

```
1. Still in Patient Booking
2. Select a SATURDAY or SUNDAY
3. Observe slots
```

**Expected Result:** 
```
❌ No available time slots
(Doctor only works Monday-Friday)
```

---

### 6️⃣ **Doctor Edits Schedule**

```
1. Login as Test Doctor
2. Go to Account
3. Edit the affiliation schedule
4. Change to: Monday to Wednesday (remove Thu-Fri)
5. Save Changes
6. Logout
```

---

### 7️⃣ **Verify Changes in Patient Booking**

```
1. Login as Patient
2. Book Appointment → Select Test Doctor
3. Try selecting THURSDAY
4. Observe slots
```

**Expected Result:**
```
❌ No slots on Thursday
(Doctor changed schedule to Mon-Wed only)
```

---

## 🎯 Pass/Fail Criteria

| Test | Expected | Status |
|------|----------|--------|
| Admin creates with default schedule | Mon-Fri 9-5 visible | ⬜ |
| Firestore has 5 individual days | Yes | ⬜ |
| Doctor can view schedule | Shows Mon-Fri range | ⬜ |
| Doctor can edit schedule | Edit dialog works | ⬜ |
| Patient sees slots on weekdays | ~14 slots per day | ⬜ |
| Patient sees no slots on weekends | 0 slots | ⬜ |
| Break time excluded | No 11AM-12PM slots | ⬜ |
| Doctor changes reflected | Updated schedule works | ⬜ |

---

## 🐛 Troubleshooting

### Issue: No slots showing for any day
**Check:**
- Firestore: Does doctor have `affiliations` array?
- Firestore: Does affiliation have `schedules` array?
- Console: Any errors in browser console?
- Day name: Is day name matching exactly? ("Monday" not "monday")

### Issue: All days showing slots (even weekends)
**Check:**
- Firestore: Are there Saturday/Sunday schedules added?
- Code: Check `_getDoctorScheduleForDay()` filter logic

### Issue: Wrong time slots
**Check:**
- Firestore: Verify `start`, `end`, `breakStart`, `breakEnd` values
- Firestore: Verify `sessionDuration` is "30" (string)
- Code: Check `_generateTimeSlots()` parsing logic

### Issue: Slots during break time
**Check:**
- Firestore: Verify `breakStart` and `breakEnd` values
- Code: Check break time exclusion in `_generateTimeSlots()`

---

## 📝 Debug Console Output

When testing patient booking, check browser console for:

```
Found 1 affiliations
--- Affiliation 0 ---
Name: AGDAO
Schedules count: 5
  Schedule 0: day="Monday", start="9:00 AM", end="5:00 PM"
  Schedule 1: day="Tuesday", start="9:00 AM", end="5:00 PM"
  ...
MATCH FOUND: Schedule day "Monday" matches requested day "Monday"
Found 1 schedules for Monday in affiliation 0
SUCCESS: Returning 1 schedules for Monday
Generating slots: 9:00 AM to 5:00 PM, break: 11:00 AM-12:00 PM, duration: 30min
```

---

## ✅ Success Indicators

1. **Admin Create:** Default schedule appears immediately
2. **Firestore:** Individual day schedules saved (not ranges)
3. **Doctor View:** Grouped into ranges for easy viewing
4. **Doctor Edit:** Can modify and save successfully
5. **Patient Booking:** Correct slots appear for correct days
6. **Break Time:** Respected (no slots during break)
7. **Session Duration:** Used correctly (30-minute intervals)
8. **Updates:** Doctor changes reflect immediately in patient booking

---

## 🎉 All Tests Pass?

**Congratulations!** The schedule system is fully connected:

✅ Admin → Firestore → Doctor → Patient

The data flows smoothly across all components!

---

**Test Duration:** ~10 minutes  
**Required Accounts:** Admin, Doctor (created), Patient  
**Components Tested:** 3 (Admin, Doctor, Patient)

