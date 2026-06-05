import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const PharmaCareApp());
}

class PharmaCareApp extends StatelessWidget {
  const PharmaCareApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF07827D);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'PharmaCare Hub',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.light,
          primary: seed,
          secondary: const Color(0xFF2476D2),
          tertiary: const Color(0xFFE5A923),
          surface: const Color(0xFFF7FAF9),
        ),
        scaffoldBackgroundColor: const Color(0xFFF7FAF9),
        fontFamily: 'Roboto',
        cardTheme: CardThemeData(
          elevation: 0,
          color: Colors.white,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: Color(0xFFE5ECEA)),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: ButtonStyle(
            minimumSize: const WidgetStatePropertyAll(Size(44, 44)),
            padding: const WidgetStatePropertyAll(
              EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            ),
            shape: const WidgetStatePropertyAll(StadiumBorder()),
            overlayColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.pressed)
                  ? seed.withValues(alpha: .12)
                  : null,
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: ButtonStyle(
            shape: const WidgetStatePropertyAll(StadiumBorder()),
            padding: const WidgetStatePropertyAll(
              EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
            overlayColor: WidgetStatePropertyAll(seed.withValues(alpha: .08)),
          ),
        ),
        iconButtonTheme: IconButtonThemeData(
          style: ButtonStyle(
            minimumSize: const WidgetStatePropertyAll(Size(42, 42)),
            shape: const WidgetStatePropertyAll(CircleBorder()),
            overlayColor: WidgetStatePropertyAll(seed.withValues(alpha: .08)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 14,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFE5ECEA)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFE5ECEA)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: seed, width: 1.5),
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          height: 72,
          indicatorShape: const StadiumBorder(),
          indicatorColor: seed.withValues(alpha: .16),
          backgroundColor: const Color(0xFFF0F7F5),
        ),
        segmentedButtonTheme: SegmentedButtonThemeData(
          style: ButtonStyle(
            minimumSize: const WidgetStatePropertyAll(Size.fromHeight(44)),
            visualDensity: VisualDensity.compact,
            shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            side: const WidgetStatePropertyAll(
              BorderSide(color: Color(0xFFD8E5E2)),
            ),
          ),
        ),
      ),
      home: const AuthGate(),
    );
  }
}

const apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://127.0.0.1:8000/api',
);

enum UserRole { patient, pharmacist, admin }

class BackendUser {
  const BackendUser({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
    required this.isActive,
    this.patientId,
    this.pharmacistId,
  });

  final int id;
  final String fullName;
  final String email;
  final UserRole role;
  final bool isActive;
  final int? patientId;
  final int? pharmacistId;

  factory BackendUser.fromJson(Map<String, dynamic> json) {
    return BackendUser(
      id: (json['id'] ?? json['user_id']) as int,
      fullName: json['full_name'] as String? ?? json['username'] as String? ?? '',
      email: json['email'] as String? ?? '',
      role: roleFromString(json['role'] as String? ?? 'patient'),
      isActive: (json['is_active'] as int? ?? 1) == 1,
      patientId: json['patient_id'] as int?,
      pharmacistId: json['pharmacist_id'] as int?,
    );
  }
}

class BackendSession {
  const BackendSession({required this.token, required this.user});

  final String token;
  final BackendUser user;
}

class ApiClient {
  const ApiClient({required this.baseUrl, this.token});

  final String baseUrl;
  final String? token;

  ApiClient authenticated(String token) => ApiClient(baseUrl: baseUrl, token: token);

  Future<BackendSession> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    final data = _decode(response);
    return BackendSession(
      token: data['token'] as String,
      user: BackendUser.fromJson(data['user'] as Map<String, dynamic>),
    );
  }

  Future<List<Map<String, dynamic>>> list(String path) async {
    final response = await http.get(Uri.parse('$baseUrl/$path'), headers: _headers);
    final data = _decode(response);
    return (data['data'] as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body) async {
    final response = await http.post(
      Uri.parse('$baseUrl/$path'),
      headers: {..._headers, 'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    final data = _decode(response);
    return data['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> put(String path, Map<String, dynamic> body) async {
    final response = await http.put(
      Uri.parse('$baseUrl/$path'),
      headers: {..._headers, 'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    final data = _decode(response);
    return data['data'] as Map<String, dynamic>;
  }

  Map<String, String> get _headers => {
    if (token != null) 'Authorization': 'Bearer $token',
  };

  Map<String, dynamic> _decode(http.Response response) {
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 400) {
      throw ApiException(data['error'] as String? ?? 'Request failed');
    }
    return data;
  }
}

class ApiException implements Exception {
  const ApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

UserRole roleFromString(String value) {
  return switch (value) {
    'admin' => UserRole.admin,
    'pharmacist' => UserRole.pharmacist,
    _ => UserRole.patient,
  };
}

void showFeatureMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  BackendSession? _session;
  final _api = const ApiClient(baseUrl: apiBaseUrl);

  @override
  Widget build(BuildContext context) {
    final session = _session;
    if (session == null) {
      return LoginScreen(
        api: _api,
        onLogin: (value) => setState(() => _session = value),
      );
    }
    final api = _api.authenticated(session.token);
    if (session.user.role == UserRole.admin) {
      return AdminShell(
        session: session,
        api: api,
        onLogout: () => setState(() => _session = null),
      );
    }
    if (session.user.role == UserRole.patient) {
      return PatientPortalShell(
        session: session,
        api: api,
        onLogout: () => setState(() => _session = null),
      );
    }
    return PharmaCareShell(
      role: session.user.role,
      api: api,
      onLogout: () => setState(() => _session = null),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({required this.api, required this.onLogin, super.key});

  final ApiClient api;
  final ValueChanged<BackendSession> onLogin;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;
  late final TextEditingController _registerNameController;
  late final TextEditingController _registerEmailController;
  late final TextEditingController _registerPasswordController;
  bool _loading = false;
  bool _registering = false;
  bool _showPassword = false;
  String? _error;
  String? _success;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: 'maria@pharmacare.local');
    _passwordController = TextEditingController(text: 'password');
    _registerNameController = TextEditingController();
    _registerEmailController = TextEditingController();
    _registerPasswordController = TextEditingController();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _registerNameController.dispose();
    _registerEmailController.dispose();
    _registerPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFEAF4FF), Color(0xFF7DBCF3)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                    side: const BorderSide(color: Color(0xFFE0E8F2)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 28, 24, 26),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const PharmaCareMark(),
                        const SizedBox(height: 20),
                        Text(
                          'Welcome back!',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF13213A),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Sign in to continue',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: const Color(0xFF66748A),
                          ),
                        ),
                        const SizedBox(height: 24),
                        TextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            hintText: 'Enter your email',
                            prefixIcon: Icon(Icons.mail_outline),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _passwordController,
                          obscureText: !_showPassword,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            hintText: 'Enter your password',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              tooltip: _showPassword ? 'Hide password' : 'Show password',
                              onPressed: () =>
                                  setState(() => _showPassword = !_showPassword),
                              icon: Icon(
                                _showPassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                              ),
                            ),
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () => _showInfo('Password reset is not connected yet.'),
                            child: const Text('Forgot password?'),
                          ),
                        ),
                        if (_error != null) ...[
                          StatusMessage(
                            message: _error!,
                            color: const Color(0xFFD24D57),
                          ),
                          const SizedBox(height: 10),
                        ],
                        if (_success != null) ...[
                          StatusMessage(
                            message: _success!,
                            color: const Color(0xFF07827D),
                          ),
                          const SizedBox(height: 10),
                        ],
                        FilledButton(
                          onPressed: _loading ? null : _login,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Text(_loading ? 'Signing In' : 'Sign In'),
                          ),
                        ),
                        const SizedBox(height: 18),
                        const DividerWithText(text: 'OR'),
                        const SizedBox(height: 18),
                        OutlinedButton.icon(
                          onPressed: () => _showInfo('Google login UI is ready; OAuth client is not connected yet.'),
                          icon: const Text(
                            'G',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF2567D8),
                            ),
                          ),
                          label: const Text('Continue with Google'),
                        ),
                        const SizedBox(height: 18),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text("Don't have an account?"),
                            TextButton(
                              onPressed: _showPatientRegistration,
                              child: const Text('Sign up'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _login() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final session = await widget.api.login(
        _emailController.text.trim(),
        _passwordController.text,
      );
      widget.onLogin(session);
    } catch (error) {
      setState(() => _error = error.toString());
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _showPatientRegistration() async {
    _registerNameController.clear();
    _registerEmailController.clear();
    _registerPasswordController.clear();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Patient Registration',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _registerNameController,
              decoration: const InputDecoration(
                labelText: 'Full name',
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _registerEmailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.mail_outline),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _registerPasswordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Password',
                prefixIcon: Icon(Icons.lock_outline),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _registering ? null : _registerPatient,
              child: Text(_registering ? 'Creating Account' : 'Create Patient Account'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _registerPatient() async {
    final navigator = Navigator.of(context);
    setState(() => _registering = true);
    try {
      await widget.api.post('register', {
        'full_name': _registerNameController.text.trim(),
        'email': _registerEmailController.text.trim(),
        'password': _registerPasswordController.text,
      });
      if (mounted) {
        navigator.pop();
      }
      setState(() {
        _success = 'Patient account created. You can sign in now.';
        _error = null;
        _emailController.text = _registerEmailController.text.trim();
      });
    } catch (error) {
      setState(() {
        _error = error.toString();
        _success = null;
      });
    } finally {
      if (mounted) {
        setState(() => _registering = false);
      }
    }
  }

  void _showInfo(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}

class RoleOption {
  const RoleOption({
    required this.role,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  final UserRole role;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
}

class RoleCard extends StatelessWidget {
  const RoleCard({
    required this.option,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final RoleOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: option.color.withValues(alpha: .14),
                foregroundColor: option.color,
                child: Icon(option.icon),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      option.title,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      option.subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF61726F),
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 160),
                child: selected
                    ? Icon(Icons.check_circle, color: option.color)
                    : const Icon(Icons.radio_button_unchecked),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PharmaCareMark extends StatelessWidget {
  const PharmaCareMark({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 78,
          height: 78,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1E5FD6), Color(0xFF21B6BF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(Icons.local_pharmacy, color: Colors.white, size: 42),
        ),
        const SizedBox(height: 12),
        RichText(
          text: const TextSpan(
            style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900),
            children: [
              TextSpan(text: 'Pharma', style: TextStyle(color: Color(0xFF1E5FD6))),
              TextSpan(text: 'Care', style: TextStyle(color: Color(0xFF21A7B7))),
            ],
          ),
        ),
      ],
    );
  }
}

class DividerWithText extends StatelessWidget {
  const DividerWithText({required this.text, super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            text,
            style: const TextStyle(
              color: Color(0xFF66748A),
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const Expanded(child: Divider()),
      ],
    );
  }
}

class PharmaCareShell extends StatefulWidget {
  const PharmaCareShell({
    required this.role,
    required this.api,
    required this.onLogout,
    super.key,
  });

  final UserRole role;
  final ApiClient api;
  final VoidCallback onLogout;

  @override
  State<PharmaCareShell> createState() => _PharmaCareShellState();
}

class AdminShell extends StatefulWidget {
  const AdminShell({
    required this.session,
    required this.api,
    required this.onLogout,
    super.key,
  });

  final BackendSession session;
  final ApiClient api;
  final VoidCallback onLogout;

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _selectedIndex = 0;

  late final List<Widget> _screens = [
    AdminDashboardScreen(api: widget.api, session: widget.session),
    PharmacistManagementScreen(api: widget.api),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(child: _screens[_selectedIndex]),
      floatingActionButton: FloatingActionButton.small(
        heroTag: 'admin-logout',
        tooltip: 'Logout',
        onPressed: widget.onLogout,
        child: const Icon(Icons.logout),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) =>
            setState(() => _selectedIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.admin_panel_settings_outlined),
            selectedIcon: Icon(Icons.admin_panel_settings),
            label: 'Admin',
          ),
          NavigationDestination(
            icon: Icon(Icons.local_pharmacy_outlined),
            selectedIcon: Icon(Icons.local_pharmacy),
            label: 'Users',
          ),
        ],
      ),
    );
  }
}

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({
    required this.api,
    required this.session,
    super.key,
  });

  final ApiClient api;
  final BackendSession session;

  @override
  Widget build(BuildContext context) {
    return ListPage(
      title: 'Admin Dashboard',
      subtitle: 'Signed in as ${session.user.fullName}',
      actionIcon: Icons.security,
      children: [
        const InventorySummary(),
        const SizedBox(height: 14),
        SectionHeader(title: 'Audit Logs'),
        const SizedBox(height: 8),
        ApiList(
          loader: () => api.list('audit-logs'),
          itemBuilder: (item) => AuditTile(auditFromApi(item)),
        ),
      ],
    );
  }
}

