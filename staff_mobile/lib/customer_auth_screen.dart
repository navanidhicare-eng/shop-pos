import 'dart:convert';
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class CustomerAuthScreen extends StatefulWidget {
  final String apiBase;
  final Function(Map<String, dynamic> user) onAuthSuccess;
  final VoidCallback onStaffLoginRequested;

  const CustomerAuthScreen({
    super.key,
    required this.apiBase,
    required this.onAuthSuccess,
    required this.onStaffLoginRequested,
  });

  @override
  State<CustomerAuthScreen> createState() => _CustomerAuthScreenState();
}

class _CustomerAuthScreenState extends State<CustomerAuthScreen> {
  int _activeTab = 0; // 0: Login, 1: Register

  // Login controllers
  final TextEditingController _loginUserCtrl = TextEditingController();
  final TextEditingController _loginPassCtrl = TextEditingController();
  bool _loginObscure = true;
  bool _loginLoading = false;
  String? _loginError;

  // Register controllers
  final TextEditingController _regNameCtrl = TextEditingController();
  final TextEditingController _regPhoneCtrl = TextEditingController();
  final TextEditingController _regUserCtrl = TextEditingController();
  final TextEditingController _regPassCtrl = TextEditingController();
  final TextEditingController _regAddressCtrl = TextEditingController();
  bool _regObscure = true;
  bool _regLoading = false;
  String? _regError;

