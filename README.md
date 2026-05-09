# Pickup App

Flutter app for tracking package pickups. Chinese UI with iOS-style design.

## Architecture

```
ui/ ──────→ app/ ──────→ core/
  │                         ▲
  └────→ platform/ ────────┘
```

| Layer | Role |
|-------|------|
| `core/` | Immutable pure logic (frozen) |
| `app/` | Sole orchestration (pipeline) |
| `platform/` | External adapters (OCR / Hive / Notification) |
| `ui/` | Flutter rendering (providers / screens / theme) |

---

## 🔴 HARD RULE: CORE IS IMMUTABLE

```
lib/core/ is FROZEN.
Read it from anywhere. Change it only for pure business logic.
```

### core MUST NOT import:

- ❌ `package:flutter/*`
- ❌ `package:pickup_app/platform/*`
- ❌ `package:pickup_app/app/*`
- ❌ `package:pickup_app/ui/*`

### core does NOT know about:

- ❌ OCR implementation (ML Kit, etc.)
- ❌ Notification system
- ❌ UI state (Widget, BuildContext, Riverpod)
- ❌ Storage mechanism (Hive, SQLite, etc.)

### core ONLY contains:

- ✅ `models/` — Package, PackageStatus, PendingConfirmation
- ✅ `parser/` — TextParser, extractors, regex patterns
- ✅ `ocr/` — OcrService interface, OcrResult, ImagePreprocessor
- ✅ `engine/` — HeroCardEngine, HeroCardState
- ✅ `sanitizer/` — TextSanitizer, noise filtering
- ✅ `utils/` — TextNormalizer
- ✅ `debug/` — DebugTrace, Metrics

---

## Quick Start

```bash
flutter pub get
flutter run
flutter test
flutter analyze
```