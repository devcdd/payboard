# Pay Board

Pay Board is an iOS-first native SwiftUI app for managing recurring subscriptions in a board layout.

## MVP scope
- Board view with upcoming subscriptions
- Create, update, delete subscription entries
- Local persistence (offline-first)
- Local reminders (3-day, 1-day, same-day)
- Preset icon catalog (200+ keys)

## Architecture
- `Sources/Domain`: Entities, protocols, and date logic
- `Sources/Data`: Local repository, notification scheduler, icon catalog
- `Sources/DesignSystem`: Tokens and reusable UI components
- `Sources/Features`: Board, editor, settings feature UI + view models
- `Sources/AppCore`: App environment / dependency wiring
- `Sources/PayBoardApp`: `@main` app entry

## Requirements
- Xcode (full install) for iOS Simulator/device builds
- Swift 6.2 toolchain

## macOS bootstrap (new machine)
```bash
./scripts/bootstrap-macos.sh
```

This installs shared dependencies via `Brewfile` and prints required post-setup commands.

## Build
```bash
swift build
```

## Test
```bash
swift test
```

## Notes
- This repository is currently Swift Package based for fast bootstrap and modularization.
- For full iPhone shipping workflows (signing, TestFlight, assets), add an Xcode iOS App project shell that references these modules.
