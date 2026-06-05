# PharmaCare Backend

Dependency-free PHP REST API for the PharmaCare frontend.

## Run

```bash
php -S 127.0.0.1:8000 -t public
```

The SQLite database is created automatically at `storage/pharmacare.sqlite`.

## Switch To MySQL

Composer and `pdo_mysql` are supported, but MySQL must be running first.

```bash
sudo systemctl start mysql
sudo mysql
```

Then create the database/user:

```sql
CREATE DATABASE pharmacare_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER 'pharmacare_user'@'localhost' IDENTIFIED BY 'password';
GRANT ALL PRIVILEGES ON pharmacare_db.* TO 'pharmacare_user'@'localhost';
FLUSH PRIVILEGES;
EXIT;
```

Create `BACKEND/.env`:

```env
DB_CONNECTION=mysql
DB_HOST=127.0.0.1
DB_PORT=3306
DB_DATABASE=pharmacare_db
DB_USERNAME=pharmacare_user
DB_PASSWORD=password
FRONTEND_ORIGIN=http://localhost:8095
```

Restart the PHP server. Tables and seed data are created automatically.

## Deploy Notes

Point your PHP web root/document root to:

```text
BACKEND/public
```

For Render Docker deploy, this backend includes:

```text
Dockerfile
start-render.sh
../render.yaml
```

Render runs the server on its assigned `$PORT` automatically.

For local network testing from a real phone, run the API on all interfaces:

```bash
php -S 0.0.0.0:8000 -t public
```

Then build Flutter with your computer LAN IP:

```bash
flutter build apk --dart-define=API_BASE_URL=http://YOUR_LAN_IP:8000/api
```

For real deployment, host the backend on HTTPS and build with:

```bash
flutter build apk --release --dart-define=API_BASE_URL=https://your-api-domain.com/api
```

## Seeded Logins

- Admin: `owner@pharmacare.com` / `password`
- Pharmacist: `maria@pharmacare.local` / `password`
- Patient: `juan@example.com` / `password`

## Main Endpoints

- `POST /api/login`
- `POST /api/register`
- `POST /api/logout`
- `GET /api/me`
- `GET /api/admin-dashboard`
- `GET /api/pharmacist-dashboard`
- `GET /api/patient-dashboard`
- `GET /api/admin/pharmacists`
- `POST /api/admin/pharmacists`
- `PUT /api/admin/pharmacists/{id}`
- `PUT /api/admin/pharmacists/{id}/disable`
- `GET|POST /api/patients`
- `GET|PUT /api/patients/{id}`

Admins and pharmacists can add and edit patient records. Patient login accounts are still created through patient self-registration.
- `GET|POST /api/pharmacists`
- `GET|POST /api/medications`
- `GET|PUT /api/medications/{id}`
- `POST /api/medications/{id}/stock-in`
- `GET|POST /api/prescriptions`
- `GET|PUT /api/prescriptions/{id}`
- `POST /api/prescriptions/{id}/details`
- `POST /api/prescriptions/{id}/dispense`

When creating a prescription as a pharmacist, `pharmacist_id` is filled from the logged-in account automatically.
Dispensing a prescription marks it as dispensed, creates a dispensing record, reduces medication stock, and notifies the patient.
- `GET|POST /api/refill-requests`
- `PUT /api/refill-requests/{id}/approve`
- `PUT /api/refill-requests/{id}/reject`

Pharmacists and admins can approve or reject pending refill requests from the dashboard.
- `GET|POST /api/dispensing-records`
- `GET /api/notifications`
- `PUT /api/notifications/{id}/read`

Patients can mark their notifications as read from the patient home reminders list.
- `GET /api/drug-interactions`
- `GET /api/audit-logs`
