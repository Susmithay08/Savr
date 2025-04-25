# SAVR – Smart Assistant for Vital Routines

SAVR is an all-in-one personal wellness assistant designed to help users manage food, medication, hydration, fitness, and overall health habits efficiently. Built using **Flutter** and **Firebase**, SAVR works across mobile and web platforms with seamless user experience.

---

## 📱 Features

- ✅ **Food Management**
  - Pantry tracking with expiry date alerts
  - Barcode scanning and AI-based expiry prediction
  - Smart grocery list generator
  - AI-powered meal planner using pantry and user preferences

- 💊 **Medication Management**
  - Add medications with dosage and schedule
  - Reminder notifications and daily logging
  - Supports "Daily", "Every 8 hours", "Specific days", and "Monthly once"

- 💧 **Hydration Tracker**
  - Daily water intake reminders
  - Logs synced to your health dashboard

- 🏋️‍♀️ **Fitness Planner**
  - Custom workout planner with rest screens
  - Full timer-based workout flow with GIF support
  - Track weekly fitness goals and calories

- 🧠 **Wellness & Self-Care**
  - Home remedy suggestions for conditions
  - Habit builder and mood tracking
  - Emergency contacts and AI health chat

- 🌐 **Cross-Platform Support**
  - Runs on Android, iOS (planned), and Web
  - Uses Firebase Firestore for real-time syncing
  - Local notifications supported for Android and Web push

---

## 🛠 Tech Stack

- **Frontend:** Flutter (Dart)
- **Backend:** Firebase (Auth, Firestore, Messaging, Storage)
- **Notifications:** `flutter_local_notifications`, FCM
- **AI Integration:** Google Gemini API (for meal & workout generation)

---

## 🚀 How to Run


# Get dependencies
flutter pub get

# Run the app (choose your platform)
flutter run -d chrome         # Web
flutter run -d windows        # Windows desktop
flutter run -d emulator-id    # Android emulator

© 2025 Susmitha Yeddula. All rights reserved.

This application is developed as part of a course project. The code, design, and intellectual property belong solely to Susmitha Yeddula. Group members contributed to documentation only and not the implementation. No part of this project may be reproduced, distributed, or transmitted without explicit permission.

This app uses open-source libraries, acknowledged respectfully.
