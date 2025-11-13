# Auto-Reply Debugging Guide

## When Auto-Reply SHOULD Appear

### ✅ Outside Working Hours
**Time**: Before 8:00 AM or After 5:00 PM (Monday-Friday)
**Time**: Any time on Saturday/Sunday

**Your screenshot shows**: 2:43 PM (Wednesday)
**Result**: This is WITHIN working hours (8AM-5PM), so **NO auto-reply should appear** ✅

### ✅ After Message Limit (During Working Hours)
**Condition**: After sending 2 messages within 10 minutes
**Message**: "You have reached the message limit..."

## Current Situation

Based on your screenshot showing **2:43 PM**, the auto-reply is working correctly by **NOT** appearing because:
- It's Wednesday (weekday) ✅
- Time is 2:43 PM (between 8AM-5PM) ✅
- Therefore: Within working hours = No auto-reply needed ✅

## Testing Auto-Reply

### Test 1: Weekend Message
**When**: Send message on Saturday or Sunday (any time)
**Expected**: Should get auto-reply: "Health worker is not available at this time. Working hours: 8:00 AM - 5:00 PM"

### Test 2: After Hours (Weekday)
**When**: Send message after 5:00 PM or before 8:00 AM
**Expected**: Should get auto-reply about working hours

### Test 3: Message Limit (During Hours)
**When**: Send 3 messages quickly between 8AM-5PM on a weekday
**Expected**: 
- Message 1: Sent ✅
- Message 2: Sent ✅
- Message 3: Auto-reply about cooldown

## Debug Logs to Check

Look for these in your terminal/console:

```
🕐 Working Hours Check:
   Current time: 2025-11-13 14:43:00.000
   Is within working hours: true
   ✅ WITHIN working hours - continuing to cooldown check
```

If you see `Is within working hours: true`, then auto-reply **correctly** doesn't appear.

## How to Force Auto-Reply for Testing

### Option 1: Change Device Time
1. Go to Settings → Date & Time
2. Disable "Automatic"
3. Set time to 7:00 PM
4. Send message → Should get auto-reply

### Option 2: Send 3 Messages Quickly
1. Send "test 1" → No auto-reply
2. Send "test 2" → No auto-reply
3. Send "test 3" → Should get cooldown auto-reply

### Option 3: Test on Weekend
Wait until Saturday/Sunday and send message

### Option 4: Temporarily Change Hours in Code
Edit `working_hours_service.dart`:
```dart
// Temporarily change to always trigger auto-reply
static bool isWithinWorkingHours() {
  return false; // Force to always be outside hours
}
```

## Checking Debug Output

### Run with logs:
```bash
flutter run
```

### Look for:
```
🕐 Working Hours Check:
   Current time: 2025-11-13 14:43:00.000
   Is within working hours: true/false
   ⚠️ OUTSIDE working hours - sending auto-reply
   OR
   ✅ WITHIN working hours - continuing to cooldown check
```

### If sending auto-reply:
```
🤖 Sending auto-reply message...
   From: system
   To: guest_123
   Message: 🤖 Automated Reply:
           Health worker is not available...
   ✅ Auto-reply sent successfully
```

## Quick Test Script

Current time: **2:43 PM Wednesday**

| Condition | Should Auto-Reply? | Why |
|-----------|-------------------|-----|
| 2:43 PM Wed | ❌ NO | Within hours (8AM-5PM) |
| 7:00 AM Wed | ✅ YES | Before 8AM |
| 6:00 PM Wed | ✅ YES | After 5PM |
| 10:00 AM Sat | ✅ YES | Weekend |
| 3rd msg in 10min | ✅ YES | Cooldown triggered |

## What's Working Correctly

If at 2:43 PM on Wednesday you're NOT seeing an auto-reply, that's **CORRECT BEHAVIOR** ✅

The system is working as designed:
- Within hours → No auto-reply
- Outside hours → Auto-reply appears

## If You Want to See Auto-Reply NOW

Change the time to test:
```dart
// In working_hours_service.dart - FOR TESTING ONLY
static const int workingHourStart = 15; // 3 PM (will be outside hours at 2:43 PM)
static const int workingHourEnd = 17;    // 5 PM
```

Or wait until after 5:00 PM today.

---

**Current Status**: System is working correctly ✅  
**At 2:43 PM Wednesday**: No auto-reply is expected (within working hours)  
**To test**: Send message after 5 PM or on weekend
