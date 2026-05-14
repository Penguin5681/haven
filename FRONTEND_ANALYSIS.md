# Frontend Architecture & Design Overview (Native Android)

## 1. Introduction
The **Haven** application frontend is built entirely natively for Android using **Java** for the application logic and **XML** for the UI layouts. This document outlines the frontend architecture, focusing on the user interface components, navigation flows, state management, and overall design patterns. It is tailored to provide a conceptual understanding for frontend developers without diving deeply into specific file paths or classes.

## 2. Architectural Pattern (MVVM)
The frontend adopts the **Model-View-ViewModel (MVVM)** architecture to ensure a clean separation of concerns. This is highly analogous to modern component-based frameworks (like React or Vue), but implemented using native Android paradigms.

*   **Views (XML Layouts + Java Controllers)**: Responsible purely for rendering the UI and capturing user interactions (clicks, swipes). XML acts as the "HTML/CSS" equivalent, defining structure and styling, while the Java layer binds these elements to the screen.
*   **ViewModels**: Act as the state managers for the Views. They hold the UI state, process user input, and interact with backend services. They survive screen rotations, ensuring the UI remains consistent.
*   **Reactive State**: The app uses an observer pattern. The Views "listen" to data streams (LiveData) provided by the ViewModels. When data changes (e.g., a new SOS alert arrives), the UI automatically re-renders the affected components.

## 3. Core Navigation & User Flows
The application features role-based routing, dividing the experience into distinct user journeys.

### 3.1. Onboarding & Authentication
*   **Splash & Role Selection**: The entry point of the app. Users choose their persona (e.g., General User/Women vs. Authority). The routing system passes this selection forward to tailor the subsequent screens.
*   **Auth Flow**: Based on the chosen role, users are routed to specific Login or Registration screens. State managers handle form validation and session persistence before allowing entry to the main dashboards.

### 3.2. Primary Dashboards
The application utilizes a Bottom Navigation pattern for the main workspace, allowing users to switch between modular views without losing their overall context.

*   **User Dashboard**: 
    *   The central hub featuring the primary **SOS Trigger**.
    *   Tabs to navigate between Map/Safe Routes, Emergency Contacts, and Settings.
*   **Authority Dashboard**:
    *   A monitoring interface that displays real-time lists of active alerts.
    *   Automatically updates as new data streams in via the ViewModel.

## 4. Key UI/UX Components
The frontend requires several highly specialized, custom-built UI components to meet the application's safety requirements.

### 4.1. The SOS Trigger Component
*   **Visuals**: A prominent, centrally located action button.
*   **Interaction**: To prevent accidental triggers, it employs custom touch handling. Instead of a simple "click," it requires a "long-press" mechanism, often accompanied by a visual filling animation (like a circular progress bar) to give the user immediate feedback on the trigger status.

### 4.2. Fake Call Simulation Interface
This is a highly customized set of views designed to perfectly mimic a native device's phone dialer.
*   **Incoming Call State**: Utilizes full-screen overlays that bypass standard app boundaries. It includes drag-to-answer mechanics ("swipe up to answer") mimicking standard OS behavior.
*   **Active Call State**: Once "answered," the UI instantly transitions to an active call screen. It features a running chronometer (call timer) and a grid of standard phone controls (Mute, Speaker, Keypad) to maintain the illusion of a real phone call.

### 4.3. Safe Routes Map View
*   Integrates a native mapping component directly into the layout.
*   **Data Overlays**: Renders custom markers and heatmaps based on area safety data.
*   **Interactive Bottom Sheets**: Tapping on map elements triggers a persistent, draggable bottom sheet that slides up to reveal route details, keeping the user in the context of the map.

### 4.4. List Views & Dynamic Data
*   Uses highly optimized, recycling list views for displaying Emergency Contacts and Authority Alerts.
*   These components only render the items currently visible on the screen, ensuring smooth scrolling even with large datasets. They support swipe-to-delete and inline editing interactions.

## 5. Styling, Theming, and Assets
The visual identity of the app is centralized, similar to a global CSS file, ensuring consistency across all screens.

*   **Global Theme**: A central theme defines the base typography, button styles, and global layout constraints (e.g., removing standard action bars for a custom look).
*   **Color Palette**: Centralized color tokens dictate the app's visual language—relying on specific purples for branding and high-contrast reds for emergency/warning states.
*   **Custom Drawables**: Instead of static images, the app heavily uses XML-defined vector graphics and "drawables." This includes defining custom button gradients, rounded corners, drop shadows, and interactive state changes (e.g., how a button visually depresses when touched).

## 6. Summary
The Haven frontend operates as a modern, reactive application built natively for Android. By treating XML as the presentation layer and Java as the logic and state management layer, it achieves a highly performant, responsive, and deeply integrated user experience that is crucial for emergency and safety contexts.