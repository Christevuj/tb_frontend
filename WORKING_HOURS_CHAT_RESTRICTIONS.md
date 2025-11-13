# Working Hours & Chat Restrictions Implementation

## Overview
Implemented working hours restrictions and anti-spam cooldown system for patients/guests chatting with health workers.

## Features Implemented

### 1. Working Hours Restrictions
- **Working Days**: Monday to Friday
- **Working Hours**: 8:00 AM to 5:00 PM
- **Non-Working Hours**: Before 8 AM and after 5 PM
- **Non-Working Days**: Saturday and Sunday

### 2. Anti-Spam Cooldown System
- **Message Limit**: 2 messages per session
- **Cooldown Duration**: 10 minutes
- **Cooldown Behavior**: After sending 2 messages, chat input is disabled (greyed out) for 10 minutes

### 3. User Experience

#### Outside Working Hours:
- When a patient/guest tries to send a message outside working hours
- An automated dialog appears with the message:
  - "Health worker is not available at this time."
  - Shows working hours: "Monday-Friday, 8:00 AM - 5:00 PM"
  - Message is NOT sent

#### Message Limit Reached:
- After sending 2 messages, the chat input becomes greyed out
- A cooldown timer is displayed showing remaining time (e.g., "9:45 remaining")
- A dialog appears explaining:
  - "You have reached the message limit to prevent spam."
  - Shows remaining cooldown time
  - Tip: "You can send 2 messages every 10 minutes."

#### Visual Indicators:
1. **Cooldown Banner** (orange):
   - Displays countdown timer in MM:SS format
   - Shows "Cooldown: X:XX remaining"

2. **Message Counter** (blue):
   - Appears after sending 1 message
   - Shows "X message(s) remaining before cooldown"

3. **Greyed Out Input**:
   - Text field becomes disabled
   - Hint text changes to "Message limit reached..."
   - Camera and send buttons are disabled
   - Visual styling changes to grey color scheme

## Files Created/Modified

### New Files:
1. **`lib/services/working_hours_service.dart`**
   - Core service handling all working hours logic
   - Cooldown tracking using SharedPreferences
   - Methods for checking availability, message limits, cooldown status

### Modified Files:
1. **`lib/chat_screens/guest_healthworker_chat_screen.dart`**
   - Added working hours validation
   - Added cooldown tracking with timer
   - Updated UI to show cooldown status
   - Added dialogs for restrictions

2. **`lib/chat_screens/chat_screen.dart`**
   - Same restrictions applied for patients chatting with healthcare workers
   - Only applies to patient->healthcare conversations
   - Doctor and healthcare worker conversations are unrestricted

## Technical Details

### WorkingHoursService Methods:
- `isWithinWorkingHours()` - Check if current time is M-F 8am-5pm
- `getAvailabilityMessage()` - Get human-readable unavailability message
- `isInCooldown(chatId)` - Check if user is in cooldown period
- `canSendMessage(chatId)` - Check if user can send a message
- `incrementMessageCount(chatId)` - Track message sends
- `getRemainingCooldownSeconds(chatId)` - Get cooldown time remaining
- `getRemainingMessages(chatId)` - Get messages remaining before cooldown

### State Management:
- Uses `SharedPreferences` to persist cooldown data
- Countdown timer updates UI every second
- Automatic reset after cooldown expires

### User Flows:

#### Flow 1: Outside Working Hours
```
User types message → Clicks send → Check working hours
→ If outside hours → Show dialog → Message not sent
```

#### Flow 2: Within Working Hours - First 2 Messages
```
User types message → Clicks send → Check cooldown
→ If < 2 messages sent → Send message → Increment counter
→ Show remaining messages indicator
```

#### Flow 3: Message Limit Reached
```
User tries to send 3rd message → Check cooldown
→ If limit reached → Show cooldown dialog → Start timer
→ Grey out input → Display countdown banner
→ After 10 minutes → Reset counter → Enable input
```

## Configuration

All settings are in `working_hours_service.dart`:

```dart
static const int workingHourStart = 8;  // 8 AM
static const int workingHourEnd = 17;   // 5 PM
static const int maxMessagesBeforeCooldown = 2;
static const int cooldownDurationMinutes = 10;
```

## Scope

### Applies To:
- ✅ Guests chatting with health workers
- ✅ Patients chatting with health workers

### Does NOT Apply To:
- ❌ Doctors chatting with patients
- ❌ Health workers chatting with patients  
- ❌ Doctor-to-doctor conversations
- ❌ Any healthcare staff outgoing messages

## Testing Checklist

- [ ] Test sending messages on Saturday/Sunday (should block)
- [ ] Test sending messages before 8 AM (should block)
- [ ] Test sending messages after 5 PM (should block)
- [ ] Test sending 2 messages quickly (should work)
- [ ] Test sending 3rd message (should trigger cooldown)
- [ ] Verify cooldown timer counts down correctly
- [ ] Verify input is greyed out during cooldown
- [ ] Verify cooldown resets after 10 minutes
- [ ] Test that healthcare workers can send unlimited messages
- [ ] Test that doctors are not restricted

## Future Enhancements

Possible improvements:
1. Admin panel to configure working hours
2. Custom working hours per health worker
3. Emergency override for urgent messages
4. Different limits for verified vs. new patients
5. Analytics dashboard for message patterns
