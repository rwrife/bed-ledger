# Bed Ledger — Plan

## Scope

Local-only garden-bed journaling for beds, seasons, plantings and harvests. It records, recalls and exports the grower's own decisions. It does not identify plants, advise agronomy, ingest weather, or sync data.

## Architecture

Flutter application shell over a pure-Dart domain and persistence package.

- `lib/domain/`: bed, season, planting, harvest entities; validation; garden/season ordering; pure functions for bed timelines.
- `lib/data/`: repository interface plus JSON-file-backed implementation. A file-system abstraction keeps domain logic unit-testable.
- `lib/ui/`: screens for bed list, season timeline, planting/harvest forms, backup/export.
- `lib/platform/`: adaptive widgets (`AdaptiveScaffold`, `AdaptiveButton`, `AdaptiveDialog`, `AdaptiveDatePicker`) and `WorkspaceLayout`, the single seam mapping the master-detail garden layout to phone, tablet and desktop.

Repository/event data are modeled as append-only records and serialized through versioned JSON. Backup import always validates, then presents a collision-safe merge/delete choice before mutation.

## Tech choices

- Flutter stable + Dart (fleet multi-platform rule) delivers Windows, Android and iOS from one codebase.
- UX strategy **A: platform-native adaptive**. Windows uses Fluent-style command bar/NavigationView and full keyboard interaction; Android uses Material 3; iOS/iPadOS uses Cupertino navigation, swipe-back and action sheets. Platform selection is confined to `lib/platform/`; screens stay common. This satisfies "platform-authentic UX" without maintaining three UIs.
- SQLite is deferred until JSON backup/export and a realistic history volume prove insufficient; `ponytail:` ceiling is a single-user local JSON journal, upgrade path is a SQLite-backed repository with JSON export retained.
- No backend, telemetry, or analytics.

## Platforms and identifiers

Windows is the primary CI/release target. Android and iOS, including tablets, are first-class. Use `com.infinityball.bedledger` as Android `applicationId`, iOS bundle identifier, and MSIX identity where applicable. App Store Connect registration status: `CREATED com.infinityball.bedledger`.

## Milestones and dependency order

1. Pinned Flutter app scaffold, platform enablement, CI and analyzer/test gates.
2. Domain entities, repository contract, JSON persistence and unit tests.
3. Bed/season/planting/harvest workflow with editable timeline.
4. Adaptive phone/tablet/desktop UI with UX strategy A and per-platform golden/widget tests.
5. Backup/restore and CSV export, plus privacy/accessibility polish.
6. Windows packaging/release Action and icon wiring.

## Testing

- Unit tests for entity validation, timeline ordering, duplicate/collision handling and JSON round-trip.
- Widget/golden tests for each critical screen on `TargetPlatform.windows`, `TargetPlatform.android` and `TargetPlatform.iOS`.
- File-picker integration tests on Linux/Windows CI. Accessibility tests verify text scaling, focus traversal and semantic labels.
- No claim of mobile store or physical device validation without artifacts.

## Packaging and distribution

`.github/workflows/release.yml` (issue #6) builds Windows release on `windows-latest` for `v*` tag or manual dispatch, zips portable build, and attaches it to a GitHub release. Android/iOS debug compile checks run in CI. TestFlight/Play later with existing ASC secret names `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_P8`, `ASC_TEAM_ID`; never print values. `AppStore/icon.png` must be wired to Windows `.ico`, Android adaptive icons and iOS asset catalog.

## Privacy and data behavior

Local app storage only. Zero network requests. No permissions beyond user-initiated file picker for backup/export. No location, camera, account, ad, analytic or crash-upload services. JSON backup is full export; CSV is harvest convenience export. Deletion and restore require confirmation.

## Risks and non-goals

- Risk: garden history grows large. Mitigation: append-only records plus tested compacted export; SQLite upgrade documented.
- Risk: file-picker differences across platforms. Mitigation: platform abstraction, CI tests per supported platform.
- Non-goals: no plant ID, crop databases, weather/frost advice, automated reminders, pest diagnosis, IoT integration, collaboration, cloud sync, native Swift-only, React Native, Expo, Kotlin Multiplatform, .NET MAUI, or Unity components. No food-safety or agricultural yield claims.
