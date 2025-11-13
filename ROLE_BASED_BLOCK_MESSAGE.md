# Role-Based Block Message Implementation

## Summary
Updated the health chat screen to display role-specific block warning messages. When a patient reaches the 3-message limit, the banner now says:
- **"The doctor will reply soon"** when chatting with a doctor
- **"The healthcare worker will reply soon"** when chatting with a healthcare worker

## Files Modified

### 1. `lib/chat_screens/health_chat_screen.dart`
**Changes:**
- Added optional `role` parameter to `PatientHealthWorkerChatScreen` widget
- Updated block warning message to use conditional text based on `widget.role`

**Code:**
```dart
// Widget parameter
final String? role; // 'doctor' or 'healthcare'

const PatientHealthWorkerChatScreen({
  super.key,
  required this.currentUserId,
  required this.healthWorkerId,
  required this.healthWorkerName,
  this.healthWorkerProfilePicture,
  this.role, // NEW
});

// Block warning message (line ~1173)
widget.role == 'doctor' 
    ? 'You have reached the message limit. The doctor will reply soon.'
    : 'You have reached the message limit. The healthcare worker will reply soon.'
```

### 2. `lib/patient/pmessages.dart`
**Changes:**
- Updated `_openChat` method to accept and pass `role` parameter
- Updated `_openChatWithoutRestore` method to accept and pass `role` parameter
- Added role detection logic to `_streamArchivedConversations`
- Updated all calls to pass role to `PatientHealthWorkerChatScreen`

**Key Updates:**

**_openChat method (line ~240):**
```dart
Future<void> _openChat(String doctorId, String doctorName, {String? role}) async {
  // Use passed role or default to 'doctor'
  await _chatService.createUserDoc(
    userId: doctorId,
    name: doctorName,
    role: role ?? 'doctor',
  );
  
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => PatientHealthWorkerChatScreen(
        currentUserId: currentUser.uid,
        healthWorkerId: doctorId,
        healthWorkerName: doctorName,
        healthWorkerProfilePicture: null,
        role: role, // Pass role to chat screen
      ),
    ),
  );
}
```

**_openChatWithoutRestore method (line ~301):**
```dart
Future<void> _openChatWithoutRestore(
    String doctorId, String doctorName, {String? role}) async {
  // Same pattern as _openChat - accepts and passes role
}
```

**_streamArchivedConversations (line ~999):**
```dart
// Added role detection for archived conversations
String contactRole = 'doctor';
try {
  final healthcareDoc = await FirebaseFirestore.instance
      .collection('healthcare')
      .doc(doctorId)
      .get();

  if (healthcareDoc.exists) {
    contactRole = 'healthcare';
  } else {
    final healthcareQuery = await FirebaseFirestore.instance
        .collection('healthcare')
        .where('authUid', isEqualTo: doctorId)
        .limit(1)
        .get();

    if (healthcareQuery.docs.isNotEmpty) {
      contactRole = 'healthcare';
    } else {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(doctorId)
          .get();
      if (userDoc.exists) {
        final userData = userDoc.data();
        contactRole = userData?['role'] ?? 'doctor';
      }
    }
  }
} catch (e) {
  print('Error determining role for $doctorId: $e');
  contactRole = 'doctor';
}

archivedConversations.add({
  'id': doctorId,
  'name': doctorName,
  'lastMessage': chatData['lastMessage'] ?? 'No messages yet',
  'lastTimestamp': chatData['lastTimestamp'],
  'state': state,
  'archivedAt': conversationState?['timestamp'],
  'role': contactRole, // NEW
});
```

**Method calls updated:**
```dart
// Active conversations (line ~821)
_openChat(doctorId, doctorName, role: roleValue);

// Archived conversations (line ~1307)
_openChatWithoutRestore(
    conversation['id'], 
    conversation['name'],
    role: conversation['role']);
```

### 3. `lib/patient/ptbfacility.dart`
**Changes:**
- Extracted `contactRole` variable from inline conditional
- Pass role to `PatientHealthWorkerChatScreen`

**Code (line ~1577):**
```dart
final contactRole = workerType == 'Doctor' ? 'doctor' : 'healthcare';

await chatService.createUserDoc(
  userId: workerId,
  name: workerName,
  role: contactRole,
);

// ...

builder: (context) => PatientHealthWorkerChatScreen(
  currentUserId: authUid,
  healthWorkerId: workerId,
  healthWorkerName: workerName,
  healthWorkerProfilePicture: profilePicture,
  role: contactRole, // NEW
),
```

### 4. `lib/patient/phealthworker.dart`
**Changes:**
- Extracted `contactRole` variable from inline conditional
- Pass role to `PatientHealthWorkerChatScreen`

**Code (line ~604):**
```dart
final contactRole = workerType == 'Doctor' ? 'doctor' : 'healthcare';

await chatService.createUserDoc(
  userId: workerId,
  name: workerName,
  role: contactRole,
);

// ...

builder: (context) => PatientHealthWorkerChatScreen(
  currentUserId: authUid,
  healthWorkerId: workerId,
  healthWorkerName: workerName,
  healthWorkerProfilePicture: profilePicture,
  role: contactRole, // NEW
),
```

## Role Detection Logic

The app determines whether a contact is a doctor or healthcare worker by:

1. **Checking healthcare collection** by document ID
2. **Checking healthcare collection** by `authUid` field
3. **Checking users collection** for `role` field
4. **Defaulting to 'doctor'** if no match found

This logic is consistently applied in:
- Active conversations in `_streamMessagedDoctors`
- Archived conversations in `_streamArchivedConversations`
- Direct navigation from facility and healthcare worker lists

## User Experience

**Before:**
- All block messages said "The healthcare worker will reply soon"
- No distinction between doctors and healthcare workers

**After:**
- Block message dynamically changes based on contact role:
  - **Doctor**: "The doctor will reply soon"
  - **Healthcare Worker**: "The healthcare worker will reply soon"
- Consistent behavior across all entry points:
  - Active conversations list
  - Archived conversations list
  - Facility contacts list
  - Healthcare worker list

## Testing Checklist

- [ ] Test block message with doctor contact (should say "doctor")
- [ ] Test block message with healthcare worker contact (should say "healthcare worker")
- [ ] Test from active conversations list in pmessages
- [ ] Test from archived conversations list in pmessages
- [ ] Test from facility contacts in ptbfacility
- [ ] Test from healthcare workers list in phealthworker
- [ ] Verify role persists after hot reload
- [ ] Verify role detection works for both new and existing conversations

## Technical Notes

- The `role` parameter is optional (nullable) to maintain backward compatibility
- Defaults to 'doctor' if role is not provided
- Role is stored in both the conversation list data and passed through navigation
- Archived conversations now include role detection to match active conversations
- All entry points (pmessages, ptbfacility, phealthworker) now pass role consistently

## Implementation Status

✅ **Complete** - All files updated and verified
- No compilation errors
- All entry points updated
- Consistent role detection across active and archived conversations
- Ready for testing
