# PayBoard

PayBoard monorepo root.

## Layout
- `ios/`: current iOS app, Swift package modules, Xcode project, Supabase scripts
- `android/`: Android app workspace placeholder

## iOS

Requirements:
- Xcode (full install)
- Swift 6.2 toolchain

Bootstrap:
```bash
cd ios
./scripts/bootstrap-macos.sh
```

Build:
```bash
cd ios
swift build
```

Test:
```bash
cd ios
swift test
```

Supabase backup bootstrap:
```bash
cd ios
cp .env.supabase.example .env.supabase
./scripts/supabase/apply_schema.sh
```

Xcode project:
- `ios/PayBoardiOS.xcodeproj`

## Android

`android/` is reserved for the native Android app.
