# AGENTS.md

Quick reference for AI agents working on this Flutter package-tracking app.

**For detailed project guidelines, see [CLAUDE.md](./CLAUDE.md). For architecture and feature overview, see [README.md](./README.md).**

## Quick Start

```bash
flutter run                    # Run on device/emulator
flutter test                   # Run all tests
flutter test test/some_test.dart  # Run specific test
flutter analyze                # Lint check
flutter build apk              # Build APK
```

## Architecture (30 seconds)

4-layer design with strict dependency rules:
- **core/** — immutable pure Dart (NO Flutter, NO platform imports)
- **app/** — orchestration (OCR pipeline, deduplication logic)
- **platform/** — adapters (ML Kit OCR, Hive storage, notifications)
- **ui/** — Flutter widgets (Riverpod providers, screens, theme)

**Key rule:** Core is frozen. Never add Flutter imports, platform calls, or UI state to `lib/core/`.

## Immediate Productivity Rules

### 1. Core Layer is Immutable ⛔

**Never do:**
```dart
// In lib/core/...
import 'package:flutter/...';  // ❌
import 'package:pickup_app/app/...';  // ❌
await Hive.box(...);  // ❌
showNotification();  // ❌
```

**Do this instead:** Add a new adapter to `platform/` and call it from `app/`.

### 2. Test First, Then Commit

- Write fixture-based tests in `test/fixtures/` for parsing edge cases
- Run `flutter test` before any commit
- Bad cases in `test/fixtures/bad/` must fail to parse; good cases must succeed

### 3. State Management = Riverpod

- One root `StateNotifier` in `lib/ui/providers/package_provider.dart` (`packageListProvider`)
- All mutations go through this provider; it auto-syncs to Hive
- Use derived providers (`pendingPackagesProvider`, etc.) for computed state
- No direct Hive writes from UI; use the notifier

### 4. Deduplication Priority (when adding packages)

1. **Tracking number + pickup code** (strongest)
2. **Pickup code + location** (medium)
3. **Transit fingerprint** (weak fallback)

### 5. Text Parsing Pipeline (core)

Raw text → `TextSanitizer` (noise filter) → `TextPreprocessor` (normalize) → `TextParser` (extractors) → `ParseResult`

**Extractors** in `lib/core/parser/extractors.dart`:
- `CourierExtractor` — keyword matching + tracking prefix patterns
- `PickupCodeExtractor` — regex for codes (e.g., "15-3-6007")
- `TrackingNumberExtractor` — courier-specific formats
- `LocationExtractor` — pickup location
- `StatusExtractor` — transit/arrived/delivering/pickedUp

### 6. Notifications

- **Arrival**: Immediate push when status changes to `arrived`
- **24h reminder**: Scheduled if still uncollected after 24h
- Notification IDs derived from package ID hash
- Cancellation on `markPickedUp()`

## Common Workflows

### Add a new courier type

1. Add enum case to `CourierType` in `lib/core/models/package.dart`
2. Add detection logic in `CourierExtractor` (keyword + prefix pattern)
3. Add tests in `test/` with sample OCR text
4. Add display name in `lib/ui/constants/` if needed

### Fix a parsing bug

1. Add failing test case to `test/fixtures/bad/` or `test/fixtures/edge/`
2. Fix the extractor in `lib/core/parser/extractors.dart`
3. Verify test passes with `flutter test test/parser_regression_test.dart`
4. Add fixture to `test/fixtures/good/` if it's now a good case

### Handle duplicate packages

Edit `PackageListNotifier._findExistingPackage()` priority logic (in `lib/ui/providers/package_provider.dart`). Verify with `flutter test test/dedupe_logic_test.dart`.

### Add UI feature

1. Create widget in `lib/ui/screens/home/widgets/` or `lib/ui/`
2. Add provider if state is needed in `lib/ui/providers/`
3. Use theme tokens from `lib/ui/constants/app_constants.dart`
4. Run `flutter run` and test manually

## Project Constraints

| Constraint | Reason |
|-----------|--------|
| Core has zero Flutter imports | Ensures testability and portability |
| State only mutates via provider | Keeps state predictable and Hive-synced |
| Hive box name is `"packages"` | Fixed constant in `main.dart` |
| SDK ≥ 3.6.0 | Requirement in `pubspec.yaml` |
| Chinese text only | ML Kit trained on Chinese courier text |

## File Paths Reference

| Purpose | Path |
|---------|------|
| Package model & enum | `lib/core/models/package.dart` |
| Text parsing | `lib/core/parser/` |
| OCR interface | `lib/core/ocr/ocr_service.dart` |
| ML Kit adapter | `lib/platform/ocr/mlkit_ocr_adapter.dart` |
| Hive storage | `lib/platform/storage/` |
| Notifications | `lib/platform/notification/notification_adapter.dart` |
| State provider | `lib/ui/providers/package_provider.dart` |
| Home screen | `lib/ui/screens/home/home_screen.dart` |
| Theme & constants | `lib/ui/theme/`, `lib/ui/constants/` |
| Tests | `test/` |
| Fixtures | `test/fixtures/good/`, `test/fixtures/bad/`, `test/fixtures/edge/` |

## Related Documentation

- [CLAUDE.md](./CLAUDE.md) — Detailed architecture, state management, hard rules
- [README.md](./README.md) — Product philosophy, feature list, tech stack
- `pubspec.yaml` — Dependencies and SDK constraint
- `analysis_options.yaml` — Linter rules