class PharmacistManagementScreen extends StatefulWidget {
  const PharmacistManagementScreen({required this.api, super.key});

  final ApiClient api;

  @override
  State<PharmacistManagementScreen> createState() =>
      _PharmacistManagementScreenState();
}

class _PharmacistManagementScreenState
    extends State<PharmacistManagementScreen> {
  int _refresh = 0;

  @override
  Widget build(BuildContext context) {
    return ListPage(
      title: 'Pharmacists',
      subtitle: 'Add, edit, disable, and view pharmacist accounts.',
      actionIcon: Icons.person_add_alt_1,
      children: [
        FilledButton.icon(
          onPressed: _showAddPharmacist,
          icon: const Icon(Icons.person_add_alt_1),
          label: const Text('Add Pharmacist'),
        ),
        const SizedBox(height: 14),
        ApiList(
          key: ValueKey(_refresh),
          loader: () => widget.api.list('admin/pharmacists'),
          itemBuilder: _pharmacistTile,
        ),
      ],
    );
  }

  Widget _pharmacistTile(Map<String, dynamic> item) {
    final active = (item['is_active'] as int? ?? 1) == 1;
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: active
              ? const Color(0xFF07827D).withValues(alpha: .14)
              : const Color(0xFFD24D57).withValues(alpha: .14),
          foregroundColor: active ? const Color(0xFF07827D) : const Color(0xFFD24D57),
          child: const Icon(Icons.local_pharmacy_outlined),
        ),
        title: Text(
          item['full_name'] as String? ?? 'Pharmacist',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(item['email'] as String? ?? ''),
        trailing: Wrap(
          spacing: 4,
          children: [
            IconButton(
              tooltip: 'Edit',
              onPressed: () => _showEditPharmacist(item),
              icon: const Icon(Icons.edit_outlined),
            ),
            IconButton(
              tooltip: 'Disable',
              onPressed: active ? () => _disablePharmacist(item) : null,
              icon: const Icon(Icons.block),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddPharmacist() async {
    await _showPharmacistSheet();
  }

  Future<void> _showEditPharmacist(Map<String, dynamic> item) async {
    await _showPharmacistSheet(item: item);
  }

  Future<void> _showPharmacistSheet({Map<String, dynamic>? item}) async {
    final name = TextEditingController(text: item?['full_name'] as String? ?? '');
    final email = TextEditingController(text: item?['email'] as String? ?? '');
    final license = TextEditingController(text: item?['license_number'] as String? ?? '');
    final contact = TextEditingController(text: item?['contact_number'] as String? ?? '');
    final password = TextEditingController(text: 'password');

    final navigator = Navigator.of(context);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              item == null ? 'Add Pharmacist' : 'Edit Pharmacist',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 14),
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Full name')),
            const SizedBox(height: 10),
            TextField(controller: email, decoration: const InputDecoration(labelText: 'Email')),
            const SizedBox(height: 10),
            TextField(controller: license, decoration: const InputDecoration(labelText: 'License number')),
            const SizedBox(height: 10),
            TextField(controller: contact, decoration: const InputDecoration(labelText: 'Contact number')),
            if (item == null) ...[
              const SizedBox(height: 10),
              TextField(
                controller: password,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Temporary password'),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () async {
                final payload = {
                  'full_name': name.text.trim(),
                  'email': email.text.trim(),
                  'license_number': license.text.trim(),
                  'contact_number': contact.text.trim(),
                  if (item == null) 'password': password.text,
                };
                if (item == null) {
                  await widget.api.post('admin/pharmacists', payload);
                } else {
                  await widget.api.put('admin/pharmacists/${item['id']}', payload);
                }
                if (mounted) {
                  navigator.pop();
                  setState(() => _refresh++);
                }
              },
              child: Text(item == null ? 'Create Pharmacist' : 'Save Changes'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _disablePharmacist(Map<String, dynamic> item) async {
    await widget.api.put('admin/pharmacists/${item['id']}/disable', {});
    setState(() => _refresh++);
  }
}

class _PharmaCareShellState extends State<PharmaCareShell> {
  int _selectedIndex = 0;

  late final List<Widget> _screens = [
    DashboardScreen(api: widget.api),
    PatientsScreen(api: widget.api),
    PrescriptionsScreen(api: widget.api),
    InventoryScreen(api: widget.api),
    AlertsScreen(api: widget.api),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            _screens[_selectedIndex],
            Positioned(
              right: 12,
              bottom: 86,
              child: FloatingActionButton.small(
                heroTag: 'staff-logout',
                tooltip: 'Logout',
                onPressed: widget.onLogout,
                child: const Icon(Icons.logout),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        onDestinationSelected: (index) =>
            setState(() => _selectedIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.groups_2_outlined),
            selectedIcon: Icon(Icons.groups_2),
            label: 'Patients',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Rx',
          ),
          NavigationDestination(
            icon: Icon(Icons.medication_liquid_outlined),
            selectedIcon: Icon(Icons.medication_liquid),
            label: 'Stock',
          ),
          NavigationDestination(
            icon: Icon(Icons.notifications_none),
            selectedIcon: Icon(Icons.notifications),
            label: 'Alerts',
          ),
        ],
      ),
    );
  }
}

class PatientPortalShell extends StatefulWidget {
  const PatientPortalShell({
    required this.session,
    required this.api,
    required this.onLogout,
    super.key,
  });

  final BackendSession session;
  final ApiClient api;
  final VoidCallback onLogout;

  @override
  State<PatientPortalShell> createState() => _PatientPortalShellState();
}

class _PatientPortalShellState extends State<PatientPortalShell> {
  int _selectedIndex = 0;

  late final List<Widget> _screens = [
    PatientHomeScreen(api: widget.api, session: widget.session),
    PatientPrescriptionsScreen(api: widget.api),
    PatientRefillsScreen(api: widget.api),
    PatientAccountScreen(api: widget.api, onLogout: widget.onLogout),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(child: _screens[_selectedIndex]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        onDestinationSelected: (index) =>
            setState(() => _selectedIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Rx',
          ),
          NavigationDestination(
            icon: Icon(Icons.sync_outlined),
            selectedIcon: Icon(Icons.sync),
            label: 'Refills',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Account',
          ),
        ],
      ),
    );
  }
}

class PatientHomeScreen extends StatefulWidget {
  const PatientHomeScreen({required this.api, required this.session, super.key});

  final ApiClient api;
  final BackendSession session;

  @override
  State<PatientHomeScreen> createState() => _PatientHomeScreenState();
}

class _PatientHomeScreenState extends State<PatientHomeScreen> {
  int _notificationRefresh = 0;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: AppHeader(
            title: 'Hi, ${widget.session.user.fullName.split(' ').first}',
            subtitle: 'Your prescriptions, refill requests, and reminders.',
            trailing: IconButton.filledTonal(
              tooltip: 'Notifications',
              onPressed: () =>
                  showFeatureMessage(context, 'Scroll down to view reminders.'),
              icon: const Icon(Icons.notifications_outlined),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          sliver: SliverList.list(
            children: [
              const PatientSummaryStrip(),
              const SizedBox(height: 16),
              SectionHeader(title: 'Active Prescriptions'),
              const SizedBox(height: 8),
              ApiList(
                loader: () => widget.api.list('prescriptions'),
                itemBuilder: (item) =>
                    PatientPrescriptionCard(prescriptionFromApi(item)),
              ),
              const SizedBox(height: 16),
              SectionHeader(title: 'Reminders'),
              const SizedBox(height: 8),
              ApiList(
                key: ValueKey(_notificationRefresh),
                loader: () => widget.api.list('notifications'),
                itemBuilder: (item) {
                  final notification = notificationFromApi(item);
                  return NotificationCard(
                    notification,
                    onRead: notification.isRead
                        ? null
                        : () => _markNotificationRead(notification),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _markNotificationRead(SafetyAlert notification) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await widget.api.put('notifications/${notification.id}/read', {});
      if (!mounted) {
        return;
      }
      setState(() => _notificationRefresh++);
      messenger.showSnackBar(
        const SnackBar(content: Text('Notification marked as read.')),
      );
    } catch (err) {
      messenger.showSnackBar(SnackBar(content: Text(err.toString())));
    }
  }
}

class PatientPrescriptionsScreen extends StatelessWidget {
  const PatientPrescriptionsScreen({required this.api, super.key});

  final ApiClient api;

  @override
  Widget build(BuildContext context) {
    return ListPage(
      title: 'My Prescriptions',
      subtitle: 'View medicines, diagnosis, dosage, and status.',
      actionIcon: Icons.download_outlined,
      children: [
        const SegmentedFilter(labels: ['Active', 'History', 'Dispensed']),
        const SizedBox(height: 14),
        ApiList(
          loader: () => api.list('prescriptions'),
          itemBuilder: (item) =>
              PatientPrescriptionCard(prescriptionFromApi(item)),
        ),
      ],
    );
  }
}

class PatientRefillsScreen extends StatefulWidget {
  const PatientRefillsScreen({required this.api, super.key});

  final ApiClient api;

  @override
  State<PatientRefillsScreen> createState() => _PatientRefillsScreenState();
}

class _PatientRefillsScreenState extends State<PatientRefillsScreen> {
  int _refresh = 0;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    return ListPage(
      title: 'Refill Requests',
      subtitle: 'Request refills and track pharmacist approval.',
      actionIcon: Icons.add_circle_outline,
      children: [
        RefillRequestForm(
          api: widget.api,
          onSubmitted: () => setState(() => _refresh++),
        ),
        const SizedBox(height: 14),
        SectionHeader(title: 'Request History'),
        const SizedBox(height: 8),
        SearchField(
          hint: 'Search refill history',
          onChanged: (value) => setState(() => _query = value),
        ),
        const SizedBox(height: 8),
        ApiList(
          key: ValueKey(_refresh),
          loader: () => widget.api.list('refill-requests'),
          filter: (item) => matchesQuery(item, _query, [
            'prescription_id',
            'request_date',
            'status',
            'notes',
          ]),
          itemBuilder: (item) => RefillTile(refillFromApi(item)),
        ),
      ],
    );
  }
}

class PatientAccountScreen extends StatelessWidget {
  const PatientAccountScreen({required this.api, required this.onLogout, super.key});

  final ApiClient api;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return ListPage(
      title: 'My Account',
      subtitle: 'Profile, allergies, history, and notification settings.',
      actionIcon: Icons.edit_outlined,
      children: [
        ApiList(
          loader: () => api.list('patients'),
          itemBuilder: (item) => PatientCard(patientFromApi(item)),
        ),
        const SizedBox(height: 4),
        SectionHeader(title: 'Notification Preferences'),
        const SizedBox(height: 8),
        const PreferenceTile(
          icon: Icons.medication_outlined,
          title: 'Medication reminders',
          subtitle: 'Daily reminders for active prescriptions.',
          enabled: true,
        ),
        const PreferenceTile(
          icon: Icons.sync_outlined,
          title: 'Refill updates',
          subtitle: 'Get notified when refills are approved.',
          enabled: true,
        ),
        const PreferenceTile(
          icon: Icons.warning_amber_rounded,
          title: 'Safety alerts',
          subtitle: 'Receive allergy and interaction warnings.',
          enabled: true,
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: onLogout,
          icon: const Icon(Icons.logout),
          label: const Text('Logout'),
        ),
      ],
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({required this.api, super.key});

  final ApiClient api;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _refillRefresh = 0;
  String _refillQuery = '';

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: AppHeader(
            title: 'Welcome back, Maria',
            subtitle: 'Centralized pharmaceutical care for today.',
            trailing: IconButton.filledTonal(
              tooltip: 'Search',
              onPressed: () =>
                  showFeatureMessage(context, 'Use the search fields inside each module.'),
              icon: const Icon(Icons.search),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
          sliver: SliverList.list(
            children: [
              const StatCarousel(),
              const SizedBox(height: 16),
              const PrescriptionChartCard(),
              const SizedBox(height: 16),
              const CareBanner(),
              const SizedBox(height: 16),
              SectionHeader(title: 'Recent Prescriptions', action: 'View all'),
              const SizedBox(height: 8),
              ApiList(
                loader: () => widget.api.list('prescriptions'),
                itemBuilder: (item) => PrescriptionTile(prescriptionFromApi(item)),
              ),
              const SizedBox(height: 16),
              SectionHeader(title: 'Medication Stock', action: 'Inventory'),
              const SizedBox(height: 8),
              ApiList(
                loader: () => widget.api.list('medications'),
                itemBuilder: (item) => MedicationStockTile(medicationFromApi(item)),
              ),
              const SizedBox(height: 16),
              SectionHeader(title: 'Pending Refills', action: 'Review'),
              const SizedBox(height: 8),
              SearchField(
                hint: 'Search refill requests',
                onChanged: (value) => setState(() => _refillQuery = value),
              ),
              const SizedBox(height: 8),
              ApiList(
                key: ValueKey(_refillRefresh),
                loader: () => widget.api.list('refill-requests'),
                filter: (item) => matchesQuery(item, _refillQuery, [
                  'patient_name',
                  'prescription_id',
                  'request_date',
                  'status',
                  'notes',
                ]),
                itemBuilder: (item) {
                  final refill = refillFromApi(item);
                  return RefillTile(
                    refill,
                    onApprove: refill.status == 'Pending'
                        ? () => _decideRefill(refill, 'approve')
                        : null,
                    onReject: refill.status == 'Pending'
                        ? () => _decideRefill(refill, 'reject')
                        : null,
                  );
                },
              ),
              const SizedBox(height: 16),
              SectionHeader(title: 'Quick Actions'),
              const SizedBox(height: 8),
              const QuickActionsGrid(),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _decideRefill(RefillRequest refill, String action) async {
    final messenger = ScaffoldMessenger.of(context);
    final label = action == 'approve' ? 'approved' : 'rejected';
    try {
      await widget.api.put('refill-requests/${refill.id}/$action', {});
      if (!mounted) {
        return;
      }
      setState(() => _refillRefresh++);
      messenger.showSnackBar(
        SnackBar(content: Text('Refill request $label.')),
      );
    } catch (err) {
      messenger.showSnackBar(
        SnackBar(content: Text(err.toString())),
      );
    }
  }
}

class PatientsScreen extends StatefulWidget {
  const PatientsScreen({required this.api, super.key});

  final ApiClient api;

  @override
  State<PatientsScreen> createState() => _PatientsScreenState();
}

class _PatientsScreenState extends State<PatientsScreen> {
  int _refresh = 0;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    return ListPage(
      title: 'Patients',
      subtitle: 'Profiles, allergies, history, and contact details.',
      actionIcon: Icons.person_add_alt_1,
      onAction: () => _showPatientForm(),
      children: [
        SearchField(
          hint: 'Search patient records',
          onChanged: (value) => setState(() => _query = value),
        ),
        const SizedBox(height: 14),
        ApiList(
          key: ValueKey(_refresh),
          loader: () => widget.api.list('patients'),
          filter: (item) => matchesQuery(item, _query, [
            'first_name',
            'last_name',
            'contact_number',
            'email',
            'allergy_info',
            'medical_history',
          ]),
          itemBuilder: (item) {
            final patient = patientFromApi(item);
            return PatientCard(
              patient,
              onEdit: () => _showPatientForm(patient: patient),
            );
          },
        ),
      ],
    );
  }

  Future<void> _showPatientForm({Patient? patient}) async {
    final firstName = TextEditingController(text: patient?.firstName ?? '');
    final lastName = TextEditingController(text: patient?.lastName ?? '');
    final birthDate = TextEditingController(text: patient?.birthDate == 'Not set' ? '' : patient?.birthDate ?? '');
    final gender = TextEditingController(text: patient?.gender ?? '');
    final address = TextEditingController(text: patient?.address ?? '');
    final contact = TextEditingController(text: patient?.contact == 'No contact' ? '' : patient?.contact ?? '');
    final email = TextEditingController(text: patient?.email ?? '');
    final allergy = TextEditingController(text: patient?.allergy == 'No known allergy' ? '' : patient?.allergy ?? '');
    final history = TextEditingController(text: patient?.history == 'No history' ? '' : patient?.history ?? '');
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    bool saving = false;
    String? error;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          Future<void> save() async {
            if (firstName.text.trim().isEmpty || lastName.text.trim().isEmpty) {
              setModalState(() {
                error = 'First name and last name are required.';
              });
              return;
            }
            setModalState(() {
              saving = true;
              error = null;
            });
            final payload = {
              'first_name': firstName.text.trim(),
              'last_name': lastName.text.trim(),
              'birth_date': birthDate.text.trim(),
              'gender': gender.text.trim(),
              'address': address.text.trim(),
              'contact_number': contact.text.trim(),
              'email': email.text.trim(),
              'allergy_info': allergy.text.trim(),
              'medical_history': history.text.trim(),
            };
            try {
              if (patient == null) {
                await widget.api.post('patients', payload);
              } else {
                await widget.api.put('patients/${patient.id}', payload);
              }
              if (!mounted) {
                return;
              }
              navigator.pop();
              setState(() => _refresh++);
              messenger.showSnackBar(
                SnackBar(
                  content: Text(
                    patient == null ? 'Patient added.' : 'Patient updated.',
                  ),
                ),
              );
            } catch (err) {
              setModalState(() {
                error = err.toString();
              });
            } finally {
              setModalState(() => saving = false);
            }
          }

          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    patient == null ? 'Add Patient' : 'Edit Patient',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: firstName,
                          decoration: const InputDecoration(
                            labelText: 'First name',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: lastName,
                          decoration: const InputDecoration(labelText: 'Last name'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: birthDate,
                          keyboardType: TextInputType.datetime,
                          decoration: const InputDecoration(
                            labelText: 'Birth date',
                            hintText: 'YYYY-MM-DD',
                            prefixIcon: Icon(Icons.cake_outlined),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: gender,
                          decoration: const InputDecoration(labelText: 'Gender'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: contact,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Contact number',
                      prefixIcon: Icon(Icons.call_outlined),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.mail_outline),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: address,
                    decoration: const InputDecoration(
                      labelText: 'Address',
                      prefixIcon: Icon(Icons.home_outlined),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: allergy,
                    decoration: const InputDecoration(
                      labelText: 'Allergy info',
                      prefixIcon: Icon(Icons.warning_amber_rounded),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: history,
                    minLines: 2,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Medical history',
                      prefixIcon: Icon(Icons.history),
                    ),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 10),
                    StatusMessage(message: error!, color: const Color(0xFFD24D57)),
                  ],
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: saving ? null : save,
                    icon: saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(saving ? 'Saving' : 'Save Patient'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class PrescriptionsScreen extends StatefulWidget {
  const PrescriptionsScreen({required this.api, super.key});

  final ApiClient api;

  @override
  State<PrescriptionsScreen> createState() => _PrescriptionsScreenState();
}

class _PrescriptionsScreenState extends State<PrescriptionsScreen> {
  int _refresh = 0;
  String _query = '';
  String _status = 'All';

  @override
  Widget build(BuildContext context) {
    return ListPage(
      title: 'Prescriptions',
      subtitle: 'Track status, diagnosis, notes, and dispensing.',
      actionIcon: Icons.add_chart,
      onAction: _showNewPrescription,
      children: [
        SearchField(
          hint: 'Search prescriptions',
          onChanged: (value) => setState(() => _query = value),
        ),
        const SizedBox(height: 10),
        SegmentedFilter(
          labels: const ['All', 'Pending', 'Dispensed'],
          onChanged: (value) => setState(() => _status = value),
        ),
        const SizedBox(height: 14),
        ApiList(
          key: ValueKey(_refresh),
          loader: () => widget.api.list('prescriptions'),
          filter: (item) {
            final statusOk = _status == 'All' || item['status'] == _status;
            return statusOk &&
                matchesQuery(item, _query, [
                  'patient_name',
                  'prescription_id',
                  'diagnosis',
                  'medication_name',
                  'pharmacist_name',
                  'status',
                ]);
          },
          itemBuilder: (item) {
            final prescription = prescriptionFromApi(item);
            return PrescriptionDetailCard(
              prescription,
              onDispense: prescription.status == 'Dispensed'
                  ? null
                  : () => _showDispensePrescription(prescription),
            );
          },
        ),
      ],
    );
  }

  Future<void> _showNewPrescription() async {
    final diagnosis = TextEditingController();
    final dosage = TextEditingController();
    final frequency = TextEditingController();
    final duration = TextEditingController();
    final quantity = TextEditingController();
    final notes = TextEditingController();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final now = DateTime.now();
    final date =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    bool saving = false;
    String? error;
    int? patientId;
    int? medicationId;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => FutureBuilder<List<List<Map<String, dynamic>>>>(
        future: Future.wait([
          widget.api.list('patients'),
          widget.api.list('medications'),
        ]),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasError) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: StatusMessage(
                message: snapshot.error.toString(),
                color: const Color(0xFFD24D57),
              ),
            );
          }

          final patients = snapshot.data?[0] ?? [];
          final medications = snapshot.data?[1] ?? [];
          patientId ??= patients.isNotEmpty ? intFrom(patients.first, 'patient_id') : null;
          medicationId ??=
              medications.isNotEmpty ? intFrom(medications.first, 'medication_id') : null;

          return StatefulBuilder(
            builder: (context, setModalState) {
              Future<void> save() async {
                if (patientId == null || medicationId == null) {
                  setModalState(() {
                    error = 'Patient and medication are required.';
                  });
                  return;
                }
                setModalState(() {
                  saving = true;
                  error = null;
                });
                try {
                  final prescription = await widget.api.post('prescriptions', {
                    'patient_id': patientId,
                    'prescription_date': date,
                    'diagnosis': diagnosis.text.trim(),
                    'status': 'Pending',
                    'notes': notes.text.trim(),
                  });
                  final prescriptionId = intFrom(prescription, 'prescription_id');
                  await widget.api.post('prescriptions/$prescriptionId/details', {
                    'medication_id': medicationId,
                    'dosage': dosage.text.trim(),
                    'frequency': frequency.text.trim(),
                    'duration': duration.text.trim(),
                    'quantity': int.tryParse(quantity.text.trim()) ?? 1,
                  });
                  if (!mounted) {
                    return;
                  }
                  navigator.pop();
                  setState(() => _refresh++);
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Prescription created.')),
                  );
                } catch (err) {
                  setModalState(() {
                    error = err.toString();
                  });
                } finally {
                  setModalState(() => saving = false);
                }
              }

              return Padding(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 20,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'New Prescription',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<int>(
                        initialValue: patientId,
                        decoration: const InputDecoration(
                          labelText: 'Patient',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        items: [
                          for (final patient in patients)
                            DropdownMenuItem(
                              value: intFrom(patient, 'patient_id'),
                              child: Text(patientName(patient)),
                            ),
                        ],
                        onChanged: (value) => setModalState(() => patientId = value),
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<int>(
                        initialValue: medicationId,
                        decoration: const InputDecoration(
                          labelText: 'Medication',
                          prefixIcon: Icon(Icons.medication_outlined),
                        ),
                        items: [
                          for (final medication in medications)
                            DropdownMenuItem(
                              value: intFrom(medication, 'medication_id'),
                              child: Text(
                                medication['medication_name'] as String? ?? 'Medication',
                              ),
                            ),
                        ],
                        onChanged: (value) =>
                            setModalState(() => medicationId = value),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: diagnosis,
                        decoration: const InputDecoration(
                          labelText: 'Diagnosis',
                          prefixIcon: Icon(Icons.medical_information_outlined),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: dosage,
                              decoration: const InputDecoration(
                                labelText: 'Dosage',
                                hintText: '1 tablet',
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: frequency,
                              decoration: const InputDecoration(
                                labelText: 'Frequency',
                                hintText: 'Every 8 hrs',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: duration,
                              decoration: const InputDecoration(
                                labelText: 'Duration',
                                hintText: '5 days',
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: quantity,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Quantity',
                                hintText: '15',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: notes,
                        minLines: 2,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Notes',
                          prefixIcon: Icon(Icons.notes_outlined),
                        ),
                      ),
                      if (error != null) ...[
                        const SizedBox(height: 10),
                        StatusMessage(
                          message: error!,
                          color: const Color(0xFFD24D57),
                        ),
                      ],
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: saving ? null : save,
                        icon: saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.save_outlined),
                        label: Text(saving ? 'Saving' : 'Save Prescription'),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _showDispensePrescription(Prescription prescription) async {
    final remarks = TextEditingController();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    bool saving = false;
    String? error;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          Future<void> save() async {
            setModalState(() {
              saving = true;
              error = null;
            });
            try {
              await widget.api.post('prescriptions/${prescription.rxId}/dispense', {
                'remarks': remarks.text.trim(),
              });
              if (!mounted) {
                return;
              }
              navigator.pop();
              setState(() => _refresh++);
              messenger.showSnackBar(
                SnackBar(content: Text('${prescription.id} dispensed.')),
              );
            } catch (err) {
              setModalState(() {
                error = err.toString();
              });
            } finally {
              setModalState(() => saving = false);
            }
          }

          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Dispense Prescription',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  prescription.id,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  '${prescription.patient} • ${prescription.medication}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: remarks,
                  minLines: 2,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Remarks',
                    hintText: 'Optional dispensing notes',
                    prefixIcon: Icon(Icons.notes_outlined),
                  ),
                ),
                if (error != null) ...[
                  const SizedBox(height: 10),
                  StatusMessage(message: error!, color: const Color(0xFFD24D57)),
                ],
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: saving ? null : save,
                  icon: saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.local_pharmacy_outlined),
                  label: Text(saving ? 'Dispensing' : 'Confirm Dispense'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({required this.api, super.key});

  final ApiClient api;

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  int _refresh = 0;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    return ListPage(
      title: 'Inventory',
      subtitle: 'Stock levels, expiration, and reorder monitoring.',
      actionIcon: Icons.add_box_outlined,
      onAction: _showAddMedication,
      children: [
        const InventorySummary(),
        const SizedBox(height: 14),
        SearchField(
          hint: 'Search inventory',
          onChanged: (value) => setState(() => _query = value),
        ),
        const SizedBox(height: 14),
        ApiList(
          key: ValueKey(_refresh),
          loader: () => widget.api.list('medications'),
          filter: (item) => matchesQuery(item, _query, [
            'medication_name',
            'description',
            'dosage_form',
            'strength',
            'manufacturer',
            'status',
          ]),
          itemBuilder: (item) {
            final medication = medicationFromApi(item);
            return MedicationInventoryCard(
              medication,
              onStockIn: () => _showStockIn(medication),
              onEdit: () => _showEditMedication(medication),
            );
          },
        ),
      ],
    );
  }

  Future<void> _showAddMedication() async {
    final name = TextEditingController();
    final description = TextEditingController();
    final dosageForm = TextEditingController();
    final strength = TextEditingController();
    final manufacturer = TextEditingController();
    final expirationDate = TextEditingController();
    final stockQuantity = TextEditingController();
    final reorderLevel = TextEditingController();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    bool saving = false;
    String? error;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          Future<void> save() async {
            setModalState(() {
              saving = true;
              error = null;
            });
            try {
              await widget.api.post('medications', {
                'medication_name': name.text.trim(),
                'description': description.text.trim(),
                'dosage_form': dosageForm.text.trim(),
                'strength': strength.text.trim(),
                'manufacturer': manufacturer.text.trim(),
                'expiration_date': expirationDate.text.trim(),
                'stock_quantity': int.tryParse(stockQuantity.text.trim()) ?? 0,
                'reorder_level': int.tryParse(reorderLevel.text.trim()) ?? 0,
              });
              if (!mounted) {
                return;
              }
              navigator.pop();
              setState(() => _refresh++);
              messenger.showSnackBar(
                const SnackBar(content: Text('Medication added to inventory.')),
              );
            } catch (err) {
              setModalState(() {
                error = err.toString();
              });
            } finally {
              setModalState(() => saving = false);
            }
          }

          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Add Medication',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: name,
                    decoration: const InputDecoration(
                      labelText: 'Medication name',
                      prefixIcon: Icon(Icons.medication_outlined),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: dosageForm,
                    decoration: const InputDecoration(
                      labelText: 'Dosage form',
                      hintText: 'Tablet, capsule, syrup',
                      prefixIcon: Icon(Icons.category_outlined),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: strength,
                    decoration: const InputDecoration(
                      labelText: 'Strength',
                      hintText: '500mg',
                      prefixIcon: Icon(Icons.science_outlined),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: manufacturer,
                    decoration: const InputDecoration(
                      labelText: 'Manufacturer',
                      prefixIcon: Icon(Icons.business_outlined),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: expirationDate,
                    keyboardType: TextInputType.datetime,
                    decoration: const InputDecoration(
                      labelText: 'Expiration date',
                      hintText: 'YYYY-MM-DD',
                      prefixIcon: Icon(Icons.event_outlined),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: stockQuantity,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Stock',
                            prefixIcon: Icon(Icons.inventory_2_outlined),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: reorderLevel,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Reorder',
                            prefixIcon: Icon(Icons.warning_amber_rounded),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: description,
                    minLines: 2,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      prefixIcon: Icon(Icons.notes_outlined),
                    ),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 10),
                    StatusMessage(message: error!, color: const Color(0xFFD24D57)),
                  ],
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: saving ? null : save,
                    icon: saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(saving ? 'Saving' : 'Save Medication'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _showStockIn(Medication medication) async {
    final quantity = TextEditingController();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    bool saving = false;
    String? error;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          Future<void> save() async {
            final amount = int.tryParse(quantity.text.trim()) ?? 0;
            if (amount <= 0) {
              setModalState(() {
                error = 'Enter a stock quantity greater than zero.';
              });
              return;
            }
            setModalState(() {
              saving = true;
              error = null;
            });
            try {
              await widget.api.post('medications/${medication.id}/stock-in', {
                'quantity': amount,
              });
              if (!mounted) {
                return;
              }
              navigator.pop();
              setState(() => _refresh++);
              messenger.showSnackBar(
                SnackBar(
                  content: Text('Added $amount stock to ${medication.name}.'),
                ),
              );
            } catch (err) {
              setModalState(() {
                error = err.toString();
              });
            } finally {
              setModalState(() => saving = false);
            }
          }

          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Stock In',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  medication.name,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Current stock: ${medication.stock}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: quantity,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Quantity received',
                    prefixIcon: Icon(Icons.add_box_outlined),
                  ),
                  onSubmitted: (_) => saving ? null : save(),
                ),
                if (error != null) ...[
                  const SizedBox(height: 10),
                  StatusMessage(message: error!, color: const Color(0xFFD24D57)),
                ],
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: saving ? null : save,
                  icon: saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.inventory_2_outlined),
                  label: Text(saving ? 'Saving' : 'Save Stock In'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _showEditMedication(Medication medication) async {
    final name = TextEditingController(text: medication.name);
    final description = TextEditingController(text: medication.description);
    final dosageForm = TextEditingController(text: medication.dosageForm);
    final strength = TextEditingController(text: medication.strength);
    final manufacturer = TextEditingController(text: medication.manufacturer);
    final expirationDate = TextEditingController(text: medication.expiry == 'No expiry' ? '' : medication.expiry);
    final stockQuantity = TextEditingController(text: '${medication.stock}');
    final reorderLevel = TextEditingController(text: '${medication.reorderLevel}');
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    bool saving = false;
    String? error;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          Future<void> save() async {
            setModalState(() {
              saving = true;
              error = null;
            });
            try {
              await widget.api.put('medications/${medication.id}', {
                'medication_name': name.text.trim(),
                'description': description.text.trim(),
                'dosage_form': dosageForm.text.trim(),
                'strength': strength.text.trim(),
                'manufacturer': manufacturer.text.trim(),
                'expiration_date': expirationDate.text.trim(),
                'stock_quantity': int.tryParse(stockQuantity.text.trim()) ?? 0,
                'reorder_level': int.tryParse(reorderLevel.text.trim()) ?? 0,
              });
              if (!mounted) {
                return;
              }
              navigator.pop();
              setState(() => _refresh++);
              messenger.showSnackBar(
                const SnackBar(content: Text('Medication updated.')),
              );
            } catch (err) {
              setModalState(() {
                error = err.toString();
              });
            } finally {
              setModalState(() => saving = false);
            }
          }

          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Edit Medication',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: name,
                    decoration: const InputDecoration(
                      labelText: 'Medication name',
                      prefixIcon: Icon(Icons.medication_outlined),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: dosageForm,
                          decoration: const InputDecoration(labelText: 'Dosage form'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: strength,
                          decoration: const InputDecoration(labelText: 'Strength'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: manufacturer,
                    decoration: const InputDecoration(
                      labelText: 'Manufacturer',
                      prefixIcon: Icon(Icons.business_outlined),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: expirationDate,
                    keyboardType: TextInputType.datetime,
                    decoration: const InputDecoration(
                      labelText: 'Expiration date',
                      hintText: 'YYYY-MM-DD',
                      prefixIcon: Icon(Icons.event_outlined),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: stockQuantity,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Stock'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: reorderLevel,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Reorder'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: description,
                    minLines: 2,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      prefixIcon: Icon(Icons.notes_outlined),
                    ),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 10),
                    StatusMessage(message: error!, color: const Color(0xFFD24D57)),
                  ],
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: saving ? null : save,
                    icon: saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(saving ? 'Saving' : 'Save Changes'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class AlertsScreen extends StatelessWidget {
  const AlertsScreen({required this.api, super.key});

  final ApiClient api;

  @override
  Widget build(BuildContext context) {
    return ListPage(
      title: 'Safety Alerts',
      subtitle: 'Interactions, allergies, reminders, and audit activity.',
      actionIcon: Icons.tune,
      children: [
        ApiList(
          loader: () => api.list('drug-interactions'),
          itemBuilder: (item) => AlertCard(interactionFromApi(item)),
        ),
        const SizedBox(height: 14),
        SectionHeader(title: 'Audit Logs'),
        const SizedBox(height: 8),
        ApiList(
          loader: () => api.list('audit-logs'),
          itemBuilder: (item) => AuditTile(auditFromApi(item)),
        ),
      ],
    );
  }
}

class AppHeader extends StatelessWidget {
  const AppHeader({
    required this.title,
    required this.subtitle,
    this.trailing,
    super.key,
  });

  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 22),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF046D68), Color(0xFF0AA79E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .16),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withValues(alpha: .3)),
            ),
            child: const Icon(Icons.local_pharmacy, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: .86),
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 10), trailing!],
        ],
      ),
    );
  }
}

class ListPage extends StatelessWidget {
  const ListPage({
    required this.title,
    required this.subtitle,
    required this.actionIcon,
    required this.children,
    this.onAction,
    super.key,
  });

  final String title;
  final String subtitle;
  final IconData actionIcon;
  final List<Widget> children;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: AppHeader(
            title: title,
            subtitle: subtitle,
            trailing: IconButton.filledTonal(
              tooltip: title,
              onPressed: onAction ??
                  () => showFeatureMessage(
                    context,
                    '$title action is ready for backend form integration.',
                  ),
              icon: Icon(actionIcon),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          sliver: SliverList.separated(
            itemCount: children.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) => children[index],
          ),
        ),
      ],
    );
  }
}

class StatCarousel extends StatelessWidget {
  const StatCarousel({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 118,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: dashboardStats.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) => StatCard(dashboardStats[index]),
      ),
    );
  }
}

class StatCard extends StatelessWidget {
  const StatCard(this.stat, {super.key});

  final DashboardStat stat;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 172,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: stat.color.withValues(alpha: .14),
                    foregroundColor: stat.color,
                    child: Icon(stat.icon, size: 21),
                  ),
                  const Spacer(),
                  Icon(Icons.trending_up, size: 16, color: stat.color),
                ],
              ),
              const Spacer(),
              Text(
                stat.value,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF17211F),
                ),
              ),
              Text(
                stat.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: const Color(0xFF61726F)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PrescriptionChartCard extends StatelessWidget {
  const PrescriptionChartCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Prescription Overview',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const Text('This Week'),
                const Icon(Icons.keyboard_arrow_down),
              ],
            ),
            const SizedBox(height: 8),
            const Row(
              children: [
                LegendDot(color: Color(0xFF46A184), label: 'Prescriptions'),
                SizedBox(width: 18),
                LegendDot(color: Color(0xFF2476D2), label: 'Dispensed'),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 180,
              width: double.infinity,
              child: CustomPaint(painter: LineChartPainter()),
            ),
          ],
        ),
      ),
    );
  }
}

class LineChartPainter extends CustomPainter {
  const LineChartPainter();

  static const List<double> prescribed = [28, 38, 37, 45, 35, 41, 34];
  static const List<double> dispensed = [13, 19, 21, 30, 20, 22, 17];

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = const Color(0xFFE6EEEB)
      ..strokeWidth = 1;
    final axisPaint = Paint()
      ..color = const Color(0xFFB8C8C4)
      ..strokeWidth = 1.2;

    const left = 28.0;
    const bottom = 24.0;
    final chart = Rect.fromLTWH(
      left,
      4,
      size.width - left - 4,
      size.height - bottom - 4,
    );

    for (var i = 0; i <= 4; i++) {
      final y = chart.top + chart.height * i / 4;
      canvas.drawLine(Offset(chart.left, y), Offset(chart.right, y), gridPaint);
    }
    canvas.drawLine(
      Offset(chart.left, chart.bottom),
      Offset(chart.right, chart.bottom),
      axisPaint,
    );

    _drawSeries(canvas, chart, prescribed, const Color(0xFF46A184));
    _drawSeries(canvas, chart, dispensed, const Color(0xFF2476D2));

    final textStyle = const TextStyle(color: Color(0xFF667773), fontSize: 10);
    for (final entry in [
      'Mon',
      'Tue',
      'Wed',
      'Thu',
      'Fri',
      'Sat',
      'Sun',
    ].asMap().entries) {
      final x = chart.left + chart.width * entry.key / 6;
      final tp = TextPainter(
        text: TextSpan(text: entry.value, style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x - tp.width / 2, chart.bottom + 8));
    }
  }

  void _drawSeries(
    Canvas canvas,
    Rect chart,
    List<double> values,
    Color color,
  ) {
    final path = Path();
    final fill = Path();
    final maxValue = 55.0;

    Offset point(int index) {
      final x = chart.left + chart.width * index / (values.length - 1);
      final y = chart.bottom - chart.height * values[index] / maxValue;
      return Offset(x, y);
    }

    for (var i = 0; i < values.length; i++) {
      final p = point(i);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
        fill.moveTo(p.dx, chart.bottom);
        fill.lineTo(p.dx, p.dy);
      } else {
        final previous = point(i - 1);
        final controlX = (previous.dx + p.dx) / 2;
        path.cubicTo(controlX, previous.dy, controlX, p.dy, p.dx, p.dy);
        fill.cubicTo(controlX, previous.dy, controlX, p.dy, p.dx, p.dy);
      }
    }

    fill
      ..lineTo(chart.right, chart.bottom)
      ..close();

    canvas.drawPath(fill, Paint()..color = color.withValues(alpha: .08));
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    for (var i = 0; i < values.length; i++) {
      canvas.drawCircle(point(i), 3.4, Paint()..color = Colors.white);
      canvas.drawCircle(point(i), 2.4, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class LegendDot extends StatelessWidget {
  const LegendDot({required this.color, required this.label, super.key});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class CareBanner extends StatelessWidget {
  const CareBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 240,
      decoration: BoxDecoration(
        color: const Color(0xFF07827D),
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: CareBannerPainter())),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Better Care.\nStronger Connections.',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    height: 1.12,
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: 190,
                  child: Text(
                    'Manage prescriptions, refills, and safety alerts in one hub.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: .9),
                    ),
                  ),
                ),
                const Spacer(),
                FilledButton.tonal(
                  onPressed: () => showFeatureMessage(
                    context,
                    'PharmaCare manages patients, prescriptions, inventory, and refills.',
                  ),
                  child: const Text('Learn More'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class CareBannerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withValues(alpha: .12);
    for (var i = 0; i < 9; i++) {
      final x = size.width * .54 + i * 18;
      final h = (22 + (i % 3) * 12).toDouble();
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, size.height - h - 12, 10, h),
          const Radius.circular(3),
        ),
        paint,
      );
    }

    final circlePaint = Paint()..color = Colors.white.withValues(alpha: .18);
    canvas.drawCircle(
      Offset(size.width * .82, size.height * .33),
      50,
      circlePaint,
    );

    final doctorPaint = Paint()..color = const Color(0xFFEAF7F5);
    final patientPaint = Paint()..color = const Color(0xFF9AD0A0);
    canvas.drawCircle(
      Offset(size.width * .68, 62),
      22,
      Paint()..color = const Color(0xFFF2C29C),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * .61, 78, 70, 80),
        const Radius.circular(18),
      ),
      doctorPaint,
    );
    canvas.drawCircle(
      Offset(size.width * .84, 75),
      19,
      Paint()..color = const Color(0xFFD79A74),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * .79, 92, 62, 72),
        const Radius.circular(16),
      ),
      patientPaint,
    );

    final shield = Path()
      ..moveTo(size.width * .77, 18)
      ..lineTo(size.width * .88, 38)
      ..quadraticBezierTo(size.width * .86, 84, size.width * .77, 98)
      ..quadraticBezierTo(size.width * .68, 84, size.width * .66, 38)
      ..close();
    canvas.drawPath(
      shield,
      Paint()
        ..color = Colors.transparent
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      shield,
      Paint()
        ..color = Colors.white.withValues(alpha: .62)
        ..strokeWidth = 4
        ..style = PaintingStyle.stroke,
    );
    final crossPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.square;
    canvas.drawLine(
      Offset(size.width * .77, 48),
      Offset(size.width * .77, 76),
      crossPaint,
    );
    canvas.drawLine(
      Offset(size.width * .72, 62),
      Offset(size.width * .82, 62),
      crossPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({required this.title, this.action, super.key});

  final String title;
  final String? action;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        if (action != null)
          TextButton(
            onPressed: () =>
                showFeatureMessage(context, '$action section is available from navigation.'),
            child: Text(action!),
          ),
      ],
    );
  }
}

