# Bed Ledger

Offline garden-bed journal for home growers: map beds, log sowing and harvests, and carry planting history across seasons on phone, tablet, and Windows.

## Why and for whom

Small-space vegetable growers forget which bed held which crop and when a harvest happened. Bed Ledger keeps a private, legible season-by-season record. It is not a plant identification service or an agronomy advisor.

## Workflow

Create a named bed with optional dimensions and notes. Add a season, record a crop planting with its chosen name, sow/transplant date, and position (free-text row/area). Log harvest date and optional quantity/unit. Browse prior seasons for a bed before planning next planting. Export the full journal as versioned JSON and harvest rows as CSV; preview before importing JSON backup.

## MVP

- Flutter 3.47.7 / Dart 3.13.5 single codebase: Windows desktop first, Android phones/tablets and iPhone/iPad enabled. Platform folders `windows/`, `android/`, `ios/` exist. App currently boots a minimal platform-aware title screen; journal behavior lands in later issues.
- Local bed, season, planting and harvest records; no crop database or recommendations.
- Adaptive layouts and keyboard/mouse + touch. UX strategy A: Fluent-style Windows, Material 3 Android, Cupertino iOS/iPadOS behind a small adaptive-widget layer. Never cross-render another platform's visual system.
- Accessible large text, high contrast, screen readers and Windows keyboard navigation.
- JSON backup/restore with validation and collision-safe preview; CSV harvest export.

## Non-goals

No cloud account, location tracking, automated weather/frost advice, pest diagnosis, sensor integration, social sharing, or syncing. No native Swift-only app, React Native, Expo, Kotlin Multiplatform, .NET MAUI, or Unity. No medical or food-safety claims. The `WorkspaceLayout` seam maps the garden master-detail view across phone, tablet, and desktop.

## Privacy and permissions

Data stays on device. No network requests, analytics, advertising, or account. File picker is used only when user requests backup import/export; no background permissions required. Storage uses app-private local files; deletion and backup are explicit. Export paths and platform file-picker behavior require tests.

## Status and milestones

Bed/season/planting/harvest domain, private JSON persistence, adaptive UI and user-initiated backup import/export exist. `AppStore/description.txt` is draft listing copy. `AppStore/icon.png` is generated source art (OpenAI Images `gpt-image-2.5-flare`); platform icons still use Flutter defaults until issue #7. Windows/Android/iOS build evidence belongs to linked CI runs, not host. No mobile store submission or physical device testing claimed.

Bundle/application ID: `com.infinityball.bedledger` on Android/iOS; Windows identity `cominfinityball.bedledger` where MSIX rules require no reverse-DNS dots after vendor. App Store Connect bundle registration: `CREATED com.infinityball.bedledger`. Repository Actions secrets configured: `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_P8`, `ASC_TEAM_ID` (names only); TestFlight/Play submission deferred.

## Develop

Install pinned Flutter stable from `toolchain.json`. After issue #1 creates platform folders, run `flutter pub get`, `flutter test`, `flutter build windows --release` on Windows; on Linux x64 in Docker run `flutter test` and `flutter build apk --debug`. This host is arm64 and does not itself prove those builds. CI will run Windows release build on `windows-latest`; `.github/workflows/release.yml` will zip the Windows build and attach it to `v*` GitHub releases or manual dispatch. No release workflow exists yet.

MIT licensed; see `LICENSE`.
