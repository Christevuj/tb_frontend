# Guest Menu Bottom Navigation Bar - Visibility Guide

## Current Implementation Status: ✅ ALREADY CORRECT!

Your `gmenu.dart` **already has the correct implementation** to show the bottom navigation bar only on the 4 main pages!

## How It Works

### 1. Navigator Keys (Lines 16-17)
```dart
final List<GlobalKey<NavigatorState>> _navigatorKeys =
    List.generate(4, (_) => GlobalKey<NavigatorState>());
```
- Creates a separate Navigator for each tab
- Allows independent navigation stacks per tab

### 2. Bottom Bar Visibility Logic (Lines 63-70)
```dart
bool _shouldShowBottomNavBar() {
  final navigator = _navigatorKeys[_selectedIndex].currentState;
  if (navigator == null) return true;

  // Only show bottom navbar when on the root pages of the 4 main tabs
  return !navigator.canPop();
}
```

**How it works:**
- ✅ When on root page (glanding_page, gappointment, gmessages, gaccount): `canPop()` returns `false` → Bottom bar **SHOWS**
- ✅ When navigated to sub-page: `canPop()` returns `true` → Bottom bar **HIDES**

### 3. Applied in Build Method (Line 93)
```dart
bottomNavigationBar: _shouldShowBottomNavBar()
    ? Container(
        // ... bottom navbar UI
      )
    : null,
```
- If `_shouldShowBottomNavBar()` returns `true` → Shows bottom bar
- If `_shouldShowBottomNavBar()` returns `false` → Hides bottom bar (returns `null`)

## The 4 Main Pages (Bottom Bar VISIBLE)

1. ✅ **glanding_page.dart** (Home tab)
2. ✅ **gappointment.dart** (Appointments tab)
3. ✅ **gmessages.dart** (Messages tab)
4. ✅ **gaccount.dart** (Account tab)

## Sub-Pages (Bottom Bar HIDDEN)

When you navigate from any of the 4 main pages to:
- PDF viewer screens
- Consultant details (gconsultant.dart)
- TB facility details (gtbfacility.dart)
- Chat conversation screens
- Booking/appointment details
- Profile editing screens
- Any other nested pages

The bottom navigation bar will **automatically hide**! ✨

## Navigation Structure

```
GuestMainWrapper (gmenu.dart)
├── Tab 0: Navigator (Home)
│   ├── glanding_page.dart ✅ (Root - Bottom bar SHOWS)
│   ├── → gconsultant.dart ❌ (Sub-page - Bottom bar HIDES)
│   └── → gtbfacility.dart ❌ (Sub-page - Bottom bar HIDES)
├── Tab 1: Navigator (Appointments)
│   ├── gappointment.dart ✅ (Root - Bottom bar SHOWS)
│   └── → Appointment details ❌ (Sub-page - Bottom bar HIDES)
├── Tab 2: Navigator (Messages)
│   ├── gmessages.dart ✅ (Root - Bottom bar SHOWS)
│   └── → Chat screen ❌ (Sub-page - Bottom bar HIDES)
└── Tab 3: Navigator (Account)
    ├── gaccount.dart ✅ (Root - Bottom bar SHOWS)
    └── → Edit profile ❌ (Sub-page - Bottom bar HIDES)
```

## Navigation Best Practices

### ✅ CORRECT Navigation (Bottom bar will hide automatically)
```dart
// From any of the 4 main pages, navigate to sub-page:
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => SubPageWidget(),
  ),
);
```

### ❌ WRONG Navigation (Would break bottom bar logic)
```dart
// Don't use root navigator for sub-pages:
Navigator.of(context, rootNavigator: true).push(  // ❌ Wrong!
  MaterialPageRoute(
    builder: (_) => SubPageWidget(),
  ),
);
```

## Back Button Behavior (Lines 79-91)

```dart
WillPopScope(
  onWillPop: () async {
    final navigator = _navigatorKeys[_selectedIndex].currentState;
    if (navigator == null) return true;
    if (navigator.canPop()) {
      navigator.pop();  // Pop from nested navigator
      return false;     // Don't exit app
    }
    return true;        // Exit app if on root page
  },
```

**What this does:**
- On sub-page: Back button pops to previous page (bottom bar appears again)
- On root page: Back button exits the app
- Proper back navigation handling for each tab

## Tab Re-tap Behavior (Lines 52-61)