class PrescriptionTile extends StatelessWidget {
  const PrescriptionTile(this.prescription, {super.key});

  final Prescription prescription;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: InitialAvatar(
          name: prescription.patient,
          color: prescription.color,
        ),
        title: Text(
          prescription.patient,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text('${prescription.id} • ${prescription.date}'),
        trailing: StatusChip(
          label: prescription.status,
          color: prescription.statusColor,
        ),
      ),
    );
  }
}

class PrescriptionDetailCard extends StatelessWidget {
  const PrescriptionDetailCard(this.prescription, {this.onDispense, super.key});

  final Prescription prescription;
  final VoidCallback? onDispense;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                InitialAvatar(
                  name: prescription.patient,
                  color: prescription.color,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        prescription.patient,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        prescription.id,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                StatusChip(
                  label: prescription.status,
                  color: prescription.statusColor,
                ),
              ],
            ),
            const SizedBox(height: 12),
            InfoRow(
              icon: Icons.event_outlined,
              label: 'Date',
              value: prescription.date.isEmpty ? 'Not set' : prescription.date,
            ),
            InfoRow(
              icon: Icons.medical_information_outlined,
              label: 'Diagnosis',
              value: prescription.diagnosis,
            ),
            InfoRow(
              icon: Icons.medication_outlined,
              label: 'Medication',
              value: prescription.medication,
            ),
            InfoRow(
              icon: Icons.person_pin_outlined,
              label: 'Pharmacist',
              value: prescription.pharmacist,
            ),
            if (onDispense != null) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.tonalIcon(
                  onPressed: onDispense,
                  icon: const Icon(Icons.local_pharmacy_outlined),
                  label: const Text('Dispense'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class MedicationStockTile extends StatelessWidget {
  const MedicationStockTile(this.medication, {super.key});

  final Medication medication;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: medication.color.withValues(alpha: .12),
          foregroundColor: medication.color,
          child: Icon(medication.icon),
        ),
        title: Text(
          medication.name,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${medication.stock} units'),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: medication.progress,
                minHeight: 7,
                color: medication.color,
                backgroundColor: medication.color.withValues(alpha: .12),
              ),
            ),
          ],
        ),
        trailing: Text(
          medication.status,
          style: TextStyle(
            color: medication.color,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class MedicationInventoryCard extends StatelessWidget {
  const MedicationInventoryCard(
    this.medication, {
    this.onStockIn,
    this.onEdit,
    super.key,
  });

  final Medication medication;
  final VoidCallback? onStockIn;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: medication.color.withValues(alpha: .12),
                  foregroundColor: medication.color,
                  child: Icon(medication.icon),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        medication.name,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        medication.form,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                StatusChip(label: medication.status, color: medication.color),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: medication.progress,
                minHeight: 8,
                color: medication.color,
                backgroundColor: medication.color.withValues(alpha: .12),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Metric(label: 'Stock', value: '${medication.stock}'),
                ),
                Expanded(
                  child: Metric(
                    label: 'Reorder',
                    value: '${medication.reorderLevel}',
                  ),
                ),
                Expanded(
                  child: Metric(label: 'Expires', value: medication.expiry),
                ),
              ],
            ),
            if (onStockIn != null || onEdit != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Edit'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: onStockIn,
                      icon: const Icon(Icons.add),
                      label: const Text('Stock In'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class RefillTile extends StatelessWidget {
  const RefillTile(this.refill, {this.onApprove, this.onReject, super.key});

  final RefillRequest refill;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                InitialAvatar(
                  name: refill.patient,
                  color: refill.statusColor,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        refill.patient,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        '${refill.medication} • ${refill.date}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                StatusChip(label: refill.status, color: refill.statusColor),
              ],
            ),
            if (onApprove != null || onReject != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onReject,
                      icon: const Icon(Icons.close),
                      label: const Text('Reject'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: onApprove,
                      icon: const Icon(Icons.check),
                      label: const Text('Approve'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class PatientCard extends StatelessWidget {
  const PatientCard(this.patient, {this.onEdit, super.key});

  final Patient patient;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                InitialAvatar(name: patient.name, color: patient.color),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        patient.name,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        patient.contact,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Edit patient',
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                ),
              ],
            ),
            const SizedBox(height: 10),
            InfoRow(
              icon: Icons.cake_outlined,
              label: 'Birth date',
              value: patient.birthDate,
            ),
            InfoRow(
              icon: Icons.warning_amber_rounded,
              label: 'Allergy',
              value: patient.allergy,
            ),
            InfoRow(
              icon: Icons.history,
              label: 'History',
              value: patient.history,
            ),
          ],
        ),
      ),
    );
  }
}

