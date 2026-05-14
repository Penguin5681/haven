# Haven: Android Native Frontend Design Document

This document outlines the native Android frontend architecture and design implementations within the Haven project. It details the custom activities, layouts, UI components, and services designed specifically for Android to ensure seamless, native user interactions.

## 1. Overview of Native UI Architecture

The native Android layer is responsible for critical features that require deep system integration and a native look-and-feel, specifically for scenarios like simulated phone calls and emergency background services. The frontend UI heavily relies on standard Android XML layouts, custom drawable resources for styling, and standard Android `Activity` classes to manage lifecycle and interactions.

### Key Native Components
- **Activities**: Serve as the primary entry points for full-screen UI (e.g., `FakeIncomingCallActivity`, `FakeOngoingCallActivity`, `MainActivity`).
- **XML Layouts**: Define the visual structure of the screens using `RelativeLayout`, `LinearLayout`, and standard widgets (`TextView`, `ImageView`, `ImageButton`).
- **Custom Drawables**: Provide styling, backgrounds, and interactive states for buttons and screens.
- **Services & Receivers**: Manage background tasks (e.g., `SosAccessibilityService`, `FakeCallAlarmReceiver`) that may trigger UI elements or notifications.

## 2. Core Activities and Layouts

### 2.1 Fake Incoming Call Interface
**Activity**: `FakeIncomingCallActivity.java`
**Layout**: `res/layout/activity_fake_incoming_call.xml`

This screen simulates a native Android incoming call interface to provide a realistic escape mechanism for users in uncomfortable situations.

**UI Elements & Design:**
- **Root Layout**: A full-screen `RelativeLayout` with a dark, gradient background defined by `@drawable/fake_call_incoming_bg`.
- **Caller Information**: 
  - `incomingCallerName`: A prominent `TextView` positioned near the top, styled with a large text size (`22sp`) and an off-white color (`#E6EBDD`).
  - `incomingCallerNumber`: A smaller `TextView` placed directly below the name, using a muted green-grey color (`#95A98F`).
- **Message Action Pill**: A central button (`incomingMessagePill`) near the bottom, styled with `@drawable/fake_call_message_pill_bg`, containing an icon and "Message" text, replicating standard Android call UI features.
- **Call Controls**: 
  - Located at the bottom using a horizontal `LinearLayout`.
  - **Decline Button**: An `ImageButton` (`incomingDecline`) with a red circular background (`@drawable/fake_call_end_bg`) and an "x" cancel icon.
  - **Accept Button**: An `ImageButton` (`incomingAccept`) with a green circular background (`@drawable/fake_call_answer_bg`) and a phone icon.

**Behavioral Characteristics:**
- The activity is configured in `AndroidManifest.xml` with `showWhenLocked="true"` and `turnScreenOn="true"` to appear over the lock screen, exactly like a real phone call.
- Uses `Theme.DeviceDefault.NoActionBar` for a modern, immersive, full-screen experience.

### 2.2 Fake Ongoing Call Interface
**Activity**: `FakeOngoingCallActivity.java`
**Layout**: `res/layout/activity_fake_ongoing_call.xml`

This interface is presented once the user "accepts" the fake incoming call, mirroring an active phone call screen.

**UI Elements & Design:**
- **Root Layout**: `RelativeLayout` with `@drawable/fake_call_ongoing_bg`.
- **Top Section (Caller Info)**:
  - `ongoingAvatar`: A circular placeholder for a profile picture (`64dp x 64dp`), styled with `@drawable/fake_call_ongoing_avatar_bg`.
  - `ongoingCallerName`: Large, bold text (`27sp`, `#FFFFFF`).
  - `ongoingCallerNumber` and `ongoingCallTimer`: Muted text (`#A0A0A0`) indicating the simulated number and the duration of the call.
- **Bottom Section (In-Call Controls)**:
  - A grid-like arrangement of in-call actions (Keypad, Mute, Speaker, Add Call) using nested `LinearLayout`s.
  - Buttons (`ongoingKeypad`, `ongoingMute`, `ongoingSpeaker`, `ongoingAddCall`) use circular, semi-transparent backgrounds (`@drawable/fake_call_control_circle_bg`) and standard Android system icons (e.g., `@android:drawable/ic_dialog_dialer`).
  - **End Call Button**: A prominent, central red button (`ongoingEndCall`) at the very bottom, styled with `@drawable/fake_call_end_small_bg`.

### 2.3 Main Application Entry
**Activity**: `MainActivity.java`

Acts as the root container for the application. It applies the `@style/LaunchTheme` initially for a seamless splash screen experience and transitions to the main application view. 

## 3. Styling and Drawables

The project leverages Android's XML drawable system extensively to create complex shapes, gradients, and states without relying on external image assets, ensuring scalability across different screen densities.

**Key Drawable Resources:**
- **Backgrounds**: `fake_call_incoming_bg.xml`, `fake_call_ongoing_bg.xml` (Define screen-level gradients or solid colors).
- **Button Shapes**: `fake_call_answer_bg.xml` (Green circle), `fake_call_end_bg.xml` (Red circle), `fake_call_control_circle_bg.xml` (Grey translucent circle).
- **Avatars & Pills**: `fake_call_ongoing_avatar_bg.xml`, `fake_call_message_pill_bg.xml`.

## 4. System Services Integration

While not purely visual, the native frontend design is tightly coupled with Android system services to provide accessibility and security features.

- **SosAccessibilityService**: Defined in the manifest and configured via `res/xml/sos_accessibility_service_config.xml`. It allows the app to respond to hardware button presses (like volume keys) to trigger SOS events, functioning at the system UI level.
- **ChunkAudioRecordingService**: Runs as a Foreground Service (type: `microphone`), utilizing native Android notifications to indicate to the user that recording is active in the background.

## 5. Manifest Configurations

The `AndroidManifest.xml` plays a crucial role in the frontend behavior:
- **Permissions**: Requests access to Camera, Contacts, Storage, Notifications, Location, and Foreground Services.
- **Activity Flags**: Uses flags like `excludeFromRecents="true"` for the fake call activities to ensure they don't appear in the Android recent apps list, maintaining privacy and the illusion of a native call.
- **Themes**: Enforces `Theme.DeviceDefault.NoActionBar` for immersive screens.

## Conclusion

The Android native frontend of Haven is purposefully built using standard Android SDK components (XML Layouts, Activities, Services). By utilizing Android's native view system for specific critical features (like the Fake Call module), the app ensures high performance, deep system integration (lock screen visibility), and an authentic user experience that mimics core OS functionalities perfectly.