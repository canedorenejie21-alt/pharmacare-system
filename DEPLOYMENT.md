# PharmaCare Deployment Guide

## Current Status

PharmaCare is demo-ready for a client presentation after hosting the backend and building the frontend with the hosted API URL.

Production hardening still recommended before real patient use:
- Replace seeded/default passwords.
- Use HTTPS.
- Use a real MySQL database backup policy.
- Add stronger validation and password reset email delivery.

## Backend Hosting

Host `BACKEND/public` as the PHP document root.

Requirements:
- PHP 8.2+
- PDO MySQL enabled
- MySQL 8+
- HTTPS domain/subdomain, for example `https://api.yourdomain.com`

Create the MySQL database:

```sql
CREATE DATABASE pharmacare_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER 'pharmacare_user'@'localhost' IDENTIFIED BY 'CHANGE_THIS_PASSWORD';
GRANT ALL PRIVILEGES ON pharmacare_db.* TO 'pharmacare_user'@'localhost';
FLUSH PRIVILEGES;
```

Create `BACKEND/.env` on the server:

```env
APP_ENV=production
APP_KEY=change-me
DB_CONNECTION=mysql
DB_HOST=127.0.0.1
DB_PORT=3306
DB_DATABASE=pharmacare_db
DB_USERNAME=pharmacare_user
DB_PASSWORD=CHANGE_THIS_PASSWORD
FRONTEND_ORIGIN=https://your-frontend-domain.com
GOOGLE_WEB_CLIENT_ID=285680876693-fmqubravnj1d5hoh5aseovjetem74tlm.apps.googleusercontent.com
GOOGLE_ANDROID_CLIENT_ID=
```

Health check:

```text
https://api.yourdomain.com/api/health
```

Expected response:

```json
{"status":"ok","service":"pharmacare-api"}
```

## Render Backend Deploy

This repo includes:

```text
render.yaml
BACKEND/Dockerfile
BACKEND/start-render.sh
BACKEND/.env.render.example
```

Render setup:

1. Push this project to GitHub.
2. In Render, create a new Blueprint or Web Service from the repository.
3. If using the Blueprint, Render reads `render.yaml`.
4. Add these environment variables in Render:

```env
APP_ENV=production
DB_CONNECTION=mysql
DB_HOST=your-mysql-host
DB_PORT=3306
DB_DATABASE=pharmacare_db
DB_USERNAME=pharmacare_user
DB_PASSWORD=your-mysql-password
FRONTEND_ORIGIN=https://your-frontend-domain.com
GOOGLE_WEB_CLIENT_ID=285680876693-fmqubravnj1d5hoh5aseovjetem74tlm.apps.googleusercontent.com
GOOGLE_ANDROID_CLIENT_ID=
```

Render does not provide free MySQL by default. Use an external MySQL provider such as Railway, Aiven, PlanetScale-compatible MySQL, Clever Cloud, or a cPanel/Hostinger MySQL database that allows remote connections.

After deploy, your backend API will look like:

```text
https://pharmacare-api.onrender.com/api
```

Check:

```text
https://pharmacare-api.onrender.com/api/health
```

## Flutter Web Build

From `FRONTEND`:

```bash
flutter build web --release \
  --dart-define=API_BASE_URL=https://api.yourdomain.com/api \
  --dart-define=GOOGLE_WEB_CLIENT_ID=285680876693-fmqubravnj1d5hoh5aseovjetem74tlm.apps.googleusercontent.com
```

Upload this folder to your frontend hosting:

```text
FRONTEND/build/web
```

## Android APK Build

For a real hosted backend:

```bash
cd ~/pharmacare/FRONTEND
flutter build apk --release \
  --dart-define=API_BASE_URL=https://api.yourdomain.com/api \
  --dart-define=GOOGLE_WEB_CLIENT_ID=285680876693-fmqubravnj1d5hoh5aseovjetem74tlm.apps.googleusercontent.com
```

APK output:

```text
FRONTEND/build/app/outputs/flutter-apk/app-release.apk
```

For local WiFi demo only:

```bash
cd ~/pharmacare/BACKEND
php -S 0.0.0.0:8000 -t public
```

Then:

```bash
cd ~/pharmacare/FRONTEND
flutter build apk --debug \
  --dart-define=API_BASE_URL=http://YOUR_LAPTOP_IP:8000/api \
  --dart-define=GOOGLE_WEB_CLIENT_ID=285680876693-fmqubravnj1d5hoh5aseovjetem74tlm.apps.googleusercontent.com
```

## Seeded Demo Logins

- Admin: `owner@pharmacare.com` / `password`
- Pharmacist: `maria@pharmacare.local` / `password`
- Patient: `juan@example.com` / `password`

Change these before giving real access.

## Client Demo Checklist

Before giving it to the client:

1. Open `/api/health` and confirm status is `ok`.
2. Login as admin, pharmacist, and patient.
3. Add medication.
4. Stock in medication.
5. Create prescription.
6. Dispense prescription.
7. Approve/reject refill.
8. Add/edit patient.
9. Mark notification as read.
10. Test APK on the actual phone if giving an APK.
