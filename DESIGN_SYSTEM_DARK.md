Dark mode for safety cannot be aesthetic inversion. It must preserve state clarity under low light, glare, and panic conditions. Contrast, not color richness, is the constraint.

---

## Core Principle

* Minimum contrast: WCAG AAA where possible
* Colors shift toward **desaturated, deeper tones**
* Avoid pure black for large surfaces (eye strain + bloom issues)

---

## Color System (Dark)

### Base Layers

* Background: `#0F172A`
* Surface/Card: `#111827`
* Elevated Surface: `#1F2937`
* Divider: `#374151`

---

### Text

* Primary: `#F9FAFB`
* Secondary: `#9CA3AF`
* Disabled: `#6B7280`

---

## State Colors (Recalibrated)

### Emergency (Red)

* Primary: `#EF5350`
* Pressed: `#C62828`
* Background tint: `#2A0F0F`

Avoid neon red; use controlled luminance to prevent eye fatigue.

---

### System / Navigation (Blue)

* Primary: `#60A5FA`
* Background tint: `#0B1E3A`

Maintains visibility without overpowering red.

---

### Safe State (Green)

* Primary: `#4CAF50`
* Background tint: `#0E1F14`

---

### Warning (Amber)

* Primary: `#FBC02D`
* Background tint: `#2A220A`

Amber must remain readable without glowing.

---

## State Mapping (Unchanged)

* Red → danger
* Amber → warning
* Green → safe
* Blue → system

Dark mode must not reinterpret meaning.

---

## Component Adaptation

### 1. SOS Button

* Fill: `#EF5350`
* Text: `#FFFFFF`
* Shadow: subtle outer glow (low blur, low opacity)

Critical element must remain the **brightest object on screen**.

---

### 2. Cards

* Background: `#111827`
* Elevation via:

  * Slight brightness shift
  * Minimal shadow (not heavy blur)

Add state strip:

* Red strip: `#EF5350`
* Green strip: `#4CAF50`

---

### 3. Status Banner

* Red: `#EF5350` background, white text
* Amber: `#FBC02D` background, near-black text
* Green: `#4CAF50` background, white text

Banner must break visual rhythm.

---

### 4. Inputs

* Background: `#1F2937`
* Border: `#374151`
* Focus: blue outline (`#60A5FA`)

---

### 5. Map Layer

* Map dark theme baseline

* Route:

  * Blue: `#60A5FA`
  * Alert: `#EF5350`

* Safe zones: muted green overlay

* Risk zones: low-opacity red heat layer

Avoid bright overlays that obscure map readability.

---

### 6. Icons

* Default: `#E5E7EB`
* Muted: `#9CA3AF`
* Active:

  * Red / Blue / Green based on state

---

## Elevation Model

No heavy shadows.

Use:

* Layer contrast (`#111827` → `#1F2937`)
* Thin borders (`#374151`)

---

## Typography Adjustments

* Increase letter spacing slightly for readability
* Avoid thin weights entirely
* Minimum: 400, preferred: 500–600

Critical text:

* Strong weight
* High contrast (white on dark)

---

## Interaction Feedback

* Tap:

  * subtle brightness increase (not scale-heavy)
* Long press:

  * radial progress indicator (light ring)
* Haptics replace visual exaggeration

---

## Token Set (Dark)

```id="dk92la"
color.bg: #0F172A
color.surface: #111827
color.surface.elevated: #1F2937

color.text.primary: #F9FAFB
color.text.secondary: #9CA3AF

color.red: #EF5350
color.red.bg: #2A0F0F

color.blue: #60A5FA
color.blue.bg: #0B1E3A

color.green: #4CAF50
color.green.bg: #0E1F14

color.amber: #FBC02D
color.amber.bg: #2A220A

border: #374151
```

---

## Structural Difference from Light Mode

Light mode:

* Separation via shadow
* Soft backgrounds

Dark mode:

* Separation via luminance steps
* Color used sparingly, only for state

---

## Failure Conditions to Avoid

* Neon colors → eye fatigue
* Low contrast gray-on-gray → unreadable
* Overuse of red → loss of urgency hierarchy
* Pure black backgrounds → bloom + harsh edges

---

System integrity depends on one invariant:
**state recognition must be instantaneous without reading text**
