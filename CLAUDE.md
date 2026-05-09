# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Flutter app for tracking package pickups. Chinese-language UI with iOS-style design. Users scan SMS messages or images to auto-parse courier info, then track packages by status and urgency.

## Build & Run

```bash
flutter run                       # Run on connected device/emulator
flutter build apk                 # Build Android APK
flutter test                      # Run all tests
flutter test test/some_test.dart  # Run single test
flutter analyze                   # Lint (uses flutter_lints)
```

SDK constraint: `^3.6.0`

## Architecture

### Four-Layer Unidirectional Design

```
ui/ ──────→ app/ ──────→ core/
  │                         ▲
  └────→ platform/ ────────┘
```

| Layer | Path | Role |
|-------|------|------|
| **core/** | `lib/core/` | Immutable pure logic. Models, parser, engine, sanitizer. |
| **app/** | `lib/app/` | Sole orchestration layer. OCR→Parser→Package pipeline, hero decision. |
| **platform/** | `lib/platform/` | Thin adapters. ML Kit OCR, Hive storage, local notifications. |
| **ui/** | `lib/ui/` | Flutter rendering. Providers, screens, theme, constants. |

---

## 🔴 HARD RULE: CORE IS IMMUTABLE

**`lib/core/` is frozen. It must NEVER be violated.**

### core MUST NOT:

- `import 'package:flutter/...'` or any Flutter SDK
- `import 'package:pickup_app/platform/...'`
- `import 'package:pickup_app/app/...'`
- `import 'package:pickup_app/ui/...'`

### core does NOT know about:

- OCR implementation (Google ML Kit, etc.)
- Notification system (flutter_local_notifications)
- UI state (Widget, BuildContext, Riverpod providers)
- Storage mechanism (Hive, SQLite, SharedPreferences)

### core ONLY contains:

- `models/` — `Package`, `PackageStatus`, `PendingConfirmation`
- `parser/` — `TextParser`, extractors, regex patterns, parse result
- `ocr/` — `OcrService` interface, `OcrResult`, `ImagePreprocessor`
- `engine/` — `HeroCardEngine`, `HeroCardState` (pure logic)
- `sanitizer/` — `TextSanitizer`, line classifier, noise filter
- `utils/` — `TextNormalizer`, text utilities
- `debug/` — `DebugTrace`, `Metrics` (print-based, no Flutter)

### Violation checklist before any core change:

- [ ] Does this import Flutter?
- [ ] Does this reference a provider?
- [ ] Does this call `Hive` directly?
- [ ] Does this show a notification?
- [ ] Does this import from `app/`, `platform/`, or `ui/`?

**If any answer is YES, the change does NOT belong in core.**

---

### State Management

Riverpod (`flutter_riverpod`). Root `ProviderScope` wraps the app in `main.dart`.

**Providers** (`lib/ui/providers/package_provider.dart`):
- `packageListProvider` — `StateNotifier<List<Package>>`, the source of truth. Loads from Hive on init, syncs back on every mutation.
- `pendingPackagesProvider` — sorted by location then urgency score.
- `completedPackagesProvider`, `groupedPendingPackagesProvider`, `heroDecisionProvider` — derived.

### Dual-Model Pattern

- `Package` (`lib/core/models/package.dart`) — immutable core model with `copyWith`, `transitionTo()`, business logic.
- `HivePackage` (`lib/platform/storage/hive_package.dart`) — Hive serialization wrapper. `HivePackage.fromPackage()` / `.toPackage()` convert between them.

`hive_package.dart` re-exports the core model, so most files just import from there.

### Text Parsing Pipeline (core)

Raw text → `TextSanitizer` (filter noise lines) → `TextPreprocessor` (normalize) → `TextParser` (orchestrates extractors) → `ParseResult`.

Extractors in `lib/core/parser/extractors.dart`: `CourierExtractor`, `PickupCodeExtractor`, `TrackingNumberExtractor`, `PhoneTailExtractor`, `LocationExtractor`, `StatusExtractor`. Each returns `ExtractionResult<T>` with confidence score.

`TextParser.parseMulti()` handles multi-package text by splitting on pickup code boundaries.

Courier detection uses both keyword matching and tracking number prefix patterns (e.g. `SF` → 顺丰, `JT` → 极兔).

### OCR (platform + core)

- `lib/core/ocr/ocr_service.dart` — abstract `OcrService` interface (pure Dart).
- `lib/platform/ocr/mlkit_ocr_adapter.dart` — Google ML Kit implementation (`OcrService`).
- `lib/core/ocr/image_preprocessor.dart` — image processing logic (uses `image` package, not Flutter).

### OCR Pipeline (app)

`lib/app/ocr_pipeline.dart` — orchestrates:
1. OCR via `MlKitOcrAdapter`
2. Text sanitization via `TextSanitizer`
3. Conflict detection via `ConflictDetector`
4. Parsing via `TextParser` (core)
5. Confidence-based routing → `Package` or `PendingConfirmation`

### Persistence (platform)

`lib/platform/storage/` — Hive storage. Box named `"packages"` (constant `kPackagesBox` in `main.dart`). Four adapters: `PackageStatusAdapter` (typeId 0), `UrgencyLevelAdapter` (1), `CourierTypeAdapter` (2), `HivePackageAdapter` (3).

`PackageListNotifier._sync()` clears and rewrites the entire box on every state change.

### Notifications (platform)

`lib/platform/notification/notification_adapter.dart` — singleton wrapping `flutter_local_notifications`. Two notification types per package:
- **Arrived**: immediate push when scan detects `arrived` status.
- **24h reminder**: scheduled via `zonedSchedule` if package still uncollected.

Notification IDs derived from package ID hash. Cancelled on `markPickedUp()`.

### Hero Card

`HeroCardEngine` (`lib/core/engine/hero_card_engine.dart`) — pure logic, takes all packages, outputs `HeroCardState`.
`HeroDecisionService` (`lib/app/hero_decision.dart`) — maps core engine output to UI format (colors, icons).

### Deduplication

`PackageListNotifier.addPackage()` uses enhanced identity matching (`_findExistingPackage()`):

1. **trackingNumber + pickupCode** (highest priority) — both must match (prevents same-tracking-different-code overwrites).
2. **pickupCode + location** — both must match exactly.
3. **transitFingerprint** (weak fallback) — for packages without tracking number.

Duplicate merges take the higher urgency, newer timestamp, and non-empty fields.

## Screen Structure

Single-screen app (`HomeScreen`) with widgets in `lib/ui/screens/home/widgets/`. Hero card at top, pending packages grouped by location below, completed section at bottom, bottom tab bar for navigation.

## Design Tokens

Colors, spacing, and radii in `lib/ui/constants/app_constants.dart` (`AppColors`, `AppSpacing`, `AppRadius`). Theme in `lib/ui/theme/app_theme.dart` — Material 3 with Cupertino theme support.

## Linter Rules

Custom rules in `analysis_options.yaml`: `prefer_const_constructors`, `prefer_const_declarations`, `avoid_print`.`