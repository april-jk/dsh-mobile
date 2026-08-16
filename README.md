# DSH Remote Mobile

Flutter mobile client for securely opening a computer's local DeepSeek Harness through the DSH Relay.

## Requirements

- Flutter 3.38.10 (Dart 3.10)
- iOS 14 or newer
- Android 8.0 (API 26) or newer

## Run with the production Relay

The default build connects to the deployed HTTPS Relay:

```bash
flutter run
```

## Run with Mock Relay

Mock mode must be enabled explicitly and supports deterministic login, pairing, device management, and session states.

```bash
flutter run --dart-define=DSH_USE_MOCK=true
```

Use any valid email, a password with at least eight characters, and any six-digit pairing code.

## Prepare the computer

Install the local `dsh-mobile` plugin into the DSH web profile, then start DSH:

```bash
dsh plugin --profile web add "/absolute/path/to/dsh-plugin"
dsh web
```

The Companion follows the `dsh web` lifecycle. It does not need to be run as a separate background process.

## Run with a real Relay

```bash
flutter run \
  --dart-define=DSH_USE_MOCK=false \
  --dart-define=DSH_RELAY_URL=http://127.0.0.1:8787
```

For an Android emulator, use `http://10.0.2.2:8787`. Physical devices need an HTTPS Relay or a development hostname reachable from the device. Production builds must use HTTPS.

## Verification

```bash
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build apk --release
flutter build ios --release --no-codesign
```

The canonical cross-team contracts are in `../dsh-公共文档/`.
