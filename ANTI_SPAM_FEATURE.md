# Anti-Spam Feature Implementation ✅

## Overview
Added anti-spam protection to prevent patients/guests from spamming messages outside working hours. After 3 auto-reply messages, the chatbox is disabled for 5 minutes.

## Feature Details

### Configuration
- **Max Auto-Replies**: 3 messages
- **Cooldown Duration**: 5 minutes
- **Applies**: Only when messaging outside working hours (before 8 AM, after 5 PM, or weekends)

### How It Works

#### Normal Flow (Outside Working Hours)
1. **Message 1**: User sends → Auto-reply sent → Counter: 1/3
2. **Message 2**: User sends → Auto-reply sent → Counter: 2/3
3. **Message 3**: User sends → Auto-reply sent → Counter: 3/3 → **Anti-spam activated!**
4. **Message 4+**: ❌ Chatbox disabled for 5 minutes

#### Anti-Spam Cooldown Active
- Input field greyed out
- Send button disabled
- Camera button disabled
- Red warning banner shows remaining time
- Hint text: "Too many messages - cooldown active"

#### After 5 Minutes
- Cooldown expires
- Chatbox re-enabled
- Auto-reply counter resets to 0
- User can send messages again

## Visual Indicators

### Anti-Spam Warning Banner (Red)
```
┌────────────────────────────────────────────────┐
│ 🚫  ⚠️ Too many messages outside working       │
│     hours. Cooldown: 4:32                      │
└────────────────────────────────────────────────┘
```

### Disabled Input Field
```
┌────────────────────────────────────────────────┐
│ 📷  Too many messages - cooldown active    🚫 │
└────────────────────────────────────────────────┘
```
- Grey background
- Grey borders
- Disabled camera, input, and send buttons

## Code Changes

### 1. `lib/services/working_hours_service.dart`

#### New Constants
```dart
// Anti-spam configuration
static const int maxAutoRepliesBeforeBlock = 3;
static const int antiSpamCooldownMinutes = 5;
```

#### New Methods
```dart
// Track auto-reply count
incrementAutoReplyCount(chatId)

// Check if in anti-spam cooldown
isInAntiSpamCooldown(chatId)

// Get remaining cooldown seconds
getRemainingAntiSpamSeconds(chatId)

// Get anti-spam message
getAntiSpamMessage(chatId)

// Get current auto-reply count
getAutoReplyCount(chatId)
```

### 2. `lib/chat_screens/guest_healthworker_chat_screen.dart`

#### New State Variables
```dart
bool _isInAntiSpamCooldown = false;
int _remainingAntiSpamSeconds = 0;
Timer? _antiSpamTimer;
```

#### Updated `_send()` Method
```dart
// Check anti-spam cooldown first
if (_isInAntiSpamCooldown) {
  return; // Block message
}

// After sending auto-reply
await WorkingHoursService.incrementAutoReplyCount(_chatId);

// Check if reached limit
if (autoReplyCount >= 3) {
  setState(() {
    _isInAntiSpamCooldown = true;
  });
  _startAntiSpamTimer();
}
```

#### Updated UI Elements
- Input field: `enabled: !_isInCooldown && !_isInAntiSpamCooldown`
- Camera button: `onPressed: (_isInCooldown || _isInAntiSpamCooldown) ? null : ...`
- Send button: Disabled when anti-spam active
- Warning banner: Red banner with countdown timer

## User Experience

### Scenario 1: Spamming Outside Hours
```
3:00 AM - User: "Hello"
          → Message sent ✅
          → Auto-reply sent ✅
          → Counter: 1/3

3:01 AM - User: "Anyone there?"
          → Message sent ✅
          → Auto-reply sent ✅
          → Counter: 2/3

3:02 AM - User: "Please respond"
          → Message sent ✅
          → Auto-reply sent ✅
          → Counter: 3/3
          → 🚫 ANTI-SPAM ACTIVATED

3:03 AM - User tries to type
          → ❌ Input field disabled
          → ⏰ "5:00 remaining" shown
          
3:08 AM - 5 minutes passed
          → ✅ Chatbox re-enabled
          → Counter reset to 0
```

### Scenario 2: During Working Hours
```
10:00 AM - User sends messages
           → ✅ No auto-replies
           → ✅ No anti-spam tracking
           → ✅ Normal rate limiting applies (2 msgs/10 min)
```

## Benefits

### 1. Prevents Spam
- Users can't flood with messages when healthcare worker is unavailable
- Protects healthcare workers from notification overload
- Encourages respectful messaging behavior

### 2. Clear Communication
- Red warning banner is highly visible
- Countdown timer shows exactly when they can message again
- Informative hint text explains the situation

### 3. Fair System
- 3 messages is reasonable allowance
- 5 minutes is short enough to not frustrate users
- Auto-resets when working hours begin

### 4. Professional
- Maintains system integrity
- Reduces database load from spam
- Encourages users to wait for working hours

## Testing Instructions

### Test Anti-Spam Activation
1. Set device time to 3:00 AM (outside working hours)
2. Send a message → See auto-reply (1/3)
3. Send another message → See auto-reply (2/3)
4. Send third message → See auto-reply (3/3)
5. Red banner appears: "Too many messages outside working hours. Cooldown: 5:00"
6. Try to type → Input field is disabled ✅
7. Try to send → Send button is greyed out ✅
8. Try camera → Camera button is greyed out ✅

### Test Cooldown Timer
1. Watch countdown: 5:00 → 4:59 → 4:58...
2. After 5 minutes → Chatbox re-enabled
3. Counter resets to 0
4. Can send messages again

### Test During Working Hours
1. Set device time to 10:00 AM
2. Send multiple messages
3. No anti-spam (only regular 2-msg rate limit)
4. No auto-replies sent

## Technical Notes

### SharedPreferences Keys
- `auto_reply_count_<chatId>`: Tracks auto-reply count
- `anti_spam_start_<chatId>`: Stores cooldown start time

### Timer Management
- `_antiSpamTimer`: Countdown timer for UI updates
- Updates every second
- Auto-cancels when cooldown expires
- Properly disposed in widget lifecycle

### State Management
- `_isInAntiSpamCooldown`: Boolean for UI state
- `_remainingAntiSpamSeconds`: For countdown display
- `_checkAntiSpamStatus()`: Called in `initState()`

## Priority Levels

1. **Anti-Spam Cooldown** (5 minutes) - Highest priority
2. **Regular Cooldown** (10 minutes) - During working hours
3. **Working Hours Check** - Always runs

If anti-spam is active, all other checks are bypassed.

---

**Status:** ✅ Complete and ready for testing
**Date:** November 13, 2025
**Configuration:**
- Max Auto-Replies: 3
- Cooldown Duration: 5 minutes
- Applies: Outside working hours only
