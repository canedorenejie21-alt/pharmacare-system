# PharmaCare Frontend

Flutter frontend for PharmaCare.

## Run Locally

Start the backend first, then run:

```bash
flutter run -d chrome --web-hostname localhost --web-port 8096 \
  --dart-define=API_BASE_URL=http://127.0.0.1:8000/api \
  --dart-define=GOOGLE_WEB_CLIENT_ID=285680876693-fmqubravnj1d5hoh5aseovjetem74tlm.apps.googleusercontent.com
```

## Build Web

```bash
flutter build web --release \
  --dart-define=API_BASE_URL=https://api.yourdomain.com/api \
  --dart-define=GOOGLE_WEB_CLIENT_ID=285680876693-fmqubravnj1d5hoh5aseovjetem74tlm.apps.googleusercontent.com
```

Upload:

```text
build/web
```

## Build APK

```bash
flutter build apk --release \
  --dart-define=API_BASE_URL=https://api.yourdomain.com/api \
  --dart-define=GOOGLE_WEB_CLIENT_ID=285680876693-fmqubravnj1d5hoh5aseovjetem74tlm.apps.googleusercontent.com
```

Output:

```text
build/app/outputs/flutter-apk/app-release.apk
```

For local phone testing, use your laptop WiFi IP instead of `127.0.0.1`.
