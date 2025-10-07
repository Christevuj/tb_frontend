# Quick Testing Guide - Facility Sync Update

## 🎯 What to Test

The admin hospital/clinic affiliation UI now matches the doctor account edit UI perfectly!

---

## ✅ Test 1: Visual Consistency

### Open Admin Registration
1. Go to Medical Staff Registration
2. Select "Doctor" role
3. Click "Add Hospital/Clinic" button
4. **Observe:** Modern facility selection container with:
   - "Facility Information" badge at top
   - Loading spinner (briefly)
   - Dropdown with all TB DOTS facilities
   - Blue address container when facility selected

### Open Doctor Account Edit
1. Login as existing doctor
2. Go to Account → Affiliations section
3. Click Edit icon on any affiliation
4. **Observe:** Scroll to top of dialog - EXACT SAME facility container!

### ✅ Pass Criteria
- Both UIs look identical
- Same colors (red accent, blue address container)
- Same spacing and padding
- Same loading behavior

---

## ✅ Test 2: Facility Data Sync

### Create New Doctor
1. Go to Admin → Medical Staff Registration
2. Fill in doctor details:
   - Name: "Test Doctor Sync"
   - Email: "testdoctor@sync.com"
   - Password: "test123"
   - Role: "Doctor"
3. Click "Add Hospital/Clinic"
4. Select facility: **"DAVAO CHEST CENTER"**
5. Verify address shows: "Villa Abrille St., Brgy 30-C, Davao City"
6. Add schedule for Monday 9:00 AM - 5:00 PM
7. Complete registration

### Login as That Doctor
1. Logout admin
2. Login as testdoctor@sync.com
3. Go to Account → Affiliations
4. **Verify:** "DAVAO CHEST CENTER" is listed
5. Click Edit icon
6. **Verify:** Facility dropdown shows "DAVAO CHEST CENTER" selected
7. **Verify:** Address shows "Villa Abrille St., Brgy 30-C, Davao City"

### ✅ Pass Criteria
- Facility name matches exactly
- Address displays correctly
- No errors in console

---

## ✅ Test 3: Edit Facility

### Change Facility in Doctor Account
1. Login as doctor
2. Go to Account → Affiliations → Edit
3. Change facility from "DAVAO CHEST CENTER" to **"AGDAO"**
4. **Verify:** Address updates to "Agdao Public Market Corner Lapu-Lapu & C. Bangoy St., Agdao, Davao City"
5. Save changes
6. **Verify:** Success message appears
7. Refresh page
8. **Verify:** Affiliation now shows "AGDAO"

### Check Firestore
1. Open Firebase Console
2. Go to Firestore Database
3. Navigate to `doctors` collection
4. Find the test doctor document
5. Check `affiliations` array
6. **Verify:** First affiliation has:
   ```json
   {
     "name": "AGDAO",
     "address": "Agdao Public Market Corner Lapu-Lapu & C. Bangoy St., Agdao, Davao City",
     "schedules": [...]
   }
   ```

### ✅ Pass Criteria
- Facility name updated in Firestore
- Address updated correctly
- No data corruption
- Schedule data preserved

---

## ✅ Test 4: Booking Integration

### Test Patient Booking
1. Login as patient
2. Go to Book Appointment
3. Select the test doctor "Test Doctor Sync"
4. **Verify:** Facility shows "AGDAO" (the updated one)
5. Select a date within schedule (Monday if you set Mon schedule)
6. **Verify:** Available time slots appear
7. **Verify:** Time slots respect the schedule you set

### ✅ Pass Criteria
- Correct facility displays
- Time slots generated correctly
- No "No available slots" error for valid dates
- All schedule fields (break times, session duration) work

---

## ✅ Test 5: Loading States

### Test Loading Indicator
1. Open admin registration
2. Click "Add Hospital/Clinic"
3. **Watch closely:** You should briefly see spinner and "Loading facilities..."
4. Then dropdown appears

### Test Empty State (Optional)
1. Temporarily clear Firebase `facilities` collection
2. Refresh admin page
3. Click "Add Hospital/Clinic"
4. **Verify:** Orange warning box appears
5. **Verify:** Message: "No facilities available. Please contact administrator."
6. **Restore** facilities collection

### ✅ Pass Criteria
- Loading spinner appears briefly
- Empty state shows if no facilities
- Fallback to default TB DOTS facilities works

---

## ✅ Test 6: Multiple Affiliations

### Add Multiple Facilities
1. Create doctor via admin
2. Add affiliation: "AGDAO" with Monday schedule
3. Click "Add Hospital/Clinic" again
4. Add affiliation: "BAGUIO" with Tuesday schedule
5. Add affiliation: "DAVAO CHEST CENTER" with Wednesday schedule
6. Complete registration

### Edit Different Affiliations
1. Login as doctor
2. Edit first affiliation (AGDAO)
3. **Verify:** Dropdown shows "AGDAO" selected
4. Change to "TORIL A"
5. Save
6. Edit second affiliation (BAGUIO)
7. **Verify:** Dropdown shows "BAGUIO" selected (not "TORIL A")
8. Each affiliation maintains its own facility selection

### ✅ Pass Criteria
- Each affiliation can have different facility
- Editing one doesn't affect others
- All facilities sync correctly

---

## 🐛 Common Issues & Solutions

### Issue: Dropdown is empty
**Solution:** Check Firebase `facilities` collection exists and has documents

### Issue: Address doesn't update
**Solution:** Verify facility name in dropdown matches exactly with Firebase data

### Issue: Loading spinner never disappears
**Solution:** Check Firebase connection, look for errors in console

### Issue: "No facilities available" always shows
**Solution:** Ensure Firebase rules allow reading `facilities` collection

### Issue: Changes don't save
**Solution:** Check Firebase rules allow writing to `doctors` collection

---

## 📝 Expected Console Output

When everything works correctly, you should see:
```
✓ Facilities loaded: 19 items
✓ Selected facility: AGDAO
✓ Facility address updated: Agdao Public Market...
✓ Affiliation saved successfully
✓ Doctor schedule updated
```

No errors should appear! ❌

---

## 🎉 Success Indicators

You'll know it's working perfectly when:

1. ✅ Admin and doctor UIs look identical
2. ✅ Facility dropdown loads in both places
3. ✅ Address displays correctly in both places
4. ✅ Changing facility in doctor account updates Firestore
5. ✅ Patient booking shows correct facility
6. ✅ Time slots generate based on schedules
7. ✅ No console errors
8. ✅ Data structure matches between creation and editing

---

## 🚀 Ready for Production?

Before deploying, ensure:
- [ ] All 6 tests pass
- [ ] No console errors
- [ ] Firebase `facilities` collection populated
- [ ] Firebase rules allow read/write
- [ ] Multiple test doctors created successfully
- [ ] Booking system works with new doctors
- [ ] Old doctors can edit their affiliations
- [ ] Documentation reviewed

Once all checkboxes are ✅, you're good to go!

---

## 🎯 Quick Test Script

Run this in order:
```
1. Admin → Register Doctor → Add 2 affiliations
2. Check Firestore data structure
3. Login as doctor → Edit affiliation → Change facility
4. Check Firestore updated correctly
5. Patient → Book appointment → Verify slots appear
6. ✅ ALL TESTS PASSED!
```

Total time: ~5 minutes

Happy Testing! 🎊

