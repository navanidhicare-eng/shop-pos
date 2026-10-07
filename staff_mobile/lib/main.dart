import 'dart:convert';
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'customer_storefront.dart';
import 'online_orders_view.dart';

void main() {
  runApp(const StaffShopApp());
}

class StaffShopApp extends StatelessWidget {
  const StaffShopApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UNIK NATURALS • POS & Store',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF164610),
          brightness: Brightness.light,
          primary: const Color(0xFF164610),
          secondary: const Color(0xFFD39715),
        ),
        fontFamily: 'Roboto',
        fontFamilyFallback: const ['Noto Sans Telugu', 'sans-serif'],
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      home: const StaffSessionGate(),
    );
  }
}

class StaffSessionGate extends StatefulWidget {
  const StaffSessionGate({super.key});

  @override
  State<StaffSessionGate> createState() => _StaffSessionGateState();
}

class _StaffSessionGateState extends State<StaffSessionGate> {
  Map<String, dynamic>? _currentUser;
  bool _isChecking = true;
  bool _viewCustomerStore = false;

  String get _activeApiBase {
    try {
      if (Uri.base.hasAuthority && Uri.base.host.isNotEmpty) {
        final port = Uri.base.hasPort ? ':${Uri.base.port}' : '';
        return '${Uri.base.scheme}://${Uri.base.host}$port/api';
      }
    } catch (_) {}
    return 'http://localhost:5000/api';
  }

  @override
  void initState() {
    super.initState();
    _checkExistingSession();
  }

  void _checkExistingSession() {
    try {
      final uri = Uri.base;
      if (uri.queryParameters['mode'] == 'customer') {
        setState(() {
          _viewCustomerStore = true;
          _isChecking = false;
        });
        return;
      }

      final rawUser = html.window.localStorage['unik_auth_user'] ?? html.window.sessionStorage['unik_auth_user'];
      if (rawUser != null && rawUser.isNotEmpty) {
        final parsed = jsonDecode(rawUser);
        if (parsed is Map<String, dynamic>) {
          setState(() {
            _currentUser = parsed;
            _isChecking = false;
          });
          return;
        }
      }

      if (uri.queryParameters['mode'] == 'staff') {
        setState(() {
          _isChecking = false;
        });
        _redirectToUnifiedLogin();
        return;
      }
    } catch (_) {}

    setState(() {
      _isChecking = false;
    });
  }

  void _redirectToUnifiedLogin() {
    try {
      html.window.location.href = '/';
    } catch (_) {}
  }

  void _handleLogout() {
    try {
      html.window.localStorage.remove('unik_auth_token');
      html.window.localStorage.remove('unik_auth_user');
      html.window.sessionStorage.remove('unik_auth_token');
      html.window.sessionStorage.remove('unik_auth_user');
    } catch (_) {}
    setState(() {
      _currentUser = null;
      _viewCustomerStore = false;
    });
    _redirectToUnifiedLogin();
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) {
      return const Scaffold(
        backgroundColor: Color(0xFF09130B),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFFF3B638)),
        ),
      );
    }

    if (_currentUser != null && !_viewCustomerStore) {
      return MainStaffScreen(
        currentUser: _currentUser,
        onLogout: _handleLogout,
        onSwitchToCustomerStore: () {
          setState(() => _viewCustomerStore = true);
        },
      );
    }

    // Customer Online Storefront View
    return CustomerStorefrontView(
      apiBase: _activeApiBase,
      onStaffLoginRequested: () {
        if (_currentUser != null) {
          setState(() => _viewCustomerStore = false);
        } else {
          _redirectToUnifiedLogin();
        }
      },
    );
  }
}

class MainStaffScreen extends StatefulWidget {
  final Map<String, dynamic>? currentUser;
  final VoidCallback? onLogout;
  final VoidCallback? onSwitchToCustomerStore;

  const MainStaffScreen({
    super.key,
    this.currentUser,
    this.onLogout,
    this.onSwitchToCustomerStore,
  });

  @override
  State<MainStaffScreen> createState() => _MainStaffScreenState();
}

class _MainStaffScreenState extends State<MainStaffScreen> {
  int _currentIndex = 0;
  late String _activeApiBase;

