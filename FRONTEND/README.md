# PharmaCare Frontend

Flutter frontend for PharmaCare.

## Run Locally

Start the backend first, then run:

```bash
flutter run -d chrome --web-port 8096 --dart-define=API_BASE_URL=http://127.0.0.1:8000/api
```

## Build Web

```bash
flutter build web --release --dart-define=API_BASE_URL=https://api.yourdomain.com/api
```

Upload:

```text
build/web
```

## Build APK

```bash
flutter build apk --release --dart-define=API_BASE_URL=https://api.yourdomain.com/api
```

Output:

```text
build/app/outputs/flutter-apk/app-release.apk
```

For local phone testing, use your laptop WiFi IP instead of `127.0.0.1`.