class AlertCard extends StatelessWidget {
  const AlertCard(this.alert, {super.key});

  final SafetyAlert alert;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: alert.color.withValues(alpha: .14),
              foregroundColor: alert.color,
              child: Icon(alert.icon),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          alert.title,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      Text(
                        alert.time,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(alert.message),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AuditTile extends StatelessWidget {
  const AuditTile(this.log, {super.key});

  final AuditLog log;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.fact_check_outlined)),
        title: Text(
          log.action,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text('${log.userRole} • ${log.dateTime}'),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}

class StatusMessage extends StatelessWidget {
  const StatusMessage({required this.message, required this.color, super.key});

  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: .18)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: color, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class ApiList extends StatelessWidget {
  const ApiList({
    required this.loader,
    required this.itemBuilder,
    this.filter,
    super.key,
  });

  final Future<List<Map<String, dynamic>>> Function() loader;
  final Widget Function(Map<String, dynamic> item) itemBuilder;
  final bool Function(Map<String, dynamic> item)? filter;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: loader(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingCard();
        }
        if (snapshot.hasError) {
          return StatusMessage(
            message: snapshot.error.toString(),
            color: const Color(0xFFD24D57),
          );
        }
        final items = (snapshot.data ?? []).where((item) {
          final itemFilter = filter;
          return itemFilter == null || itemFilter(item);
        }).toList();
        if (items.isEmpty) {
          return const EmptyCard();
        }
        return Column(
          children: [
            for (final item in items) ...[
              itemBuilder(item),
              const SizedBox(height: 8),
            ],
          ],
        );
      },
    );
  }
}

