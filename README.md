# 📦 Pickup App

> Screenshot-based package pickup event manager built with Flutter.

Pickup App is not a logistics tracker.
It is an **OCR-powered event understanding system** focused on one question:

> **“Do I need to pick up a package right now?”**

The app extracts package pickup events directly from screenshots using OCR + text parsing + rule-based event analysis, then turns them into actionable reminders.

---

# ✨ Features

* 📷 Import screenshots or take photos
* 🔍 Chinese OCR using Google ML Kit
* 🧠 Multi-stage text parsing pipeline
* 📦 Automatic package event extraction
* 🔔 Arrival notifications + reminder notifications
* 🧹 OCR noise filtering & typo correction
* 🚫 Conflict detection & invalid page abort rules
* 🧠 Smart HeroCard decision engine
* 💾 Local persistence with Hive
* ⚡ Offline-first architecture
* 🧪 Regression-tested parsing system

---

# 🧠 Product Philosophy

Traditional logistics apps focus on:

```text
Package Tracking → Logistics Timeline → Delivery Details
```

Pickup App focuses on:

```text
Screenshot → Event Understanding → Action Reminder
```

This is an **event-driven system**, not a tracking system.

---

# 🏗 Architecture

```text
ui/        → Flutter presentation layer
app/       → orchestration & workflow
platform/  → external adapters (ML Kit / Hive / Notifications)
core/      → immutable pure Dart business logic
```

Dependency direction:

```text
ui → app → core
ui → platform → core
```

`core/` is fully isolated:

* ❌ No Flutter imports
* ❌ No platform dependencies
* ❌ No UI dependencies

---

# 📂 Project Structure

```text
lib/
├── core/          # Pure Dart business logic
├── platform/      # ML Kit / Hive / Notification adapters
├── app/           # OCR pipeline orchestration
├── ui/            # Flutter UI layer
└── main.dart
```

---

# 🔄 OCR Pipeline

```text
Image
→ OCR (ML Kit Chinese Recognition)
→ Text Preprocess
→ Conflict Detection
→ Abort Rules
→ Multi-package Parsing
→ Package Factory
→ Dedupe
→ Local Persistence
→ Notification Trigger
```

---

# 📦 Core Package Model

```dart
enum PackageStatus {
  transit,
  delivering,
  arrived,
  pickedUp,
}
```

```dart
class Package {
  String id;
  String courier;
  PackageStatus status;
  String? pickupCode;
  String? location;
  String? trackingNumber;
  bool notifiedArrived;
  DateTime createdAt;
}
```

---

# 🔧 Parsing Features

## OCR typo correction

```text
极免 → 极兔
圓通 → 圆通
韵逹 → 韵达
豐巢 → 丰巢
順丰 → 顺丰
```

## Tracking number inference

```text
JT + 13 digits → J&T Express
SF + 12 digits → SF Express
YT + 13 digits → YTO Express
ZT + 12 digits → ZTO Express
```

## Noise filtering

Ignored logistics hub keywords:

```text
转运中心
分拣中心
集散中心
处理中心
航空港
```

Ignored UI badge text:

```text
(待取件2)
```

---

# 🔔 Notification System

Arrival notification:

```text
📦 Your package has arrived!
SF Express · Pickup Code: 15-3-6007
```

24-hour reminder:

```text
⏰ Your package is still waiting for pickup
```

---

# 🧪 Testing

Regression test coverage includes:

* ✅ Good cases
* ✅ Bad cases
* ✅ Edge cases
* ✅ Dedupe logic
* ✅ End-to-end parsing

Run tests:

```bash
flutter test
```

---

# ⚙️ Tech Stack

* Flutter
* Riverpod
* Hive
* Google ML Kit
* flutter_local_notifications
* image_picker

---

# 📱 Platform Support

Current status:

| Platform | Support    |
| -------- | ---------- |
| Android  | ✅          |
| iOS      | 🚧 Planned |

---

# 🚫 Non-Goals

The app intentionally does NOT include:

* Real-time logistics tracking
* Logistics API polling
* Account system
* Cloud sync
* Delivery maps
* iOS support (for now)

---

# 🚀 Current Status

### Stable Features

* OCR recognition
* Screenshot upload flow
* Parsing pipeline
* Notification system
* Dedupe system
* Architecture refactor
* Regression tests

### In Progress

* Multi-station location management
* Better long-tail OCR coverage
* Raw event modeling experiments

---

# 🧊 Core Architecture Rule

> `lib/core/` is immutable.

The core layer is pure business logic and must never depend on:

* Flutter
* UI
* Platform APIs
* External frameworks

---

# 📸 Screenshots

*Add screenshots here*

```text
/assets/screenshots/
```

---

# 🚀 Getting Started

## 1. Clone the repository

```bash
git clone <your_repo_url>
cd pickup_app
```

## 2. Install dependencies

```bash
flutter pub get
```

## 3. Run the app

```bash
flutter run
```

---

# 📄 License

MIT License

---

# 👨‍💻 Author

Built by a student developer exploring:

* OCR systems
* Event-driven architecture
* Mobile automation
* Information extraction
* Real-world parsing systems
