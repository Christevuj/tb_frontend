# Chat Bubble Auto-Reply Messages - Implementation Guide

## Overview
Auto-reply messages now appear as **chat bubbles** in the conversation (like Messenger system messages), instead of popup SnackBars.

## How It Works

### 1. **Message Flow**
When a patient/guest sends a message:
1. ✅ **User's message is sent first** and appears in the chat
2. 🤖 **System auto-reply appears as a chat bubble** if restrictions apply
3. The auto-reply explains why restrictions are in place

### 2. **Auto-Reply Triggers**

#### Outside Working Hours
```
User: "Hello, I need help"
      [Message sent successfully]

System: 🤖 Automated Reply:

        We're currently outside of working hours.
        
        Working Hours:
        Monday - Friday
        8:00 AM - 5:00 PM
        
        Your message has been received. Our health workers 
        will respond during working hours.
```

#### Message Limit Reached
```
User: "This is my 3rd message"
      [Message sent successfully]

System: 🤖 Automated Reply:

        You have reached the message limit.
        
        ⏰ Cooldown: 9 minutes, 58 seconds remaining
        
        You can send 2 messages every 10 minutes.
```

## Visual Appearance

### System Message Bubble Style
- **Sender ID**: `'system'` (special identifier)
- **Icon**: 🤖 robot emoji prefix
- **Formatting**: Multi-line with clear sections
- **Appearance**: Displayed like received messages (left-aligned, gray bubble)

### User Experience
1. User types message and taps send
2. Their message appears immediately in the chat
3. If restricted, system auto-reply bubble appears right after
4. Chat feels natural and conversational
5. No blocking popups or interruptions

## Technical Implementation

### File: `guest_healthworker_chat_screen.dart`
```dart
Future<void> _sendAutoReply(String message) async {
  try {
    await _chatService.sendTextMessage(
      senderId: 'system',              // Special system ID
      receiverId: widget.guestId,      // Send to guest
      text: '🤖 Automated Reply:\n\n$message',
      senderRole: 'system',
      receiverRole: 'guest',
    );
  } catch (e) {
    debugPrint('Error sending auto-reply: $e');
  }
}
```

### File: `chat_screen.dart`
```dart
Future<void> _sendAutoReply(String message) async {
  try {
    await _chatService.sendTextMessage(
      senderId: 'system',              // Special system ID
      receiverId: widget.currentUserId,// Send to current user
      text: '🤖 Automated Reply:\n\n$message',
      senderRole: 'system',
      receiverRole: await _chatService.getUserRole(widget.currentUserId),
    );
  } catch (e) {
    debugPrint('Error sending auto-reply: $e');
  }
}
```

## Updated Send Logic

### Before (Old Behavior)
```dart
void _send() {
  // Check restrictions BEFORE sending
  if (!canSend) {
    showSnackBar();  // ❌ Blocking popup
    clear();
    return;          // ❌ Message NOT sent
  }
  
  // Send message
  sendMessage();
}
```

### After (New Behavior)
```dart
void _send() {
  // Send user's message FIRST
  sendMessage();     // ✅ Always sent
  clear();
  
  // Then check and send auto-reply if needed
  if (!canSend) {
    sendAutoReply(); // ✅ Chat bubble appears
  }
}
```

## Key Changes

### 1. **Message Always Sent**
- User messages are no longer blocked
- Every message goes through successfully
- Better user experience - no confusion

### 2. **Auto-Reply as Conversation**
- System messages appear in chat history
- Persistent - users can scroll back and review
- More natural than popups

### 3. **No More Popups**
- Removed all `ScaffoldMessenger.showSnackBar()` calls
- No blocking dialogs
- Smoother chat experience

## Benefits

### For Users (Patients/Guests)
✅ Messages always send - no frustration  
✅ Clear feedback in conversation context  
✅ Can reference auto-replies later  
✅ Feels like chatting with a helpful bot  

### For Healthcare Workers
✅ Can see system messages in history  
✅ Understand context of user restrictions  
✅ No additional action needed  

### For System
✅ All messages logged in Firestore  
✅ Audit trail of auto-replies  
✅ Consistent message handling  

## Testing Checklist

- [ ] Send message outside working hours → See user message + auto-reply
- [ ] Send 3 messages quickly → See all messages + cooldown auto-reply
- [ ] Check chat history → Auto-replies are visible
- [ ] Healthcare worker view → Can see system messages
- [ ] Weekend test → User message sent, auto-reply appears
- [ ] Cooldown countdown → UI updates correctly
- [ ] Message counter → Shows remaining messages

## Firestore Data Structure

### System Message Example
```json
{
  "senderId": "system",
  "receiverId": "patient_123",
  "senderRole": "system",
  "receiverRole": "patient",
  "text": "🤖 Automated Reply:\n\nWe're currently outside of working hours...",
  "timestamp": 1699888888,
  "type": "text",
  "read": false
}
```

## Customization

### Change Auto-Reply Appearance
Edit the text template in `_sendAutoReply()`:
```dart
text: '🤖 Automated Reply:\n\n$message',
// Change to:
text: '⚠️ Notice:\n\n$message',
// or:
text: '[System] $message',
```

### Different Icon per Type
```dart
// Working hours
text: '⏰ Outside Office Hours:\n\n$message',

// Cooldown
text: '⏳ Please Wait:\n\n$message',
```

## Notes

- System messages use `senderId: 'system'` to distinguish from regular messages
- Auto-replies are sent AFTER user's message for better UX
- Cooldown timer and message counter still work the same
- Healthcare workers are NOT restricted and don't see auto-replies

## Previous Documentation
- See `WORKING_HOURS_CHAT_RESTRICTIONS.md` for technical details
- See `QUICK_START_CHAT_RESTRICTIONS.md` for usage guide
- See `AUTO_REPLY_MESSAGES_UPDATE.md` for SnackBar implementation (deprecated)

---

**Updated**: November 13, 2025  
**Status**: ✅ Implemented - Chat Bubble Style  
**Affects**: Patient & Guest chats with Healthcare Workers