class LoadingCard extends StatelessWidget {
  const LoadingCard({super.key});

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(18),
        child: Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class EmptyCard extends StatelessWidget {
  const EmptyCard({super.key});

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Text('No records found.'),
      ),
    );
  }
}

class PatientSummaryStrip extends StatelessWidget {
  const PatientSummaryStrip({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        Expanded(
          child: SummaryPill(
            icon: Icons.receipt_long_outlined,
            value: '3',
            label: 'Active Rx',
          ),
        ),
        SizedBox(width: 10),
        Expanded(
          child: SummaryPill(icon: Icons.sync, value: '1', label: 'Refill'),
        ),
        SizedBox(width: 10),
        Expanded(
          child: SummaryPill(
            icon: Icons.notifications_outlined,
            value: '4',
            label: 'Alerts',
          ),
        ),
      ],
    );
  }
}

class PatientPrescriptionCard extends StatelessWidget {
  const PatientPrescriptionCard(this.prescription, {super.key});

  final Prescription prescription;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                InitialAvatar(
                  name: prescription.medication,
                  color: prescription.statusColor,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        prescription.medication,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      Text(
                        prescription.id,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                StatusChip(
                  label: prescription.status,
                  color: prescription.statusColor,
                ),
              ],
            ),
            const SizedBox(height: 12),
            InfoRow(
              icon: Icons.medical_information_outlined,
              label: 'Diagnosis',
              value: prescription.diagnosis,
            ),
            const InfoRow(
              icon: Icons.schedule_outlined,
              label: 'Frequency',
              value: 'Every 8 hours',
            ),
            const InfoRow(
              icon: Icons.timelapse_outlined,
              label: 'Duration',
              value: '5 days',
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: () => showFeatureMessage(
                      context,
                      'Open the Refills tab to submit a refill request.',
                    ),
                    icon: const Icon(Icons.sync),
                    label: const Text('Request Refill'),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton.filledTonal(
                  tooltip: 'Download',
                  onPressed: () => showFeatureMessage(
                    context,
                    'Prescription download will be enabled when PDF export is added.',
                  ),
                  icon: const Icon(Icons.download_outlined),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class RefillRequestForm extends StatefulWidget {
  const RefillRequestForm({required this.api, this.onSubmitted, super.key});

  final ApiClient api;
  final VoidCallback? onSubmitted;

  @override
  State<RefillRequestForm> createState() => _RefillRequestFormState();
}

class _RefillRequestFormState extends State<RefillRequestForm> {
  final _notesController = TextEditingController();
  int _prescriptionId = 1;
  bool _loading = false;
  String? _message;
  Color _messageColor = const Color(0xFF07827D);

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'New Refill Request',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: _prescriptionId,
              decoration: const InputDecoration(
                labelText: 'Prescription',
                prefixIcon: Icon(Icons.receipt_long_outlined),
              ),
              items: [
                for (final rx in recentPrescriptions.take(3).toList().asMap().entries)
                  DropdownMenuItem(
                    value: rx.key + 1,
                    child: Text(rx.value.medication),
                  ),
              ],
              onChanged: (value) => setState(() => _prescriptionId = value ?? 1),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _notesController,
              minLines: 2,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Notes',
                prefixIcon: Icon(Icons.notes_outlined),
              ),
            ),
            if (_message != null) ...[
              const SizedBox(height: 10),
              StatusMessage(message: _message!, color: _messageColor),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _loading ? null : _submit,
                icon: _loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_outlined),
                label: Text(_loading ? 'Submitting' : 'Submit Request'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _message = null;
    });
    try {
      await widget.api.post('refill-requests', {
        'prescription_id': _prescriptionId,
        'notes': _notesController.text.trim(),
      });
      setState(() {
        _message = 'Refill request submitted.';
        _messageColor = const Color(0xFF07827D);
        _notesController.clear();
      });
      widget.onSubmitted?.call();
    } catch (error) {
      setState(() {
        _message = error.toString();
        _messageColor = const Color(0xFFD24D57);
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }
}

class NotificationCard extends StatelessWidget {
  const NotificationCard(this.notification, {this.onRead, super.key});

  final SafetyAlert notification;
  final VoidCallback? onRead;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: notification.color.withValues(alpha: .14),
          foregroundColor: notification.color,
          child: Icon(notification.icon),
        ),
        title: Text(
          notification.title,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(notification.message),
        trailing: onRead == null
            ? Text(
                notification.isRead ? 'Read' : notification.time,
                style: Theme.of(context).textTheme.bodySmall,
              )
            : IconButton.filledTonal(
                tooltip: 'Mark as read',
                onPressed: onRead,
                icon: const Icon(Icons.done),
              ),
      ),
    );
  }
}

