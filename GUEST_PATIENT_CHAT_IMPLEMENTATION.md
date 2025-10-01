# Guest-Patient Chat Implementation

## Overview
This document describes the implementation of a chat system between healthcare workers (guest users) and patients, similar to the existing patient-healthcare worker chat functionality.

## Implementation Date
October 1, 2025

## Files Created/Modified

### 1. New File: `guest_chat_screen.dart`
**Location:** `lib/chat_screens/guest_chat_screen.dart`

**Purpose:** Dedicated chat screen for healthcare workers (acting as guests) to communicate with patients.

**Key Features:**
- Real-time messaging using Firestore
- Modern UI with gradient header
- Online/offline status indicators
- Message timestamps with detailed time formatting
- Date separators for message organization
- Delete conversation functionality
- Profile picture support
- Responsive message bubbles

**Main Components:**
- `GuestPatientChatScreen`: Main chat widget
- `_MessageBubble`: Reusable message bubble component

### 2. Updated File: `ghealthworkers.dart`
**Location:** `lib/guest/ghealthworkers.dart`

**Changes Made:**
- **Added Message Button:** Replaced the old placeholder message button with a fully functional one
- **Added `_handleMessageTap` method:** Shows a dialog informing guest users that they need to log in to message health workers
- **Improved UI:** Updated the message button to match the style of `phealthworkers.dart`

**Key Changes:**
```dart
// New message button with proper handler
ElevatedButton.icon(
  onPressed: () => _handleMessageTap(...),
  icon: const Icon(Icons.message_rounded, size: 16),
  label: Text('Message ${type == 'Doctor' ? 'Doctor' : 'Health Worker'}'),
  ...
)

// Handler method that shows login required dialog for guests
Future<void> _handleMessageTap(...) async {
  showDialog(...); // Shows "Login Required" message
}
```

### 3. Updated File: `gmessages.dart`
**Location:** `lib/guest/gmessages.dart`

**Changes Made:**
- **Complete Rewrite:** Replaced demo data with real Firestore integration
- **Firebase Integration:** Added Firebase Auth and Firestore for real-time chat data
- **ChatService Integration:** Uses the existing `ChatService` for managing conversations
- **Real-time Streaming:** Implemented `_streamMessagedPatients()` to display active conversations
- **Search Functionality:** Enhanced search to work with real data
- **Navigation:** Opens `GuestPatientChatScreen` when a conversation is tapped

**Key Features:**
- User authentication and profile management
- Real-time conversation list
- Profile picture display
- Role-based badges (Patient, Doctor, Health Worker)
- Last message and timestamp display
- Search and filter conversations
- Modern UI with Material Design 3 elements

**Key Methods:**
- `_getCurrentUserDetails()`: Fetches current healthcare worker info
- `_resolveCurrentUserName()`: Resolves user name from multiple sources
- `_getPatientName()`: Fetches patient names for conversations
- `_openChat()`: Opens the guest-patient chat screen
- `_streamMessagedPatients()`: Streams real-time conversation data
- `_formatTimeDetailed()`: Formats timestamps in a user-friendly way

### 4. File: `hlanding_page.dart`
**Location:** `lib/healthcare/hlanding_page.dart`

**Status:** No changes required - already properly configured to receive messages from patients and guests. The existing implementation handles all message routing correctly.

## Data Flow

### Guest (Healthcare Worker) → Patient Message Flow
1. Healthcare worker views list in `gmessages.dart`
2. Taps on a patient conversation
3. `_openChat()` method is called
4. Creates/ensures user documents in Firestore
5. Opens `GuestPatientChatScreen` with proper IDs
6. Messages are sent via `ChatService.sendTextMessage()`
7. Messages are stored in Firestore `chats` collection
8. Real-time listeners update both participants' screens

### Patient → Guest (Healthcare Worker) Message Flow
1. Patient messages healthcare worker from their interface
2. Message is stored in Firestore `chats` collection
3. Healthcare worker's `gmessages.dart` receives update via stream
4. Conversation appears in healthcare worker's message list
5. Healthcare worker can tap to open `GuestPatientChatScreen`
6. Two-way communication is established

## Firestore Collections Used

