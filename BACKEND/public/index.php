<?php

declare(strict_types=1);

const BASE_DIR = __DIR__ . '/..';
const DB_FILE = BASE_DIR . '/storage/pharmacare.sqlite';

loadEnv();

header('Access-Control-Allow-Origin: ' . env('FRONTEND_ORIGIN', '*'));
header('Access-Control-Allow-Headers: Authorization, Content-Type');
header('Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS');
header('Content-Type: application/json');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(204);
    exit;
}

try {
    $pdo = db();
    migrate($pdo);
    migrateUsersRbac($pdo);
    seed($pdo);
    dispatch($pdo);
} catch (Throwable $e) {
    json(['error' => 'Server error', 'message' => $e->getMessage()], 500);
}

function db(): PDO
{
    loadEnv();
    $connection = env('DB_CONNECTION', 'sqlite');

    if ($connection === 'mysql') {
        $host = env('DB_HOST', '127.0.0.1');
        $port = env('DB_PORT', '3306');
        $database = env('DB_DATABASE', 'pharmacare_db');
        $username = env('DB_USERNAME', 'root');
        $password = env('DB_PASSWORD', '');
        $dsn = "mysql:host=$host;port=$port;dbname=$database;charset=utf8mb4";
        $pdo = new PDO($dsn, $username, $password);
        $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
        $pdo->setAttribute(PDO::ATTR_DEFAULT_FETCH_MODE, PDO::FETCH_ASSOC);
        return $pdo;
    }

    $dir = dirname(DB_FILE);
    if (!is_dir($dir)) {
        mkdir($dir, 0775, true);
    }

    $pdo = new PDO('sqlite:' . DB_FILE);
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    $pdo->setAttribute(PDO::ATTR_DEFAULT_FETCH_MODE, PDO::FETCH_ASSOC);
    $pdo->exec('PRAGMA foreign_keys = ON');

    return $pdo;
}

function loadEnv(): void
{
    $path = BASE_DIR . '/.env';
    if (!is_file($path)) {
        return;
    }

    foreach (file($path, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES) as $line) {
        $line = trim($line);
        if ($line === '' || str_starts_with($line, '#') || !str_contains($line, '=')) {
            continue;
        }
        [$key, $value] = explode('=', $line, 2);
        $_ENV[trim($key)] = trim($value);
    }
}

function env(string $key, string $default = ''): string
{
    return $_ENV[$key] ?? getenv($key) ?: $default;
}

