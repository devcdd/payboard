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

## Supabase backup bootstrap
1. Create env file:
```bash
cp .env.supabase.example .env.supabase
```
2. Fill `SUPABASE_DB_URL` in `.env.supabase`.
3. Apply schema:
```bash
./scripts/supabase/apply_schema.sh
```

Files:
- `scripts/supabase/schema.sql`: backup tables + RLS policies
- `scripts/supabase/apply_schema.sh`: schema apply helper
- `scripts/supabase/generate_apple_client_secret.sh`: Apple client secret(JWT) generator for Supabase
- `.env.supabase.example`: env template

Apple client secret generation example:
```bash
./scripts/supabase/generate_apple_client_secret.sh \
  --team-id YOUR_TEAM_ID \
  --key-id YOUR_KEY_ID \
  --client-id YOUR_SERVICES_ID \
  --p8-file /absolute/path/AuthKey_XXXXXX.p8
```

## Notes
- This repository is currently Swift Package based for fast bootstrap and modularization.
- For full iPhone shipping workflows (signing, TestFlight, assets), add an Xcode iOS App project shell that references these modules.