  @override
  void initState() {
    super.initState();
    try {
      if (Uri.base.hasAuthority && Uri.base.host.isNotEmpty) {
        final port = Uri.base.hasPort ? ':${Uri.base.port}' : '';
        _activeApiBase = '${Uri.base.scheme}://${Uri.base.host}$port/api';
      } else {
        _activeApiBase = 'http://localhost:5000/api';
      }
    } catch (_) {
      _activeApiBase = 'http://localhost:5000/api';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0E1F12),
        elevation: 0,
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFF59E0B), width: 1.5),
                color: Colors.white,
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.asset(
                'assets/logo.png',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const Center(
                  child: Text('🌿', style: TextStyle(fontSize: 18)),
                ),
              ),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'UNIK NATURALS',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  'Counter POS • Cold-Pressed Oils & Mill',
                  style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 11),
                ),
              ],
            ),
          ],
        ),
        actions: [
          if (widget.currentUser != null && widget.currentUser!['role'] == 'ADMIN')
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF59E0B),
                  foregroundColor: const Color(0xFF09130B),
                  elevation: 3,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.dashboard, size: 16, color: Color(0xFF09130B)),
                label: const Text(
                  '📊 అడ్మిన్ ERP డ్యాష్‌బోర్డ్',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
                ),
                onPressed: () {
                  try {
                    html.window.location.href = '/';
                  } catch (_) {}
                },
              ),
            ),

          // Switch to Customer Store preview
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFF59E0B),
                side: const BorderSide(color: Color(0xFFF59E0B), width: 1.2),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.storefront, size: 15, color: Color(0xFFF59E0B)),
              label: const Text(
                '🛍️ కస్టమర్ షాప్',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              ),
              onPressed: () {
                widget.onSwitchToCustomerStore?.call();
              },
            ),
          ),

          // Current User Profile Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
            decoration: BoxDecoration(
              color: const Color(0xFF164610),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFF59E0B), width: 1.2),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(widget.currentUser?['role'] == 'ADMIN' ? Icons.workspace_premium : Icons.person, size: 14, color: const Color(0xFFF59E0B)),
                const SizedBox(width: 4),
                Text(
                  widget.currentUser != null ? (widget.currentUser!['name'] ?? widget.currentUser!['username'] ?? 'Staff') : 'Staff',
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),

          // Prominent Red Logout Button
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 2,
              ),
              icon: const Icon(Icons.logout, size: 15),
              label: const Text(
                'లాగౌట్',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              onPressed: _showLogoutDialog,
            ),
          ),

          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Colors.white70),
            onPressed: _showSettingsDialog,
            tooltip: 'సర్వర్ సెట్టింగ్స్',
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          ShopRetailSalesView(apiBase: _activeApiBase),
          MillingServiceSalesView(apiBase: _activeApiBase),
          DayEndCashTallyView(apiBase: _activeApiBase),
          QuickBatchProductionView(apiBase: _activeApiBase),
          CustomerKhataLedgerView(apiBase: _activeApiBase),
          StaffOnlineOrdersView(apiBase: _activeApiBase),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0xFFE5E7EB), width: 1)),
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (index) {
            setState(() => _currentIndex = index);
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.shopping_bag_outlined),
              selectedIcon: Icon(Icons.shopping_bag, color: Color(0xFFD97706)),
              label: 'షాప్ సేల్స్',
            ),
            NavigationDestination(
              icon: Icon(Icons.grain_outlined),
              selectedIcon: Icon(Icons.grain, color: Color(0xFF10B981)),
              label: 'మిల్లింగ్ కూలి',
            ),
            NavigationDestination(
              icon: Icon(Icons.account_balance_wallet_outlined),
              selectedIcon: Icon(Icons.account_balance_wallet, color: Color(0xFF3B82F6)),
              label: 'గల్లా లెక్క',
            ),
            NavigationDestination(
              icon: Icon(Icons.precision_manufacturing_outlined),
              selectedIcon: Icon(Icons.precision_manufacturing, color: Color(0xFF8B5CF6)),
              label: 'నూనె బ్యాచ్',
            ),
            NavigationDestination(
              icon: Icon(Icons.menu_book_outlined),
              selectedIcon: Icon(Icons.menu_book, color: Color(0xFF7C3AED)),
              label: 'ఖాతా పుస్తకం',
            ),
            NavigationDestination(
              icon: Icon(Icons.local_shipping_outlined),
              selectedIcon: Icon(Icons.local_shipping, color: Color(0xFFF59E0B)),
              label: 'ఆన్‌లైన్ ఆర్డర్లు',
            ),
          ],
        ),
      ),
    );
  }

  void _showSettingsDialog() {
    final controller = TextEditingController(text: _activeApiBase);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('API సర్వర్ IP అడ్రస్'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'ఫోన్‌లో యాప్ రన్ చేస్తున్నప్పుడు మీ కంప్యూటర్ లోకల్ IP (e.g. http://192.168.1.5:5000/api) ఇవ్వండి:',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'API URL',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('రద్దు చేయి'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() => _activeApiBase = controller.text.trim());
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('సర్వర్ URL అప్‌డేట్ చేయబడింది!')),
              );
            },
            child: const Text('సేవ్ చేయి'),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0E1F12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0xFFDC2626), width: 1.5),
        ),
        title: const Row(
          children: [
            Icon(Icons.logout, color: Color(0xFFF87171)),
            SizedBox(width: 8),
            Text('లాగౌట్ / Logout', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'మీరు (${widget.currentUser?['name'] ?? 'Staff'}) ఖాతా నుండి లాగౌట్ అవ్వాలనుకుంటున్నారా?\n(Are you sure you want to log out?)',
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('రద్దు (Cancel)', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              widget.onLogout?.call();
            },
            child: const Text('అవును, లాగౌట్ అవ్వండి', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 1. RETAIL SHOP SALES TAB & PRODUCT GROUPING
// ==========================================
class ProductGroup {
  final String key;
  final String titleTe;
  final String titleEn;
  final String category;
  final String? imageUrl;
  final List<Map<String, dynamic>> variants;

  ProductGroup({
    required this.key,
    required this.titleTe,
    required this.titleEn,
    required this.category,
    required this.imageUrl,
    required this.variants,
  });

  double get minPrice {
    if (variants.isEmpty) return 0;
    return variants
        .map((v) => (v['selling_price'] as num).toDouble())
        .reduce((a, b) => a < b ? a : b);
  }

  double get maxPrice {
    if (variants.isEmpty) return 0;
    return variants
        .map((v) => (v['selling_price'] as num).toDouble())
        .reduce((a, b) => a > b ? a : b);
  }

  int inCartCount(Map<int, int> cart) {
    int total = 0;
    for (final v in variants) {
      final id = v['id'] as int;
      total += cart[id] ?? 0;
    }
    return total;
  }
}

class MillingCartEntry {
  final int serviceId;
  final String serviceName;
  final String serviceNameTe;
  final double ratePerKg;
  double weightKg;

  MillingCartEntry({
    required this.serviceId,
    required this.serviceName,
    required this.serviceNameTe,
    required this.ratePerKg,
    required this.weightKg,
  });

  double get total => ratePerKg * weightKg;

  String get displayName => '$serviceNameTe (${weightKg % 1 == 0 ? weightKg.toInt() : weightKg} kg కూలి)';
}

class ShopRetailSalesView extends StatefulWidget {
  final String apiBase;
  const ShopRetailSalesView({super.key, required this.apiBase});

  @override
  State<ShopRetailSalesView> createState() => _ShopRetailSalesViewState();
}

class _ShopRetailSalesViewState extends State<ShopRetailSalesView> {
  List<dynamic> _items = [];
  List<dynamic> _millingServices = [];
  String _selectedCategory = 'ALL';
  final Map<int, int> _cart = {}; // itemId -> quantity
  final List<MillingCartEntry> _millingCart = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchItems();
    _fetchMillingServices();
  }

  Future<void> _fetchItems() async {
    setState(() => _isLoading = true);
    try {
      final res = await http.get(Uri.parse('${widget.apiBase}/items'));
      if (res.statusCode == 200) {
        setState(() {
          _items = jsonDecode(res.body);
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchMillingServices() async {
    try {
      final res = await http.get(Uri.parse('${widget.apiBase}/milling-services'));
      if (res.statusCode == 200) {
        setState(() {
          _millingServices = jsonDecode(res.body);
        });
      }
    } catch (_) {}
  }

  double get _retailTotal {
    double total = 0;
    _cart.forEach((itemId, qty) {
      final item = _items.firstWhere((i) => i['id'] == itemId, orElse: () => null);
      if (item != null) {
        total += (item['selling_price'] as num) * qty;
      }
    });
    return total;
  }

  double get _millingTotal {
    double total = 0;
    for (final m in _millingCart) {
      total += m.total;
    }
    return total;
  }

  double get _cartTotal => _retailTotal + _millingTotal;

  int get _cartItemCount {
    int count = 0;
    _cart.forEach((_, qty) => count += qty);
    count += _millingCart.length;
    return count;
  }

  Future<void> _processSale(
    String paymentMode, {
    int? customerId,
    String? customerName,
    String? customerPhone,
    double advancePaid = 0,
    double creditAmount = 0,
    String? notes,
  }) async {
    if (_cart.isEmpty && _millingCart.isEmpty) return;

    final saleItems = [];
    _cart.forEach((itemId, qty) {
      final item = _items.firstWhere((i) => i['id'] == itemId, orElse: () => null);
      if (item != null) {
        saleItems.add({
          'item_type': 'PRODUCT',
          'reference_id': item['id'],
          'name': item['name'],
          'quantity': qty,
          'rate': item['selling_price'],
        });
      }
    });

    for (final m in _millingCart) {
      saleItems.add({
        'item_type': 'MILLING',
        'reference_id': m.serviceId,
        'name': m.displayName,
        'quantity': m.weightKg,
        'rate': m.ratePerKg,
      });
    }

    final payload = {
      'items': saleItems,
      'payment_mode': paymentMode,
      'cash_paid': paymentMode == 'CASH'
          ? _cartTotal
          : (paymentMode == 'CREDIT' ? advancePaid : 0),
      'upi_paid': paymentMode == 'UPI' ? _cartTotal : 0,
      'credit_amount': paymentMode == 'CREDIT'
          ? (creditAmount > 0 ? creditAmount : (_cartTotal - advancePaid))
          : 0,
      'customer_id': customerId,
      'customer_name': customerName,
      'customer_phone': customerPhone,
      'notes': notes,
    };

    try {
      final res = await http.post(
        Uri.parse('${widget.apiBase}/sales'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (mounted) {
          final isCredit = paymentMode == 'CREDIT';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: isCredit ? const Color(0xFF8B5CF6) : const Color(0xFF10B981),
              content: Text(
                isCredit
                    ? '📒 ఖాతా బిల్ జారీ అయింది: ${data['bill_number']} • ₹${_cartTotal.toInt()} (${customerName ?? 'కస్టమర్'})'
                    : '✅ బిల్ జారీ అయింది: ${data['bill_number']} • ₹${_cartTotal.toInt()} ($paymentMode)',
              ),
              duration: const Duration(seconds: 3),
            ),
          );
          setState(() {
            _cart.clear();
            _millingCart.clear();
          });
          _fetchItems(); // Refresh live stocks
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('సేల్ నమోదులో లోపం జరిగింది!')),
        );
      }
    }
  }

  Future<void> _showCreditSaleDialog() async {
    if (_cart.isEmpty && _millingCart.isEmpty) return;

    List<dynamic> existingCustomers = [];
    try {
      final res = await http.get(Uri.parse('${widget.apiBase}/customers'));
      if (res.statusCode == 200) {
        existingCustomers = jsonDecode(res.body);
      }
    } catch (_) {}

    if (!mounted) return;

    dynamic selectedCustomer;
    if (existingCustomers.isNotEmpty) {
      selectedCustomer = existingCustomers[0];
    }
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final advanceController = TextEditingController(text: '0');
    bool isNewCustomer = existingCustomers.isEmpty;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          final totalBill = _cartTotal;
          final advance = double.tryParse(advanceController.text.trim()) ?? 0;
          final balanceCredit = (totalBill - advance).clamp(0.0, totalBill);

          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.menu_book, color: Color(0xFF8B5CF6)),
                SizedBox(width: 8),
                Text('📒 ఖాతా బిల్లింగ్ (Credit Sale)', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F3FF),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFDDD6FE)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('మొత్తం బిల్లు మొత్తం:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        Text('₹${totalBill.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFF6D28D9))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  if (existingCustomers.isNotEmpty)
                    Row(
                      children: [
                        ChoiceChip(
                          label: const Text('ఖాతాదారుల లిస్ట్'),
                          selected: !isNewCustomer,
                          onSelected: (val) {
                            setDialogState(() {
                              isNewCustomer = !val;
                            });
                          },
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('➕ కొత్త పేరు'),
                          selected: isNewCustomer,
                          onSelected: (val) {
                            setDialogState(() {
                              isNewCustomer = val;
                            });
                          },
                        ),
                      ],
                    ),
                  const SizedBox(height: 12),

                  if (!isNewCustomer && existingCustomers.isNotEmpty) ...[
                    const Text('కస్టమర్‌ను ఎంచుకోండి:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<dynamic>(
                      initialValue: selectedCustomer,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      items: existingCustomers.map((c) {
                        final due = (c['total_credit_due'] as num).toInt();
                        return DropdownMenuItem<dynamic>(
                          value: c,
                          child: Text(
                            '${c['name']} ${c['phone'] != null ? '(${c['phone']})' : ''} • బాకీ: ₹$due',
                            style: const TextStyle(fontSize: 13),
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setDialogState(() {
                          selectedCustomer = val;
                        });
                      },
                    ),
                  ] else ...[
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'కస్టమర్ పేరు (Customer Name) *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'మొబైల్ నెంబర్ (Mobile / WhatsApp)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                    ),
                  ],

                  const SizedBox(height: 14),
                  const Divider(),
                  const SizedBox(height: 8),

                  TextField(
                    controller: advanceController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'ఇప్పుడే ఇచ్చిన నగదు (Paid Now ₹)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.money),
                      helperText: 'ఏమీ ఇవ్వకపోతే 0 అలాగే ఉంచండి',
                    ),
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  const SizedBox(height: 10),

                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFECACA)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('ఖాతాలో మిగిలే బాకీ:', style: TextStyle(color: Color(0xFFB91C1C), fontWeight: FontWeight.bold, fontSize: 13)),
                        Text('₹${balanceCredit.toStringAsFixed(0)}', style: const TextStyle(color: Color(0xFFB91C1C), fontWeight: FontWeight.w900, fontSize: 16)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('రద్దు (Cancel)'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8B5CF6),
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  int? custId;
                  String? custName;
                  String? custPhone;

                  if (!isNewCustomer && selectedCustomer != null) {
                    custId = selectedCustomer['id'] as int;
                    custName = selectedCustomer['name'];
                    custPhone = selectedCustomer['phone'];
                  } else {
                    custName = nameController.text.trim();
                    custPhone = phoneController.text.trim();
                    if (custName.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('దయచేసి కస్టమర్ పేరు నమోదు చేయండి')),
                      );
                      return;
                    }
                  }

                  Navigator.pop(dialogCtx);
                  _processSale(
                    'CREDIT',
                    customerId: custId,
                    customerName: custName,
                    customerPhone: custPhone,
                    advancePaid: advance,
                    creditAmount: balanceCredit,
                  );
                },
                child: const Text('ఖాతాలో నమోదు చేయి'),
              ),
            ],
          );
        },
      ),
    );
  }

  List<ProductGroup> _computeProductGroups(List<dynamic> rawItems) {
    final Map<String, List<Map<String, dynamic>>> groupMap = {};
    final Map<String, Map<String, dynamic>> metaMap = {};

    for (final raw in rawItems) {
      final item = Map<String, dynamic>.from(raw as Map);
      String key = (item['group_name'] ?? '').toString().trim();
      if (key.isEmpty) {
        key = item['name']
            .toString()
            .replaceAll(RegExp(r'\s*\d+(\.\d+)?\s*(L|ml|Kg|g|kg|ltr|can|bottle|packet)', caseSensitive: false), '')
            .trim();
      }

      groupMap.putIfAbsent(key, () => []).add(item);

      if (!metaMap.containsKey(key)) {
        metaMap[key] = {
          'titleTe': item['group_name_te'] ?? item['name_te'] ?? item['name'],
          'titleEn': item['group_name'] ?? item['name'],
          'category': item['category'],
          'imageUrl': item['image_url'],
        };
      } else {
        if (metaMap[key]!['imageUrl'] == null && item['image_url'] != null) {
          metaMap[key]!['imageUrl'] = item['image_url'];
        }
      }
    }

    final List<ProductGroup> groups = [];
    groupMap.forEach((key, variants) {
      variants.sort((a, b) => ((a['selling_price'] as num).toDouble())
          .compareTo((b['selling_price'] as num).toDouble()));

      final meta = metaMap[key]!;
      groups.add(ProductGroup(
        key: key,
        titleTe: meta['titleTe'] ?? key,
        titleEn: meta['titleEn'] ?? key,
        category: meta['category'] ?? 'OIL',
        imageUrl: meta['imageUrl'],
        variants: variants,
      ));
    });

    return groups;
  }

  void _openVariantBottomSheet(ProductGroup group) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            final groupInCart = group.inCartCount(_cart);
            double groupTotal = 0;
            for (final v in group.variants) {
              final vid = v['id'] as int;
              final q = _cart[vid] ?? 0;
              groupTotal += (v['selling_price'] as num).toDouble() * q;
            }

            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.85,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Drag handle
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),

                  // Header with Image + Title
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: 58,
                          height: 58,
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xFFD97706), width: 1.5),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: _buildProductImage(group.imageUrl, group.category),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              group.titleTe,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF164610),
                              ),
                            ),
                            Text(
                              group.titleEn,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFECFDF5),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFFA7F3D0)),
                              ),
                              child: Text(
                                '${group.variants.length} సైజులు అందుబాటులో ఉన్నాయి',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF047857),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(modalCtx),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 10),

                  // Prompt
                  Row(
                    children: [
                      const Icon(Icons.tune, size: 16, color: Color(0xFFD97706)),
                      const SizedBox(width: 6),
                      Text(
                        'సైజు మరియు సంఖ్యను (+ / -) ఎంచుకోండి:',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Variants List
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: group.variants.length,
                      separatorBuilder: (ctx, i) => const SizedBox(height: 8),
                      itemBuilder: (context, idx) {
                        final v = group.variants[idx];
                        final vid = v['id'] as int;
                        final q = _cart[vid] ?? 0;
                        final vTitle = v['variant_name_te'] ?? v['name_te'] ?? v['name'];
                        final vSub = v['variant_name'] ?? v['name'];
                        final price = (v['selling_price'] as num).toInt();
                        final stock = (v['stock_qty'] as num).toDouble();
                        final isLowStock = stock <= (v['low_stock_threshold'] ?? 5);

                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: q > 0 ? const Color(0xFFFEFCE8) : const Color(0xFFF9FAFB),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: q > 0 ? const Color(0xFFF59E0B) : const Color(0xFFE5E7EB),
                              width: q > 0 ? 1.8 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              // Variant Name & Details
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      vTitle,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF111827),
                                      ),
                                    ),
                                    Text(
                                      '$vSub • స్టాక్: ${stock.toInt()} ${v['unit'] ?? ''}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isLowStock ? Colors.red.shade600 : Colors.grey.shade600,
                                        fontWeight: isLowStock ? FontWeight.w600 : FontWeight.normal,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '₹$price',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w900,
                                        color: Color(0xFF164610),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Stepper / Add button
                              if (q == 0)
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF164610),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    elevation: 0,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _cart[vid] = 1;
                                    });
                                    setModalState(() {});
                                  },
                                  icon: const Icon(Icons.add, size: 16),
                                  label: const Text(
                                    'చేర్చు',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                )
                              else
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: const Color(0xFFF59E0B), width: 1.5),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Decrement button
                                      IconButton(
                                        visualDensity: VisualDensity.compact,
                                        icon: Icon(
                                          q == 1 ? Icons.delete_outline : Icons.remove,
                                          size: 18,
                                          color: q == 1 ? Colors.red : const Color(0xFFD97706),
                                        ),
                                        onPressed: () {
                                          setState(() {
                                            if (q <= 1) {
                                              _cart.remove(vid);
                                            } else {
                                              _cart[vid] = q - 1;
                                            }
                                          });
                                          setModalState(() {});
                                        },
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 8),
                                        child: Text(
                                          '$q',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF111827),
                                          ),
                                        ),
                                      ),
                                      // Increment button
                                      IconButton(
                                        visualDensity: VisualDensity.compact,
                                        icon: const Icon(Icons.add, size: 18, color: Color(0xFF164610)),
                                        onPressed: () {
                                          setState(() {
                                            _cart[vid] = q + 1;
                                          });
                                          setModalState(() {});
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Bottom Done Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF164610),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 2,
                      ),
                      onPressed: () => Navigator.pop(modalCtx),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.check_circle_outline, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            groupInCart > 0
                                ? 'పూర్తయింది ($groupInCart ఐటమ్స్ • ₹${groupTotal.toInt()})'
                                : 'పూర్తయింది (Done)',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showAddMillingDialog() {
    if (_millingServices.isEmpty) {
      _fetchMillingServices();
    }

    dynamic selectedService = _millingServices.isNotEmpty ? _millingServices[0] : null;
    double weightKg = 5.0;
    final weightController = TextEditingController(text: '5');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final rate = selectedService != null ? (selectedService['rate_per_kg'] as num).toDouble() : 0.0;
            final cooliAmount = rate * weightKg;

            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: EdgeInsets.only(
                top: 20,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(modalCtx).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.grain, color: Color(0xFF059669), size: 24),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '🌾 పిండి మిల్లింగ్ కూలి చేర్చు',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF064E3B)),
                              ),
                              Text(
                                'సామానుల బిల్లులోనే మిల్లింగ్ కూలి కలిపి సింగిల్ బిల్ వేయండి',
                                style: TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(modalCtx),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    const Text(
                      'మిల్లింగ్ సర్వీస్ ఎంచుకోండి:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF374151)),
                    ),
                    const SizedBox(height: 8),
                    if (_millingServices.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text('సర్వీసెస్ లోడ్ అవుతున్నాయి...'),
                      )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _millingServices.map((srv) {
                          final isSelected = selectedService != null && selectedService['id'] == srv['id'];
                          final srvRate = (srv['rate_per_kg'] as num).toDouble();
                          final srvNameTe = srv['name_te'] ?? srv['name'];
                          return ChoiceChip(
                            label: Text(
                              '$srvNameTe (₹${srvRate.toInt()}/kg)',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                color: isSelected ? Colors.white : Colors.black87,
                              ),
                            ),
                            selected: isSelected,
                            selectedColor: const Color(0xFF047857),
                            backgroundColor: const Color(0xFFF3F4F6),
                            onSelected: (val) {
                              if (val) {
                                setModalState(() {
                                  selectedService = srv;
                                });
                              }
                            },
                          );
                        }).toList(),
                      ),
                    const SizedBox(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'ధాన్యము / పిండి బరువు (Weight):',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF374151)),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${weightKg.toStringAsFixed(1)} kg',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF92400E)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [1.0, 2.0, 5.0, 10.0, 15.0, 20.0, 25.0].map((w) {
                        final isWSelected = (weightKg - w).abs() < 0.05;
                        return InkWell(
                          onTap: () {
                            setModalState(() {
                              weightKg = w;
                              weightController.text = w % 1 == 0 ? w.toInt().toString() : w.toString();
                            });
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                            decoration: BoxDecoration(
                              color: isWSelected ? const Color(0xFF059669) : Colors.white,
                              border: Border.all(
                                color: isWSelected ? const Color(0xFF059669) : const Color(0xFFD1D5DB),
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${w % 1 == 0 ? w.toInt() : w} kg',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: isWSelected ? Colors.white : Colors.black87,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        IconButton.filledTonal(
                          icon: const Icon(Icons.remove),
                          onPressed: () {
                            if (weightKg > 0.5) {
                              setModalState(() {
                                weightKg = (weightKg - 0.5).clamp(0.5, 500.0);
                                weightController.text = weightKg.toStringAsFixed(1);
                              });
                            }
                          },
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: weightController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            decoration: const InputDecoration(
                              suffixText: 'kg',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(vertical: 10),
                            ),
                            onChanged: (val) {
                              final parsed = double.tryParse(val);
                              if (parsed != null && parsed > 0) {
                                setModalState(() {
                                  weightKg = parsed;
                                });
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filledTonal(
                          icon: const Icon(Icons.add),
                          onPressed: () {
                            setModalState(() {
                              weightKg = (weightKg + 0.5);
                              weightController.text = weightKg.toStringAsFixed(1);
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFBBF7D0)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${selectedService != null ? (selectedService['name_te'] ?? selectedService['name']) : ''}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF166534)),
                              ),
                              Text(
                                '${weightKg.toStringAsFixed(1)} kg × ₹${rate.toInt()}/kg',
                                style: const TextStyle(fontSize: 11, color: Color(0xFF15803D)),
                              ),
                            ],
                          ),
                          Text(
                            '₹${cooliAmount.toInt()}',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF15803D),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF047857),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 2,
                        ),
                        onPressed: selectedService == null || weightKg <= 0
                            ? null
                            : () {
                                final srvId = selectedService['id'] as int;
                                final srvName = selectedService['name'].toString();
                                final srvNameTe = (selectedService['name_te'] ?? selectedService['name']).toString();
                                final srvRate = (selectedService['rate_per_kg'] as num).toDouble();

                                setState(() {
                                  final existingIdx = _millingCart.indexWhere((m) => m.serviceId == srvId);
                                  if (existingIdx >= 0) {
                                    _millingCart[existingIdx].weightKg += weightKg;
                                  } else {
                                    _millingCart.add(MillingCartEntry(
                                      serviceId: srvId,
                                      serviceName: srvName,
                                      serviceNameTe: srvNameTe,
                                      ratePerKg: srvRate,
                                      weightKg: weightKg,
                                    ));
                                  }
                                });

                                Navigator.pop(modalCtx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    backgroundColor: const Color(0xFF059669),
                                    content: Text('🌾 $srvNameTe ($weightKg kg కూలి) కార్ట్‌లో చేరింది! (+₹${cooliAmount.toInt()})'),
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              },
                        icon: const Icon(Icons.add_shopping_cart, size: 20),
                        label: Text(
                          'కార్ట్‌లో చేర్చు (+ ₹${cooliAmount.toInt()})',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showCartReviewModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.all(20),
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(modalCtx).size.height * 0.8,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.shopping_bag, color: Color(0xFF164610)),
                          const SizedBox(width: 8),
                          Text(
                            'కార్ట్ వివరాలు ($_cartItemCount ఐటమ్స్)',
                            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      TextButton.icon(
                        style: TextButton.styleFrom(foregroundColor: Colors.red),
                        onPressed: () {
                          setState(() {
                            _cart.clear();
                            _millingCart.clear();
                          });
                          Navigator.pop(modalCtx);
                        },
                        icon: const Icon(Icons.delete_outline, size: 18),
                        label: const Text('అన్నీ తీసివేయి'),
                      ),
                    ],
                  ),
                  const Divider(),
                  Expanded(
                    child: ListView(
                      children: [
                        if (_cart.isNotEmpty) ...[
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 4),
                            child: Text(
                              '🛍️ షాప్ సరుకులు (Retail Items):',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1F2937)),
                            ),
                          ),
                          ..._cart.entries.map((entry) {
                            final item = _items.firstWhere((i) => i['id'] == entry.key, orElse: () => null);
                            if (item == null) return const SizedBox.shrink();
                            final qty = entry.value;
                            final price = (item['selling_price'] as num).toDouble();
                            final lineTotal = price * qty;

                            return Card(
                              elevation: 0,
                              color: const Color(0xFFF9FAFB),
                              margin: const EdgeInsets.only(bottom: 6),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                                side: const BorderSide(color: Color(0xFFE5E7EB)),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item['name_te'] ?? item['name'],
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                          ),
                                          Text(
                                            '₹$price × $qty = ₹${lineTotal.toInt()}',
                                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      visualDensity: VisualDensity.compact,
                                      icon: const Icon(Icons.remove_circle_outline, size: 20, color: Colors.amber),
                                      onPressed: () {
                                        setState(() {
                                          if (qty <= 1) {
                                            _cart.remove(entry.key);
                                          } else {
                                            _cart[entry.key] = qty - 1;
                                          }
                                        });
                                        setModalState(() {});
                                      },
                                    ),
                                    Text('$qty', style: const TextStyle(fontWeight: FontWeight.bold)),
                                    IconButton(
                                      visualDensity: VisualDensity.compact,
                                      icon: const Icon(Icons.add_circle_outline, size: 20, color: Color(0xFF164610)),
                                      onPressed: () {
                                        setState(() {
                                          _cart[entry.key] = qty + 1;
                                        });
                                        setModalState(() {});
                                      },
                                    ),
                                    IconButton(
                                      visualDensity: VisualDensity.compact,
                                      icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                                      onPressed: () {
                                        setState(() {
                                          _cart.remove(entry.key);
                                        });
                                        setModalState(() {});
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                          const SizedBox(height: 10),
                        ],
                        if (_millingCart.isNotEmpty) ...[
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 4),
                            child: Text(
                              '🌾 మిల్లింగ్ సర్వీసులు (Milling Charges):',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF065F46)),
                            ),
                          ),
                          ..._millingCart.asMap().entries.map((entry) {
                            final idx = entry.key;
                            final m = entry.value;

                            return Card(
                              elevation: 0,
                              color: const Color(0xFFECFDF5),
                              margin: const EdgeInsets.only(bottom: 6),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                                side: const BorderSide(color: Color(0xFFA7F3D0)),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                child: Row(
                                  children: [
                                    const Icon(Icons.grain, color: Color(0xFF059669), size: 20),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            m.displayName,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF064E3B)),
                                          ),
                                          Text(
                                            '${m.weightKg} kg @ ₹${m.ratePerKg.toInt()}/kg',
                                            style: const TextStyle(fontSize: 11, color: Color(0xFF047857)),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      '₹${m.total.toInt()}',
                                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Color(0xFF064E3B)),
                                    ),
                                    IconButton(
                                      visualDensity: VisualDensity.compact,
                                      icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                      onPressed: () {
                                        setState(() {
                                          _millingCart.removeAt(idx);
                                        });
                                        setModalState(() {});
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                          const SizedBox(height: 10),
                        ],
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF059669),
                            side: const BorderSide(color: Color(0xFF059669)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () {
                            Navigator.pop(modalCtx);
                            _showAddMillingDialog();
                          },
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('🌾 ఇంకా మిల్లింగ్ కూలి చేర్చు'),
                        ),
                      ],
                    ),
                  ),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('సరుకులు + కూలి మొత్తం:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      Text(
                        '₹${_cartTotal.toStringAsFixed(0)}',
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: Color(0xFF164610)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF164610),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => Navigator.pop(modalCtx),
                      child: const Text('సరిచూసుకున్నాం (Done)', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final allGroups = _computeProductGroups(_items);
    final filteredGroups = _selectedCategory == 'ALL'
        ? allGroups
        : allGroups.where((g) => g.category == _selectedCategory).toList();

    return Column(
      children: [
        // Category Pills Filter
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              _buildCategoryChip('ALL', 'అన్నీ (All)'),
              _buildCategoryChip('OIL', '🛢️ ఆయిల్స్'),
              _buildCategoryChip('REPACK', '📦 రీప్యాక్డ్'),
              _buildCategoryChip('SNACK', '🍿 స్నాక్స్'),
              _buildCategoryChip('CAKE', '🌾 నూనె చెక్క'),
            ],
          ),
        ),

        // Quick Action: Add Milling Service directly to this Bill
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          child: Material(
            color: const Color(0xFF064E3B),
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: _showAddMillingDialog,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: Color(0xFF059669),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.grain, color: Colors.white, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text(
                                '🌾 పిండి / మిల్లింగ్ కూలి చేర్చు',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              if (_millingCart.isNotEmpty) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF59E0B),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '${_millingCart.length} చేర్చబడ్డాయి',
                                    style: const TextStyle(
                                      color: Colors.black,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const Text(
                            'గోధుమ, రాగులు, కారం, నూనె గానుగ కూలి ఒకే బిల్లులో వేయండి',
                            style: TextStyle(color: Color(0xFFA7F3D0), fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add, size: 14, color: Colors.black),
                          SizedBox(width: 2),
                          Text(
                            'కూలి చేర్చు',
                            style: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Product Grid
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : filteredGroups.isEmpty
                  ? const Center(child: Text('సరుకులు లేవు'))
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        final width = constraints.maxWidth;
                        // Always 2 items per row as requested ("varusaku 2 undalaga")
                        const crossAxisCount = 2;
                        final aspectRatio = width >= 500 ? 1.05 : 0.80;

                        return GridView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: crossAxisCount,
                            childAspectRatio: aspectRatio,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                          ),
                          itemCount: filteredGroups.length,
                          itemBuilder: (ctx, idx) {
                            final group = filteredGroups[idx];
                            final inCartQty = group.inCartCount(_cart);

                            return InkWell(
                              onTap: () => _openVariantBottomSheet(group),
                              borderRadius: BorderRadius.circular(14),
                              child: Card(
                                elevation: inCartQty > 0 ? 4 : 2,
                                color: inCartQty > 0 ? const Color(0xFFFEF9C3) : Colors.white,
                                margin: EdgeInsets.zero,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  side: BorderSide(
                                    color: inCartQty > 0
                                        ? const Color(0xFFD97706)
                                        : const Color(0xFFE5E7EB),
                                    width: inCartQty > 0 ? 2 : 1,
                                  ),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // 1. PRODUCT PHOTO SECTION
                                    Expanded(
                                      flex: 5,
                                      child: Stack(
                                        fit: StackFit.expand,
                                        children: [
                                          _buildProductImage(group.imageUrl, group.category),

                                          // Category icon badge (top-left)
                                          Positioned(
                                            top: 6,
                                            left: 6,
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: Colors.black.withValues(alpha: 0.55),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                _getCategoryIcon(group.category),
                                                style: const TextStyle(fontSize: 12),
                                              ),
                                            ),
                                          ),

                                          // In-cart count or Variant count pill (top-right)
                                          Positioned(
                                            top: 6,
                                            right: 6,
                                            child: inCartQty > 0
                                                ? Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                    decoration: BoxDecoration(
                                                      color: const Color(0xFFD97706),
                                                      borderRadius: BorderRadius.circular(10),
                                                      boxShadow: const [
                                                        BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))
                                                      ],
                                                    ),
                                                    child: Text(
                                                      '🛒 × $inCartQty',
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 11,
                                                      ),
                                                    ),
                                                  )
                                                : Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: Colors.black.withValues(alpha: 0.6),
                                                      borderRadius: BorderRadius.circular(6),
                                                    ),
                                                    child: Text(
                                                      group.variants.length > 1
                                                          ? '${group.variants.length} సైజులు'
                                                          : '1 సైజు',
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 10,
                                                        fontWeight: FontWeight.w600,
                                                      ),
                                                    ),
                                                  ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    // 2. PRODUCT DETAILS SECTION
                                    Expanded(
                                      flex: 4,
                                      child: Padding(
                                        padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            // Names
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  group.titleTe,
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 13,
                                                    color: Color(0xFF111827),
                                                  ),
                                                ),
                                                Text(
                                                  group.titleEn,
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    color: Color(0xFF6B7280),
                                                    fontSize: 10,
                                                  ),
                                                ),
                                              ],
                                            ),

                                            // Price & Select Button
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Text(
                                                  group.variants.length == 1
                                                      ? '₹${group.minPrice.toInt()}'
                                                      : '₹${group.minPrice.toInt()} నుండి',
                                                  style: const TextStyle(
                                                    color: Color(0xFF164610),
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w900,
                                                  ),
                                                ),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: inCartQty > 0
                                                        ? const Color(0xFFD97706)
                                                        : const Color(0xFF164610),
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Text(
                                                        group.variants.length > 1
                                                            ? (inCartQty > 0 ? 'మార్చు ▾' : 'సైజులు ▾')
                                                            : (inCartQty > 0 ? '✓ $inCartQty' : '+ చేర్చు'),
                                                        style: const TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 10,
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
        ),

        // Bottom Fast Checkout Panel
        if (_cart.isNotEmpty || _millingCart.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF111827),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 10,
                  offset: const Offset(0, -4),
                )
              ],
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      InkWell(
                        onTap: _showCartReviewModal,
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          child: Row(
                            children: [
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                onPressed: () => setState(() {
                                  _cart.clear();
                                  _millingCart.clear();
                                }),
                                tooltip: 'ఖాళీ చేయి',
                              ),
                              Text(
                                '$_cartItemCount ఐటమ్స్',
                                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.arrow_drop_up, color: Colors.white70, size: 20),
                            ],
                          ),
                        ),
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF047857),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: _showAddMillingDialog,
                        icon: const Icon(Icons.grain, size: 15),
                        label: const Text('+ మిల్లింగ్', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                      Text(
                        'మొత్తం: ₹${_cartTotal.toStringAsFixed(0)}',
                        style: const TextStyle(
                          color: Color(0xFFFBBF24),
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () => _processSale('CASH'),
                          icon: const Icon(Icons.payments_outlined, size: 18),
                          label: const Text(
                            'నగదు\nCASH',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, height: 1.15),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 3,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () => _processSale('UPI'),
                          icon: const Icon(Icons.qr_code_2, size: 18),
                          label: const Text(
                            'PhonePe\nUPI',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, height: 1.15),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 4,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF7C3AED),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () => _showCreditSaleDialog(),
                          icon: const Icon(Icons.menu_book, size: 18),
                          label: const Text(
                            '📒 ఖాతా\nCREDIT',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, height: 1.15),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCategoryChip(String catKey, String label) {
    final isSelected = _selectedCategory == catKey;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        selected: isSelected,
        label: Text(label),
        selectedColor: const Color(0xFFF59E0B),
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : Colors.black87,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          fontSize: 12,
        ),
        onSelected: (_) {
          setState(() => _selectedCategory = catKey);
        },
      ),
    );
  }

  String _getCategoryIcon(String cat) {
    switch (cat) {
      case 'OIL': return '🛢️';
      case 'REPACK': return '📦';
      case 'SNACK': return '🍿';
      case 'CAKE': return '🌾';
      default: return '🛍️';
    }
  }

  Widget _buildProductImage(String? imageUrl, dynamic category) {
    final catStr = (category ?? '').toString().toUpperCase();

    if (imageUrl != null && imageUrl.isNotEmpty) {
      String resolvedUrl = imageUrl;
      if (!imageUrl.startsWith('http://') && !imageUrl.startsWith('https://')) {
        final serverRoot = widget.apiBase.replaceAll(RegExp(r'/api/?$'), '');
        resolvedUrl = '$serverRoot$imageUrl';
      }

      return Image.network(
        resolvedUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          final fallbackAsset = _getFallbackAsset(catStr);
          if (fallbackAsset != null) {
            return Image.asset(
              fallbackAsset,
              fit: BoxFit.cover,
              errorBuilder: (c, e, s) => _buildFallbackEmoji(catStr),
            );
          }
          return _buildFallbackEmoji(catStr);
        },
      );
    }

    final fallbackAsset = _getFallbackAsset(catStr);
    if (fallbackAsset != null) {
      return Image.asset(
        fallbackAsset,
        fit: BoxFit.cover,
        errorBuilder: (c, e, s) => _buildFallbackEmoji(catStr),
      );
    }
    return _buildFallbackEmoji(catStr);
  }

  String? _getFallbackAsset(String category) {
    switch (category) {
      case 'OIL':
        return 'assets/products/groundnut_oil.jpg';
      case 'REPACK':
        return 'assets/products/repack_peanuts.jpg';
      case 'SNACK':
        return 'assets/products/snack_mixture.jpg';
      case 'CAKE':
        return 'assets/products/oil_cake.jpg';
      default:
        return null;
    }
  }

  Widget _buildFallbackEmoji(String category) {
    return Container(
      color: const Color(0xFFF3F4F6),
      child: Center(
        child: Text(
          _getCategoryIcon(category),
          style: const TextStyle(fontSize: 40),
        ),
      ),
    );
  }
}

