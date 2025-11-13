# Quick Start Guide: Working Hours Chat Restrictions

## Summary
✅ **Implemented!** Chat restrictions for patients/guests chatting with health workers.

## What's New?

### 🕐 Working Hours
- **Available**: Monday-Friday, 8:00 AM - 5:00 PM
- **Unavailable**: Nights, weekends, and before 8 AM

### 🚫 Anti-Spam Protection
- Users can send **2 messages** per session
- After 2 messages: **10-minute cooldown**
- Chat input becomes greyed out during cooldown
- Live countdown timer shows time remaining

### 📱 What Users See

#### Scenario 1: Outside Working Hours
```
User: *tries to send message at 7 PM*
System: 🚫 Dialog appears
"Health worker is not available at this time.
Working hours: Monday-Friday, 8:00 AM - 5:00 PM"
Result: Message NOT sent
```

#### Scenario 2: Reaching Message Limit
```
User: *sends 1st message* ✅ Sent
System: Shows "1 message remaining before cooldown"

User: *sends 2nd message* ✅ Sent
System: Shows countdown timer "Cooldown: 9:58 remaining"
        Input field greyed out

User: *waits 10 minutes*
System: Input re-enabled, counter resets
```

## Who Is Affected?

### ✅ Restrictions Apply To:
- Patients chatting with health workers
- Guests chatting with health workers

### ❌ Restrictions DO NOT Apply To:
- Doctors (unrestricted)
- Health workers sending messages (unrestricted)
- Doctor-to-patient chats
- Doctor-to-doctor chats

## Configuration

Want to change the settings? Edit `lib/services/working_hours_service.dart`:

```dart
// Change working hours
static const int workingHourStart = 8;  // 8 AM
static const int workingHourEnd = 17;   // 5 PM (change to 18 for 6 PM)

// Change message limit
static const int maxMessagesBeforeCooldown = 2;  // Change to 3 for 3 messages

// Change cooldown duration
static const int cooldownDurationMinutes = 10;  // Change to 15 for 15 minutes
```

## Testing Instructions

### Test 1: Working Hours
1. Change device time to Saturday
2. Try to send a message to a health worker
3. ✅ Should see "not available on weekends" dialog

### Test 2: Message Limit
1. Send 2 messages to a health worker
2. Try to send a 3rd message
3. ✅ Should see cooldown dialog and greyed input

### Test 3: Cooldown Timer
1. After reaching limit, observe the timer
2. ✅ Should count down from 10:00 to 0:00
3. ✅ Input should re-enable automatically

### Test 4: Health Worker Unrestricted
1. Login as a health worker
2. Try sending multiple messages
3. ✅ Should send unlimited messages

## Troubleshooting

### Issue: Timer doesn't count down
- **Solution**: Make sure the app stays open (timer runs in memory)

### Issue: Cooldown persists after 10 minutes
- **Solution**: Force close and reopen the app to reset

### Issue: Health worker also has restrictions
- **Solution**: Check user role in database - must be `role: 'healthcare'`

### Manual Reset (For Testing)
If you need to reset cooldown manually for testing:
```dart
await WorkingHoursService.resetChat(chatId);
```

## Files Modified
1. ✅ `lib/services/working_hours_service.dart` - NEW
2. ✅ `lib/chat_screens/guest_healthworker_chat_screen.dart` - UPDATED
3. ✅ `lib/chat_screens/chat_screen.dart` - UPDATED

## Next Steps
- [ ] Test on real device
- [ ] Get user feedback
- [ ] Adjust cooldown time if needed
- [ ] Consider adding emergency override button

## Support
For questions or issues, check:
- Full documentation: `WORKING_HOURS_CHAT_RESTRICTIONS.md`
- Code comments in `working_hours_service.dart`
