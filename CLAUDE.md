# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Flutter app for tracking package pickups. Chinese-language UI with iOS-style design. Users scan SMS messages or images to auto-parse courier info, then track packages by status and urgency.

## Build & Run

```bash
flutter run                    # Run on connected device/emulator
flutter build apk              # Build Android APK
flutter test                   # Run all tests
flutter test test/some_test.dart  # Run single test
flutter analyze                # Lint (uses flutter_lints)
```

SDK constraint: `^3.6.0`

## Architecture

**State management:** Riverpod (`flutter_riverpod`). Root `ProviderScope` wraps the app in `main.dart`.

**Data flow:**
- `Package` model (`lib/models/package_model.dart`) — immutable data class with `copyWith`
- `PackageListNotifier` (`lib/providers/package_provider.dart`) — `StateNotifier` holds the package list, exposes `addPackage()` and `markPickedUp()`
- Derived providers: `pendingPackagesProvider`, `completedPackagesProvider`, `heroDecisionProvider` — all computed from `packageListProvider`

**Key services:**
- `OcrService` — currently returns mock SMS text (real OCR not implemented yet)
- `TextParser` — parses courier name, pickup code, location, and status from raw text using keyword matching and regex
- `HeroDecisionService` — determines what to show in the hero card based on package urgency and location clustering

**Screen structure:** Single-screen app (`HomeScreen`) with widgets in `lib/screens/home/widgets/`. The hero card at the top summarizes pending pickups; package list below shows individual cards grouped by status.

**Design tokens:** All colors, spacing, and radii are in `lib/constants/app_constants.dart` (`AppColors`, `AppSpacing`, `AppRadius`). Theme defined in `lib/theme/app_theme.dart` — uses Material 3 with both Material and Cupertino theme support.

## Linter Rules

Custom rules in `analysis_options.yaml`: `prefer_const_constructors`, `prefer_const_declarations`, `avoid_print`.