// ==========================================
// 2. MILLING SERVICE (JOB WORK) TAB
// ==========================================
class MillingServiceSalesView extends StatefulWidget {
  final String apiBase;
  const MillingServiceSalesView({super.key, required this.apiBase});

  @override
  State<MillingServiceSalesView> createState() => _MillingServiceSalesViewState();
}

class _MillingServiceSalesViewState extends State<MillingServiceSalesView> {
  List<dynamic> _services = [];
  dynamic _selectedService;
  double _weightKg = 5.0;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchServices();
  }

  Future<void> _fetchServices() async {
    setState(() => _isLoading = true);
    try {
      final res = await http.get(Uri.parse('${widget.apiBase}/milling-services'));
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body);
        setState(() {
          _services = list;
          if (_services.isNotEmpty) _selectedService = _services[0];
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  double get _millingAmount {
    if (_selectedService == null) return 0;
    final rate = (_selectedService['rate_per_kg'] as num).toDouble();
    return rate * _weightKg;
  }

  Future<void> _recordMillingSale(String paymentMode) async {
    if (_selectedService == null || _weightKg <= 0) return;

    final payload = {
      'items': [
        {
          'item_type': 'MILLING',
          'reference_id': _selectedService['id'],
          'name': '${_selectedService['name']} ($_weightKg kg కూలి)',
          'quantity': _weightKg,
          'rate': _selectedService['rate_per_kg'],
        }
      ],
      'payment_mode': paymentMode,
      'cash_paid': paymentMode == 'CASH' ? _millingAmount : 0,
      'upi_paid': paymentMode == 'UPI' ? _millingAmount : 0,
    };

    try {
      final res = await http.post(
        Uri.parse('${widget.apiBase}/sales'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (res.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFF10B981),
              content: Text('🌾 కూలి నమోదు చేయబడింది: ₹${_millingAmount.toInt()} ($paymentMode)'),
            ),
          );
          setState(() {
            _weightKg = 5.0;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('కూలి నమోదులో లోపం')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return RefreshIndicator(
      onRefresh: _fetchServices,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'మిల్లింగ్ / కూలి పట్టడం (Spot Job Work)',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'కస్టమర్ తెచ్చిన ధాన్యం లేదా గింజల కూలి లెక్క',
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, color: Color(0xFF164610)),
                  tooltip: 'ధరలు / సర్వీసులు రీఫ్రెష్ చేయి',
                  onPressed: _fetchServices,
                ),
              ],
            ),
            const SizedBox(height: 16),

          // Service Selection Grid
          const Text('1. సర్వీస్ ఎంచుకోండి:', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _services.map((s) {
              final isSel = _selectedService != null && _selectedService['id'] == s['id'];
              return ChoiceChip(
                selected: isSel,
                label: Text('${s['name_te'] ?? s['name']} (₹${s['rate_per_kg']}/kg)'),
                selectedColor: const Color(0xFF10B981),
                labelStyle: TextStyle(
                  color: isSel ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.bold,
                ),
                onSelected: (val) {
                  if (val) setState(() => _selectedService = s);
                },
              );
            }).toList(),
          ),

          const SizedBox(height: 24),

          // Weight Entry
          const Text('2. ఎన్ని కేజీలు (Weight in Kg):', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildKgButton(1),
              _buildKgButton(2),
              _buildKgButton(5),
              _buildKgButton(10),
              _buildKgButton(20),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('పరిమాణం (Kg):', style: TextStyle(fontSize: 15)),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: () {
                        if (_weightKg > 0.5) setState(() => _weightKg -= 0.5);
                      },
                    ),
                    Text(
                      '$_weightKg kg',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: () {
                        setState(() => _weightKg += 0.5);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Total Calculation Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF111827), Color(0xFF1F2937)],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _selectedService != null ? _selectedService['name'] : '',
                      style: const TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    Text(
                      '$_weightKg kg × ₹${_selectedService != null ? _selectedService['rate_per_kg'] : 0}',
                      style: const TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ],
                ),
                const Divider(color: Colors.white24, height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'తీసుకోవాల్సిన కూలి:',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '₹${_millingAmount.toStringAsFixed(0)}',
                      style: const TextStyle(
                        color: Color(0xFF10B981),
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Instant Payment Buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => _recordMillingSale('CASH'),
                  icon: const Icon(Icons.money),
                  label: const Text('నగదు (CASH)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3B82F6),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => _recordMillingSale('UPI'),
                  icon: const Icon(Icons.qr_code),
                  label: const Text('PhonePe / UPI', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

  Widget _buildKgButton(double kg) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 10),
            backgroundColor: _weightKg == kg ? const Color(0xFF10B981).withValues(alpha: 0.15) : null,
          ),
          onPressed: () => setState(() => _weightKg = kg),
          child: Text('${kg.toInt()}k', style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }
}

// ==========================================
// 3. DAY END CASH TALLY TAB (గల్లా లెక్క)
// ==========================================
class DayEndCashTallyView extends StatefulWidget {
  final String apiBase;
  const DayEndCashTallyView({super.key, required this.apiBase});

  @override
  State<DayEndCashTallyView> createState() => _DayEndCashTallyViewState();
}

class _DayEndCashTallyViewState extends State<DayEndCashTallyView> {
  final _cashController = TextEditingController();
  final _notesController = TextEditingController();
  Map<String, dynamic>? _tallyResult;
  Map<String, dynamic>? _todaySummary;
  bool _isLoading = false;
  bool _isLoadingSummary = false;

  @override
  void initState() {
    super.initState();
    _fetchTodaySummary();
  }

  Future<void> _fetchTodaySummary() async {
    setState(() => _isLoadingSummary = true);
    try {
      final res = await http.get(Uri.parse('${widget.apiBase}/sales/today-summary'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          _todaySummary = data['summary'];
          _isLoadingSummary = false;
        });
      }
    } catch (_) {
      setState(() => _isLoadingSummary = false);
    }
  }

  Future<void> _submitTally() async {
    final cash = double.tryParse(_cashController.text);
    if (cash == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('దయచేసి గల్లాలో ఉన్న క్యాష్ మొత్తం ఎంటర్ చేయండి')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final res = await http.post(
        Uri.parse('${widget.apiBase}/day-end'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'actual_cash_counted': cash,
          'notes': _notesController.text.trim(),
        }),
      );

      if (res.statusCode == 200) {
        setState(() {
          _tallyResult = jsonDecode(res.body);
          _isLoading = false;
        });
        _fetchTodaySummary();
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'సాయంత్రం గల్లా లెక్క (Day-End Cash Close)',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const Text(
            'షాప్ కట్టేసే ముందు గల్లా పెట్టెలో చేతికి వచ్చిన నగదు లెక్కించి ఇక్కడ ఎంటర్ చేయండి',
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
          const SizedBox(height: 16),

          // Live Today Collections Breakdown Card (UPI & Cash)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.query_stats, color: Color(0xFF38BDF8), size: 20),
                        SizedBox(width: 8),
                        Text(
                          'నేటి అమ్మకాల సారాంశం (Live)',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ],
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: _isLoadingSummary
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.refresh, color: Colors.white70, size: 18),
                      onPressed: _isLoadingSummary ? null : _fetchTodaySummary,
                      tooltip: 'రిఫ్రెష్ చేయి',
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    // UPI Box
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E3A8A).withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF3B82F6), width: 1.2),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.qr_code_2, color: Color(0xFF60A5FA), size: 16),
                                SizedBox(width: 4),
                                Text(
                                  'PhonePe / UPI',
                                  style: TextStyle(color: Color(0xFF93C5FD), fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '₹${(_todaySummary?['total_upi'] ?? 0).toString()}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const Text(
                              'బ్యాంకులో జమ (PhonePe)',
                              style: TextStyle(color: Color(0xFFBFDBFE), fontSize: 9),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Cash Box
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF064E3B).withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF10B981), width: 1.2),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.payments_outlined, color: Color(0xFF34D399), size: 16),
                                SizedBox(width: 4),
                                Text(
                                  'క్యాష్ (Cash)',
                                  style: TextStyle(color: Color(0xFFA7F3D0), fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '₹${(_todaySummary?['total_cash'] ?? 0).toString()}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const Text(
                              'గల్లాలో ఉండాల్సింది',
                              style: TextStyle(color: Color(0xFFA7F3D0), fontSize: 9),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'మొత్తం సేల్స్: ₹${(_todaySummary?['total_sales'] ?? 0).toString()}',
                        style: const TextStyle(color: Color(0xFFFDE68A), fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      Text(
                        'బిల్లులు: ${(_todaySummary?['total_bills'] ?? 0).toString()}',
                        style: const TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    controller: _cashController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.currency_rupee, color: Color(0xFFD97706)),
                      border: OutlineInputBorder(),
                      labelText: 'గల్లాలో లెక్కించిన క్యాష్ మొత్తం (₹)',
                      hintText: 'ఉదా: 4250',
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _notesController,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'గమనిక / నోట్స్ (ఐచ్ఛికం)',
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF111827),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _isLoading ? null : _submitTally,
                      icon: const Icon(Icons.verified),
                      label: const Text('లెక్క టాలీ చెక్ చేయి & క్లోజ్ చేయి', style: TextStyle(fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (_tallyResult != null) ...[
            const SizedBox(height: 20),
            _buildResultCard(),
          ],
        ],
      ),
    );
  }

  Widget _buildResultCard() {
    final diff = (_tallyResult!['cash_difference'] as num).toDouble();
    final isMatch = diff == 0;
    final isShort = diff < 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isMatch
            ? const Color(0xFFECFDF5)
            : (isShort ? const Color(0xFFFEF2F2) : const Color(0xFFFFFBEB)),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isMatch
              ? const Color(0xFF10B981)
              : (isShort ? Colors.redAccent : const Color(0xFFF59E0B)),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                isMatch ? Icons.check_circle : (isShort ? Icons.error : Icons.info),
                color: isMatch ? const Color(0xFF10B981) : (isShort ? Colors.red : Colors.orange),
                size: 28,
              ),
              const SizedBox(width: 10),
              Text(
                isMatch ? 'లెక్క సరిపోయింది! (0 Difference)' : (isShort ? 'క్యాష్ తక్కువ వచ్చింది (Shortage)' : 'అదనంగా క్యాష్ ఉంది (Excess)'),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: isMatch ? const Color(0xFF10B981) : (isShort ? Colors.red : Colors.orange),
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          _tallyRow('కంప్యూటర్ క్యాష్ సేల్స్:', '₹${_tallyResult!['system_cash_sales']}'),
          _tallyRow('PhonePe / UPI సేల్స్:', '₹${_tallyResult!['system_upi_sales']}'),
          _tallyRow('మొత్తం అమ్మకాలు:', '₹${_tallyResult!['system_total_sales']}'),
          _tallyRow('గల్లాలో మీరు లెక్కించినది:', '₹${_tallyResult!['actual_cash_counted']}', isBold: true),
          const Divider(height: 16),
          _tallyRow(
            'తేడా (Difference):',
            '₹${diff.toStringAsFixed(0)}',
            isBold: true,
            color: isMatch ? const Color(0xFF10B981) : Colors.red,
          ),
        ],
      ),
    );
  }

  Widget _tallyRow(String label, String val, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 14, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(
            val,
            style: TextStyle(
              fontSize: isBold ? 16 : 14,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 4. OIL PRODUCTION & BOTTLING (క్రషింగ్ & బాట్లింగ్)
// ==========================================
class QuickBatchProductionView extends StatefulWidget {
  final String apiBase;
  const QuickBatchProductionView({super.key, required this.apiBase});

  @override
  State<QuickBatchProductionView> createState() => _QuickBatchProductionViewState();
}

class _QuickBatchProductionViewState extends State<QuickBatchProductionView> {
  int _activeStage = 0; // 0: క్రషింగ్ రోజు (Crush & Cake), 1: బాట్లింగ్ రోజు (2 రోజుల తర్వాత - Pack Bottles)
  bool _isLoading = false;

  // Stage 1 Fields (Crushing)
  String _seedName = 'వేరుశనగ / పల్లీలు (Groundnut)';
  final _tinLabelCtrl = TextEditingController(text: 'టిన్ / డ్రమ్ #1');
  final _seedKgCtrl = TextEditingController(text: '20');
  final _oilKgCtrl = TextEditingController(text: '7.6');
  final _cakeKgCtrl = TextEditingController(text: '11.5');
  final _procCostCtrl = TextEditingController(text: '143');

  // Machine Start & Stop Timers
  TimeOfDay? _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay? _stopTime = const TimeOfDay(hour: 10, minute: 45);
  int _durationMinutes = 105; // 1 hr 45 min
  bool _isMachineRunning = false;

  // Stage 2 Fields (Bottling after 2 days)
  List<Map<String, dynamic>> _pendingTins = [];
  int? _selectedTinId;
  Map<String, dynamic>? _selectedTin;
  String _bottlingOilType = 'GROUNDNUT'; // 'GROUNDNUT' or 'SESAME'
  final _bottle1LCtrl = TextEditingController(text: '15');
  final _bottle500mlCtrl = TextEditingController(text: '10');
  final _can5LCtrl = TextEditingController(text: '0');
  final _sludgeLtrCtrl = TextEditingController(text: '1.0');

  @override
  void initState() {
    super.initState();
    _seedKgCtrl.addListener(() {
      _recalcProcessingCost();
      setState(() {});
    });
    _oilKgCtrl.addListener(() => setState(() {}));
    _cakeKgCtrl.addListener(() => setState(() {}));
    _bottle1LCtrl.addListener(() => setState(() {}));
    _bottle500mlCtrl.addListener(() => setState(() {}));
    _can5LCtrl.addListener(() => setState(() {}));
    _sludgeLtrCtrl.addListener(() => setState(() {}));
    _fetchPendingTins();
    _recalcProcessingCost();
  }

  @override
  void dispose() {
    _tinLabelCtrl.dispose();
    _seedKgCtrl.dispose();
    _oilKgCtrl.dispose();
    _cakeKgCtrl.dispose();
    _procCostCtrl.dispose();
    _bottle1LCtrl.dispose();
    _bottle500mlCtrl.dispose();
    _can5LCtrl.dispose();
    _sludgeLtrCtrl.dispose();
    super.dispose();
  }

  // --- Fetch Tins / Drums resting after crushing ---
  Future<void> _fetchPendingTins() async {
    try {
      final res = await http.get(Uri.parse('${widget.apiBase}/production/pending-tins'));
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        if (mounted) {
          setState(() {
            _pendingTins = data.map((e) => Map<String, dynamic>.from(e)).toList();
            if (_pendingTins.isNotEmpty) {
              if (_selectedTinId == null || !_pendingTins.any((t) => t['id'] == _selectedTinId)) {
                _onSelectTinId(_pendingTins.first['id'] as int);
              }
            } else {
              _selectedTinId = 0;
              _selectedTin = null;
            }
          });
        }
      }
    } catch (_) {}
  }

  void _onSelectTinId(int id) {
    setState(() {
      _selectedTinId = id;
      if (id == 0) {
        _selectedTin = null;
        _bottlingOilType = 'GROUNDNUT';
      } else if (id == -1) {
        _selectedTin = null;
        _bottlingOilType = 'SESAME';
      } else {
        final match = _pendingTins.firstWhere((t) => t['id'] == id, orElse: () => {});
        if (match.isNotEmpty) {
          _selectedTin = match;
          final seed = match['seed_name']?.toString() ?? '';
          if (seed.contains('నువ్వులు') || seed.toLowerCase().contains('sesame')) {
            _bottlingOilType = 'SESAME';
          } else {
            _bottlingOilType = 'GROUNDNUT';
          }

          final remLtr = (match['settled_oil_litres_remaining'] as num?)?.toDouble() ?? 0.0;
          if (remLtr > 0) {
            final est1L = ((remLtr - 1.0) * 0.7).floor();
            final remForHalf = (remLtr - 1.0) - est1L;
            final est500ml = (remForHalf * 2).floor();
            _bottle1LCtrl.text = (est1L > 0 ? est1L : 0).toString();
            _bottle500mlCtrl.text = (est500ml > 0 ? est500ml : 0).toString();
            _can5LCtrl.text = '0';
            _sludgeLtrCtrl.text = '1.0';
          }
        }
      }
    });
  }

  // --- Machine Timer Methods ---
  String _formatTime(TimeOfDay? t) {
    if (t == null) return '--:--';
    final hour = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final minute = t.minute.toString().padLeft(2, '0');
    final period = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  void _onStartMachineNow() {
    setState(() {
      _startTime = TimeOfDay.now();
      _stopTime = null;
      _isMachineRunning = true;
    });
  }

  void _onStopMachineNow() {
    setState(() {
      _stopTime = TimeOfDay.now();
      _isMachineRunning = false;
      _recalcDurationAndCost();
    });
  }

  Future<void> _pickStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _startTime ?? TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        _startTime = picked;
        _recalcDurationAndCost();
      });
    }
  }

  Future<void> _pickStopTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _stopTime ?? TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        _stopTime = picked;
        _isMachineRunning = false;
        _recalcDurationAndCost();
      });
    }
  }

  void _recalcDurationAndCost() {
    if (_startTime != null && _stopTime != null) {
      final startMins = _startTime!.hour * 60 + _startTime!.minute;
      final stopMins = _stopTime!.hour * 60 + _stopTime!.minute;
      int diff = stopMins - startMins;
      if (diff < 0) diff += 24 * 60;
      _durationMinutes = diff > 0 ? diff : 15;
    }
    final total = (_timerPowerCost + _timerLaborCost).round();
    _procCostCtrl.text = total.toString();
  }

  double get _timerRunHours => _durationMinutes / 60.0;
  double get _timerPowerUnits => _timerRunHours * 3.2; // 5HP single-phase load ≈ 3.2 kW
  double get _timerPowerCost => _timerPowerUnits * 9.0; // ₹9 per commercial unit
  double get _timerLaborCost => _timerRunHours * 50.0; // ₹400 for 8 hrs = ₹50/hour

  // --- Stage 1 Calculations (Wood-Pressed / చెక్క గానుగ 20kg capacity, 5HP single-phase, ₹400/day labor) ---
  double get _estRunHours {
    final seedKg = double.tryParse(_seedKgCtrl.text.trim()) ?? 0;
    final isSesame = _seedName.contains('నువ్వులు') || _seedName.toLowerCase().contains('sesame');
    // Groundnut: ~1.5 hours per 20kg; Sesame: ~2.0 hours per 20kg; Others: ~1.75 hours
    final double hoursPer20Kg = isSesame ? 2.0 : 1.5;
    return (seedKg / 20.0) * hoursPer20Kg;
  }

  double get _estPowerCost {
    // 5HP Single phase under grinding load draws ~3.2 kW * ₹9.0/unit commercial tariff
    return _estRunHours * 3.2 * 9.0;
  }

  double get _estLaborCost {
    // 8-hour shift wage ₹400 = 4 batches (20kg each) @ ₹100 per batch
    final seedKg = double.tryParse(_seedKgCtrl.text.trim()) ?? 0;
    return (seedKg / 20.0) * 100.0;
  }

  void _recalcProcessingCost() {
    final total = (_estPowerCost + _estLaborCost).round();
    if (total > 0) {
      _procCostCtrl.text = total.toString();
    }
  }

  double get _computedLitres {
    final kg = double.tryParse(_oilKgCtrl.text.trim()) ?? 0;
    return kg > 0 ? (kg / 0.91) : 0;
  }

  double get _extractionPct {
    final inKg = double.tryParse(_seedKgCtrl.text.trim()) ?? 1;
    final outKg = double.tryParse(_oilKgCtrl.text.trim()) ?? 0;
    return inKg > 0 ? ((outKg / inKg) * 100) : 0;
  }

  // --- Stage 2 Calculations ---
  double get _totalPackedLitres {
    final b1 = double.tryParse(_bottle1LCtrl.text.trim()) ?? 0;
    final b500 = double.tryParse(_bottle500mlCtrl.text.trim()) ?? 0;
    final c5 = double.tryParse(_can5LCtrl.text.trim()) ?? 0;
    return (b1 * 1.0) + (b500 * 0.5) + (c5 * 5.0);
  }

  double get _sludgeLtr {
    return double.tryParse(_sludgeLtrCtrl.text.trim()) ?? 0;
  }

  double get _totalOilConsumed {
    return _totalPackedLitres + _sludgeLtr;
  }

  int get _totalEmptyBottles {
    final b1 = int.tryParse(_bottle1LCtrl.text.trim()) ?? 0;
    final b500 = int.tryParse(_bottle500mlCtrl.text.trim()) ?? 0;
    final c5 = int.tryParse(_can5LCtrl.text.trim()) ?? 0;
    return b1 + b500 + c5;
  }

  // --- Submit Stage 1: Crushing Batch ---
  Future<void> _submitCrushingBatch() async {
    final seedKg = double.tryParse(_seedKgCtrl.text.trim()) ?? 0;
    final oilKg = double.tryParse(_oilKgCtrl.text.trim()) ?? 0;
    final cakeKg = double.tryParse(_cakeKgCtrl.text.trim()) ?? 0;
    final tinLabel = _tinLabelCtrl.text.trim().isNotEmpty ? _tinLabelCtrl.text.trim() : 'టిన్ / డ్రమ్ #1';

    if (seedKg <= 0 || oilKg <= 0 || cakeKg <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('దయచేసి గింజలు, నూనె తూకం మరియు కేక్ కేజీలు నమోదు చేయండి')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final res = await http.post(
        Uri.parse('${widget.apiBase}/production/oil-batch'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'seed_name': _seedName,
          'tin_label': tinLabel,
          'seed_input_kg': seedKg,
          'seed_cost_per_kg': _seedName.contains('నువ్వులు') ? 150 : 85,
          'oil_output_kg': oilKg,
          'oil_output_litres': _computedLitres,
          'cake_output_kg': cakeKg,
          'processing_cost': double.tryParse(_procCostCtrl.text.trim()) ?? 143,
          'start_time': _formatTime(_startTime),
          'end_time': _formatTime(_stopTime),
          'duration_minutes': _durationMinutes,
        }),
      );

      if (res.statusCode == 200 && mounted) {
        _fetchPendingTins();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF10B981),
            content: Text(
              '✅ క్రషింగ్ బ్యాచ్ నమోదైంది!\n'
              '• నూనె చెక్క: ${cakeKg.toInt()} kg (వెంటనే సేల్స్ స్టాక్‌లోకి చేరింది)\n'
              '• $tinLabel: $oilKg Kg (≈ ${_computedLitres.toStringAsFixed(1)} Ltr డ్రమ్‌లో తేలుతోంది)\n'
              '• రన్నింగ్ సమయం: ${_durationMinutes ~/ 60} గం. ${_durationMinutes % 60} నిమి. (కరెంట్ & కూలీ: ₹${_procCostCtrl.text})',
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('క్రషింగ్ బ్యాచ్ నమోదులో లోపం')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- Submit Stage 2: Bottling (Pack into finished bottles) ---
  Future<void> _submitBottling() async {
    final b1 = int.tryParse(_bottle1LCtrl.text.trim()) ?? 0;
    final b500 = int.tryParse(_bottle500mlCtrl.text.trim()) ?? 0;
    final c5 = int.tryParse(_can5LCtrl.text.trim()) ?? 0;

    if (b1 <= 0 && b500 <= 0 && c5 <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('దయచేసి ప్యాక్ చేసిన బాటిళ్ల సంఖ్య నమోదు చేయండి')),
      );
      return;
    }

    setState(() => _isLoading = true);

    // Mapped Item IDs based on selected oil type
    final int id1L = _bottlingOilType == 'GROUNDNUT' ? 1 : 4;
    final int id500 = _bottlingOilType == 'GROUNDNUT' ? 2 : 5;
    final int id5L = 3;

    final List<Map<String, dynamic>> packs = [];
    if (b1 > 0) {
      packs.add({
        'item_id': id1L,
        'bottles_packed': b1,
        'bulk_oil_litres_used': b1 * 1.0,
        'bottle_cost_per_unit': 9,
        'label_cost_per_unit': 1.5,
      });
    }
    if (b500 > 0) {
      packs.add({
        'item_id': id500,
        'bottles_packed': b500,
        'bulk_oil_litres_used': b500 * 0.5,
        'bottle_cost_per_unit': 7,
        'label_cost_per_unit': 1.5,
      });
    }
    if (c5 > 0 && _bottlingOilType == 'GROUNDNUT') {
      packs.add({
        'item_id': id5L,
        'bottles_packed': c5,
        'bulk_oil_litres_used': c5 * 5.0,
        'bottle_cost_per_unit': 35,
        'label_cost_per_unit': 2.0,
      });
    }

    try {
      final res = await http.post(
        Uri.parse('${widget.apiBase}/production/bottling'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'batch_id': _selectedTin?['id'],
          'packs': packs,
          'sludge_waste_litres': _sludgeLtr,
          'notes': '${_selectedTin?['tin_label'] ?? _bottlingOilType} బాట్లింగ్. వృథా మడ్డి: $_sludgeLtr Ltr',
        }),
      );

      if (res.statusCode == 200 && mounted) {
        _fetchPendingTins();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF10B981),
            content: Text(
              '✅ బాట్లింగ్ పూర్తయింది!\n'
              '• $_totalEmptyBottles బాటిల్స్ కౌంటర్ సేల్స్ స్టాక్‌లోకి జమయ్యాయి!\n'
              '• $_totalEmptyBottles ఖాళీ బాటిల్స్ & లేబుల్స్ స్టాక్ నుండి తగ్గాయి.\n'
              '• $_sludgeLtr Ltr మడ్డి వేస్టేజ్ గా రికార్డ్ అయింది.',
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('బాట్లింగ్ నమోదులో లోపం')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Screen Header
          const Text(
            'ఆయిల్ తయారీ & బాట్లింగ్ (Oil Production)',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF164610)),
          ),
          const Text(
            'గానుగ క్రషింగ్ లెక్కలు మరియు 2 రోజుల తర్వాత బాట్లింగ్ నిర్వహణ',
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
          const SizedBox(height: 16),

          // Two-Stage Toggle Header
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFFE5E7EB),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _activeStage = 0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _activeStage == 0 ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: _activeStage == 0
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
                            Icons.precision_manufacturing,
                            size: 18,
                            color: _activeStage == 0 ? const Color(0xFFD97706) : Colors.grey.shade600,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '1. క్రషింగ్ రోజు\n(Crush & Cake)',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              height: 1.15,
                              color: _activeStage == 0 ? const Color(0xFF111827) : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    onTap: () {
                      setState(() => _activeStage = 1);
                      _fetchPendingTins();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _activeStage == 1 ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: _activeStage == 1
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
                            Icons.sanitizer,
                            size: 18,
                            color: _activeStage == 1 ? const Color(0xFF10B981) : Colors.grey.shade600,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '2. బాట్లింగ్ రోజు\n(2 రోజుల తర్వాత)',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              height: 1.15,
                              color: _activeStage == 1 ? const Color(0xFF111827) : Colors.grey.shade600,
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
          const SizedBox(height: 16),

          // Render active stage content
          if (_activeStage == 0) _buildStage1CrushingView() else _buildStage2BottlingView(),
        ],
      ),
    );
  }

  // ==========================================
  // STAGE 1: CRUSHING DAY VIEW
  // ==========================================
  Widget _buildStage1CrushingView() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.grain, color: Color(0xFFD97706), size: 20),
                ),
                const SizedBox(width: 10),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'మిల్లులో క్రషింగ్ లెక్క (Crushing Entry)',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'ఆడిన గింజలు, వచ్చిన కేక్ & స్కేల్ పై నూనె తూకం',
                      style: TextStyle(color: Colors.grey, fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Seed Type
            DropdownButtonFormField<String>(
              initialValue: _seedName,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'గింజల రకం (Seed Variety)',
                prefixIcon: Icon(Icons.grass),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'వేరుశనగ / పల్లీలు (Groundnut)',
                  child: Text('వేరుశనగ / పల్లీలు (Groundnut)'),
                ),
                DropdownMenuItem(
                  value: 'నువ్వులు (Sesame / Til)',
                  child: Text('నువ్వులు (Sesame / Til)'),
                ),
                DropdownMenuItem(
                  value: 'ఆవాలు (Mustard)',
                  child: Text('ఆవాలు (Mustard)'),
                ),
              ],
              onChanged: (v) {
                if (v != null) {
                  setState(() {
                    _seedName = v;
                    _recalcProcessingCost();
                  });
                }
              },
            ),
            const SizedBox(height: 14),

            // Tin / Drum Marking
            TextField(
              controller: _tinLabelCtrl,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'నిల్వ చేసే టిన్ / డ్రమ్ మార్కింగ్ (Tin/Drum Label) *',
                prefixIcon: Icon(Icons.label_important_outline),
                helperText: 'నూనె నిల్వ ఉంచే టిన్ పేరు/నంబర్ ఇవ్వండి (ఉదా: టిన్ #1, డ్రమ్ #A)',
              ),
            ),
            const SizedBox(height: 14),

            // Input Seeds Kg
            TextField(
              controller: _seedKgCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'వాడిన గింజలు (Input Kg) *',
                prefixIcon: Icon(Icons.scale),
                suffixText: 'Kg',
              ),
            ),
            const SizedBox(height: 14),

            // Oil Weighed in Kg (on scale machine!)
            TextField(
              controller: _oilKgCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'వేయింగ్ స్కేల్‌పై నూనె తూకం (Oil Weighed in Kg) *',
                prefixIcon: Icon(Icons.monitor_weight_outlined),
                suffixText: 'Kg',
                helperText: 'తూకం మెషిన్‌పై చూసిన కేజీలు నమోదు చేయండి',
              ),
            ),
            const SizedBox(height: 8),

            // Auto-calculated Litres Banner
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFA7F3D0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome, color: Color(0xFF047857), size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '👉 సుమారు ${_computedLitres.toStringAsFixed(1)} లీటర్ల ముడి నూనె (Litres)',
                          style: const TextStyle(
                            color: Color(0xFF065F46),
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const Text(
                          'డెన్సిటీ ~0.91 kg/Ltr • డ్రమ్‌లో తేలడానికి 2 రోజులు నిల్వ ఉంచాలి',
                          style: TextStyle(color: Color(0xFF047857), fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Cake Output Kg
            TextField(
              controller: _cakeKgCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'వచ్చిన నూనె చెక్క/పిండి (Oil Cake in Kg) *',
                prefixIcon: Icon(Icons.inventory_2_outlined),
                suffixText: 'Kg',
                helperText: '✓ ఈ కేక్ వెంటనే సేల్స్ స్టాక్‌లోకి యాడ్ అవుతుంది (ఆ రోజే అమ్మవచ్చు)',
                helperStyle: TextStyle(color: Color(0xFF047857), fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 14),

            // Machine Run Timer Card (Start & Stop Time)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFD1D5DB)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.timer_outlined, color: Color(0xFFD97706), size: 18),
                      ),
                      const SizedBox(width: 8),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'మిషన్ రన్నింగ్ సమయం (Machine Run Time)',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1F2937)),
                          ),
                          Text(
                            'స్టార్ట్ & స్టాప్ టైమ్ ఆధారంగా కరెంట్ & కూలీ ఖచ్చితంగా లెక్కిస్తుంది',
                            style: TextStyle(fontSize: 10, color: Colors.grey),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Start and Stop Time Blocks
                  Row(
                    children: [
                      // Start Time Card
                      Expanded(
                        child: InkWell(
                          onTap: _pickStartTime,
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0FDF4),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFF86EFAC)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.play_circle_fill, color: Color(0xFF16A34A), size: 14),
                                    SizedBox(width: 4),
                                    Text('స్టార్టింగ్ టైమ్', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF166534))),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _formatTime(_startTime),
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF14532D)),
                                ),
                                const SizedBox(height: 4),
                                SizedBox(
                                  width: double.infinity,
                                  height: 26,
                                  child: OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                      padding: EdgeInsets.zero,
                                      side: const BorderSide(color: Color(0xFF16A34A)),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                    ),
                                    onPressed: _onStartMachineNow,
                                    child: const Text('⏱️ ఇప్పుడు స్టార్ట్', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF16A34A))),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Stop Time Card
                      Expanded(
                        child: InkWell(
                          onTap: _pickStopTime,
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFFECACA)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.stop_circle, color: Color(0xFFDC2626), size: 14),
                                    SizedBox(width: 4),
                                    Text('ముగింపు సమయం', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF991B1B))),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _formatTime(_stopTime),
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF7F1D1D)),
                                ),
                                const SizedBox(height: 4),
                                SizedBox(
                                  width: double.infinity,
                                  height: 26,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      padding: EdgeInsets.zero,
                                      backgroundColor: const Color(0xFFDC2626),
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                    ),
                                    onPressed: _onStopMachineNow,
                                    child: const Text('⏹️ ఇప్పుడు ఆపు', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Duration Banner
                  if (_isMachineRunning)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF86EFAC)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.autorenew, color: Color(0xFF16A34A), size: 16),
                          SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '🟢 మిషన్ నడుస్తోంది... క్రషింగ్ పూర్తి కాగానే "ఇప్పుడు ఆపు" నొక్కండి.',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF15803D)),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('మొత్తం నడిచిన సమయం:', style: TextStyle(fontSize: 11, color: Colors.black87)),
                          Text(
                            '${_durationMinutes ~/ 60} గంటల ${_durationMinutes % 60} నిమిషాలు ($_durationMinutes నిమి.)',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF164610)),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 10),

                  // Calculated Cost Breakdown Pill
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('వాస్తవ కరెంట్ & లేబర్ ఖర్చు:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF92400E))),
                            Text(
                              '₹${(_timerPowerCost + _timerLaborCost).round()}',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFFB45309)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '• ⚡ కరెంట్ (${_timerPowerUnits.toStringAsFixed(1)} యూనిట్లు): ~₹${_timerPowerCost.round()} (5HP • ${_timerRunHours.toStringAsFixed(1)} గం.)\n'
                          '• 👷 కూలీ: ~₹${_timerLaborCost.round()} (₹400/రోజుకు - గంటకు ₹50 చొప్పున)',
                          style: const TextStyle(fontSize: 10, color: Color(0xFF78350F), height: 1.3),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Editable Processing Cost Input
                  TextField(
                    controller: _procCostCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      labelText: 'ఖర్చు నమోదు (₹)',
                      prefixIcon: Icon(Icons.currency_rupee, size: 20),
                      suffixText: '₹',
                      helperText: 'రన్నింగ్ టైమ్‌తో ఆటోమేటిక్‌గా వచ్చింది (అవసరమైతే మార్చుకోవచ్చు)',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Recovery / Yield Pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('నూనె రికవరీ రేటు (Oil Yield):', style: TextStyle(fontSize: 12, color: Colors.black87)),
                  Text(
                    '${_extractionPct.toStringAsFixed(1)}%',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF164610)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD97706),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                ),
                onPressed: _isLoading ? null : _submitCrushingBatch,
                icon: const Icon(Icons.save),
                label: const Text('క్రషింగ్ బ్యాచ్ నమోదు చేయి', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // STAGE 2: BOTTLING DAY VIEW (2 Days Later)
  // ==========================================
  Widget _buildStage2BottlingView() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD1FAE5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.sanitizer, color: Color(0xFF047857), size: 20),
                ),
                const SizedBox(width: 10),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'బాట్లింగ్ & ప్యాకింగ్ (Bottling Entry)',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '2 రోజుల తర్వాత తేరిన నూనెను బాటిళ్లలో ప్యాకింగ్ చేయడం',
                      style: TextStyle(color: Colors.grey, fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Pending Tins Dropdown
            const Text(
              'ప్రాసెస్ పూర్తయి టిన్స్‌లో ఉన్న నూనె బ్యాచ్ (Select Tin/Drum Batch): *',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF164610)),
            ),
            const SizedBox(height: 6),
            DropdownButtonFormField<int>(
              key: ValueKey(_selectedTinId),
              initialValue: _selectedTinId,
              isExpanded: true,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                prefixIcon: Icon(Icons.oil_barrel, color: Color(0xFF047857)),
                labelText: 'తేరిన నూనె టిన్ / డ్రమ్ ఎంచుకోండి',
                filled: true,
                fillColor: Color(0xFFF9FAFB),
              ),
              items: [
                ..._pendingTins.map((tin) {
                  final id = tin['id'] as int;
                  final label = tin['tin_label'] ?? 'టిన్ #$id';
                  final seed = tin['seed_name'] ?? 'నూనె';
                  final remLtr = (tin['settled_oil_litres_remaining'] as num?)?.toDouble() ?? 0.0;
                  final days = tin['days_settled'] ?? 0;
                  final statusTag = days >= 2 ? '✅ $days రోజులు తేరినది (Ready)' : '⏳ $days రోజు (నిల్వలో ఉంది)';
                  return DropdownMenuItem<int>(
                    value: id,
                    child: Text(
                      '$label: $seed • ${remLtr.toStringAsFixed(1)} Ltr ($statusTag)',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }),
                const DropdownMenuItem<int>(
                  value: 0,
                  child: Text(
                    '+ సాధారణ వేరుశనగ నూనె (General Groundnut Oil)',
                    style: TextStyle(fontSize: 13, color: Colors.blueGrey, fontStyle: FontStyle.italic),
                  ),
                ),
                const DropdownMenuItem<int>(
                  value: -1,
                  child: Text(
                    '+ సాధారణ నువ్వుల నూనె (General Sesame Oil)',
                    style: TextStyle(fontSize: 13, color: Colors.blueGrey, fontStyle: FontStyle.italic),
                  ),
                ),
              ],
              onChanged: (val) {
                if (val != null) _onSelectTinId(val);
              },
            ),

            // Highlighted Tin Info Badge
            if (_selectedTin != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFA7F3D0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.check_circle, color: Color(0xFF059669), size: 18),
                            const SizedBox(width: 6),
                            Text(
                              '${_selectedTin!['tin_label']} (${_selectedTin!['seed_name']})',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF065F46)),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: ((_selectedTin!['days_settled'] ?? 0) >= 2)
                                ? const Color(0xFF059669)
                                : const Color(0xFFD97706),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            ((_selectedTin!['days_settled'] ?? 0) >= 2)
                                ? 'తేరి సిద్ధంగా ఉంది (Ready)'
                                : '${_selectedTin!['days_settled']} రోజు (నిల్వలో ఉంది)',
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '• టిన్‌లో మిగిలిన ముడి నూనె: ${(_selectedTin!['settled_oil_litres_remaining'] as num?)?.toStringAsFixed(1) ?? '0.0'} Ltr (~${(_selectedTin!['oil_output_kg'] as num?)?.toStringAsFixed(1) ?? '--'} Kg)\n'
                      '• క్రషింగ్ చేసిన తేదీ: ${_selectedTin!['batch_date']} (${_selectedTin!['days_settled']} రోజుల క్రితం)',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF047857), height: 1.35),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 14),

            const Divider(),
            const SizedBox(height: 8),
            const Text(
              'ప్యాక్ చేసిన బాటిళ్ల సంఖ్య నమోదు చేయండి:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF164610)),
            ),
            const SizedBox(height: 10),

            // 1 Litre Bottles
            TextField(
              controller: _bottle1LCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: '1 లీటర్ బాటిల్స్ (1L Bottles)',
                prefixIcon: Icon(Icons.wine_bar_outlined),
                suffixText: 'బాటిళ్లు',
                helperText: '1L బాటిల్స్ & లేబుల్స్ స్టాక్ నుండి ఆటోమేటిక్‌గా తగ్గుతాయి',
              ),
            ),
            const SizedBox(height: 12),

            // 500 ml Bottles
            TextField(
              controller: _bottle500mlCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: '500 ml బాటిల్స్ (500ml Bottles)',
                prefixIcon: Icon(Icons.wine_bar_outlined),
                suffixText: 'బాటిళ్లు',
                helperText: '500ml బాటిల్స్ & లేబుల్స్ స్టాక్ నుండి ఆటోమేటిక్‌గా తగ్గుతాయి',
              ),
            ),
            const SizedBox(height: 12),

            // 5 Litre Cans (Only for groundnut)
            if (_bottlingOilType == 'GROUNDNUT') ...[
              TextField(
                controller: _can5LCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: '5 లీటర్ల క్యాన్లు (5L Cans)',
                  prefixIcon: Icon(Icons.local_gas_station_outlined),
                  suffixText: 'క్యాన్లు',
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Discarded Sludge Wastage Field
            TextField(
              controller: _sludgeLtrCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'అడుగున మిగిలిన గానుగ మడ్డి (Sludge in Litres)',
                prefixIcon: Icon(Icons.delete_sweep_outlined),
                suffixText: 'Ltr',
              ),
            ),
            const SizedBox(height: 6),

            // Discarded Sludge Notice
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Color(0xFFB91C1C), size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'ఈ మడ్డి పూర్తి ప్రాసెస్ వేస్టేజ్ / వృథా మాత్రమే (అమ్మకానికి పెట్టబడదు).',
                      style: TextStyle(color: Color(0xFF991B1B), fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Summary Card
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('మొత్తం ప్యాక్ అయిన నూనె:'),
                      Text('${_totalPackedLitres.toStringAsFixed(1)} Ltr', style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('మడ్డి వేస్టేజ్ (వృథా):', style: TextStyle(color: Color(0xFFB91C1C))),
                      Text('${_sludgeLtr.toStringAsFixed(1)} Ltr', style: const TextStyle(color: Color(0xFFB91C1C), fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const Divider(height: 12),
                  if (_selectedTin != null) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('ఎంచుకున్న టిన్ నూనె:', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF047857))),
                        Text(
                          '${(_selectedTin!['settled_oil_litres_remaining'] as num?)?.toStringAsFixed(1) ?? '0.0'} Ltr',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF047857)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                  ],
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('మొత్తం వాడిన డ్రమ్ నూనె:', style: TextStyle(fontWeight: FontWeight.bold)),
                      Text('${_totalOilConsumed.toStringAsFixed(1)} Ltr', style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF164610))),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('వాడే ఖాళీ బాటిల్స్ & లేబుల్స్:', style: TextStyle(color: Colors.blueGrey)),
                      Text('$_totalEmptyBottles సెట్లు (-$_totalEmptyBottles తగ్గుతాయి)', style: const TextStyle(color: Colors.blueGrey, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Submit Bottling Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                ),
                onPressed: _isLoading ? null : _submitBottling,
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('బాటిల్స్ ప్యాక్ చేసి స్టాక్‌లో చేర్చు', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 5. CUSTOMER KHATA (CREDIT LEDGER) TAB
// ==========================================
class CustomerKhataLedgerView extends StatefulWidget {
  final String apiBase;
  const CustomerKhataLedgerView({super.key, required this.apiBase});

  @override
  State<CustomerKhataLedgerView> createState() => _CustomerKhataLedgerViewState();
}

class _CustomerKhataLedgerViewState extends State<CustomerKhataLedgerView> {
  List<dynamic> _customers = [];
  bool _isLoading = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadKhataData();
  }

  Future<void> _loadKhataData() async {
    setState(() => _isLoading = true);
    try {
      final res = await http.get(Uri.parse('${widget.apiBase}/customers'));
      if (res.statusCode == 200) {
        _customers = jsonDecode(res.body);
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  List<dynamic> get _filteredCustomers {
    if (_searchQuery.trim().isEmpty) return _customers;
    final q = _searchQuery.toLowerCase().trim();
    return _customers.where((c) {
      final name = (c['name'] ?? '').toString().toLowerCase();
      final nameTe = (c['name_te'] ?? '').toString().toLowerCase();
      final phone = (c['phone'] ?? '').toString().toLowerCase();
      return name.contains(q) || nameTe.contains(q) || phone.contains(q);
    }).toList();
  }

  Future<void> _showAddCustomerDialog() async {
    final nameCtrl = TextEditingController();
    final nameTeCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    final limitCtrl = TextEditingController(text: '5000');

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.person_add_alt_1, color: Color(0xFF7C3AED)),
            SizedBox(width: 8),
            Text('కొత్త ఖాతాదారుడు (New Customer)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'పేరు (Name in English) *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: nameTeCtrl,
                decoration: const InputDecoration(
                  labelText: 'పేరు (తెలుగులో - ఐచ్ఛికం)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'మొబైల్ నెంబర్ *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: addressCtrl,
                decoration: const InputDecoration(
                  labelText: 'చిరునామా / గ్రామం / ల్యాండ్‌మార్క్',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: limitCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'క్రెడిట్ పరిమితి (Limit ₹)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('రద్దు (Cancel)'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7C3AED),
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('దయచేసి పేరు నమోదు చేయండి')),
                );
                return;
              }
              Navigator.pop(ctx);
              try {
                final res = await http.post(
                  Uri.parse('${widget.apiBase}/customers'),
                  headers: {'Content-Type': 'application/json'},
                  body: jsonEncode({
                    'name': name,
                    'name_te': nameTeCtrl.text.trim().isNotEmpty ? nameTeCtrl.text.trim() : null,
                    'phone': phoneCtrl.text.trim().isNotEmpty ? phoneCtrl.text.trim() : null,
                    'address': addressCtrl.text.trim().isNotEmpty ? addressCtrl.text.trim() : null,
                    'credit_limit': double.tryParse(limitCtrl.text.trim()) ?? 5000,
                  }),
                );
                if (res.statusCode == 201 && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: const Color(0xFF10B981),
                      content: Text('✅ $name ఖాతా విజయవంతంగా చేర్చబడింది!'),
                    ),
                  );
                  _loadKhataData();
                }
              } catch (_) {}
            },
            child: const Text('ఖాతా తెరువు'),
          ),
        ],
      ),
    );
  }

  Future<void> _showReceivePaymentDialog(dynamic cust) async {
    final custId = cust['id'];
    final custName = cust['name_te'] ?? cust['name'];
    final due = (cust['total_credit_due'] as num).toDouble();
    final amountCtrl = TextEditingController(text: due > 0 ? due.toInt().toString() : '');
    final notesCtrl = TextEditingController();
    String paymentMode = 'CASH';

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dCtx, setDState) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.payments, color: Color(0xFF10B981)),
              const SizedBox(width: 8),
              Expanded(
                child: Text('ఖాతా బాకీ వసూలు • $custName',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFECACA)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('ప్రస్తుత బాకీ (Current Due):',
                          style: TextStyle(fontSize: 13, color: Color(0xFF991B1B), fontWeight: FontWeight.w600)),
                      Text('₹${due.toInt()}',
                          style: const TextStyle(fontSize: 18, color: Color(0xFF991B1B), fontWeight: FontWeight.w900)),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'ఇచ్చిన మొత్తం (Amount Paid ₹) *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.currency_rupee),
                  ),
                ),
                const SizedBox(height: 12),
                const Text('చెల్లింపు విధానం (Payment Mode):',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        avatar: const Icon(Icons.money, size: 16),
                        label: const Text('నగదు (Cash)'),
                        selected: paymentMode == 'CASH',
                        selectedColor: const Color(0xFFD1FAE5),
                        onSelected: (val) {
                          if (val) setDState(() => paymentMode = 'CASH');
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ChoiceChip(
                        avatar: const Icon(Icons.qr_code, size: 16),
                        label: const Text('UPI / PhonePe'),
                        selected: paymentMode == 'UPI',
                        selectedColor: const Color(0xFFDBEAFE),
                        onSelected: (val) {
                          if (val) setDState(() => paymentMode = 'UPI');
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesCtrl,
                  decoration: const InputDecoration(
                    labelText: 'గమనిక (ఉదా: గూగుల్ పే చేసారు / నోట్స్)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('రద్దు (Cancel)'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final amt = double.tryParse(amountCtrl.text.trim()) ?? 0;
                if (amt <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('దయచేసి సరైన మొత్తం నమోదు చేయండి')),
                  );
                  return;
                }
                Navigator.pop(ctx);
                try {
                  final res = await http.post(
                    Uri.parse('${widget.apiBase}/customers/$custId/payment'),
                    headers: {'Content-Type': 'application/json'},
                    body: jsonEncode({
                      'amount': amt,
                      'payment_mode': paymentMode,
                      'notes': notesCtrl.text.trim().isNotEmpty ? notesCtrl.text.trim() : null,
                    }),
                  );
                  if (res.statusCode == 200 && mounted) {
                    final data = jsonDecode(res.body);
                    final newBal = (data['new_balance'] as num).toInt();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: const Color(0xFF10B981),
                        content: Text('✅ ₹${amt.toInt()} జమ చేయబడింది! మిగిలిన బాకీ: ₹$newBal'),
                      ),
                    );
                    _loadKhataData();
                  }
                } catch (_) {}
              },
              child: const Text('చెల్లింపు నమోదు చేయి'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCustomerLedgerDialog(dynamic cust) async {
    final custId = cust['id'];
    final custName = cust['name_te'] ?? cust['name'];
    final phone = cust['phone'] ?? '';

    List<dynamic> transactions = [];
    bool loading = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (lCtx, setLState) {
          if (loading) {
            http.get(Uri.parse('${widget.apiBase}/customers/$custId/ledger')).then((res) {
              if (res.statusCode == 200) {
                final data = jsonDecode(res.body);
                setLState(() {
                  transactions = data['ledger'] ?? [];
                  loading = false;
                });
              } else {
                setLState(() => loading = false);
              }
            }).catchError((_) {
              setLState(() => loading = false);
            });
          }

          final due = (cust['total_credit_due'] as num).toInt();

          return AlertDialog(
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('$custName లెక్కల పుస్తకం',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis),
                      if (phone.isNotEmpty)
                        Text(phone, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: due > 0 ? const Color(0xFFFEE2E2) : const Color(0xFFD1FAE5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    due > 0 ? 'బాకీ: ₹$due' : 'పూర్తయింది ✓',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: due > 0 ? const Color(0xFFB91C1C) : const Color(0xFF047857),
                    ),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              height: 420,
              child: loading
                  ? const Center(child: CircularProgressIndicator())
                  : transactions.isEmpty
                      ? const Center(child: Text('ఎలాంటి లావాదేవీలు లేవు'))
                      : ListView.separated(
                          itemCount: transactions.length,
                          separatorBuilder: (c, i) => const Divider(height: 1),
                          itemBuilder: (c, idx) {
                            final tx = transactions[idx];
                            final isPayment = tx['type'] == 'PAYMENT';
                            final amt = (tx['amount'] as num).toInt();
                            final bal = (tx['balance_after'] as num).toInt();
                            final date = (tx['created_at'] ?? '').toString().replaceFirst('T', ' ').split('.')[0];

                            return ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: CircleAvatar(
                                radius: 16,
                                backgroundColor: isPayment ? const Color(0xFFD1FAE5) : const Color(0xFFFEE2E2),
                                child: Icon(
                                  isPayment ? Icons.arrow_downward : Icons.shopping_bag_outlined,
                                  size: 16,
                                  color: isPayment ? const Color(0xFF047857) : const Color(0xFFB91C1C),
                                ),
                              ),
                              title: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    isPayment
                                        ? 'జమ (${tx['payment_mode'] ?? 'CASH'})'
                                        : 'కొనుగోలు (${tx['bill_number'] ?? 'ఉద్దెర'})',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                  Text(
                                    isPayment ? '- ₹$amt' : '+ ₹$amt',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 14,
                                      color: isPayment ? const Color(0xFF047857) : const Color(0xFFB91C1C),
                                    ),
                                  ),
                                ],
                              ),
                              subtitle: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(date, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                                  Text('మిగిలింది: ₹$bal',
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                                ],
                              ),
                            );
                          },
                        ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('మూసివేయి (Close)'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showWhatsAppReminderDialog(dynamic cust) {
    final custName = cust['name_te'] ?? cust['name'];
    final due = (cust['total_credit_due'] as num).toInt();
    final phone = (cust['phone'] ?? '').toString();

    final message = '''నమస్కారం $custName గారు 🙏
UNIK NATURALS (కోల్డ్ ప్రెస్డ్ ఆయిల్స్ & పిండి మిల్లు) నుండి.
మీ ఖాతాలో ప్రస్తుత బకాయి: ₹$due.
సౌలభ్యం కొద్దీ నగదు లేదా PhonePe / GPay ద్వారా చెల్లించగలరు.
ధన్యవాదాలు! 🌿''';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.chat, color: Color(0xFF10B981)),
            SizedBox(width: 8),
            Text('వాట్సాప్ రిమైండర్ మెసేజ్', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ఫోన్: ${phone.isNotEmpty ? phone : "నెంబర్ లేదు"}',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Text(message, style: const TextStyle(fontSize: 13, height: 1.4)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('రద్దు (Cancel)'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: message));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  backgroundColor: Color(0xFF10B981),
                  content: Text('📋 మెసేజ్ కాపీ అయింది! మీరు వాట్సాప్‌లో పేస్ట్ చేయవచ్చు.'),
                ),
              );
            },
            icon: const Icon(Icons.copy, size: 16),
            label: const Text('మెసేజ్ కాపీ చేయి'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final list = _filteredCustomers;
    int totalDue = 0;
    int activeCount = 0;
    for (final c in _customers) {
      final d = (c['total_credit_due'] as num?)?.toInt() ?? 0;
      totalDue += d;
      if (d > 0) activeCount++;
    }

    return RefreshIndicator(
      onRefresh: _loadKhataData,
      child: Column(
        children: [
          // 1. TOP STATS CARD
          Container(
            margin: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF4C1D95), Color(0xFF7C3AED)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF7C3AED).withValues(alpha: 0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.menu_book, color: Color(0xFFFDE68A), size: 18),
                            SizedBox(width: 6),
                            Text(
                              'మార్కెట్ ఖాతా బాకీ (Market Credit Due)',
                              style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '₹$totalDue',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF59E0B),
                        foregroundColor: const Color(0xFF111827),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                      onPressed: _showAddCustomerDialog,
                      icon: const Icon(Icons.person_add, size: 16),
                      label: const Text('➕ కొత్త ఖాతా', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'బాకీ ఉన్నవారు: $activeCount మంది',
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'మొత్తం ఖాతాలు: ${_customers.length}',
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 2. SEARCH BOX
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'కస్టమర్ పేరు లేదా ఫోన్ నెంబర్‌తో వెతకండి...',
                hintStyle: const TextStyle(fontSize: 13),
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          setState(() {
                            _searchQuery = '';
                            _searchController.clear();
                          });
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),

          // 3. CUSTOMER LIST
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : list.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.contacts_outlined, size: 48, color: Colors.grey),
                            const SizedBox(height: 8),
                            Text(
                              _searchQuery.isNotEmpty ? 'కస్టమర్ దొరకలేదు' : 'ఇంకా ఖాతాలు లేవు',
                              style: const TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        itemCount: list.length,
                        itemBuilder: (ctx, idx) {
                          final c = list[idx];
                          final due = (c['total_credit_due'] as num).toInt();
                          final nameTe = c['name_te'] ?? c['name'];
                          final nameEn = c['name'];
                          final phone = c['phone'] ?? '';
                          final hasDue = due > 0;

                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            elevation: hasDue ? 2 : 1,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: BorderSide(
                                color: hasDue ? const Color(0xFFFDE68A) : const Color(0xFFE5E7EB),
                                width: hasDue ? 1.5 : 1,
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Top Row: Avatar + Name + Due Badge
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      CircleAvatar(
                                        radius: 20,
                                        backgroundColor: hasDue
                                            ? const Color(0xFFFEE2E2)
                                            : const Color(0xFFE0E7FF),
                                        child: Text(
                                          (nameEn.isNotEmpty ? nameEn[0] : 'U').toUpperCase(),
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: hasDue
                                                ? const Color(0xFFB91C1C)
                                                : const Color(0xFF4338CA),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              nameTe,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15,
                                                color: Color(0xFF111827),
                                              ),
                                            ),
                                            if (nameTe != nameEn)
                                              Text(
                                                nameEn,
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color: Color(0xFF6B7280),
                                                ),
                                              ),
                                            if (phone.isNotEmpty)
                                              Row(
                                                children: [
                                                  const Icon(Icons.phone_outlined, size: 12, color: Color(0xFF6B7280)),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    phone,
                                                    style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
                                                  ),
                                                ],
                                              ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: hasDue
                                              ? const Color(0xFFFEF2F2)
                                              : const Color(0xFFECFDF5),
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(
                                            color: hasDue
                                                ? const Color(0xFFFECACA)
                                                : const Color(0xFFA7F3D0),
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              hasDue ? 'బాకీ (Due)' : 'బాకీ లేదు',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w600,
                                                color: hasDue
                                                    ? const Color(0xFF991B1B)
                                                    : const Color(0xFF047857),
                                              ),
                                            ),
                                            Text(
                                              '₹$due',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w900,
                                                color: hasDue
                                                    ? const Color(0xFFB91C1C)
                                                    : const Color(0xFF047857),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 10),
                                  const Divider(height: 1),
                                  const SizedBox(height: 8),

                                  // Action Buttons
                                  Row(
                                    children: [
                                      // Receive Payment Button
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: const Color(0xFF047857),
                                            side: const BorderSide(color: Color(0xFF10B981)),
                                            padding: const EdgeInsets.symmetric(vertical: 8),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          ),
                                          onPressed: () => _showReceivePaymentDialog(c),
                                          icon: const Icon(Icons.add_card, size: 15),
                                          label: const Text('వసూలు', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                        ),
                                      ),
                                      const SizedBox(width: 6),

                                      // Ledger / Statement Button
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: const Color(0xFF6D28D9),
                                            side: const BorderSide(color: Color(0xFF8B5CF6)),
                                            padding: const EdgeInsets.symmetric(vertical: 8),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          ),
                                          onPressed: () => _showCustomerLedgerDialog(c),
                                          icon: const Icon(Icons.receipt_long, size: 15),
                                          label: const Text('లెక్క', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                        ),
                                      ),
                                      const SizedBox(width: 6),

                                      // WhatsApp Button
                                      IconButton.outlined(
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: const Color(0xFF047857),
                                          side: const BorderSide(color: Color(0xFF10B981)),
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                        icon: const Icon(Icons.chat_bubble_outline, size: 16),
                                        tooltip: 'WhatsApp రిమైండర్',
                                        onPressed: () => _showWhatsAppReminderDialog(c),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

