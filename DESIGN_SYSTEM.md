The current system is optimized for comfort and commerce. A safety system requires urgency, clarity under stress, and unambiguous state signaling. Pastel-heavy design weakens that.

Shift from “pleasant” → “decisive + legible + hierarchical”.

---

## Color System (Rebuilt)

### Core Principle

* Every color maps to a **state**, not aesthetics
* Contrast must hold under panic, low light, motion

---

### Primary (Action / Safety Trigger)

* Emergency Red: `#D32F2F`
  Use: SOS, alerts, danger states
* Pressed: `#B71C1C`

Red becomes **functional**, not decorative.

---

### Secondary (Trust / System Stability)

* Deep Blue: `#1E3A8A`
  Use: navigation, system UI, headers
* Light Blue: `#E3F2FD`
  Use: backgrounds for safe zones/info

Blue communicates **control + reliability**

---

### Support Colors (Expanded)

**Safe State**

* Green: `#2E7D32`
* Light Green: `#E8F5E9`
  Use: “Reached safely”, verified contacts, successful alerts

**Warning / Attention**

* Amber: `#F9A825`
* Light Amber: `#FFF8E1`
  Use: “Low battery”, “location weak”, “network unstable”

**Critical Background**

* Soft Red Tint: `#FFEBEE`
  Used behind alerts to increase visibility without full aggression

---

### Neutrals (Adjusted for contrast)

* Background: `#F4F6F8` (less playful, more neutral)
* Card: `#FFFFFF`
* Divider: `#DADCE0`

**Text**

* Primary: `#111827` (stronger than before)
* Secondary: `#4B5563`
* Inverse: `#FFFFFF`

---

## State Mapping (Non-negotiable)

* Red → Immediate danger / trigger
* Amber → Potential issue
* Green → Confirmed safety
* Blue → System / navigation
* Gray → Passive / neutral

No overlap. No decorative misuse.

---

## Component Adjustments

### 1. Primary Button (Critical)

* Default: Red
* Label: “SOS”, “Send Alert”
* Size: Larger than all other buttons
* Placement: fixed, bottom or thumb zone

Non-critical actions must never visually compete.

---

### 2. Secondary Buttons

* Blue or outlined
* Used for:

  * “Share location”
  * “Call contact”
  * “Track route”

---

### 3. Cards

Keep structure, change purpose:

* Add **state strip** on top or left:

  * Red strip → active emergency
  * Green → safe confirmation
  * Amber → warning

This removes reliance on reading.

---

### 4. Status Banner (New Component)

Persistent, top-level

* Red banner: “Emergency active”
* Amber: “Weak GPS”
* Green: “You are safe”

Must override normal UI hierarchy.

---

### 5. Map Layer

Enhancements:

* Safe zones → green overlays
* Risk zones → light red heat areas
* Route line:

  * Blue → normal
  * Red → deviation or unsafe

---

### 6. Contact Chips

* Verified contacts: green outline
* Unverified: gray
* Active tracking: blue glow

---

## Typography Shift

* Increase weight for critical info
* Reduce decorative hierarchy

**Changes**

* Headings: bolder (600–700)
* Critical text: ALL CAPS or spaced
* Numbers (time, distance): monospaced or highly legible

---

## Layout Changes

* Reduce visual clutter
* Increase spacing between actionable elements
* Prioritize thumb-reach zones

---

## Interaction Changes

* Long press → emergency trigger (prevents accidental taps)
* Haptic feedback on critical actions
* Visual confirmation must be immediate and irreversible-looking

---

## Visual Language Shift

Current: soft, rounded, friendly
Revised: still rounded, but **firmer + higher contrast**

* Reduce excessive pastel backgrounds
* Increase edge clarity
* Use color blocks instead of subtle gradients

---

## Updated Token Example

```
color.primary.red: #D32F2F
color.primary.blue: #1E3A8A
color.success: #2E7D32
color.warning: #F9A825

color.bg: #F4F6F8
color.surface: #FFFFFF

color.text.primary: #111827
color.text.secondary: #4B5563

radius.md: 16px
radius.lg: 20px

shadow.card: 0 4px 10px rgba(0,0,0,0.08)
```

---

## Structural Difference

Old system:

* Emotion-first
* Discovery-oriented
* Visual softness

New system:

* State-first
* Action-oriented
* Cognitive clarity under stress

A safety interface fails if it requires interpretation. Every color and component must resolve instantly into meaning.
