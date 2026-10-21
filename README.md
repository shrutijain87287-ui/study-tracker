# Study Tracker — Universal Cross-Platform App

**Study Tracker** is a flexible, universal Flutter application designed for any study goal—college semesters, competitive exams (UPSC, GATE, GRE, USMLE, CA, CFA), professional certifications, school curriculum, or independent self-study.

It comes with zero hardcoded subjects or rigid curricula, allowing you to configure your exact study plan, track progress, pace your study toward target deadlines, and manage multi-cycle revisions.

---

## ✨ Features

- **🌐 Universal & Plan-Agnostic**: Start with any qualification, degree, or personal learning project. No hardcoded or pre-filled curriculum.
- **🔄 Multiple Study Plans**: Create, manage, and switch between separate study plans (e.g., "Fall Semester 2026", "AWS Certification", "Language Learning").
- **📚 3 Flexible Tracking Modes**:
  1. **Flat Lecture Counter**: Set total lectures and tick off numbered units (1..N).
  2. **Chapters & Subtopics**: Hierarchical breakdown of chapters and granular subtopics.
  3. **Task Checklist**: Open-ended study syllabus with custom items.
- **🎯 Target Deadlines & Daily Pace Calculator**:
  - Primary target & optional backup target countdowns.
  - Automatic daily required pace calculation (`remaining items / remaining days`) so you always know today's required output.
- **🔁 Customizable Revision Matrix**:
  - Track multiple revision stages (R1, R2, R3, Mock Exams, or custom cycles).
  - High-level subject-by-revision matrix overview.
- **⏱️ Integrated Pomodoro Focus Timer**:
  - Focus (25m), Short Break (5m), and Long Break (15m) modes with animated visual indicator.
  - Tag sessions to specific subjects and record session notes.
  - Manual session logger and history log tracking today's progress vs. daily study goal.
- **📝 Tagged Study Notes & Formulas**:
  - Save key points, formulas, and tricky topics categorized by tags (`Formula`, `Concept`, `Mistake`, `Summary`).
  - Searchable across subjects and available in the centralized revision pack.
- **⏰ Local Daily Reminders**:
  - Configurable daily reminder times using local notifications.
- **📱 Responsive UI**:
  - Adaptive layout with a side `NavigationRail` on desktop/web and a bottom `NavigationBar` on mobile.
  - Light and Dark theme modes with smooth transition.
- **🔒 Privacy-First & Offline**:
  - 100% offline local storage using `SharedPreferences`.
  - JSON backup **Export** (copy to clipboard) and **Import** (paste and restore) for easy migration and data backup.
  - Built-in backward compatibility for legacy tracker data.

---

## 🏗️ Project Structure

```
ca_inter_tracker/
├── lib/
│   ├── main.dart                  # Entry point, theme provider, route handler
│   ├── models/
│   │   └── study_plan.dart        # Core domain models (StudyPlan, Subject, Chapter, Task, etc.)
│   ├── services/
│   │   ├── storage_service.dart   # SharedPreferences persistence, JSON import/export, migrations
│   │   └── notification_service.dart # Local notifications manager (platform guarded)
│   ├── screens/
│   │   ├── onboarding_screen.dart # 3-step setup wizard for first launch
│   │   ├── home_shell.dart        # Responsive shell (Rail/BottomNav)
│   │   ├── dashboard_screen.dart  # Countdown hero, pace metric, fl_chart progress, quick actions
│   │   ├── subjects_screen.dart   # Subject grid/list, add/edit/delete subjects
│   │   ├── subject_detail_screen.dart # Curriculum checklist, revision status, tagged notes
│   │   ├── pomodoro_screen.dart   # Pomodoro focus timer, subject session logger
│   │   ├── revision_screen.dart   # Revision matrix & master notes/formula pack
│   │   ├── reminders_screen.dart  # Daily study reminder list & switches
│   │   └── settings_screen.dart   # Plan switcher, revision cycle config, theme, JSON backup
│   └── theme/
│       └── app_theme.dart         # Material 3 theme definitions, color scheme, icon helper
└── test/
    └── study_plan_test.dart       # Unit tests for pace math, progress calculations, JSON roundtrip
```

---

## 🚀 Getting Started

