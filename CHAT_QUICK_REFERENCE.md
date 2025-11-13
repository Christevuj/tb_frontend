# Quick Reference: Chat & Working Hours

## 📱 Chat Behavior

### Message Flow (Like Messenger)
```
┌─────────────────────────┐
│     [Old messages]      │  ← Top
│           ↓             │
│    "Hello" (User)       │
│           ↓             │
│  🤖 Auto-reply (System) │
│           ↓             │
│    "Thanks" (User)      │
│           ↓             │
│  "Welcome" (Healthcare) │
│           ↓             │
│    [New messages]       │  ← Bottom
│                         │
│  [Type message here...] │  ← Input
└─────────────────────────┘
```

## ⏰ Working Hours Schedule

### ✅ Available (Can Chat Freely)
| Day       | Time        |
|-----------|-------------|
| Monday    | 8am - 5pm   |
| Tuesday   | 8am - 5pm   |
| Wednesday | 8am - 5pm   |
| Thursday  | 8am - 5pm   |
| Friday    | 8am - 5pm   |

### ❌ Not Available (Auto-Reply Sent)

#### Before Work Hours
- **Time**: 12am - 7:59am (before 8am)
- **Days**: Monday - Friday
- **Message**: "Health worker is not available yet. Working hours: 8:00 AM - 5:00 PM"

#### After Work Hours
- **Time**: 5:00pm - 11:59pm (after 5pm)
- **Days**: Monday - Friday
- **Message**: "Health worker is no longer available. Working hours: 8:00 AM - 5:00 PM"

#### Weekends
- **Days**: Saturday, Sunday
- **Time**: All day (24 hours)
- **Message**: "Health worker is not available at this time. Working hours: 8:00 AM - 5:00 PM"

## 🚫 Message Limits (Anti-Spam)

### Rules
- **Limit**: 2 messages per 10 minutes
- **Cooldown**: 10 minutes after limit reached
- **Applies to**: Patients & Guests only
- **Does NOT apply to**: Healthcare workers

### Example Timeline
```
8:00 AM - Message 1 sent ✅ (1/2 remaining)
8:05 AM - Message 2 sent ✅ (0/2 remaining)
8:06 AM - Message 3 blocked ⏳ (cooldown: 9 min 54 sec)
         → Auto-reply: "You have reached the message limit..."
8:15 AM - Cooldown ends ✅ (2/2 available again)
```

## 📝 Auto-Reply Format

### What User Sees (Chat Bubble)
```
┌──────────────────────────────────┐
│ 🤖 Automated Reply:              │
│                                  │
│ Health worker is not available   │
│ at this time.                    │
│                                  │
│ Working hours: 8:00 AM - 5:00 PM │
└──────────────────────────────────┘
```

### Key Features
- ✅ Appears as a chat bubble (left side)
- ✅ Shows robot emoji 🤖
- ✅ Only mentions time (not days)
- ✅ Stays in chat history
- ✅ User's message still sent first

## 🔄 What Changed

### Before (Old Behavior)
```
❌ Messages scrolled UP (newest at top)
❌ Auto-reply said "Monday-Friday, 8:00 AM - 5:00 PM"
❌ Confusing navigation
```

### After (New Behavior)
```
✅ Messages scroll DOWN (newest at bottom)
✅ Auto-reply says "8:00 AM - 5:00 PM" (time only)
✅ Natural Messenger-like experience
```

## 📊 Quick Time Check

### Current Time → Auto-Reply?

| Time      | Monday-Friday | Saturday-Sunday |
|-----------|---------------|-----------------|
| 6:00 AM   | ❌ "not yet"   | ❌ "not at time" |
| 7:30 AM   | ❌ "not yet"   | ❌ "not at time" |
| 8:00 AM   | ✅ Available   | ❌ "not at time" |
| 12:00 PM  | ✅ Available   | ❌ "not at time" |
| 4:59 PM   | ✅ Available   | ❌ "not at time" |
| 5:00 PM   | ❌ "no longer" | ❌ "not at time" |
| 10:00 PM  | ❌ "no longer" | ❌ "not at time" |

## 💡 Testing Tips

1. **Test Message Flow**
   - Send message → Should appear at bottom
   - Scroll down → Should see newest messages
   - Keyboard opens → Chat adjusts naturally

2. **Test Working Hours**
   - Send at 7am → Auto-reply: "not available yet"
   - Send at 6pm → Auto-reply: "no longer available"
   - Send on Saturday → Auto-reply: "not available at this time"

3. **Test Message Limits**
   - Send 2 messages quickly → Both go through
   - Send 3rd message → Auto-reply about cooldown
   - Wait 10 minutes → Can send again

4. **Verify Auto-Reply**
   - Check it's a chat bubble (not popup)
   - Check it says "8:00 AM - 5:00 PM" (no days)
   - Check it has 🤖 emoji
   - Check user's message appears first

---

**Last Updated**: November 13, 2025  
**Status**: ✅ Ready for Testing