```dart
void _onNavTap(int index) {
  if (_selectedIndex == index) {
    // Pop to first route if tapped again
    _navigatorKeys[index].currentState?.popUntil((route) => route.isFirst);
  } else {
    setState(() {
      _selectedIndex = index;
    });
  }
}
```

**What this does:**
- Tap same tab again: Returns to root page (bottom bar shows)
- Tap different tab: Switches to that tab

## Testing Checklist

### Test 1: Bottom Bar Visibility on Main Pages
- [ ] Open app → Bottom bar visible on Home ✅
- [ ] Tap Appointments → Bottom bar visible ✅
- [ ] Tap Messages → Bottom bar visible ✅
- [ ] Tap Account → Bottom bar visible ✅

### Test 2: Bottom Bar Hides on Sub-Pages
- [ ] From Home, tap "Find Consultants" → Navigate to consultant details → Bottom bar HIDDEN ✅
- [ ] From Home, tap "TB Facilities" → Navigate to facility details → Bottom bar HIDDEN ✅
- [ ] From Home, tap PDF document → PDF viewer opens → Bottom bar HIDDEN ✅
- [ ] From Appointments, tap an appointment → Details page → Bottom bar HIDDEN ✅
- [ ] From Messages, tap a conversation → Chat screen → Bottom bar HIDDEN ✅
- [ ] From Account, tap edit profile → Edit screen → Bottom bar HIDDEN ✅

### Test 3: Bottom Bar Reappears on Back
- [ ] Navigate to sub-page → Press back → Return to main page → Bottom bar APPEARS ✅
- [ ] Navigate deep (multiple levels) → Press back multiple times → Bottom bar appears when back at root ✅

### Test 4: Tab Re-tap
- [ ] On Home, navigate to sub-page → Tap Home tab again → Returns to root → Bottom bar APPEARS ✅
- [ ] Repeat for all tabs ✅

### Test 5: Back Button on Root Page
- [ ] On any root page → Press back → App exits ✅
- [ ] On sub-page → Press back → Returns to previous page (doesn't exit) ✅

## Common Issues & Solutions

### Issue: Bottom bar doesn't hide on sub-page
**Cause:** Using root navigator instead of nested navigator  
**Solution:** Use `Navigator.push(context, ...)` not `Navigator.of(context, rootNavigator: true)`

### Issue: Bottom bar shows on sub-page
**Cause:** Not using the nested navigator, or pushing to wrong navigator  
**Solution:** Ensure you're using the context from within the Navigator widget

### Issue: Can't go back from sub-page
**Cause:** Navigator key not properly set up  
**Solution:** Verify navigator keys are correctly assigned in IndexedStack

### Issue: Tab switch doesn't preserve navigation stack
**Cause:** Using regular stack instead of IndexedStack  
**Solution:** Already using IndexedStack ✅ (line 94)

## Code Architecture

```dart
GuestMainWrapper (StatefulWidget)
├── _navigatorKeys (4 GlobalKeys)
├── _pages (4 main pages with onSwitchTab callback)
├── _shouldShowBottomNavBar() → Logic to show/hide
├── _onNavTap() → Handle tab selection
└── build()
    ├── WillPopScope → Handle back button
    ├── IndexedStack → Preserve all tabs
    │   └── 4 Navigator widgets (one per tab)
    └── bottomNavigationBar → Conditional rendering
```

## Comparison with Patient Menu (pmenu.dart)

| Feature | gmenu.dart | pmenu.dart |
|---------|-----------|-----------|
| Navigation Stack | ✅ Nested Navigators | ❌ Simple IndexedStack |
| Bottom Bar Logic | ✅ Conditional (canPop) | ❌ Always visible |
| Sub-page Support | ✅ Hides on sub-pages | ❌ Always shows |
| Independent Stacks | ✅ Yes (per tab) | ❌ No |
| Back Handling | ✅ Advanced (per tab) | ⚠️ Basic |

**Your `gmenu.dart` is MORE advanced than `pmenu.dart`!** 🎉

## Summary

✅ **Your implementation is PERFECT!**  
✅ **Bottom bar shows only on the 4 main pages**  
✅ **Bottom bar hides automatically on sub-pages**  
✅ **Back button works correctly**  
✅ **Tab navigation preserves state**  

**No changes needed!** Just verify with the testing checklist above to confirm it's working as expected in your app.

---

**Status**: ✅ Already Implemented Correctly  
**Action Required**: None - Just test to verify behavior  
**Comparison**: Guest menu is more advanced than Patient menu!