function migrate(PDO $pdo): void
{
    if ($pdo->getAttribute(PDO::ATTR_DRIVER_NAME) === 'mysql') {
        migrateMysql($pdo);
        return;
    }

    $pdo->exec("
        CREATE TABLE IF NOT EXISTS patients (
            patient_id INTEGER PRIMARY KEY AUTOINCREMENT,
            first_name TEXT NOT NULL,
            last_name TEXT NOT NULL,
            birth_date TEXT,
            gender TEXT,
            address TEXT,
            contact_number TEXT,
            email TEXT UNIQUE,
            allergy_info TEXT,
            medical_history TEXT,
            created_at TEXT DEFAULT CURRENT_TIMESTAMP,
            updated_at TEXT DEFAULT CURRENT_TIMESTAMP
        );

        CREATE TABLE IF NOT EXISTS pharmacists (
            pharmacist_id INTEGER PRIMARY KEY AUTOINCREMENT,
            first_name TEXT NOT NULL,
            last_name TEXT NOT NULL,
            license_number TEXT UNIQUE,
            contact_number TEXT,
            email TEXT UNIQUE,
            created_at TEXT DEFAULT CURRENT_TIMESTAMP,
            updated_at TEXT DEFAULT CURRENT_TIMESTAMP
        );

        CREATE TABLE IF NOT EXISTS users (
            user_id INTEGER PRIMARY KEY AUTOINCREMENT,
            username TEXT NOT NULL UNIQUE,
            email TEXT UNIQUE,
            password_hash TEXT NOT NULL,
            role TEXT NOT NULL CHECK (role IN ('admin', 'pharmacist', 'patient')),
            patient_id INTEGER,
            pharmacist_id INTEGER,
            created_at TEXT DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (patient_id) REFERENCES patients(patient_id) ON DELETE CASCADE,
            FOREIGN KEY (pharmacist_id) REFERENCES pharmacists(pharmacist_id) ON DELETE CASCADE
        );

        CREATE TABLE IF NOT EXISTS auth_tokens (
            token TEXT PRIMARY KEY,
            user_id INTEGER NOT NULL,
            expires_at TEXT NOT NULL,
            created_at TEXT DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
        );

        CREATE TABLE IF NOT EXISTS medications (
            medication_id INTEGER PRIMARY KEY AUTOINCREMENT,
            medication_name TEXT NOT NULL,
            description TEXT,
            dosage_form TEXT,
            strength TEXT,
            manufacturer TEXT,
            expiration_date TEXT,
            stock_quantity INTEGER NOT NULL DEFAULT 0,
            reorder_level INTEGER NOT NULL DEFAULT 0,
            created_at TEXT DEFAULT CURRENT_TIMESTAMP,
            updated_at TEXT DEFAULT CURRENT_TIMESTAMP
        );

        CREATE TABLE IF NOT EXISTS prescriptions (
            prescription_id INTEGER PRIMARY KEY AUTOINCREMENT,
            patient_id INTEGER NOT NULL,
            pharmacist_id INTEGER NOT NULL,
            prescription_date TEXT NOT NULL,
            diagnosis TEXT,
            status TEXT NOT NULL DEFAULT 'Pending',
            notes TEXT,
            created_at TEXT DEFAULT CURRENT_TIMESTAMP,
            updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (patient_id) REFERENCES patients(patient_id),
            FOREIGN KEY (pharmacist_id) REFERENCES pharmacists(pharmacist_id)
        );

        CREATE TABLE IF NOT EXISTS prescription_details (
            prescription_detail_id INTEGER PRIMARY KEY AUTOINCREMENT,
            prescription_id INTEGER NOT NULL,
            medication_id INTEGER NOT NULL,
            dosage TEXT,
            frequency TEXT,
            duration TEXT,
            quantity INTEGER NOT NULL DEFAULT 1,
            FOREIGN KEY (prescription_id) REFERENCES prescriptions(prescription_id) ON DELETE CASCADE,
            FOREIGN KEY (medication_id) REFERENCES medications(medication_id)
        );

        CREATE TABLE IF NOT EXISTS refill_requests (
            refill_id INTEGER PRIMARY KEY AUTOINCREMENT,
            patient_id INTEGER NOT NULL,
            prescription_id INTEGER NOT NULL,
            request_date TEXT NOT NULL,
            status TEXT NOT NULL DEFAULT 'Pending',
            approval_date TEXT,
            notes TEXT,
            FOREIGN KEY (patient_id) REFERENCES patients(patient_id),
            FOREIGN KEY (prescription_id) REFERENCES prescriptions(prescription_id)
        );

        CREATE TABLE IF NOT EXISTS dispensing_records (
            dispense_id INTEGER PRIMARY KEY AUTOINCREMENT,
            prescription_id INTEGER NOT NULL,
            pharmacist_id INTEGER NOT NULL,
            dispense_date TEXT NOT NULL,
            quantity_dispensed INTEGER NOT NULL,
            remarks TEXT,
            FOREIGN KEY (prescription_id) REFERENCES prescriptions(prescription_id),
            FOREIGN KEY (pharmacist_id) REFERENCES pharmacists(pharmacist_id)
        );

        CREATE TABLE IF NOT EXISTS notifications (
            notification_id INTEGER PRIMARY KEY AUTOINCREMENT,
            patient_id INTEGER NOT NULL,
            message TEXT NOT NULL,
            notification_type TEXT NOT NULL,
            date_sent TEXT NOT NULL,
            status TEXT NOT NULL DEFAULT 'Unread',
            FOREIGN KEY (patient_id) REFERENCES patients(patient_id) ON DELETE CASCADE
        );

        CREATE TABLE IF NOT EXISTS drug_interactions (
            interaction_id INTEGER PRIMARY KEY AUTOINCREMENT,
            medication1_id INTEGER NOT NULL,
            medication2_id INTEGER NOT NULL,
            interaction_description TEXT NOT NULL,
            severity_level TEXT NOT NULL,
            FOREIGN KEY (medication1_id) REFERENCES medications(medication_id),
            FOREIGN KEY (medication2_id) REFERENCES medications(medication_id)
        );

        CREATE TABLE IF NOT EXISTS audit_logs (
            log_id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER,
            user_role TEXT NOT NULL,
            action_performed TEXT NOT NULL,
            date_time TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
            description TEXT,
            FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE SET NULL
        );
    ");
}

function migrateMysql(PDO $pdo): void
{
    $pdo->exec("
        CREATE TABLE IF NOT EXISTS patients (
            patient_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
            first_name VARCHAR(100) NOT NULL,
            last_name VARCHAR(100) NOT NULL,
            birth_date DATE NULL,
            gender VARCHAR(30) NULL,
            address VARCHAR(255) NULL,
            contact_number VARCHAR(40) NULL,
            email VARCHAR(191) UNIQUE,
            allergy_info TEXT NULL,
            medical_history TEXT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

        CREATE TABLE IF NOT EXISTS pharmacists (
            pharmacist_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
            first_name VARCHAR(100) NOT NULL,
            last_name VARCHAR(100) NOT NULL,
            license_number VARCHAR(100) UNIQUE,
            contact_number VARCHAR(40) NULL,
            email VARCHAR(191) UNIQUE,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

        CREATE TABLE IF NOT EXISTS users (
            user_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
            username VARCHAR(100) NOT NULL UNIQUE,
            email VARCHAR(191) UNIQUE,
            password_hash VARCHAR(255) NOT NULL,
            role ENUM('admin', 'pharmacist', 'patient') NOT NULL,
            patient_id INT UNSIGNED NULL,
            pharmacist_id INT UNSIGNED NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            CONSTRAINT fk_users_patient FOREIGN KEY (patient_id) REFERENCES patients(patient_id) ON DELETE CASCADE,
            CONSTRAINT fk_users_pharmacist FOREIGN KEY (pharmacist_id) REFERENCES pharmacists(pharmacist_id) ON DELETE CASCADE
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

        CREATE TABLE IF NOT EXISTS auth_tokens (
            token CHAR(64) PRIMARY KEY,
            user_id INT UNSIGNED NOT NULL,
            expires_at DATETIME NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            CONSTRAINT fk_tokens_user FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

        CREATE TABLE IF NOT EXISTS medications (
            medication_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
            medication_name VARCHAR(191) NOT NULL,
            description TEXT NULL,
            dosage_form VARCHAR(100) NULL,
            strength VARCHAR(100) NULL,
            manufacturer VARCHAR(191) NULL,
            expiration_date DATE NULL,
            stock_quantity INT NOT NULL DEFAULT 0,
            reorder_level INT NOT NULL DEFAULT 0,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

        CREATE TABLE IF NOT EXISTS prescriptions (
            prescription_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
            patient_id INT UNSIGNED NOT NULL,
            pharmacist_id INT UNSIGNED NOT NULL,
            prescription_date DATE NOT NULL,
            diagnosis VARCHAR(255) NULL,
            status VARCHAR(50) NOT NULL DEFAULT 'Pending',
            notes TEXT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            CONSTRAINT fk_prescriptions_patient FOREIGN KEY (patient_id) REFERENCES patients(patient_id),
            CONSTRAINT fk_prescriptions_pharmacist FOREIGN KEY (pharmacist_id) REFERENCES pharmacists(pharmacist_id)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

        CREATE TABLE IF NOT EXISTS prescription_details (
            prescription_detail_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
            prescription_id INT UNSIGNED NOT NULL,
            medication_id INT UNSIGNED NOT NULL,
            dosage VARCHAR(100) NULL,
            frequency VARCHAR(100) NULL,
            duration VARCHAR(100) NULL,
            quantity INT NOT NULL DEFAULT 1,
            CONSTRAINT fk_details_prescription FOREIGN KEY (prescription_id) REFERENCES prescriptions(prescription_id) ON DELETE CASCADE,
            CONSTRAINT fk_details_medication FOREIGN KEY (medication_id) REFERENCES medications(medication_id)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

        CREATE TABLE IF NOT EXISTS refill_requests (
            refill_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
            patient_id INT UNSIGNED NOT NULL,
            prescription_id INT UNSIGNED NOT NULL,
            request_date DATE NOT NULL,
            status VARCHAR(50) NOT NULL DEFAULT 'Pending',
            approval_date DATE NULL,
            notes TEXT NULL,
            CONSTRAINT fk_refills_patient FOREIGN KEY (patient_id) REFERENCES patients(patient_id),
            CONSTRAINT fk_refills_prescription FOREIGN KEY (prescription_id) REFERENCES prescriptions(prescription_id)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

        CREATE TABLE IF NOT EXISTS dispensing_records (
            dispense_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
            prescription_id INT UNSIGNED NOT NULL,
            pharmacist_id INT UNSIGNED NOT NULL,
            dispense_date DATE NOT NULL,
            quantity_dispensed INT NOT NULL,
            remarks TEXT NULL,
            CONSTRAINT fk_dispensing_prescription FOREIGN KEY (prescription_id) REFERENCES prescriptions(prescription_id),
            CONSTRAINT fk_dispensing_pharmacist FOREIGN KEY (pharmacist_id) REFERENCES pharmacists(pharmacist_id)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

        CREATE TABLE IF NOT EXISTS notifications (
            notification_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
            patient_id INT UNSIGNED NOT NULL,
            message TEXT NOT NULL,
            notification_type VARCHAR(100) NOT NULL,
            date_sent DATETIME NOT NULL,
            status VARCHAR(50) NOT NULL DEFAULT 'Unread',
            CONSTRAINT fk_notifications_patient FOREIGN KEY (patient_id) REFERENCES patients(patient_id) ON DELETE CASCADE
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

        CREATE TABLE IF NOT EXISTS drug_interactions (
            interaction_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
            medication1_id INT UNSIGNED NOT NULL,
            medication2_id INT UNSIGNED NOT NULL,
            interaction_description TEXT NOT NULL,
            severity_level VARCHAR(50) NOT NULL,
            CONSTRAINT fk_interactions_med1 FOREIGN KEY (medication1_id) REFERENCES medications(medication_id),
            CONSTRAINT fk_interactions_med2 FOREIGN KEY (medication2_id) REFERENCES medications(medication_id)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

        CREATE TABLE IF NOT EXISTS audit_logs (
            log_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
            user_id INT UNSIGNED NULL,
            user_role VARCHAR(50) NOT NULL,
            action_performed VARCHAR(191) NOT NULL,
            date_time TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            description TEXT NULL,
            CONSTRAINT fk_audit_user FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE SET NULL
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ");
}

function migrateUsersRbac(PDO $pdo): void
{
    $driver = $pdo->getAttribute(PDO::ATTR_DRIVER_NAME);
    $columns = array_column(query($pdo, $driver === 'mysql'
        ? 'SHOW COLUMNS FROM users'
        : 'PRAGMA table_info(users)'), $driver === 'mysql' ? 'Field' : 'name');

    if (!in_array('full_name', $columns, true)) {
        $pdo->exec($driver === 'mysql'
            ? 'ALTER TABLE users ADD COLUMN full_name VARCHAR(191) NULL AFTER username'
            : 'ALTER TABLE users ADD COLUMN full_name TEXT NULL');
    }
    if (!in_array('is_active', $columns, true)) {
        $pdo->exec($driver === 'mysql'
            ? 'ALTER TABLE users ADD COLUMN is_active TINYINT(1) NOT NULL DEFAULT 1 AFTER role'
            : 'ALTER TABLE users ADD COLUMN is_active INTEGER NOT NULL DEFAULT 1');
    }

    $pdo->exec("UPDATE users SET full_name = COALESCE(full_name, username)");
    $pdo->exec("UPDATE users SET is_active = 1 WHERE is_active IS NULL");

    if (!queryOne($pdo, 'SELECT user_id FROM users WHERE email = ? LIMIT 1', ['owner@pharmacare.com'])) {
        insert($pdo, 'users', [
            'username' => 'owner',
            'full_name' => 'System Owner',
            'email' => 'owner@pharmacare.com',
            'password_hash' => password_hash('password', PASSWORD_DEFAULT),
            'role' => 'admin',
            'is_active' => 1,
        ]);
    }
}

function seed(PDO $pdo): void
{
    if ((int) $pdo->query('SELECT COUNT(*) AS count FROM users')->fetch()['count'] > 0) {
        return;
    }

    $pdo->beginTransaction();

    insert($pdo, 'patients', [
        'first_name' => 'Juan',
        'last_name' => 'Dela Cruz',
        'birth_date' => '1984-03-02',
        'gender' => 'Male',
        'address' => 'Quezon City',
        'contact_number' => '0917 234 8901',
        'email' => 'juan@example.com',
        'allergy_info' => 'Ibuprofen',
        'medical_history' => 'Hypertension',
    ]);
    insert($pdo, 'patients', [
        'first_name' => 'Sofia',
        'last_name' => 'Reyes',
        'birth_date' => '1991-07-18',
        'gender' => 'Female',
        'address' => 'Makati City',
        'contact_number' => '0928 112 3490',
        'email' => 'sofia@example.com',
        'allergy_info' => 'Penicillin',
        'medical_history' => 'Asthma',
    ]);

    insert($pdo, 'pharmacists', [
        'first_name' => 'Maria',
        'last_name' => 'Santos',
        'license_number' => 'PH-2026-001',
        'contact_number' => '0918 555 1099',
        'email' => 'maria@pharmacare.local',
    ]);

    insert($pdo, 'users', [
        'username' => 'juan',
        'full_name' => 'Juan Dela Cruz',
        'email' => 'juan@example.com',
        'password_hash' => password_hash('password', PASSWORD_DEFAULT),
        'role' => 'patient',
        'is_active' => 1,
        'patient_id' => 1,
    ]);
    insert($pdo, 'users', [
        'username' => 'maria',
        'full_name' => 'Maria Santos',
        'email' => 'maria@pharmacare.local',
        'password_hash' => password_hash('password', PASSWORD_DEFAULT),
        'role' => 'pharmacist',
        'is_active' => 1,
        'pharmacist_id' => 1,
    ]);
    insert($pdo, 'users', [
        'username' => 'owner',
        'full_name' => 'System Owner',
        'email' => 'owner@pharmacare.com',
        'password_hash' => password_hash('password', PASSWORD_DEFAULT),
        'role' => 'admin',
        'is_active' => 1,
    ]);

    $meds = [
        ['Paracetamol 500mg', 'Pain reliever and fever reducer', 'Tablet', '500mg', 'RiteMed', '2026-12-31', 1200, 150],
        ['Amoxicillin 250mg', 'Antibiotic capsule', 'Capsule', '250mg', 'Generika', '2026-11-30', 450, 100],
        ['Salbutamol Inhaler', 'Bronchodilator inhaler', 'Inhaler', '100mcg', 'GSK', '2026-07-31', 20, 50],
        ['Ibuprofen 200mg', 'NSAID pain reliever', 'Tablet', '200mg', 'Unilab', '2026-10-31', 300, 80],
    ];
    foreach ($meds as $med) {
        insert($pdo, 'medications', [
            'medication_name' => $med[0],
            'description' => $med[1],
            'dosage_form' => $med[2],
            'strength' => $med[3],
            'manufacturer' => $med[4],
            'expiration_date' => $med[5],
            'stock_quantity' => $med[6],
            'reorder_level' => $med[7],
        ]);
    }

    insert($pdo, 'prescriptions', [
        'patient_id' => 1,
        'pharmacist_id' => 1,
        'prescription_date' => '2026-06-03',
        'diagnosis' => 'Fever',
        'status' => 'Pending',
        'notes' => 'Take after meals.',
    ]);
    insert($pdo, 'prescription_details', [
        'prescription_id' => 1,
        'medication_id' => 1,
        'dosage' => '1 tablet',
        'frequency' => 'Every 8 hours',
        'duration' => '5 days',
        'quantity' => 15,
    ]);
    insert($pdo, 'refill_requests', [
        'patient_id' => 1,
        'prescription_id' => 1,
        'request_date' => '2026-06-03',
        'status' => 'Pending',
        'notes' => 'Need refill this week.',
    ]);
    insert($pdo, 'notifications', [
        'patient_id' => 1,
        'message' => 'Your refill request is pending pharmacist review.',
        'notification_type' => 'Refill',
        'date_sent' => '2026-06-03 12:00:00',
        'status' => 'Unread',
    ]);
    insert($pdo, 'drug_interactions', [
        'medication1_id' => 1,
        'medication2_id' => 4,
        'interaction_description' => 'Ibuprofen allergy is listed in patient profile.',
        'severity_level' => 'High',
    ]);
    insert($pdo, 'audit_logs', [
        'user_id' => 2,
        'user_role' => 'pharmacist',
        'action_performed' => 'Seeded system data',
        'description' => 'Initial development data was created.',
    ]);

    $pdo->commit();
}

function dispatch(PDO $pdo): void
{
    $method = $_SERVER['REQUEST_METHOD'];
    $path = parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH) ?? '/';
    $path = preg_replace('#^/api#', '', $path);
    $parts = array_values(array_filter(explode('/', trim($path, '/'))));

    if ($method === 'GET' && route($parts, ['health'])) {
        json(['status' => 'ok', 'service' => 'pharmacare-api']);
    }

    $public = in_array($parts[0] ?? '', ['login', 'register'], true);
    $user = $public ? null : currentUser($pdo);

    if ($method === 'POST' && route($parts, ['login'])) {
        login($pdo);
    }
    if ($method === 'POST' && route($parts, ['register'])) {
        registerPatient($pdo);
    }
    if ($method === 'POST' && route($parts, ['logout'])) {
        requireAuth($user);
        bearerToken() && deleteWhere($pdo, 'auth_tokens', 'token = ?', [bearerToken()]);
        json(['message' => 'Logged out']);
    }
    if ($method === 'GET' && route($parts, ['me'])) {
        requireAuth($user);
        json(['data' => $user]);
    }

    requireAuth($user);

    if ($method === 'GET' && route($parts, ['admin-dashboard'])) {
        requireRole($user, ['admin']);
        json(['data' => ['dashboard' => 'admin', 'user' => publicUser($user)]]);
    }
    if ($method === 'GET' && route($parts, ['pharmacist-dashboard'])) {
        requireRole($user, ['pharmacist']);
        json(['data' => ['dashboard' => 'pharmacist', 'user' => publicUser($user)]]);
    }
    if ($method === 'GET' && route($parts, ['patient-dashboard'])) {
        requireRole($user, ['patient']);
        json(['data' => ['dashboard' => 'patient', 'user' => publicUser($user)]]);
    }

    resource($pdo, $method, $parts, 'patients', 'patient_id', ['admin', 'pharmacist'], $user);
    resource($pdo, $method, $parts, 'pharmacists', 'pharmacist_id', ['admin'], $user);
    adminPharmacists($pdo, $method, $parts, $user);
    stockIn($pdo, $method, $parts, $user);
    resource($pdo, $method, $parts, 'medications', 'medication_id', ['admin', 'pharmacist'], $user);
    prescriptions($pdo, $method, $parts, $user);
    refills($pdo, $method, $parts, $user);
    dispensing($pdo, $method, $parts, $user);
    notifications($pdo, $method, $parts, $user);
    readonly($pdo, $method, $parts, 'drug-interactions', 'drug_interactions', $user);
    readonly($pdo, $method, $parts, 'audit-logs', 'audit_logs', $user, ['admin', 'pharmacist']);

    json(['error' => 'Not found'], 404);
}

function login(PDO $pdo): void
{
    $body = body();
    $username = trim((string) ($body['email'] ?? $body['username'] ?? ''));
    $password = (string) ($body['password'] ?? '');

    $stmt = $pdo->prepare('SELECT * FROM users WHERE email = ? OR username = ? LIMIT 1');
    $stmt->execute([$username, $username]);
    $user = $stmt->fetch();

    if (!$user || !password_verify($password, $user['password_hash'])) {
        json(['error' => 'Invalid credentials'], 401);
    }
    if ((int) ($user['is_active'] ?? 1) !== 1) {
        json(['error' => 'Account is disabled'], 403);
    }

    $token = bin2hex(random_bytes(32));
    insert($pdo, 'auth_tokens', [
        'token' => $token,
        'user_id' => $user['user_id'],
        'expires_at' => date('Y-m-d H:i:s', time() + 86400),
    ]);
    audit($pdo, $user, 'Login', 'User logged in.');

    unset($user['password_hash']);
    json(['token' => $token, 'user' => publicUser($user)]);
}

function registerPatient(PDO $pdo): void
{
    $body = body();
    $fullName = trim((string) ($body['full_name'] ?? ''));
    $email = trim((string) ($body['email'] ?? ''));
    $password = (string) ($body['password'] ?? '');

    if ($fullName === '' || $email === '' || strlen($password) < 6) {
        json(['error' => 'Full name, valid email, and password with at least 6 characters are required'], 422);
    }
    if (queryOne($pdo, 'SELECT user_id FROM users WHERE email = ? LIMIT 1', [$email])) {
        json(['error' => 'Email is already registered'], 422);
    }

    [$first, $last] = splitName($fullName);
    $pdo->beginTransaction();
    $patientId = insert($pdo, 'patients', [
        'first_name' => $first,
        'last_name' => $last,
        'email' => $email,
        'contact_number' => $body['contact_number'] ?? null,
        'allergy_info' => $body['allergy_info'] ?? null,
        'medical_history' => $body['medical_history'] ?? null,
    ]);
    $userId = insert($pdo, 'users', [
        'username' => $email,
        'full_name' => $fullName,
        'email' => $email,
        'password_hash' => password_hash($password, PASSWORD_DEFAULT),
        'role' => 'patient',
        'is_active' => 1,
        'patient_id' => $patientId,
    ]);
    $pdo->commit();

    json(['data' => publicUser(findRow($pdo, 'users', 'user_id', $userId))], 201);
}

function resource(PDO $pdo, string $method, array $parts, string $table, string $pk, array $writeRoles, array $user): void
{
    $route = str_replace('_', '-', $table);
    if (($parts[0] ?? '') !== $route) {
        return;
    }

    if ($table === 'patients' && $user['role'] === 'patient') {
        if ($method === 'GET' && count($parts) === 1) {
            json(['data' => [findRow($pdo, $table, $pk, (int) $user['patient_id'])]]);
        }
        if ($method === 'GET' && count($parts) === 2 && (int) $parts[1] === (int) $user['patient_id']) {
            json(['data' => findRow($pdo, $table, $pk, (int) $parts[1])]);
        }
        json(['error' => 'Forbidden'], 403);
    }

    if ($method === 'GET' && count($parts) === 1) {
        json(['data' => allRows($pdo, $table)]);
    }
    if ($method === 'GET' && count($parts) === 2) {
        json(['data' => findRow($pdo, $table, $pk, (int) $parts[1])]);
    }
    requireRole($user, $writeRoles);
    if ($method === 'POST' && count($parts) === 1) {
        $id = insert($pdo, $table, body());
        audit($pdo, $user, "Created $table", "Created $table #$id");
        json(['data' => findRow($pdo, $table, $pk, $id)], 201);
    }
    if ($method === 'PUT' && count($parts) === 2) {
        update($pdo, $table, $pk, (int) $parts[1], body());
        audit($pdo, $user, "Updated $table", "Updated $table #{$parts[1]}");
        json(['data' => findRow($pdo, $table, $pk, (int) $parts[1])]);
    }
}

function adminPharmacists(PDO $pdo, string $method, array $parts, array $user): void
{
    if (!routePrefix($parts, ['admin', 'pharmacists'])) {
        return;
    }
    requireRole($user, ['admin']);

    if ($method === 'GET' && count($parts) === 2) {
        json(['data' => query($pdo, "SELECT u.user_id AS id, u.full_name, u.email, u.role, u.is_active,
            ph.pharmacist_id, ph.license_number, ph.contact_number
            FROM users u
            LEFT JOIN pharmacists ph ON ph.pharmacist_id = u.pharmacist_id
            WHERE u.role = 'pharmacist'
            ORDER BY u.user_id DESC")]);
    }

    if ($method === 'POST' && count($parts) === 2) {
        $body = body();
        $fullName = trim((string) ($body['full_name'] ?? ''));
        $email = trim((string) ($body['email'] ?? ''));
        $password = (string) ($body['password'] ?? 'password');
        if ($fullName === '' || $email === '') {
            json(['error' => 'Full name and email are required'], 422);
        }
        if (queryOne($pdo, 'SELECT user_id FROM users WHERE email = ? LIMIT 1', [$email])) {
            json(['error' => 'Email is already registered'], 422);
        }

        [$first, $last] = splitName($fullName);
        $pdo->beginTransaction();
        $pharmacistId = insert($pdo, 'pharmacists', [
            'first_name' => $first,
            'last_name' => $last,
            'email' => $email,
            'license_number' => $body['license_number'] ?? null,
            'contact_number' => $body['contact_number'] ?? null,
        ]);
        $userId = insert($pdo, 'users', [
            'username' => $email,
            'full_name' => $fullName,
            'email' => $email,
            'password_hash' => password_hash($password, PASSWORD_DEFAULT),
            'role' => 'pharmacist',
            'is_active' => 1,
            'pharmacist_id' => $pharmacistId,
        ]);
        audit($pdo, $user, 'Created pharmacist', "Created pharmacist user #$userId");
        $pdo->commit();
        json(['data' => publicUser(findRow($pdo, 'users', 'user_id', $userId))], 201);
    }

    if ($method === 'PUT' && count($parts) === 3) {
        $id = (int) $parts[2];
        $target = findRow($pdo, 'users', 'user_id', $id);
        if ($target['role'] !== 'pharmacist') {
            json(['error' => 'Only pharmacist accounts can be edited here'], 422);
        }
        $body = body();
        update($pdo, 'users', 'user_id', $id, array_filter([
            'full_name' => $body['full_name'] ?? null,
            'email' => $body['email'] ?? null,
            'is_active' => isset($body['is_active']) ? (int) $body['is_active'] : null,
        ], fn($value) => $value !== null));
        if (!empty($target['pharmacist_id'])) {
            [$first, $last] = splitName((string) ($body['full_name'] ?? $target['full_name']));
            update($pdo, 'pharmacists', 'pharmacist_id', (int) $target['pharmacist_id'], array_filter([
                'first_name' => $first,
                'last_name' => $last,
                'email' => $body['email'] ?? null,
                'license_number' => $body['license_number'] ?? null,
                'contact_number' => $body['contact_number'] ?? null,
            ], fn($value) => $value !== null));
        }
        audit($pdo, $user, 'Updated pharmacist', "Updated pharmacist user #$id");
        json(['data' => publicUser(findRow($pdo, 'users', 'user_id', $id))]);
    }

    if ($method === 'PUT' && count($parts) === 4 && $parts[3] === 'disable') {
        $id = (int) $parts[2];
        $target = findRow($pdo, 'users', 'user_id', $id);
        if ($target['role'] !== 'pharmacist') {
            json(['error' => 'Only pharmacist accounts can be disabled here'], 422);
        }
        update($pdo, 'users', 'user_id', $id, ['is_active' => 0]);
        audit($pdo, $user, 'Disabled pharmacist', "Disabled pharmacist user #$id");
        json(['data' => publicUser(findRow($pdo, 'users', 'user_id', $id))]);
    }
}

function stockIn(PDO $pdo, string $method, array $parts, array $user): void
{
    if (($parts[0] ?? '') !== 'medications' || count($parts) !== 3 || $parts[2] !== 'stock-in') {
        return;
    }
    if ($method !== 'POST') {
        json(['error' => 'Method not allowed'], 405);
    }

    requireRole($user, ['admin', 'pharmacist']);
    $body = body();
    $quantity = (int) ($body['quantity'] ?? 0);
    if ($quantity <= 0) {
        json(['error' => 'Quantity must be greater than zero'], 422);
    }

    $id = (int) $parts[1];
    $medication = findRow($pdo, 'medications', 'medication_id', $id);
    $newStock = (int) ($medication['stock_quantity'] ?? 0) + $quantity;
    update($pdo, 'medications', 'medication_id', $id, ['stock_quantity' => $newStock]);
    audit(
        $pdo,
        $user,
        'Stock in',
        "Added $quantity units to {$medication['medication_name']}."
    );

    json(['data' => findRow($pdo, 'medications', 'medication_id', $id)]);
}

function prescriptions(PDO $pdo, string $method, array $parts, array $user): void
{
    if (($parts[0] ?? '') !== 'prescriptions') {
        return;
    }

    if ($method === 'GET' && count($parts) === 1) {
        $sql = prescriptionSql($pdo);
        $params = [];
        if ($user['role'] === 'patient') {
            $sql .= ' WHERE p.patient_id = ?';
            $params[] = $user['patient_id'];
        }
        json(['data' => query($pdo, $sql . ' ORDER BY p.prescription_id DESC', $params)]);
    }
    if ($method === 'GET' && count($parts) === 2) {
        json(['data' => findRow($pdo, 'prescriptions', 'prescription_id', (int) $parts[1])]);
    }
    if ($method === 'POST' && count($parts) === 3 && $parts[2] === 'dispense') {
        requireRole($user, ['admin', 'pharmacist']);
        dispensePrescription($pdo, (int) $parts[1], $user);
    }
    if ($method === 'POST' && count($parts) === 1) {
        requireRole($user, ['admin', 'pharmacist']);
        $body = body();
        $pharmacistId = (int) ($body['pharmacist_id'] ?? $user['pharmacist_id'] ?? 0);
        if ($pharmacistId <= 0 && $user['role'] === 'admin') {
            $pharmacist = queryOne($pdo, 'SELECT pharmacist_id FROM pharmacists ORDER BY pharmacist_id LIMIT 1');
            $pharmacistId = (int) ($pharmacist['pharmacist_id'] ?? 0);
        }
        if ($pharmacistId <= 0) {
            json(['error' => 'A pharmacist is required to create a prescription'], 422);
        }

        $id = insert($pdo, 'prescriptions', [
            'patient_id' => $body['patient_id'] ?? null,
            'pharmacist_id' => $pharmacistId,
            'prescription_date' => $body['prescription_date'] ?? date('Y-m-d'),
            'diagnosis' => $body['diagnosis'] ?? null,
            'status' => $body['status'] ?? 'Pending',
            'notes' => $body['notes'] ?? null,
        ]);
        audit($pdo, $user, 'Created prescription', "Created prescription #$id");
        json(['data' => findRow($pdo, 'prescriptions', 'prescription_id', $id)], 201);
    }
    if ($method === 'PUT' && count($parts) === 2) {
        requireRole($user, ['admin', 'pharmacist']);
        update($pdo, 'prescriptions', 'prescription_id', (int) $parts[1], body());
        audit($pdo, $user, 'Updated prescription', "Updated prescription #{$parts[1]}");
        json(['data' => findRow($pdo, 'prescriptions', 'prescription_id', (int) $parts[1])]);
    }
    if ($method === 'POST' && count($parts) === 3 && $parts[2] === 'details') {
        requireRole($user, ['admin', 'pharmacist']);
        $data = body() + ['prescription_id' => (int) $parts[1]];
        $id = insert($pdo, 'prescription_details', $data);
        json(['data' => findRow($pdo, 'prescription_details', 'prescription_detail_id', $id)], 201);
    }
}

function dispensePrescription(PDO $pdo, int $prescriptionId, array $user): void
{
    $body = body();
    $prescription = findRow($pdo, 'prescriptions', 'prescription_id', $prescriptionId);
    if (($prescription['status'] ?? '') === 'Dispensed') {
        json(['error' => 'Prescription is already dispensed'], 422);
    }

    $details = query(
        $pdo,
        'SELECT pd.*, m.medication_name, m.stock_quantity
            FROM prescription_details pd
            JOIN medications m ON m.medication_id = pd.medication_id
            WHERE pd.prescription_id = ?',
        [$prescriptionId]
    );
    if (!$details) {
        json(['error' => 'Prescription has no medication details'], 422);
    }

    foreach ($details as $detail) {
        if ((int) $detail['stock_quantity'] < (int) $detail['quantity']) {
            json(['error' => "Insufficient stock for {$detail['medication_name']}"], 422);
        }
    }

    $pharmacistId = (int) ($user['pharmacist_id'] ?? $prescription['pharmacist_id'] ?? 0);
    if ($pharmacistId <= 0) {
        $pharmacistId = (int) $prescription['pharmacist_id'];
    }
    $quantityDispensed = array_sum(array_map(fn($detail) => (int) $detail['quantity'], $details));

    $pdo->beginTransaction();
    foreach ($details as $detail) {
        update($pdo, 'medications', 'medication_id', (int) $detail['medication_id'], [
            'stock_quantity' => (int) $detail['stock_quantity'] - (int) $detail['quantity'],
        ]);
    }
    $dispenseId = insert($pdo, 'dispensing_records', [
        'prescription_id' => $prescriptionId,
        'pharmacist_id' => $pharmacistId,
        'dispense_date' => $body['dispense_date'] ?? date('Y-m-d'),
        'quantity_dispensed' => $body['quantity_dispensed'] ?? $quantityDispensed,
        'remarks' => $body['remarks'] ?? 'Dispensed through PharmaCare.',
    ]);
    update($pdo, 'prescriptions', 'prescription_id', $prescriptionId, ['status' => 'Dispensed']);
    insert($pdo, 'notifications', [
        'patient_id' => $prescription['patient_id'],
        'message' => "Prescription RX-$prescriptionId has been dispensed.",
        'notification_type' => 'Prescription',
        'date_sent' => date('Y-m-d H:i:s'),
        'status' => 'Unread',
    ]);
    audit($pdo, $user, 'Dispensed prescription', "Dispensed prescription #$prescriptionId");
    $pdo->commit();

    json([
        'data' => [
            'dispensing_record' => findRow($pdo, 'dispensing_records', 'dispense_id', $dispenseId),
            'prescription' => findRow($pdo, 'prescriptions', 'prescription_id', $prescriptionId),
        ],
    ]);
}

function refills(PDO $pdo, string $method, array $parts, array $user): void
{
    if (($parts[0] ?? '') !== 'refill-requests') {
        return;
    }

    if ($method === 'GET' && count($parts) === 1) {
        $name = fullNameSql($pdo, 'p');
        $sql = "SELECT r.*, $name AS patient_name FROM refill_requests r JOIN patients p ON p.patient_id = r.patient_id";
        $params = [];
        if ($user['role'] === 'patient') {
            $sql .= ' WHERE r.patient_id = ?';
            $params[] = $user['patient_id'];
        }
        json(['data' => query($pdo, $sql . ' ORDER BY r.refill_id DESC', $params)]);
    }
    if ($method === 'POST' && count($parts) === 1) {
        $data = body();
        if ($user['role'] === 'patient') {
            $data['patient_id'] = $user['patient_id'];
        } else {
            requireRole($user, ['admin', 'pharmacist']);
        }
        $data['request_date'] ??= date('Y-m-d');
        $data['status'] ??= 'Pending';
        $id = insert($pdo, 'refill_requests', $data);
        audit($pdo, $user, 'Created refill request', "Created refill request #$id");
        json(['data' => findRow($pdo, 'refill_requests', 'refill_id', $id)], 201);
    }
    if ($method === 'PUT' && count($parts) === 3 && in_array($parts[2], ['approve', 'reject'], true)) {
        requireRole($user, ['admin', 'pharmacist']);
        $status = $parts[2] === 'approve' ? 'Approved' : 'Rejected';
        update($pdo, 'refill_requests', 'refill_id', (int) $parts[1], [
            'status' => $status,
            'approval_date' => date('Y-m-d'),
        ]);
        audit($pdo, $user, "$status refill request", "$status refill request #{$parts[1]}");
        json(['data' => findRow($pdo, 'refill_requests', 'refill_id', (int) $parts[1])]);
    }
}

function dispensing(PDO $pdo, string $method, array $parts, array $user): void
{
    if (($parts[0] ?? '') !== 'dispensing-records') {
        return;
    }
    requireRole($user, ['admin', 'pharmacist']);
    if ($method === 'GET') {
        json(['data' => allRows($pdo, 'dispensing_records')]);
    }
    if ($method === 'POST') {
        $id = insert($pdo, 'dispensing_records', body());
        audit($pdo, $user, 'Created dispensing record', "Created dispense #$id");
        json(['data' => findRow($pdo, 'dispensing_records', 'dispense_id', $id)], 201);
    }
}

function notifications(PDO $pdo, string $method, array $parts, array $user): void
{
    if (($parts[0] ?? '') !== 'notifications') {
        return;
    }
    if ($method === 'GET') {
        $params = [];
        $sql = 'SELECT * FROM notifications';
        if ($user['role'] === 'patient') {
            $sql .= ' WHERE patient_id = ?';
            $params[] = $user['patient_id'];
        }
        json(['data' => query($pdo, $sql . ' ORDER BY notification_id DESC', $params)]);
    }
    if ($method === 'PUT' && count($parts) === 3 && $parts[2] === 'read') {
        update($pdo, 'notifications', 'notification_id', (int) $parts[1], ['status' => 'Read']);
        json(['data' => findRow($pdo, 'notifications', 'notification_id', (int) $parts[1])]);
    }
}

function readonly(PDO $pdo, string $method, array $parts, string $route, string $table, array $user, array $roles = []): void
{
    if (($parts[0] ?? '') !== $route) {
        return;
    }
    if ($roles) {
        requireRole($user, $roles);
    }
    if ($method === 'GET') {
        json(['data' => allRows($pdo, $table)]);
    }
}

function prescriptionSql(PDO $pdo): string
{
    $patientName = fullNameSql($pdo, 'pa');
    $pharmacistName = fullNameSql($pdo, 'ph');

    return "SELECT p.*, $patientName AS patient_name,
            $pharmacistName AS pharmacist_name,
            COALESCE(m.medication_name, 'Prescription details') AS medication_name
        FROM prescriptions p
        JOIN patients pa ON pa.patient_id = p.patient_id
        JOIN pharmacists ph ON ph.pharmacist_id = p.pharmacist_id
        LEFT JOIN prescription_details pd ON pd.prescription_id = p.prescription_id
        LEFT JOIN medications m ON m.medication_id = pd.medication_id";
}

function fullNameSql(PDO $pdo, string $alias): string
{
    if ($pdo->getAttribute(PDO::ATTR_DRIVER_NAME) === 'mysql') {
        return "CONCAT($alias.first_name, ' ', $alias.last_name)";
    }

    return "$alias.first_name || ' ' || $alias.last_name";
}

function currentUser(PDO $pdo): ?array
{
    $token = bearerToken();
    if (!$token) {
        return null;
    }
    $sql = 'SELECT u.user_id, u.user_id AS id, u.username, u.full_name, u.email, u.role,
            u.is_active, u.patient_id, u.pharmacist_id
        FROM auth_tokens t JOIN users u ON u.user_id = t.user_id
        WHERE t.token = ? AND t.expires_at > CURRENT_TIMESTAMP AND u.is_active = 1 LIMIT 1';
    return queryOne($pdo, $sql, [$token]) ?: null;
}

function publicUser(array $user): array
{
    return [
        'id' => (int) ($user['user_id'] ?? $user['id']),
        'user_id' => (int) ($user['user_id'] ?? $user['id']),
        'full_name' => $user['full_name'] ?? $user['username'] ?? '',
        'email' => $user['email'] ?? '',
        'role' => $user['role'] ?? 'patient',
        'is_active' => (int) ($user['is_active'] ?? 1),
        'patient_id' => isset($user['patient_id']) ? (int) $user['patient_id'] : null,
        'pharmacist_id' => isset($user['pharmacist_id']) ? (int) $user['pharmacist_id'] : null,
    ];
}

function bearerToken(): ?string
{
    $header = $_SERVER['HTTP_AUTHORIZATION'] ?? '';
    if (preg_match('/Bearer\s+(.+)/', $header, $matches)) {
        return trim($matches[1]);
    }
    return null;
}

function requireAuth(?array $user): void
{
    if (!$user) {
        json(['error' => 'Unauthenticated'], 401);
    }
}

function requireRole(array $user, array $roles): void
{
    if (!in_array($user['role'], $roles, true)) {
        json(['error' => 'Forbidden'], 403);
    }
}

function route(array $parts, array $expected): bool
{
    return $parts === $expected;
}

function routePrefix(array $parts, array $expected): bool
{
    return array_slice($parts, 0, count($expected)) === $expected;
}

function splitName(string $fullName): array
{
    $parts = preg_split('/\s+/', trim($fullName)) ?: ['User'];
    $first = array_shift($parts) ?: 'User';
    $last = trim(implode(' ', $parts)) ?: 'Account';
    return [$first, $last];
}

function body(): array
{
    $raw = file_get_contents('php://input') ?: '{}';
    $data = json_decode($raw, true);
    return is_array($data) ? $data : [];
}

function query(PDO $pdo, string $sql, array $params = []): array
{
    $stmt = $pdo->prepare($sql);
    $stmt->execute($params);
    return $stmt->fetchAll();
}

function queryOne(PDO $pdo, string $sql, array $params = []): ?array
{
    $rows = query($pdo, $sql, $params);
    return $rows[0] ?? null;
}

function allRows(PDO $pdo, string $table): array
{
    return query($pdo, "SELECT * FROM $table ORDER BY 1 DESC");
}

function findRow(PDO $pdo, string $table, string $pk, int $id): array
{
    $row = queryOne($pdo, "SELECT * FROM $table WHERE $pk = ? LIMIT 1", [$id]);
    if (!$row) {
        json(['error' => 'Record not found'], 404);
    }
    return $row;
}

function insert(PDO $pdo, string $table, array $data): int
{
    $data = array_filter($data, fn($value) => $value !== null);
    $columns = array_keys($data);
    $placeholders = array_fill(0, count($columns), '?');
    $sql = sprintf(
        'INSERT INTO %s (%s) VALUES (%s)',
        $table,
        implode(', ', $columns),
        implode(', ', $placeholders)
    );
    $stmt = $pdo->prepare($sql);
    $stmt->execute(array_values($data));
    return (int) $pdo->lastInsertId();
}

function update(PDO $pdo, string $table, string $pk, int $id, array $data): void
{
    unset($data[$pk]);
    if (!$data) {
        return;
    }
    $sets = array_map(fn($column) => "$column = ?", array_keys($data));
    $sql = sprintf('UPDATE %s SET %s WHERE %s = ?', $table, implode(', ', $sets), $pk);
    $stmt = $pdo->prepare($sql);
    $stmt->execute([...array_values($data), $id]);
}

function deleteWhere(PDO $pdo, string $table, string $where, array $params): void
{
    $stmt = $pdo->prepare("DELETE FROM $table WHERE $where");
    $stmt->execute($params);
}

function audit(PDO $pdo, array $user, string $action, string $description): void
{
    insert($pdo, 'audit_logs', [
        'user_id' => $user['user_id'],
        'user_role' => $user['role'],
        'action_performed' => $action,
        'description' => $description,
    ]);
}

function json(array $payload, int $status = 200): never
{
    http_response_code($status);
    echo json_encode($payload, JSON_PRETTY_PRINT);
    exit;
}
