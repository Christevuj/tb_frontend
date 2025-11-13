# Message Refresh Counter Bug - FIXED ✅

## Problem
The message counter was resetting every time messages refreshed, including when the patient sent their own messages. This caused:
1. **Counter refreshing constantly** - Every new message triggered a reset
2. **Block status resetting when navigating back** - Counter would reset when reopening chat
3. **Incorrect block detection** - System thought healthcare worker replied when patient sent messages

## Root Cause
The `_listenToHealthWorkerReplies()` method was listening to the message stream and checking if the **last message** was from the healthcare worker. The problem:

```dart
// OLD CODE - BUG
void _listenToHealthWorkerReplies() {
  _messageSubscription = _chatService
      .getMessages(widget.guestId, widget.healthWorkerId)
      .listen((messages) async {
    if (messages.isNotEmpty) {
      final lastMessage = messages.first;
      // This fires EVERY TIME any message is added!
      if (lastMessage.senderId == widget.healthWorkerId) {
        // Reset happens on EVERY refresh if last message was from healthcare
        await WorkingHoursService.resetPatientMessageCount(_chatId);
        _checkBlockStatus();
      }
    }
  });
}
```

### Why It Failed:
- Stream fires **every time** the message list updates
- When patient sends message → stream fires → checks last message
- If last message was from healthcare worker (from before), it **resets again**
- Result: Counter never increments properly

## Solution
Track the **last processed healthcare worker message ID** to avoid processing the same message multiple times:

```dart
// NEW CODE - FIXED
String? _lastProcessedMessageId; // Track last healthcare worker message

void _listenToHealthWorkerReplies() {
  _messageSubscription = _chatService
      .getMessages(widget.guestId, widget.healthWorkerId)
      .listen((messages) async {
    if (messages.isNotEmpty) {
      final lastMessage = messages.first;
      
      // Only reset if this is a NEW healthcare worker message we haven't processed yet
      if (lastMessage.senderId == widget.healthWorkerId &&
          lastMessage.id != _lastProcessedMessageId) {
        debugPrint('🔓 Healthcare worker sent new message - resetting block');
        _lastProcessedMessageId = lastMessage.id; // Mark as processed
        
        // Healthcare worker replied - reset block
        await WorkingHoursService.resetPatientMessageCount(_chatId);
        _checkBlockStatus();
      }
    }
  });
}
```

### How It Works:
1. **First healthcare worker message**: 
   - `lastMessage.id != _lastProcessedMessageId` (null) → ✅ Reset
   - Store message ID in `_lastProcessedMessageId`

2. **Patient sends message**:
   - Stream fires again
   - Last message is healthcare worker's message (still)
   - `lastMessage.id == _lastProcessedMessageId` → ❌ Don't reset (already processed)

3. **Healthcare worker sends NEW message**:
   - Stream fires
   - Last message is NEW healthcare worker message
   - `lastMessage.id != _lastProcessedMessageId` (different ID) → ✅ Reset
   - Update `_lastProcessedMessageId` to new ID

4. **Auto-reply sent (outside working hours)**:
   - Stream fires
   - Last message starts with '🤖 Automated Reply:'
   - `lastMessage.text.startsWith('🤖 Automated Reply:')` → ❌ Don't reset (it's automated)
   - Auto-replies don't count as real healthcare worker responses

## Files Modified

### 1. `lib/chat_screens/guest_healthworker_chat_screen.dart`
**Added:**
```dart
String? _lastProcessedMessageId; // Track last healthcare worker message
```

**Updated:**
```dart
void _listenToHealthWorkerReplies() {
  _messageSubscription = _chatService
      .getMessages(widget.guestId, widget.healthWorkerId)
      .listen((messages) async {
    if (messages.isNotEmpty) {
      final lastMessage = messages.first;
      
      // Exclude auto-reply messages from triggering reset
      if (lastMessage.senderId == widget.healthWorkerId &&
          lastMessage.id != _lastProcessedMessageId &&
          !lastMessage.text.startsWith('🤖 Automated Reply:')) {
        debugPrint('🔓 Healthcare worker sent new message - resetting block');
        _lastProcessedMessageId = lastMessage.id;
        
        await WorkingHoursService.resetPatientMessageCount(_chatId);
        _checkBlockStatus();
      }
    }
  });
}
```

### 2. `lib/chat_screens/chat_screen.dart`
Applied identical changes as above.

## Testing Results ✅

### Test 1: Message Counter Persistence
- ✅ Patient sends message → Counter decrements correctly
- ✅ Patient sends another message → Counter continues decrementing
- ✅ Counter doesn't reset on message list refresh

### Test 2: Navigation Persistence
- ✅ Patient sends 2 messages → Counter shows "1 remaining"
- ✅ Navigate back to chat list
- ✅ Return to chat → Counter still shows "1 remaining" (persists!)

### Test 3: Healthcare Worker Reply Detection
- ✅ Patient sends 3 messages → Blocked
- ✅ Healthcare worker sends reply → Block released
- ✅ Counter resets to 3
- ✅ Patient can send messages again

### Test 4: Auto-Reply Still Works
- ✅ Messages sent outside working hours
- ✅ Auto-reply message sent correctly
- ✅ Auto-reply doesn't affect block count

## Debug Output
You can now see when the reset happens:
```
🔓 Healthcare worker sent new message - resetting block
```

This will only appear when healthcare worker sends a **NEW** message, not on every refresh.

## Technical Details

### Message Object Structure
```dart
class Message {
  final String id;          // Unique message ID
  final String senderId;    // Who sent it
  final String receiverId;  // Who receives it
  final String text;
  final DateTime timestamp;
  // ... other fields
}
```

### SharedPreferences Keys (Unchanged)
```dart
'msg_count_$chatId'        // Patient message count (0-3)
'block_status_$chatId'     // Block status (true/false)
```

### Stream Behavior
Firebase Firestore streams emit a new event whenever:
- New message added
- Message updated
- Message deleted
- App regains connection
- Screen is reopened

The fix ensures we only process **new** healthcare worker messages, not existing ones on every refresh.

## Impact
✅ **No more false resets** - Counter only resets when healthcare worker actually replies
✅ **Proper persistence** - Block status maintained across app navigation
✅ **Accurate blocking** - Patient correctly blocked after 3 messages
✅ **Clean debug logs** - Only see reset message when it actually happens

---
**Fix Date**: January 2025
**Bug Severity**: High (core functionality broken)
**Fix Complexity**: Low (added message ID tracking)
**Status**: ✅ RESOLVED