### Prerequisites
- [Flutter SDK](https://flutter.dev/docs/get-started/install) (version 3.22+ or newer)
- Android Studio / Android SDK (for Android deployment)
- Google Chrome or modern web browser (for Web deployment)

### Dependencies
Install all package dependencies:
```bash
flutter pub get
```

### Run on Web (Chrome)
```bash
flutter run -d chrome
```

Or build a production web release:
```bash
flutter build web --release
```

### Run on Android
1. Connect an Android device with USB debugging enabled or start an Android Emulator.
2. Launch the app:
   ```bash
   flutter run
   ```
3. To generate a release APK:
   ```bash
   flutter build apk --release
   ```
   The APK will be generated at `build/app/outputs/flutter-apk/app-release.apk`.

---

## ☁️ Cloud Authentication, Backup & Recovery

Study Tracker provides a complete cloud synchronization and data recovery architecture powered by **Firebase Authentication** and **Cloud Firestore**.

### 🌟 Core Capabilities
- **Cross-Device Recovery**: Reinstall the app or switch devices, sign in with your email, and all study plans, notes, subjects, lecture completion, and settings restore automatically.
- **Local Data Migration**: When an existing user first registers, the app automatically detects unauthenticated local data and offers to migrate it safely to the cloud.
- **Fail-Safe Protection**: Local data is never overwritten by an empty cloud response. If offline or network errors occur, changes persist locally and sync once connection is restored.
- **Conflict Resolution**: Two-way sync reconciles local and remote edits, preserving the most recently edited versions of notebooks and plans.

### 🛠️ Firebase Console Setup Instructions

To connect your own Firebase project:

1. **Create a Firebase Project**:
   - Go to [Firebase Console](https://console.firebase.google.com/) and create a project (e.g. `study-tracker-app`).
2. **Enable Firebase Authentication**:
   - Navigate to **Build → Authentication → Sign-in method**.
   - Enable **Email/Password** provider (Email link is optional).
3. **Create Cloud Firestore**:
   - Navigate to **Build → Firestore Database → Create Database**.
   - Start in **Production mode**.
   - Set Cloud Firestore Security Rules using the provided [`firestore.rules`](file:///Users/shrutijain/Downloads/ca_inter_tracker/firestore.rules):
     ```javascript
     rules_version = '2';
     service cloud.firestore {
       match /databases/{database}/documents {
         match /users/{userId} {
           allow read, write: if request.auth != null && request.auth.uid == userId;
           match /{allSubcollections=**} {
             allow read, write: if request.auth != null && request.auth.uid == userId;
           }
         }
         match /{document=**} {
           allow read, write: false;
         }
       }
     }
     ```
4. **Register Your Apps**:
   - **Web App**: Click **Project Settings → Add App → Web**. Copy your `apiKey`, `appId`, `projectId`, `messagingSenderId`, and paste them into [`lib/firebase_options.dart`](file:///Users/shrutijain/Downloads/ca_inter_tracker/lib/firebase_options.dart) or provide via `--dart-define`.
   - **Android App**: Add an Android app with package name `com.example.caintertracker`. Download `google-services.json` and place it in `android/app/`.

---

## 🧪 Testing & Validation

The codebase maintains strict quality standards:

- **Static Analysis**:
  ```bash
  flutter analyze
  ```
  *(Zero lints, warnings, or errors)*

- **Unit & Widget Tests**:
  ```bash
  flutter test
  ```
  *(Verifies pace calculators, progress ratios, chapter hierarchies, and JSON serialization roundtrips)*

---

## 💡 Usage Guide

1. **First Launch (Setup Wizard)**:
   - **Step 1**: Name your study plan (e.g. "CFA Level 1" or "Semester 4") and choose a category.
   - **Step 2**: Enter your target exam or deadline date and your daily study goal in hours.
   - **Step 3**: Add your initial subjects and pick their tracking mode (Flat lectures, Chapters & Topics, or Task checklist).
2. **Dashboard**:
   - Check the countdown hero banner and the **Daily Required Pace** indicator.
   - View visual completion bars and jump directly to any subject.
3. **Subject Detail**:
   - Tap any subject card to view chapters, check off finished items, track R1/R2/R3 revision passes, or save quick formula notes.
4. **Pomodoro Timer**:
   - Select your current subject, click Start, and log your focused minutes directly into today's study progress.
5. **Settings & Data Backup**:
   - Switch between multiple plans or create new ones.
   - Tap **Export JSON Backup** to save your progress or **Import JSON Backup** to restore on another device.