class PreferenceTile extends StatelessWidget {
  const PreferenceTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.enabled,
    super.key,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      value: enabled,
      onChanged: (_) => showFeatureMessage(
        context,
        'Notification preference saved for the demo session.',
      ),
      secondary: Icon(icon),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text(subtitle),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      tileColor: Colors.white,
    );
  }
}

class QuickActionsGrid extends StatelessWidget {
  const QuickActionsGrid({super.key});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 2.9,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: quickActions
          .map((action) => QuickActionButton(action))
          .toList(),
    );
  }
}

class QuickActionButton extends StatelessWidget {
  const QuickActionButton(this.action, {super.key});

  final QuickAction action;

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonalIcon(
      onPressed: () => showFeatureMessage(
        context,
        '${action.label} action is ready for backend workflow integration.',
      ),
      icon: Icon(action.icon, color: action.color),
      label: Text(action.label, overflow: TextOverflow.ellipsis),
      style: FilledButton.styleFrom(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        side: BorderSide(color: action.color.withValues(alpha: .14)),
      ),
    );
  }
}

class SearchField extends StatelessWidget {
  const SearchField({required this.hint, this.onChanged, super.key});

  final String hint;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(Icons.search),
      ),
    );
  }
}

class SegmentedFilter extends StatefulWidget {
  const SegmentedFilter({required this.labels, this.onChanged, super.key});

