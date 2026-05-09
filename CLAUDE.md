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

No code generation step needed currently — Hive adapters are hand-written in `lib/adapters/hive_adapters.dart`.

## Architecture

### Layered Design

The codebase has two layers:

- **`lib/core/`** — Pure Dart, no Flutter dependency. Contains models, parsers, OCR, sanitization, and the hero card engine. Testable in isolation.
- **`lib/`** (top-level) — Flutter layer. Screens, widgets, Riverpod providers, Hive persistence, notification service.

### State Management

Riverpod (`flutter_riverpod`). Root `ProviderScope` wraps the app in `main.dart`.

**Providers** (`lib/providers/package_provider.dart`):
- `packageListProvider` — `StateNotifier<List<Package>>`, the source of truth. Loads from Hive on init, syncs back on every mutation.
- `pendingPackagesProvider` — sorted by location then urgency score.
- `completedPackagesProvider`, `groupedPendingPackagesProvider`, `heroDecisionProvider` — derived.

### Dual-Model Pattern

- `Package` (`lib/core/models/package.dart`) — immutable core model with `copyWith`, `transitionTo()`, business logic. Used everywhere in the Flutter layer.
- `HivePackage` (`lib/models/package_model.dart`) — Hive serialization wrapper. `HivePackage.fromPackage()` / `.toPackage()` convert between them.

`package_model.dart` re-exports the core model, so most files just import from there.

### Text Parsing Pipeline

Raw text → `TextSanitizer` (filter noise lines) → `TextPreprocessor` (normalize) → `TextParser` (orchestrates extractors) → `ParseResult`.

Extractors in `lib/core/parser/extractors.dart`: `CourierExtractor`, `PickupCodeExtractor`, `TrackingNumberExtractor`, `PhoneTailExtractor`, `LocationExtractor`, `StatusExtractor`. Each returns `ExtractionResult<T>` with confidence score.

`TextParser.parseMulti()` handles multi-package text by splitting on pickup code boundaries.

Courier detection uses both keyword matching and tracking number prefix patterns (e.g. `SF` → 顺丰, `JT` → 极兔).

### OCR

`lib/services/ocr_service.dart` — compatibility wrapper around Google ML Kit (`google_mlkit_text_recognition`). Uses `TextRecognitionScript.chinese`. Returns raw text or `OcrResult` with parse candidates.

### Persistence

Hive stores packages in a box named `"packages"` (constant `kPackagesBox` in `main.dart`). Four adapters registered at startup: `PackageStatusAdapter` (typeId 0), `UrgencyLevelAdapter` (1), `CourierTypeAdapter` (2), `HivePackageAdapter` (3).

`PackageListNotifier._sync()` clears and rewrites the entire box on every state change.

### Notifications

`NotificationService` (singleton) — event-driven, no background polling. Two notification types per package:
- **Arrived**: immediate push when scan detects `arrived` status.
- **24h reminder**: scheduled via `zonedSchedule` if package still uncollected.

Notification IDs derived from package ID hash. Cancelled on `markPickedUp()`.

### Hero Card

`HeroCardEngine` (`lib/core/engine/hero_card_engine.dart`) — pure logic, takes all packages, outputs `HeroCardState` with title, subtitle, urgency score, emotion state, badges, and suggested action. `HeroDecisionService` wraps it for the provider layer.

### Deduplication

`PackageListNotifier.addPackage()` uses tracking-first identity matching (`_findExistingPackage()`):

1. **trackingNumber** (highest priority) — exact match, no courier dependency.
2. **pickupCode + location** — both must match exactly.
3. **transitFingerprint** (weak fallback) — for packages without tracking number.

Duplicate merges take the higher urgency, newer timestamp, and non-empty fields.

## Screen Structure

Single-screen app (`HomeScreen`) with widgets in `lib/screens/home/widgets/`. Hero card at top, pending packages grouped by location below, completed section at bottom, bottom tab bar for navigation.

## Design Tokens

Colors, spacing, and radii in `lib/constants/app_constants.dart` (`AppColors`, `AppSpacing`, `AppRadius`). Theme in `lib/theme/app_theme.dart` — Material 3 with Cupertino theme support.

## Linter Rules

Custom rules in `analysis_options.yaml`: `prefer_const_constructors`, `prefer_const_declarations`, `avoid_print`.