  @override
  void dispose() {
    _loginUserCtrl.dispose();
    _loginPassCtrl.dispose();
    _regNameCtrl.dispose();
    _regPhoneCtrl.dispose();
    _regUserCtrl.dispose();
    _regPassCtrl.dispose();
    _regAddressCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final u = _loginUserCtrl.text.trim();
    final p = _loginPassCtrl.text.trim();

    if (u.isEmpty || p.isEmpty) {
      setState(() => _loginError = 'దయచేసి యూజర్‌నేమ్/మొబైల్ మరియు పాస్‌వర్డ్ నమోదు చేయండి');
      return;
    }

    setState(() {
      _loginLoading = true;
      _loginError = null;
    });

    try {
      final res = await http.post(
        Uri.parse('${widget.apiBase}/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': u, 'password': p}),
      );

      final data = jsonDecode(res.body);
      if (res.statusCode == 200 && data['success'] == true) {
        final user = data['user'];
        final token = data['token'] ?? '';
        _persistSession(user, token);
        widget.onAuthSuccess(user);
        return;
      }

      setState(() {
        _loginLoading = false;
        _loginError = data['error'] ?? 'లాగిన్ విఫలమైంది (${res.statusCode})';
      });
    } catch (e) {
      setState(() {
        _loginLoading = false;
        _loginError = 'సర్వర్ కనెక్ట్ కాలేదు: $e';
      });
    }
  }

  Future<void> _handleRegister() async {
    final name = _regNameCtrl.text.trim();
    final phone = _regPhoneCtrl.text.trim();
    final username = _regUserCtrl.text.trim();
    final pass = _regPassCtrl.text.trim();
    final address = _regAddressCtrl.text.trim();

    if (name.isEmpty) {
      setState(() => _regError = 'దయచేసి మీ పూర్తి పేరు నమోదు చేయండి');
      return;
    }
    if (phone.length < 10) {
      setState(() => _regError = 'దయచేసి సరైన 10 అంకెల మొబైల్ నంబర్ నమోదు చేయండి');
      return;
    }
    if (pass.length < 4) {
      setState(() => _regError = 'పాస్‌వర్డ్ కనీసం 4 అక్షరాలు ఉండాలి');
      return;
    }

    setState(() {
      _regLoading = true;
      _regError = null;
    });

    try {
      final res = await http.post(
        Uri.parse('${widget.apiBase}/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': name,
          'phone': phone,
          'username': username.isNotEmpty ? username : phone,
          'password': pass,
          'address': address,
        }),
      );

      final data = jsonDecode(res.body);
      if (res.statusCode == 200 && data['success'] == true) {
        final user = data['user'];
        final token = data['token'] ?? '';
        _persistSession(user, token);
        widget.onAuthSuccess(user);
        return;
      }

      setState(() {
        _regLoading = false;
        _regError = data['error'] ?? 'నమోదు విఫలమైంది (${res.statusCode})';
      });
    } catch (e) {
      setState(() {
        _regLoading = false;
        _regError = 'సర్వర్ కనెక్ట్ కాలేదు: $e';
      });
    }
  }

  void _persistSession(Map<String, dynamic> user, String token) {
    try {
      final uJson = jsonEncode(user);
      html.window.localStorage['unik_auth_token'] = token;
      html.window.localStorage['unik_auth_user'] = uJson;
      html.window.localStorage['unik_customer_token'] = token;
      html.window.localStorage['unik_customer_user'] = uJson;
      html.window.localStorage['unik_customer_name'] = user['name'] ?? '';
      html.window.localStorage['unik_customer_phone'] = user['phone'] ?? '';
      html.window.localStorage['unik_customer_address'] = user['address'] ?? '';
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF044E3B), Color(0xFF065F46), Color(0xFF047857)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Brand Logo with Golden Accent
                    Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        border: Border.all(color: const Color(0xFFFBBF24), width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.25),
                            blurRadius: 18,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Image.asset(
                        'assets/logo.png',
                        fit: BoxFit.cover,
                        errorBuilder: (ctx, err, st) => const Center(
                          child: Text('🌿', style: TextStyle(fontSize: 36)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'UNIK NATURALS',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'గానుగ నూనెలు & మిల్లింగ్ ఉత్పత్తులు',
                      style: TextStyle(
                        color: Color(0xFFFDE68A),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                      ),
                      child: const Text(
                        '🌿 స్వచ్ఛమైన ఆన్‌లైన్ స్టోర్ • కస్టమర్ పోర్టల్',
                        style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Main Auth Card
                    Card(
                      elevation: 10,
                      shadowColor: Colors.black.withValues(alpha: 0.35),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      color: Colors.white,
                      clipBehavior: Clip.antiAlias,
                      child: Padding(
                        padding: const EdgeInsets.all(22),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Sleek Pill Selector for Tabs
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: InkWell(
                                      onTap: () => setState(() => _activeTab = 0),
                                      borderRadius: BorderRadius.circular(10),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(vertical: 10),
                                        decoration: BoxDecoration(
                                          color: _activeTab == 0 ? Colors.white : Colors.transparent,
                                          borderRadius: BorderRadius.circular(10),
                                          boxShadow: _activeTab == 0
                                              ? [
                                                  BoxShadow(
                                                    color: Colors.black.withValues(alpha: 0.08),
                                                    blurRadius: 4,
                                                    offset: const Offset(0, 2),
                                                  )
                                                ]
                                              : null,
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.login,
                                              size: 16,
                                              color: _activeTab == 0 ? const Color(0xFF047857) : const Color(0xFF64748B),
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              'లాగిన్ (Login)',
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: _activeTab == 0 ? FontWeight.w800 : FontWeight.w600,
                                                color: _activeTab == 0 ? const Color(0xFF047857) : const Color(0xFF64748B),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: InkWell(
                                      onTap: () => setState(() => _activeTab = 1),
                                      borderRadius: BorderRadius.circular(10),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(vertical: 10),
                                        decoration: BoxDecoration(
                                          color: _activeTab == 1 ? Colors.white : Colors.transparent,
                                          borderRadius: BorderRadius.circular(10),
                                          boxShadow: _activeTab == 1
                                              ? [
                                                  BoxShadow(
                                                    color: Colors.black.withValues(alpha: 0.08),
                                                    blurRadius: 4,
                                                    offset: const Offset(0, 2),
                                                  )
                                                ]
                                              : null,
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.person_add_alt_1,
                                              size: 16,
                                              color: _activeTab == 1 ? const Color(0xFF047857) : const Color(0xFF64748B),
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              'రిజిస్ట్రేషన్ (Register)',
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: _activeTab == 1 ? FontWeight.w800 : FontWeight.w600,
                                                color: _activeTab == 1 ? const Color(0xFF047857) : const Color(0xFF64748B),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 20),

                            // Form View
                            if (_activeTab == 0) _buildLoginForm() else _buildRegisterForm(),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),

                    // Staff Portal Link at Bottom
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'మీరు షాప్ సిబ్బందా? ',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFFFDE68A),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          ),
                          onPressed: widget.onStaffLoginRequested,
                          icon: const Icon(Icons.lock_outline, size: 14),
                          label: const Text(
                            'స్టాఫ్ / యజమాని లాగిన్',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                          ),
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
    );
  }

  Widget _buildFieldLabel(String title, {bool isRequired = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1E293B),
            ),
          ),
          if (isRequired)
            const Text(
              ' *',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFFEF4444)),
            ),
        ],
      ),
    );
  }

  Widget _buildLoginForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_loginError != null)
          Container(
            padding: const EdgeInsets.all(10),
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFF87171)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: Color(0xFFDC2626), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _loginError!,
                    style: const TextStyle(color: Color(0xFF991B1B), fontSize: 12),
                  ),
                ),
              ],
            ),
          ),

        // Username / Phone Label & Clean Empty Field
        _buildFieldLabel('యూజర్‌నేమ్ లేదా మొబైల్ నంబర్', isRequired: true),
        TextField(
          controller: _loginUserCtrl,
          style: const TextStyle(fontSize: 14, color: Color(0xFF0F172A)),
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.person_outline, size: 20, color: Color(0xFF047857)),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF047857), width: 2),
            ),
          ),
        ),

        const SizedBox(height: 14),

        // Password Label & Clean Empty Field
        _buildFieldLabel('పాస్‌వర్డ్ (Password)', isRequired: true),
        TextField(
          controller: _loginPassCtrl,
          obscureText: _loginObscure,
          style: const TextStyle(fontSize: 14, color: Color(0xFF0F172A)),
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.lock_outline, size: 20, color: Color(0xFF047857)),
            suffixIcon: IconButton(
              icon: Icon(_loginObscure ? Icons.visibility_off : Icons.visibility, size: 20, color: const Color(0xFF64748B)),
              onPressed: () => setState(() => _loginObscure = !_loginObscure),
            ),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF047857), width: 2),
            ),
          ),
        ),

        const SizedBox(height: 22),

        // Login Button
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF047857),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 13),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 2,
            shadowColor: const Color(0xFF047857).withValues(alpha: 0.35),
          ),
          onPressed: _loginLoading ? null : _handleLogin,
          icon: _loginLoading
              ? const SizedBox.shrink()
              : const Icon(Icons.login, size: 18),
          label: _loginLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text(
                  'లాగిన్ అవ్వండి (Login)',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                ),
        ),

        const SizedBox(height: 16),

        // Switch to Register
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('ఇంకా ఖాతా లేదా? ', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
            TextButton(
              onPressed: () => setState(() => _activeTab = 1),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                foregroundColor: const Color(0xFF047857),
                padding: EdgeInsets.zero,
              ),
              child: const Text(
                'కొత్త ఖాతా రిజిస్టర్ చేసుకోండి',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRegisterForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_regError != null)
          Container(
            padding: const EdgeInsets.all(10),
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFF87171)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: Color(0xFFDC2626), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _regError!,
                    style: const TextStyle(color: Color(0xFF991B1B), fontSize: 12),
                  ),
                ),
              ],
            ),
          ),

        // Full Name
        _buildFieldLabel('పూర్తి పేరు (Full Name)', isRequired: true),
        TextField(
          controller: _regNameCtrl,
          style: const TextStyle(fontSize: 14, color: Color(0xFF0F172A)),
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.badge_outlined, size: 20, color: Color(0xFF047857)),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF047857), width: 2),
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Mobile Number
        _buildFieldLabel('మొబైల్ నంబర్ (10 Digits)', isRequired: true),
        TextField(
          controller: _regPhoneCtrl,
          keyboardType: TextInputType.phone,
          style: const TextStyle(fontSize: 14, color: Color(0xFF0F172A)),
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.phone_outlined, size: 20, color: Color(0xFF047857)),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF047857), width: 2),
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Username
        _buildFieldLabel('యూజర్‌నేమ్ (Username - ఐచ్ఛికం)'),
        TextField(
          controller: _regUserCtrl,
          style: const TextStyle(fontSize: 14, color: Color(0xFF0F172A)),
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.account_circle_outlined, size: 20, color: Color(0xFF047857)),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF047857), width: 2),
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Password
        _buildFieldLabel('పాస్‌వర్డ్ (Password)', isRequired: true),
        TextField(
          controller: _regPassCtrl,
          obscureText: _regObscure,
          style: const TextStyle(fontSize: 14, color: Color(0xFF0F172A)),
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.lock_outline, size: 20, color: Color(0xFF047857)),
            suffixIcon: IconButton(
              icon: Icon(_regObscure ? Icons.visibility_off : Icons.visibility, size: 20, color: const Color(0xFF64748B)),
              onPressed: () => setState(() => _regObscure = !_regObscure),
            ),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF047857), width: 2),
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Delivery Address
        _buildFieldLabel('డెలివరీ చిరునామా (Delivery Address)'),
        TextField(
          controller: _regAddressCtrl,
          maxLines: 2,
          style: const TextStyle(fontSize: 14, color: Color(0xFF0F172A)),
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.location_on_outlined, size: 20, color: Color(0xFF047857)),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF047857), width: 2),
            ),
          ),
        ),

        const SizedBox(height: 20),

        // Register Button
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF047857),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 13),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 2,
            shadowColor: const Color(0xFF047857).withValues(alpha: 0.35),
          ),
          onPressed: _regLoading ? null : _handleRegister,
          icon: _regLoading
              ? const SizedBox.shrink()
              : const Icon(Icons.person_add, size: 18),
          label: _regLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text(
                  'ఖాతా సృష్టించండి (Create Account)',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                ),
        ),

        const SizedBox(height: 14),

        // Switch to Login
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('ఇప్పటికే ఖాతా ఉందా? ', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
            TextButton(
              onPressed: () => setState(() => _activeTab = 0),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                foregroundColor: const Color(0xFF047857),
                padding: EdgeInsets.zero,
              ),
              child: const Text(
                'లాగిన్ అవ్వండి',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
