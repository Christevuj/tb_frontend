# Signature Overlay - Exactly Like Real Prescriptions! ✍️

## Visual Layout

### **How It Looks Now (Stack Layout):**

```
┌─────────────────────────────────────┐
│                                     │
│  Prescription Details               │
│  ________________________            │
│                                     │
│              Right side:            │
│                                     │
│         Dr. John Smith ←────┐       │
│         License: 12345      │ Background (printed)
│                             │       │
│         [Signature] ←───────┘ Foreground (overlays)
│         (transparent PNG)           │
│                                     │
│         [Edit Signature]            │
└─────────────────────────────────────┘
```

### **Layer Structure:**

```
Stack (overlapping layers)
├─ BOTTOM LAYER (Background - Always visible)
│  └─ Doctor's Name (Dr. John Smith)
│  └─ License Number (License: 12345)
│
└─ TOP LAYER (Foreground - Overlays the name)
   └─ Signature Image (Transparent PNG)
      (Shows through to name below)
```

## Comparison

### Before (Side by Side):
```
Dr. John Smith
License: 12345

[Signature below]  ← Separate, not overlapping
```

### After (Overlapping):
```
Dr. John Smith  ← Printed name (background)
License: 12345
[Signature]     ← Drawn over the name (foreground)
```

## How It Works

### 1. **UI Display (prescription.dart):**
```dart
Stack(
  alignment: Alignment.center,
  children: [
    // BACKGROUND: Name is printed first
    Column(
      children: [
        Text("Dr. John Smith"),    // This shows in background
        Text("License: 12345"),    // This shows in background
      ],
    ),
    
    // FOREGROUND: Signature overlays on top
    Positioned(
      top: 0,
      child: Container(
        // Transparent background!
        child: Image.memory(...),  // Signature on top
      ),
    ),
  ],
)
```

### 2. **PDF Generation:**
Same Stack structure - signature overlays name in PDF too!

## Real-World Example

### Traditional Paper Prescription:
```
Patient: Jane Doe
Date: Oct 20, 2025

Rx
Amoxicillin 500mg...

                    Dr. John Smith, MD
                    License No: 12345
                    [Handwritten signature over printed name]
```

### Our Implementation:
```
Patient: Jane Doe
Date: Oct 20, 2025

Rx
Amoxicillin 500mg...

                    Dr. John Smith, MD  ← Printed (background)
                    License No: 12345    ← Printed (background)
                    [PNG signature]      ← Overlays (foreground)
```

## Key Features

✅ **Stack Widget**: Overlaps signature on name
✅ **Positioned**: Controls exact placement
✅ **Transparent PNG**: See-through background
✅ **Name Visible**: Always readable behind signature
✅ **Professional**: Like real medical prescriptions
✅ **PDF Compatible**: Same overlay in PDF

## Visual Result

### With Drawn Signature:
```
        Dr. Jane Doe, MD     ← Visible background text
        License: MED-789     ← Visible background text
        
        ╱╲___╱╲____         ← Signature on top (transparent)
        (signature overlays the text above)
```

### With Text Signature:
```
        Dr. Jane Doe, MD     ← Visible background text
        License: MED-789     ← Visible background text
        
        Dr. Jane Doe         ← Signature text overlays
        (italic, semi-transparent effect)
```

### Without Signature:
```
        Dr. Jane Doe, MD
        License: MED-789
        
        _______________      ← Placeholder line
```

## Why Stack?

**Stack Widget** allows layering:
- Bottom layer = Printed name (always visible)
- Top layer = Signature (transparent, overlays)
- Result = Signature appears "written over" the name

Just like signing a real prescription! 📝✨

---

**Perfect!** The signature now properly overlays the doctor's name with transparent background, exactly like a real handwritten signature on a paper prescription! 🏥