  final List<String> labels;
  final ValueChanged<String>? onChanged;

  @override
  State<SegmentedFilter> createState() => _SegmentedFilterState();
}

class _SegmentedFilterState extends State<SegmentedFilter> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<int>(
      segments: [
        for (final entry in widget.labels.asMap().entries)
          ButtonSegment(value: entry.key, label: Text(entry.value)),
      ],
      selected: {_index},
      onSelectionChanged: (value) {
        setState(() => _index = value.first);
        widget.onChanged?.call(widget.labels[value.first]);
      },
    );
  }
}

class InventorySummary extends StatelessWidget {
  const InventorySummary({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        Expanded(
          child: SummaryPill(
            icon: Icons.inventory_2_outlined,
            value: '256',
            label: 'Items',
          ),
        ),
        SizedBox(width: 10),
        Expanded(
          child: SummaryPill(
            icon: Icons.warning_amber_rounded,
            value: '12',
            label: 'Low stock',
          ),
        ),
        SizedBox(width: 10),
        Expanded(
          child: SummaryPill(
            icon: Icons.event_busy_outlined,
            value: '9',
            label: 'Expiring',
          ),
        ),
      ],
    );
  }
}

class SummaryPill extends StatelessWidget {
  const SummaryPill({
    required this.icon,
    required this.value,
    required this.label,
    super.key,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
            ),
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}

class InitialAvatar extends StatelessWidget {
  const InitialAvatar({required this.name, required this.color, super.key});

  final String name;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final parts = name.trim().split(RegExp(r'\s+'));
    final initials = parts.take(2).map((part) => part[0]).join();

    return CircleAvatar(
      backgroundColor: color.withValues(alpha: .14),
      foregroundColor: color,
      child: Text(
        initials,
        style: const TextStyle(fontWeight: FontWeight.w900),
      ),
    );
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip({required this.label, required this.color, super.key});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: .18)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }
}

class InfoRow extends StatelessWidget {
  const InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    super.key,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 7),
      child: Row(
        children: [
          Icon(icon, size: 17, color: const Color(0xFF607571)),
          const SizedBox(width: 8),
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w700)),
          Expanded(child: Text(value, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }
}

class Metric extends StatelessWidget {
  const Metric({required this.label, required this.value, super.key});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
      ],
    );
  }
}

class DashboardStat {
  const DashboardStat(this.label, this.value, this.icon, this.color);

  final String label;
  final String value;
  final IconData icon;
  final Color color;
}

class Prescription {
  const Prescription({
    required this.rxId,
    required this.patient,
    required this.id,
    required this.date,
    required this.status,
    required this.statusColor,
    required this.medication,
    required this.diagnosis,
    required this.pharmacist,
    required this.color,
  });

  final int rxId;
  final String patient;
  final String id;
  final String date;
  final String status;
  final Color statusColor;
  final String medication;
  final String diagnosis;
  final String pharmacist;
  final Color color;
}

class Medication {
  const Medication({
    required this.id,
    required this.name,
    required this.description,
    required this.dosageForm,
    required this.strength,
    required this.manufacturer,
    required this.form,
    required this.stock,
    required this.reorderLevel,
    required this.expiry,
    required this.status,
    required this.progress,
    required this.color,
    required this.icon,
  });

  final int id;
  final String name;
  final String description;
  final String dosageForm;
  final String strength;
  final String manufacturer;
  final String form;
  final int stock;
  final int reorderLevel;
  final String expiry;
  final String status;
  final double progress;
  final Color color;
  final IconData icon;
}

class Patient {
  const Patient({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.name,
    required this.birthDate,
    required this.gender,
    required this.address,
    required this.contact,
    required this.email,
    required this.allergy,
    required this.history,
    required this.color,
  });

  final int id;
  final String firstName;
  final String lastName;
  final String name;
  final String birthDate;
  final String gender;
  final String address;
  final String contact;
  final String email;
  final String allergy;
  final String history;
  final Color color;
}

class RefillRequest {
  const RefillRequest(
    this.id,
    this.patient,
    this.medication,
    this.date,
    this.status,
    this.statusColor,
  );

  final int id;
  final String patient;
  final String medication;
  final String date;
  final String status;
  final Color statusColor;
}

class SafetyAlert {
  const SafetyAlert(
    this.id,
    this.title,
    this.message,
    this.time,
    this.icon,
    this.color, {
    this.isRead = false,
  });

  final int id;
  final String title;
  final String message;
  final String time;
  final IconData icon;
  final Color color;
  final bool isRead;
}

class AuditLog {
  const AuditLog(this.action, this.userRole, this.dateTime);

  final String action;
  final String userRole;
  final String dateTime;
}

class QuickAction {
  const QuickAction(this.label, this.icon, this.color);

  final String label;
  final IconData icon;
  final Color color;
}

Patient patientFromApi(Map<String, dynamic> item) {
  final first = item['first_name'] as String? ?? '';
  final last = item['last_name'] as String? ?? '';
  return Patient(
    id: intFrom(item, 'patient_id'),
    firstName: first,
    lastName: last,
    name: '$first $last'.trim(),
    birthDate: item['birth_date'] as String? ?? 'Not set',
    gender: item['gender'] as String? ?? '',
    address: item['address'] as String? ?? '',
    contact: item['contact_number'] as String? ?? 'No contact',
    email: item['email'] as String? ?? '',
    allergy: item['allergy_info'] as String? ?? 'No known allergy',
    history: item['medical_history'] as String? ?? 'No history',
    color: const Color(0xFF07827D),
  );
}

int intFrom(Map<String, dynamic> item, String key) {
  final value = item[key];
  if (value is int) {
    return value;
  }
  return int.tryParse('$value') ?? 0;
}

String patientName(Map<String, dynamic> item) {
  final first = item['first_name'] as String? ?? '';
  final last = item['last_name'] as String? ?? '';
  final fullName = '$first $last'.trim();
  return fullName.isEmpty ? 'Patient #${item['patient_id']}' : fullName;
}

bool matchesQuery(Map<String, dynamic> item, String query, List<String> keys) {
  final needle = query.trim().toLowerCase();
  if (needle.isEmpty) {
    return true;
  }
  return keys.any((key) => '${item[key] ?? ''}'.toLowerCase().contains(needle));
}

Prescription prescriptionFromApi(Map<String, dynamic> item) {
  final status = item['status'] as String? ?? 'Pending';
  return Prescription(
    rxId: intFrom(item, 'prescription_id'),
    patient: item['patient_name'] as String? ?? 'Patient #${item['patient_id']}',
    id: 'RX-${item['prescription_id']}',
    date: item['prescription_date'] as String? ?? '',
    status: status,
    statusColor: statusColor(status),
    medication: item['medication_name'] as String? ?? 'Prescription details',
    diagnosis: item['diagnosis'] as String? ?? 'No diagnosis',
    pharmacist: item['pharmacist_name'] as String? ?? 'Assigned pharmacist',
    color: const Color(0xFF2476D2),
  );
}

Medication medicationFromApi(Map<String, dynamic> item) {
  final stock = item['stock_quantity'] is int
      ? item['stock_quantity'] as int
      : int.tryParse('${item['stock_quantity']}') ?? 0;
  final reorder = item['reorder_level'] is int
      ? item['reorder_level'] as int
      : int.tryParse('${item['reorder_level']}') ?? 0;
  final lowStock = stock <= reorder;
  return Medication(
    id: item['medication_id'] is int
        ? item['medication_id'] as int
        : int.tryParse('${item['medication_id']}') ?? 0,
    name: item['medication_name'] as String? ?? 'Medication',
    description: item['description'] as String? ?? '',
    dosageForm: item['dosage_form'] as String? ?? '',
    strength: item['strength'] as String? ?? '',
    manufacturer: item['manufacturer'] as String? ?? '',
    form:
        '${item['dosage_form'] as String? ?? 'Form'} • ${item['manufacturer'] as String? ?? 'Manufacturer'}',
    stock: stock,
    reorderLevel: reorder,
    expiry: item['expiration_date'] as String? ?? 'No expiry',
    status: lowStock ? 'Low Stock' : 'In Stock',
    progress: stock <= 0 ? 0 : (stock / (stock + reorder + 1)).clamp(0.0, 1.0),
    color: lowStock ? const Color(0xFFE5A923) : const Color(0xFF4F9F62),
    icon: Icons.medication,
  );
}