### `chats` Collection
```
chats/{chatId}/
  ├── participants: [guestId, patientId]
  ├── lastMessage: "Latest message text"
  ├── lastTimestamp: Timestamp
  └── messages (subcollection)
      └── {messageId}/
          ├── senderId: string
          ├── receiverId: string
          ├── text: string
          ├── timestamp: Timestamp
          └── isRead: boolean
```

### `users` Collection
```
users/{userId}/
  ├── name: string
  ├── firstName: string (optional)
  ├── lastName: string (optional)
  ├── email: string
  ├── role: "healthcare" | "patient" | "doctor"
  ├── profilePicture: string (optional)
  └── lastSeen: Timestamp
```

## UI/UX Features

### Guest Chat Screen (`guest_chat_screen.dart`)
- **Modern gradient header** with red accent colors
- **Profile avatars** with online status indicators
- **Message bubbles** with smooth animations
- **Timestamp toggles** - tap message to show/hide detailed time
- **Date separators** for easy navigation
- **Delete conversation** option in menu
- **Responsive design** adapts to screen size
- **Keyboard handling** with proper text input

### Messages List (`gmessages.dart`)
- **Search bar** for filtering conversations
- **Real-time updates** as new messages arrive
- **Role badges** showing user type (Patient/Doctor/Health Worker)
- **Last message preview** with truncation
- **Timestamp formatting** showing relative time
- **Empty state** with helpful message
- **Loading states** with progress indicators
- **Error handling** with user-friendly messages

## Integration Points

### With Existing Chat System
- Uses the same `ChatService` as other chat implementations
- Compatible with `PresenceService` for online/offline status
- Follows same message structure as `health_chat_screen.dart`
- Consistent UI/UX patterns across all chat screens

### With Firebase
- Firebase Authentication for user identification
- Cloud Firestore for real-time data sync
- Firestore security rules apply (ensure proper configuration)
- Presence tracking via Firestore

## Security Considerations

1. **Authentication Required:** Users must be authenticated to access chat features
2. **User Verification:** User IDs are verified before opening chats
3. **Data Validation:** Input is validated before sending messages
4. **Role-Based Access:** Only authorized users can access their conversations
5. **Error Handling:** Comprehensive error handling prevents crashes

## Testing Checklist

- [x] Healthcare worker can view conversation list
- [x] Healthcare worker can open existing conversations
- [x] Healthcare worker can send messages to patients
- [x] Healthcare worker can receive messages from patients
- [x] Real-time updates work correctly
- [x] Search functionality filters conversations
- [x] Profile pictures display correctly
- [x] Online/offline status updates
- [x] Timestamps format correctly
- [x] Delete conversation works
- [x] Error states display properly
- [x] Empty states display properly
- [x] Guest message button shows login required dialog

## Future Enhancements

1. **Media Sharing:** Add support for images and files
2. **Push Notifications:** Notify users of new messages
3. **Message Read Receipts:** Show when messages are read
4. **Typing Indicators:** Show when the other person is typing
5. **Message Reactions:** Add emoji reactions to messages
6. **Voice Messages:** Support audio message recording
7. **Message Search:** Search within conversation history
8. **Archive Conversations:** Hide conversations without deleting
9. **Bulk Actions:** Select and delete multiple conversations
10. **Message Forwarding:** Forward messages to other users

## Notes

- The guest chat system uses the same chat ID generation as other chat implementations for consistency
- Healthcare workers in `gmessages.dart` can chat with any patients who message them
- The system automatically creates user documents if they don't exist
- All timestamps are timezone-aware and format based on device settings
- The UI follows Material Design 3 principles for modern appearance

## Troubleshooting

### Messages not appearing
- Check Firestore security rules
- Verify user authentication
- Check network connection
- Verify chat ID generation

### Online status not updating
- Ensure `PresenceService` is properly configured
- Check Firestore connection
- Verify user ID is correct

### Profile pictures not loading
- Check image URL validity
- Verify network permissions
- Check Firestore data structure

## Related Files

- `lib/services/chat_service.dart` - Core chat functionality
- `lib/services/presence_service.dart` - Online/offline tracking
- `lib/models/message.dart` - Message data model
- `lib/chat_screens/health_chat_screen.dart` - Patient-Healthcare chat (reference)
- `lib/patient/phealthworker.dart` - Patient view (reference)
- `lib/healthcare/hlanding_page.dart` - Healthcare worker landing page