RefillRequest refillFromApi(Map<String, dynamic> item) {
  final status = item['status'] as String? ?? 'Pending';
  return RefillRequest(
    intFrom(item, 'refill_id'),
    item['patient_name'] as String? ?? 'Patient #${item['patient_id']}',
    'Prescription #${item['prescription_id']}',
    item['request_date'] as String? ?? '',
    status,
    statusColor(status),
  );
}

SafetyAlert notificationFromApi(Map<String, dynamic> item) {
  final isRead = (item['status'] as String? ?? 'Unread') == 'Read';
  return SafetyAlert(
    intFrom(item, 'notification_id'),
    item['notification_type'] as String? ?? 'Notification',
    item['message'] as String? ?? '',
    item['date_sent'] as String? ?? '',
    Icons.notifications_active_outlined,
    isRead ? const Color(0xFF8A98A4) : const Color(0xFF2476D2),
    isRead: isRead,
  );
}

SafetyAlert interactionFromApi(Map<String, dynamic> item) {
  final severity = item['severity_level'] as String? ?? 'Info';
  return SafetyAlert(
    intFrom(item, 'interaction_id'),
    'Drug interaction',
    item['interaction_description'] as String? ?? '',
    severity,
    Icons.dangerous_outlined,
    severity == 'High' ? const Color(0xFFD24D57) : const Color(0xFFE5A923),
  );
}

AuditLog auditFromApi(Map<String, dynamic> item) {
  return AuditLog(
    item['action_performed'] as String? ?? 'Activity',
    item['user_role'] as String? ?? 'User',
    item['date_time'] as String? ?? '',
  );
}

Color statusColor(String status) {
  return switch (status.toLowerCase()) {
    'dispensed' || 'approved' || 'in stock' => const Color(0xFF4F9F62),
    'partial' || 'pending' => const Color(0xFFE5A923),
    'rejected' || 'low stock' => const Color(0xFFD24D57),
    _ => const Color(0xFF2476D2),
  };
}

const dashboardStats = [
  DashboardStat(
    'Total Patients',
    '1,248',
    Icons.groups_2_outlined,
    Color(0xFF07827D),
  ),
  DashboardStat(
    'Today Rx',
    '32',
    Icons.receipt_long_outlined,
    Color(0xFF2476D2),
  ),
  DashboardStat('Refill Requests', '14', Icons.sync, Color(0xFFE5A923)),
  DashboardStat(
    'Medications',
    '256',
    Icons.medication_outlined,
    Color(0xFF4F9F62),
  ),
  DashboardStat(
    'Expiring Soon',
    '9',
    Icons.event_busy_outlined,
    Color(0xFFD24D57),
  ),
];

const recentPrescriptions = [
  Prescription(
    rxId: 1,
    patient: 'Juan Dela Cruz',
    id: 'RX-202515-001',
    date: 'May 15, 2025',
    status: 'Dispensed',
    statusColor: Color(0xFF4F9F62),
    medication: 'Paracetamol 500mg',
    diagnosis: 'Fever',
    pharmacist: 'Maria Santos',
    color: Color(0xFF07827D),
  ),
  Prescription(
    rxId: 2,
    patient: 'Sofia Reyes',
    id: 'RX-202515-002',
    date: 'May 15, 2025',
    status: 'Pending',
    statusColor: Color(0xFF2476D2),
    medication: 'Amoxicillin 250mg',
    diagnosis: 'Respiratory infection',
    pharmacist: 'Maria Santos',
    color: Color(0xFF2476D2),
  ),
  Prescription(
    rxId: 3,
    patient: 'Aminah Abdullah',
    id: 'RX-202515-003',
    date: 'May 15, 2025',
    status: 'Dispensed',
    statusColor: Color(0xFF4F9F62),
    medication: 'Metformin 500mg',
    diagnosis: 'Type 2 diabetes',
    pharmacist: 'Maria Santos',
    color: Color(0xFF8E6AD8),
  ),
  Prescription(
    rxId: 4,
    patient: 'Pedro Santos',
    id: 'RX-202515-004',
    date: 'May 15, 2025',
    status: 'Partial',
    statusColor: Color(0xFFE5A923),
    medication: 'Salbutamol Inhaler',
    diagnosis: 'Asthma',
    pharmacist: 'Maria Santos',
    color: Color(0xFFD0625F),
  ),
];

const medications = [
  Medication(
    id: 1,
    name: 'Paracetamol 500mg',
    description: 'Pain reliever and fever reducer',
    dosageForm: 'Tablet',
    strength: '500mg',
    manufacturer: 'RiteMed',
    form: 'Tablet • RiteMed',
    stock: 1200,
    reorderLevel: 150,
    expiry: 'Dec 2026',
    status: 'In Stock',
    progress: .88,
    color: Color(0xFF4F9F62),
    icon: Icons.medication,
  ),
  Medication(
    id: 2,
    name: 'Amoxicillin 250mg',
    description: 'Antibiotic capsule',
    dosageForm: 'Capsule',
    strength: '250mg',
    manufacturer: 'Generika',
    form: 'Capsule • Generika',
    stock: 450,
    reorderLevel: 100,
    expiry: 'Nov 2026',
    status: 'In Stock',
    progress: .72,
    color: Color(0xFF4F9F62),
    icon: Icons.medication_liquid,
  ),
  Medication(
    id: 3,
    name: 'Ciprofloxacin 500mg',
    description: 'Antibiotic tablet',
    dosageForm: 'Tablet',
    strength: '500mg',
    manufacturer: 'Unilab',
    form: 'Tablet • Unilab',
    stock: 80,
    reorderLevel: 120,
    expiry: 'Aug 2026',
    status: 'Low Stock',
    progress: .36,
    color: Color(0xFFE5A923),
    icon: Icons.medication,
  ),
  Medication(
    id: 4,
    name: 'Salbutamol Inhaler',
    description: 'Bronchodilator inhaler',
    dosageForm: 'Inhaler',
    strength: '100mcg',
    manufacturer: 'GSK',
    form: 'Inhaler • GSK',
    stock: 20,
    reorderLevel: 50,
    expiry: 'Jul 2026',
    status: 'Low Stock',
    progress: .18,
    color: Color(0xFFD24D57),
    icon: Icons.air,
  ),
  Medication(
    id: 5,
    name: 'Metformin 500mg',
    description: 'Diabetes medication',
    dosageForm: 'Tablet',
    strength: '500mg',
    manufacturer: 'Mercury',
    form: 'Tablet • Mercury',
    stock: 200,
    reorderLevel: 80,
    expiry: 'Jan 2027',
    status: 'In Stock',
    progress: .64,
    color: Color(0xFF4F9F62),
    icon: Icons.medication,
  ),
];

const refillRequests = [
  RefillRequest(
    1,
    'Rashid Karim',
    'Amlodipine 5mg',
    'May 15, 2025',
    'Pending',
    Color(0xFFE5A923),
  ),
  RefillRequest(
    2,
    'Nora Halim',
    'Atorvastatin 20mg',
    'May 15, 2025',
    'Pending',
    Color(0xFFE5A923),
  ),
  RefillRequest(
    3,
    'Benjie Tan',
    'Losartan 50mg',
    'May 15, 2025',
    'Pending',
    Color(0xFFE5A923),
  ),
];

const patients = [
  Patient(
    id: 1,
    firstName: 'Juan',
    lastName: 'Dela Cruz',
    name: 'Juan Dela Cruz',
    birthDate: 'March 2, 1984',
    gender: 'Male',
    address: 'Quezon City',
    contact: '0917 234 8901',
    email: 'juan@example.com',
    allergy: 'Ibuprofen',
    history: 'Hypertension',
    color: Color(0xFF07827D),
  ),
  Patient(
    id: 2,
    firstName: 'Sofia',
    lastName: 'Reyes',
    name: 'Sofia Reyes',
    birthDate: 'July 18, 1991',
    gender: 'Female',
    address: 'Makati City',
    contact: '0928 112 3490',
    email: 'sofia@example.com',
    allergy: 'Penicillin',
    history: 'Asthma',
    color: Color(0xFF2476D2),
  ),
  Patient(
    id: 3,
    firstName: 'Aminah',
    lastName: 'Abdullah',
    name: 'Aminah Abdullah',
    birthDate: 'January 9, 1978',
    gender: 'Female',
    address: 'Manila City',
    contact: '0999 720 4411',
    email: 'aminah@example.com',
    allergy: 'No known allergy',
    history: 'Diabetes',
    color: Color(0xFF8E6AD8),
  ),
];

const alerts = [
  SafetyAlert(
    1,
    'Drug interaction detected',
    'Aspirin and Ibuprofen may increase bleeding risk.',
    '10:30 AM',
    Icons.dangerous_outlined,
    Color(0xFFD24D57),
  ),
  SafetyAlert(
    2,
    '3 medications expiring soon',
    'Check the Expiring Soon inventory section for details.',
    '09:15 AM',
    Icons.event_busy_outlined,
    Color(0xFFE5A923),
  ),
  SafetyAlert(
    3,
    'Medication reminder sent',
    'Reminders were sent to 24 patients.',
    '08:45 AM',
    Icons.notifications_active_outlined,
    Color(0xFF2476D2),
  ),
];

const patientNotifications = [
  SafetyAlert(
    1,
    'Refill request received',
    'Your refill request for Amlodipine 5mg is pending review.',
    'Now',
    Icons.sync_outlined,
    Color(0xFFE5A923),
  ),
  SafetyAlert(
    2,
    'Medication reminder',
    'Take Paracetamol 500mg after meals as prescribed.',
    '08:00 AM',
    Icons.notifications_active_outlined,
    Color(0xFF2476D2),
  ),
  SafetyAlert(
    3,
    'Safety note',
    'Your profile lists Ibuprofen as an allergy.',
    'Yesterday',
    Icons.warning_amber_rounded,
    Color(0xFFD24D57),
  ),
];

const auditLogs = [
  AuditLog(
    'Prescription RX-202515-002 updated',
    'Pharmacist',
    'May 15, 2025 10:45 AM',
  ),
  AuditLog('Refill request approved', 'Pharmacist', 'May 15, 2025 09:40 AM'),
  AuditLog('Inventory stock adjusted', 'Admin', 'May 14, 2025 04:20 PM'),
];

const quickActions = [
  QuickAction('New Rx', Icons.add_circle_outline, Color(0xFF07827D)),
  QuickAction('Add Patient', Icons.person_add_alt_1, Color(0xFF2476D2)),
  QuickAction('Refill', Icons.sync, Color(0xFFE5A923)),
  QuickAction('Add Med', Icons.medication_outlined, Color(0xFF8E6AD8)),
  QuickAction('Stock In', Icons.download_outlined, Color(0xFF2476D2)),
  QuickAction('Reports', Icons.bar_chart, Color(0xFF4F9F62)),
];
