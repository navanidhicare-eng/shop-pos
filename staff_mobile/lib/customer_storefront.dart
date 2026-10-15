import 'dart:convert';
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class CustomerStorefrontView extends StatefulWidget {
  final String apiBase;
  final VoidCallback onStaffLoginRequested;
  final Map<String, dynamic>? currentCustomer;
  final Function(Map<String, dynamic>?)? onCustomerAuthChanged;

  const CustomerStorefrontView({
    super.key,
    required this.apiBase,
    required this.onStaffLoginRequested,
    this.currentCustomer,
    this.onCustomerAuthChanged,
  });

  @override
  State<CustomerStorefrontView> createState() => _CustomerStorefrontViewState();
}

class _CustomerStorefrontViewState extends State<CustomerStorefrontView> {
  List<Map<String, dynamic>> _products = [];
  bool _isLoading = true;
  String _errorMessage = '';
  String _selectedCategory = 'ALL';
  String _searchQuery = '';
  Map<String, dynamic>? _customer;

  // Cart: Map<int, Map<String, dynamic>> where key is item id
  final Map<int, Map<String, dynamic>> _cart = {};

  final TextEditingController _searchController = TextEditingController();

  String _lang = 'te'; // 'te' or 'en'
  bool get _isTe => _lang == 'te';
  String _t(String te, String en) => _isTe ? te : en;

  final List<Map<String, String>> _categories = [
    {'key': 'ALL', 'name_te': 'అన్నీ', 'name_en': 'All', 'icon': '🌟'},
    {'key': 'OIL', 'name_te': 'గానుగ నూనెలు', 'name_en': 'Cold Pressed Oils', 'icon': '🛢️'},
    {'key': 'CAKE', 'name_te': 'నూనె చెక్క', 'name_en': 'Oil Cakes', 'icon': '🥜'},
    {'key': 'REPACK', 'name_te': 'పప్పులు & గింజలు', 'name_en': 'Pulses & Grains', 'icon': '🌾'},
    {'key': 'SNACK', 'name_te': 'తాజా స్నాక్స్', 'name_en': 'Fresh Snacks', 'icon': '🍿'},
  ];

  @override
  void initState() {
    super.initState();
    _loadSavedLanguage();
    _customer = widget.currentCustomer;
    if (_customer == null) {
      _loadSavedCustomer();
    }
    _fetchProducts();
  }

  void _loadSavedLanguage() {
    try {
      final saved = html.window.localStorage['unik_customer_lang'];
      if (saved == 'en' || saved == 'te') {
        _lang = saved!;
      }
    } catch (_) {}
  }

  void _setLanguage(String lang) {
    if (_lang == lang) return;
    setState(() {
      _lang = lang;
    });
    try {
      html.window.localStorage['unik_customer_lang'] = lang;
    } catch (_) {}
  }

  void _loadSavedCustomer() {
    try {
      final raw = html.window.localStorage['unik_customer_user'];
      if (raw != null && raw.isNotEmpty) {
        final parsed = jsonDecode(raw);
        if (parsed is Map<String, dynamic>) {
          setState(() {
            _customer = parsed;
          });
          widget.onCustomerAuthChanged?.call(parsed);
        }
      }
    } catch (_) {}
  }

  @override
  void didUpdateWidget(covariant CustomerStorefrontView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentCustomer != oldWidget.currentCustomer) {
      setState(() {
        _customer = widget.currentCustomer;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchProducts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    try {
      final res = await http.get(Uri.parse('${widget.apiBase}/customer/products'));
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        setState(() {
          _products = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'వస్తువుల వివరాలు పొందలేకపోయాము (Code: ${res.statusCode})';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'సర్వర్ కనెక్ట్ కావడం లేదు: $e';
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filteredProducts {
    return _products.where((item) {
      if (_selectedCategory != 'ALL') {
        final cat = (item['category'] ?? '').toString().toUpperCase();
        if (_selectedCategory == 'OIL' && !cat.contains('OIL')) return false;
        if (_selectedCategory == 'CAKE' && !cat.contains('CAKE')) return false;
        if (_selectedCategory == 'REPACK' && !cat.contains('REPACK') && !cat.contains('FLOUR')) return false;
        if (_selectedCategory == 'SNACK' && !cat.contains('SNACK') && !cat.contains('PACKAGED')) return false;
      }
      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.toLowerCase().trim();
        final name = (item['name'] ?? '').toString().toLowerCase();
        final nameTe = (item['name_te'] ?? '').toString().toLowerCase();
        final group = (item['group_name'] ?? '').toString().toLowerCase();
        final groupTe = (item['group_name_te'] ?? '').toString().toLowerCase();
        if (!name.contains(q) && !nameTe.contains(q) && !group.contains(q) && !groupTe.contains(q)) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  int get _cartTotalCount {
    int total = 0;
    _cart.forEach((_, item) {
      total += (item['qty'] as num).toInt();
    });
    return total;
  }

  double get _cartTotalPrice {
    double total = 0;
    _cart.forEach((_, item) {
      final price = (item['product']['selling_price'] as num).toDouble();
      final qty = (item['qty'] as num).toDouble();
      total += price * qty;
    });
    return total;
  }

  void _addToCart(Map<String, dynamic> product) {
    final id = product['id'] as int;
    setState(() {
      if (_cart.containsKey(id)) {
        _cart[id]!['qty'] = (_cart[id]!['qty'] as int) + 1;
      } else {
        _cart[id] = {'product': product, 'qty': 1};
      }
    });
  }

  void _removeFromCart(int productId) {
    setState(() {
      if (_cart.containsKey(productId)) {
        final currentQty = _cart[productId]!['qty'] as int;
        if (currentQty > 1) {
          _cart[productId]!['qty'] = currentQty - 1;
        } else {
          _cart.remove(productId);
        }
      }
    });
  }

  void _openCartSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CartCheckoutSheet(
        apiBase: widget.apiBase,
        cart: _cart,
        customer: _customer,
        isTe: _isTe,
        onRequireLogin: () {
          Navigator.pop(ctx);
          _openCustomerAuthDialog();
        },
        onCartUpdated: () => setState(() {}),
        onOrderSuccess: (orderData) {
          setState(() {
            _cart.clear();
          });
          Navigator.pop(ctx);
          _showOrderSuccessDialog(orderData);
        },
      ),
    );
  }

  void _openCustomerAuthDialog({bool initialRegister = false}) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => _CustomerAuthDialog(
        apiBase: widget.apiBase,
        initialRegister: initialRegister,
        isTe: _isTe,
      ),
    );

    if (result != null && result['user'] != null && mounted) {
      final user = result['user'];
      final token = result['token'] ?? '';
      try {
        html.window.localStorage['unik_customer_token'] = token;
        html.window.localStorage['unik_customer_user'] = jsonEncode(user);
        html.window.localStorage['unik_customer_name'] = user['name'] ?? '';
        html.window.localStorage['unik_customer_phone'] = user['phone'] ?? '';
        html.window.localStorage['unik_customer_address'] = user['address'] ?? '';
      } catch (_) {}

      setState(() {
        _customer = user;
      });
      widget.onCustomerAuthChanged?.call(user);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF047857),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Color(0xFFFBBF24), size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _isTe
                      ? 'స్వాగతం, ${user['name']} గారు! లాగిన్ విజయవంతమైంది.'
                      : 'Welcome, ${user['name']}! Login successful.',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  void _showCustomerProfileSheet() {
    if (_customer == null) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CustomerProfileSheet(
        customer: _customer!,
        isTe: _isTe,
        onViewOrders: () {
          Navigator.pop(ctx);
          _openOrderTrackerDialog();
        },
        onLogout: () {
          Navigator.pop(ctx);
          try {
            html.window.localStorage.remove('unik_customer_token');
            html.window.localStorage.remove('unik_customer_user');
          } catch (_) {}
          setState(() {
            _customer = null;
          });
          widget.onCustomerAuthChanged?.call(null);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_isTe ? 'లాగౌట్ పూర్తయింది.' : 'Logged out successfully.'),
              duration: const Duration(seconds: 2),
            ),
          );
        },
      ),
    );
  }

  void _openOrderTrackerDialog() {
    showDialog(
      context: context,
      builder: (ctx) => _CustomerOrderTrackerDialog(
        apiBase: widget.apiBase,
        isTe: _isTe,
      ),
    );
  }

  void _openProductDetails(Map<String, dynamic> product) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => _ProductDetailsPage(
          apiBase: widget.apiBase,
          product: product,
          isTe: _isTe,
          cartTotalCount: _cartTotalCount,
          cartQty: _cart[product['id'] as int]?['qty'] as int? ?? 0,
          onAddToCart: () {
            _addToCart(product);
          },
          onRemoveFromCart: () {
            _removeFromCart(product['id'] as int);
          },
          onOpenCart: () {
            Navigator.pop(ctx);
            _openCartSheet();
          },
        ),
      ),
    ).then((_) {
      if (mounted) setState(() {});
    });
  }

  void _showOrderSuccessDialog(Map<String, dynamic> order) {
    final orderNum = order['order_number'] ?? 'ORD-000';
    final total = order['total_amount'] ?? 0;
    final delType = order['delivery_type'] == 'PICKUP'
        ? (_isTe ? 'షాప్ పికప్' : 'Store Pickup')
        : (_isTe ? 'హోమ్ డెలివరీ' : 'Home Delivery');

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFFDCFCE7),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF16A34A), width: 3),
              ),
              child: const Icon(Icons.check_circle_outline, color: Color(0xFF16A34A), size: 48),
            ),
            const SizedBox(height: 16),
            Text(
              _t('🎉 ఆర్డర్ నమోదైంది!', '🎉 Order Placed Successfully!'),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF164610)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              _t('మీ ఆర్డర్ షాప్‌కు చేరింది. మేము త్వరలోనే సిద్ధం చేస్తాము.', 'Your order has been received by our shop. We will prepare it shortly.'),
              style: const TextStyle(fontSize: 13, color: Color(0xFF4B5563)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_t('ఆర్డర్ నంబర్:', 'Order Number:'), style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
                      Text(orderNum, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF1F2937))),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_t('మొత్తం చెల్లింపు:', 'Total Amount:'), style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
                      Text('₹$total', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF16A34A))),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_t('రకం:', 'Type:'), style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
                      Text(delType, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF374151))),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF25D366),
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(44),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                final msg = _isTe
                    ? 'నమస్తే UNIK NATURALS, నేను ఆన్‌లైన్ ద్వారా ఆర్డర్ చేసాను. ఆర్డర్ నంబర్: $orderNum, మొత్తం: ₹$total. దయచేసి నిర్ధారించండి.'
                    : 'Hello UNIK NATURALS, I have placed an online order. Order #$orderNum, Total: ₹$total. Please confirm.';
                try {
                  final url = 'https://wa.me/919848012345?text=${Uri.encodeComponent(msg)}';
                  html.window.open(url, '_blank');
                } catch (_) {}
              },
              icon: const Icon(Icons.chat, size: 18),
              label: Text(
                _t('💬 షాప్‌కు వాట్సాప్‌లో చెప్పండి', '💬 Notify Shop on WhatsApp'),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(42),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                _t('సరే (పూర్తయింది)', 'Done'),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerDrawer() {
    final customerName = _customer != null ? (_customer!['name'] ?? _t('కస్టమర్', 'Customer')) : null;
    final customerPhone = _customer != null ? (_customer!['phone'] ?? '') : null;

    return Drawer(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drawer Header
            Container(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 18),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF064E3B), Color(0xFF047857)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFFF59E0B), width: 1.5),
                          color: Colors.white,
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Image.asset(
                          'assets/logo.png',
                          fit: BoxFit.cover,
                          errorBuilder: (ctx, err, st) => const Center(
                            child: Text('🌿', style: TextStyle(fontSize: 20)),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white70, size: 22),
                        onPressed: () => Navigator.pop(context),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'UNIK NATURALS',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                    ),
                  ),
                  Text(
                    _t('గానుగ నూనెలు & మిల్లింగ్ ఉత్పత్తులు', 'Wood-Pressed Oils & Fresh Flours'),
                    style: const TextStyle(
                      color: Color(0xFFFDE68A),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (_customer != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: const Color(0xFF10B981),
                            child: Text(
                              customerName!.isNotEmpty ? customerName[0].toUpperCase() : 'C',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  customerName,
                                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (customerPhone != null && customerPhone.isNotEmpty)
                                  Text(
                                    customerPhone,
                                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFBBF24),
                        foregroundColor: const Color(0xFF064E3B),
                        minimumSize: const Size.fromHeight(38),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        _openCustomerAuthDialog();
                      },
                      icon: const Icon(Icons.login, size: 16),
                      label: Text(
                        _t('లాగిన్ / కొత్త రిజిస్ట్రేషన్', 'Login / Register'),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                ],
              ),
            ),

            // Drawer Items
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                children: [
                  // Store Home
                  ListTile(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    leading: const Icon(Icons.storefront_outlined, color: Color(0xFF047857), size: 22),
                    title: Text(
                      _t('షాపింగ్ హోమ్', 'Store Home'),
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF1E293B)),
                    ),
                    onTap: () => Navigator.pop(context),
                  ),

                  // MY ORDERS (In the Menu Drawer as requested by user!)
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFA7F3D0), width: 1.2),
                    ),
                    child: ListTile(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      leading: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: const Color(0xFF047857),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.receipt_long, color: Colors.white, size: 18),
                      ),
                      title: Text(
                        _t('నా ఆర్డర్లు', 'My Orders'),
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Color(0xFF065F46)),
                      ),
                      subtitle: Text(
                        _t('ఆర్డర్ స్థితి, ట్రాకింగ్ మరియు హిస్టరీ', 'Track order status and history'),
                        style: const TextStyle(fontSize: 11, color: Color(0xFF047857)),
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 13, color: Color(0xFF047857)),
                      onTap: () {
                        Navigator.pop(context);
                        _openOrderTrackerDialog();
                      },
                    ),
                  ),

                  // My Profile (if logged in)
                  if (_customer != null)
                    ListTile(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      leading: const Icon(Icons.person_pin_outlined, color: Color(0xFF047857), size: 22),
                      title: Text(
                        _t('ఖాతా ప్రొఫైల్ & చిరునామా', 'My Profile & Address'),
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF1E293B)),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        _showCustomerProfileSheet();
                      },
                    ),

                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    child: Divider(),
                  ),

                  // WhatsApp Contact
                  ListTile(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    leading: const Icon(Icons.chat_outlined, color: Color(0xFF25D366), size: 22),
                    title: Text(
                      _t('వాట్సాప్ ద్వారా సంప్రదించండి', 'Contact on WhatsApp'),
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF1E293B)),
                    ),
                    subtitle: const Text('+91 98480 12345', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                    onTap: () {
                      Navigator.pop(context);
                      final msg = _isTe
                          ? 'నమస్తే UNIK NATURALS, నాకు మీ ఉత్పత్తుల గురించి సమాచారం కావాలి.'
                          : 'Hello UNIK NATURALS, I would like information about your products.';
                      try {
                        html.window.open('https://wa.me/919848012345?text=${Uri.encodeComponent(msg)}', '_blank');
                      } catch (_) {}
                    },
                  ),

                  // About UNIK Naturals
                  ListTile(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    leading: const Icon(Icons.verified_outlined, color: Color(0xFFD97706), size: 22),
                    title: Text(
                      _t('100% ప్యూర్ నాణ్యత హామీ', '100% Pure Quality Promise'),
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF1E293B)),
                    ),
                    subtitle: Text(
                      _t('రసాయనాలు లేని గానుగ నూనెలు', 'Cold-pressed chemical-free oils'),
                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                    onTap: () => Navigator.pop(context),
                  ),

                  if (_customer != null) ...[
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      child: Divider(),
                    ),
                    ListTile(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      leading: const Icon(Icons.logout, color: Color(0xFFDC2626), size: 20),
                      title: Text(
                        _t('ఖాతా నుండి లాగౌట్', 'Log Out'),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFFDC2626)),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        try {
                          html.window.localStorage.remove('unik_customer_token');
                          html.window.localStorage.remove('unik_customer_user');
                        } catch (_) {}
                        setState(() {
                          _customer = null;
                        });
                        widget.onCustomerAuthChanged?.call(null);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(_isTe ? 'లాగౌట్ పూర్తయింది.' : 'Logged out successfully.'),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),

            // Drawer Footer: Language & Version
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _t('భాష:', 'Language:'),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        InkWell(
                          borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
                          onTap: () => _setLanguage('te'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: _isTe ? const Color(0xFF047857) : Colors.transparent,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              'తెలుగు',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: _isTe ? Colors.white : const Color(0xFF475569),
                              ),
                            ),
                          ),
                        ),
                        InkWell(
                          borderRadius: const BorderRadius.horizontal(right: Radius.circular(16)),
                          onTap: () => _setLanguage('en'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: !_isTe ? const Color(0xFF047857) : Colors.transparent,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              'English',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: !_isTe ? Colors.white : const Color(0xFF475569),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final products = _filteredProducts;
    final hasItemsInCart = _cartTotalCount > 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      drawer: _buildCustomerDrawer(),
      appBar: AppBar(
        backgroundColor: const Color(0xFF064E3B),
        elevation: 0,
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu_rounded, color: Colors.white, size: 24),
            tooltip: _t('మెనూ', 'Menu'),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFF59E0B), width: 1.5),
                color: Colors.white,
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.asset(
                'assets/logo.png',
                fit: BoxFit.cover,
                errorBuilder: (ctx, err, st) => const Center(
                  child: Text('🌿', style: TextStyle(fontSize: 18)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'UNIK NATURALS',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  _t('గానుగ నూనెలు & మిల్లింగ్ ఉత్పత్తులు', 'Wood-Pressed Oils & Fresh Flours'),
                  style: const TextStyle(
                    color: Color(0xFFFDE68A),
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          // Customer Auth: Profile Chip if logged in, or Login/Register button
          if (_customer != null)
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
              child: InkWell(
                onTap: _showCustomerProfileSheet,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF34D399), width: 1.2),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircleAvatar(
                        radius: 10,
                        backgroundColor: Color(0xFF34D399),
                        child: Icon(Icons.person, size: 12, color: Colors.white),
                      ),
                      const SizedBox(width: 5),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 75),
                        child: Text(
                          _customer!['name'] ?? _t('కస్టమర్', 'Customer'),
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF064E3B),
                  elevation: 1,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                onPressed: () => _openCustomerAuthDialog(),
                icon: const Icon(Icons.person_outline, size: 13, color: Color(0xFF064E3B)),
                label: Text(
                  _t('లాగిన్', 'Login'),
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
                ),
              ),
            ),

          // Telugu / English Language Toggle Switch (Replaces the Staff button)
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  borderRadius: const BorderRadius.horizontal(left: Radius.circular(20)),
                  onTap: () => _setLanguage('te'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _isTe ? const Color(0xFFFBBF24) : Colors.transparent,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Text(
                      'తెలుగు',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: _isTe ? const Color(0xFF064E3B) : Colors.white,
                      ),
                    ),
                  ),
                ),
                InkWell(
                  borderRadius: const BorderRadius.horizontal(right: Radius.circular(20)),
                  onTap: () => _setLanguage('en'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: !_isTe ? const Color(0xFFFBBF24) : Colors.transparent,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Text(
                      'English',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: !_isTe ? const Color(0xFF064E3B) : Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: const Color(0xFF047857),
        onRefresh: _fetchProducts,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Premium Hero Banner
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF064E3B), Color(0xFF065F46), Color(0xFF047857)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFFDE68A).withValues(alpha: 0.6), width: 1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('🌿 ', style: TextStyle(fontSize: 11)),
                          Text(
                            _t('100% ప్యూర్ & కోల్డ్ ప్రెస్డ్ • సహజసిద్ధ నాణ్యత', '100% Pure & Cold Pressed • Natural Quality'),
                            style: const TextStyle(color: Color(0xFFFDE68A), fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _t('స్వచ్ఛమైన గానుగ నూనెలు &\nమిల్లింగ్ పిండ్లు ఇంటి వద్దకే!', 'Pure Wood-Pressed Oils &\nStone-Ground Flours At Your Doorstep!'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        height: 1.25,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _t('రసాయనాలు లేని ఆరోగ్యకరమైన నూనెలు, స్వచ్ఛమైన పిండి & తాజా స్నాక్స్.', 'Chemical-free wholesome cooking oils, unadulterated flours & fresh snacks.'),
                      style: const TextStyle(color: Color(0xFFD1FAE5), fontSize: 12),
                    ),
                    const SizedBox(height: 14),

                    // Quick Highlights Row
                    Row(
                      children: [
                        _buildHeroTag(Icons.local_shipping_outlined, _t('హోమ్ డెలివరీ', 'Home Delivery')),
                        const SizedBox(width: 8),
                        _buildHeroTag(Icons.verified_outlined, _t('స్వచ్ఛత గ్యారెంటీ', 'Purity Guarantee')),
                        const SizedBox(width: 8),
                        _buildHeroTag(Icons.eco_outlined, _t('100% ఆర్గానిక్', '100% Organic')),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Floating Search Field
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: _t('🔍 నూనె, పప్పులు, స్నాక్స్ శోధించండి...', '🔍 Search oils, pulses, snacks...'),
                          hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                          prefixIcon: const Icon(Icons.search, color: Color(0xFF047857), size: 20),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18, color: Color(0xFF64748B)),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _searchQuery = '');
                                  },
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                        onChanged: (val) => setState(() => _searchQuery = val),
                      ),
                    ),
                  ],
                ),
              ),

              // Categories Filter Bar
              Container(
                height: 48,
                margin: const EdgeInsets.only(top: 10, bottom: 4),
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  itemCount: _categories.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (ctx, idx) {
                    final cat = _categories[idx];
                    final isSelected = _selectedCategory == cat['key'];
                    final label = _isTe ? (cat['name_te'] ?? '') : (cat['name_en'] ?? '');
                    return InkWell(
                      borderRadius: BorderRadius.circular(24),
                      onTap: () {
                        setState(() => _selectedCategory = cat['key']!);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFF047857) : Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: isSelected ? const Color(0xFF047857) : const Color(0xFFE2E8F0),
                            width: 1.2,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: const Color(0xFF047857).withValues(alpha: 0.25),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(cat['icon'] ?? '', style: const TextStyle(fontSize: 13)),
                            const SizedBox(width: 6),
                            Text(
                              label,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                color: isSelected ? Colors.white : const Color(0xFF334155),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Product Catalog Header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text(
                          _t('ఉత్పత్తులు (${products.length})', 'Products (${products.length})'),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        if (_selectedCategory != 'ALL') ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFECFDF5),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _categories.firstWhere((c) => c['key'] == _selectedCategory, orElse: () => {'name_te': '', 'name_en': ''})[_isTe ? 'name_te' : 'name_en'] ?? '',
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF047857)),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (_selectedCategory != 'ALL' || _searchQuery.isNotEmpty)
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF047857),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        ),
                        onPressed: () {
                          setState(() {
                            _selectedCategory = 'ALL';
                            _searchQuery = '';
                            _searchController.clear();
                          });
                        },
                        icon: const Icon(Icons.refresh, size: 14),
                        label: Text(_t('అన్నీ చూపించు', 'Show All'), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                  ],
                ),
              ),

              // Product Listing Grid
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 60),
                  child: Center(child: CircularProgressIndicator(color: Color(0xFF047857))),
                )
              else if (_errorMessage.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Column(
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: Colors.red),
                        const SizedBox(height: 10),
                        Text(_errorMessage, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF047857)),
                          onPressed: _fetchProducts,
                          child: Text(_t('తిరిగి ప్రయత్నించండి', 'Retry'), style: const TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  ),
                )
              else if (products.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 20),
                  child: Center(
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: const BoxDecoration(
                            color: Color(0xFFF1F5F9),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.search_off, size: 40, color: Color(0xFF94A3B8)),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _t('ఏ ఉత్పత్తులు కనుగొనబడలేదు', 'No products found'),
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _t('మరొక కేటగిరీ లేదా పేరుతో వెతకండి.', 'Try searching with another category or name.'),
                          style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final crossAxisCount = constraints.maxWidth > 800
                          ? 4
                          : constraints.maxWidth > 550
                              ? 3
                              : 2;
                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          childAspectRatio: 0.65,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        ),
                        itemCount: products.length,
                        itemBuilder: (ctx, idx) {
                          final p = products[idx];
                          final id = p['id'] as int;
                          final inCartQty = _cart[id]?['qty'] as int? ?? 0;
                          return _ProductCard(
                            apiBase: widget.apiBase,
                            product: p,
                            inCartQty: inCartQty,
                            isTe: _isTe,
                            onTap: () => _openProductDetails(p),
                            onAdd: () => _addToCart(p),
                            onRemove: () => _removeFromCart(id),
                          );
                        },
                      );
                    },
                  ),
                ),

              const SizedBox(height: 100), // Space for floating cart bar
            ],
          ),
        ),
      ),

      // Sticky Bottom Floating Cart Bar
      bottomSheet: hasItemsInCart
          ? Container(
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF064E3B),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 14,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.shopping_bag_outlined, color: Color(0xFFFDE68A), size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isTe
                                ? '$_cartTotalCount వస్తువులు • ₹${_cartTotalPrice.toInt()}'
                                : '$_cartTotalCount items • ₹${_cartTotalPrice.toInt()}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            _t('🚚 ఉచిత హోమ్ డెలివరీ వర్తిస్తుంది', '🚚 Free Home Delivery applies'),
                            style: const TextStyle(color: Color(0xFF6EE7B7), fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF59E0B),
                        foregroundColor: const Color(0xFF0F172A),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      onPressed: _openCartSheet,
                      icon: const Icon(Icons.arrow_forward, size: 16, color: Color(0xFF0F172A)),
                      label: Text(
                        _t('ఆర్డర్ చేయండి', 'Checkout'),
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildHeroTag(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: const Color(0xFF6EE7B7)),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final String apiBase;
  final Map<String, dynamic> product;
  final int inCartQty;
  final bool isTe;
  final VoidCallback onTap;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  const _ProductCard({
    required this.apiBase,
    required this.product,
    required this.inCartQty,
    required this.isTe,
    required this.onTap,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final displayName = isTe
        ? (product['name_te'] ?? product['name'] ?? '').toString()
        : (product['name'] ?? product['name_te'] ?? '').toString();
    final price = (product['selling_price'] as num?)?.toDouble() ?? 0;
    final unit = (product['unit'] ?? '').toString();
    final category = (product['category'] ?? '').toString().toUpperCase();
    final imgUrl = product['image_url'] as String?;
    final stock = (product['stock_qty'] as num?)?.toInt() ?? 0;

    // Resolve full image URL
    String? fullImgUrl;
    if (imgUrl != null && imgUrl.isNotEmpty) {
      if (imgUrl.startsWith('http')) {
        fullImgUrl = imgUrl;
      } else if (imgUrl.startsWith('/')) {
        final root = apiBase.replaceAll(RegExp(r'/api/?$'), '');
        fullImgUrl = '$root$imgUrl';
      } else {
        fullImgUrl = imgUrl;
      }
    }

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: inCartQty > 0 ? const Color(0xFF047857) : const Color(0xFFE2E8F0),
          width: inCartQty > 0 ? 1.8 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Image / Category Illustration Container
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                Container(
                  color: _getCategoryBgColor(category),
                  child: fullImgUrl != null && fullImgUrl.isNotEmpty
                      ? Image.network(
                          fullImgUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _buildCategoryIllustration(category),
                        )
                      : _buildCategoryIllustration(category),
                ),

                // Top Gradient overlay for badges readability
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 36,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.black.withValues(alpha: 0.35), Colors.transparent],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ),

                // Stock Badge
                Positioned(
                  top: 6,
                  left: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: stock > 0 ? const Color(0xFF059669) : const Color(0xFFE11D48),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      stock > 0 ? (isTe ? 'ఇన్ స్టాక్' : 'In Stock') : (isTe ? 'అయిపోయింది' : 'Out of Stock'),
                      style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),

                // Category Micro Tag
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _getCategoryLabel(category, isTe),
                      style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),

                // In Cart Tag
                if (inCartQty > 0)
                  Positioned(
                    bottom: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF047857),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: Text(
                        isTe ? '$inCartQty కార్ట్‌లో' : '$inCartQty in Cart',
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Details Section
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 6),

                // Price Row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '₹${price.toInt()}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF047857),
                      ),
                    ),
                    if (unit.isNotEmpty)
                      Text(
                        ' / $unit',
                        style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                      ),
                  ],
                ),
                const SizedBox(height: 8),

                // Add to Cart Button or Stepper
                if (inCartQty == 0)
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF047857),
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(34),
                      elevation: 0,
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: stock > 0 ? onAdd : null,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.add_shopping_cart, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          stock > 0 ? (isTe ? '+ చేర్చండి' : '+ Add') : (isTe ? 'అందుబాటులో లేదు' : 'Out of Stock'),
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    height: 34,
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF047857), width: 1.2),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove, size: 16, color: Color(0xFF047857)),
                          onPressed: onRemove,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          padding: EdgeInsets.zero,
                        ),
                        Text(
                          '$inCartQty',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF047857),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add, size: 16, color: Color(0xFF047857)),
                          onPressed: onAdd,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          padding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
  }

  Color _getCategoryBgColor(String cat) {
    if (cat.contains('OIL')) return const Color(0xFFFEF3C7);
    if (cat.contains('CAKE')) return const Color(0xFFFFEDD5);
    if (cat.contains('REPACK') || cat.contains('FLOUR')) return const Color(0xFFDCFCE7);
    return const Color(0xFFF1F5F9);
  }

  String _getCategoryLabel(String cat, bool isTe) {
    if (cat.contains('OIL')) return isTe ? 'గానుగ నూనె' : 'Wood-Pressed Oil';
    if (cat.contains('CAKE')) return isTe ? 'నూనె చెక్క' : 'Oil Cake';
    if (cat.contains('REPACK')) return isTe ? 'పప్పులు & గింజలు' : 'Pulses & Grains';
    if (cat.contains('FLOUR')) return isTe ? 'పిండి మిల్లు' : 'Flour Mill';
    if (cat.contains('SNACK')) return isTe ? 'తాజా స్నాక్స్' : 'Fresh Snack';
    return isTe ? 'ఉత్పత్తి' : 'Product';
  }

  Widget _buildCategoryIllustration(String cat) {
    String emoji = '🌿';
    Color iconColor = const Color(0xFF047857);
    if (cat.contains('OIL')) {
      emoji = '🛢️';
      iconColor = const Color(0xFFD97706);
    } else if (cat.contains('CAKE')) {
      emoji = '🥜';
      iconColor = const Color(0xFFB45309);
    } else if (cat.contains('REPACK') || cat.contains('FLOUR')) {
      emoji = '🌾';
      iconColor = const Color(0xFF059669);
    } else if (cat.contains('SNACK')) {
      emoji = '🍿';
      iconColor = const Color(0xFFEA580C);
    }

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: iconColor.withValues(alpha: 0.15),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Center(
              child: Text(emoji, style: const TextStyle(fontSize: 24)),
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// PRODUCT FULL DETAILS PAGE
// ==========================================

class _ProductDetailsPage extends StatefulWidget {
  final String apiBase;
  final Map<String, dynamic> product;
  final bool isTe;
  final int cartTotalCount;
  final int cartQty;
  final VoidCallback onAddToCart;
  final VoidCallback onRemoveFromCart;
  final VoidCallback onOpenCart;

  const _ProductDetailsPage({
    required this.apiBase,
    required this.product,
    required this.isTe,
    required this.cartTotalCount,
    required this.cartQty,
    required this.onAddToCart,
    required this.onRemoveFromCart,
    required this.onOpenCart,
  });

  @override
  State<_ProductDetailsPage> createState() => _ProductDetailsPageState();
}

class _ProductDetailsPageState extends State<_ProductDetailsPage> {
  late int _qty;

  @override
  void initState() {
    super.initState();
    _qty = widget.cartQty;
  }

  String _t(String te, String en) => widget.isTe ? te : en;

  String? _getFullImageUrl(String? imgUrl) {
    if (imgUrl == null || imgUrl.isEmpty) return null;
    if (imgUrl.startsWith('http')) return imgUrl;
    if (imgUrl.startsWith('/')) {
      final root = widget.apiBase.replaceAll(RegExp(r'/api/?$'), '');
      return '$root$imgUrl';
    }
    return imgUrl;
  }

  String _getCategoryLabel(String cat) {
    final c = cat.toUpperCase();
    if (c.contains('OIL')) return _t('గానుగ నూనె', 'Wood-Pressed Oil');
    if (c.contains('CAKE')) return _t('నూనె చెక్క', 'Oil Cake');
    if (c.contains('REPACK')) return _t('పప్పులు & గింజలు', 'Pulses & Grains');
    if (c.contains('FLOUR')) return _t('పిండి మిల్లు', 'Flour Mill');
    if (c.contains('SNACK')) return _t('తాజా స్నాక్స్', 'Fresh Snack');
    return _t('ఉత్పత్తి', 'Product');
  }

  String _getProductDescription(String cat, String name) {
    final c = cat.toUpperCase();
    if (c.contains('OIL')) {
      return _t(
        'UNIK NATURALS స్వచ్ఛమైన చెక్క గానుగ నూనె సంప్రదాయ పద్ధతిలో తక్కువ ఉష్ణోగ్రత వద్ద విత్తనాల నుండి తీయబడుతుంది. ఇందులో సహజ రుచి, ఘాటు మరియు యాంటీఆక్సిడెంట్లు పుష్కలంగా ఉంటాయి. ఎటువంటి కృత్రిమ రంగులు, రసాయనాలు లేదా ఫిల్టరింగ్ ఏజెంట్లు కలపలేదు. గుండె ఆరోగ్యానికి మరియు వంటల సహజ రుచికి అత్యుత్తమమైనది.',
        'UNIK NATURALS pure wood-pressed oil is traditionally extracted at low temperatures without heating or chemical refining. Rich in natural antioxidants, vital fatty acids, and authentic aroma. Ideal for heart health and wholesome daily cooking.',
      );
    }
    if (c.contains('FLOUR') || c.contains('MILL')) {
      return _t(
        'నాణ్యమైన ఎంపిక చేసిన ధాన్యాలను రాయి గానుగ మిల్లింగ్ ద్వారా స్వచ్ఛంగా పిండి ఆడించబడింది. తవుడు, సహజ పీచు పదార్థం మరియు విటమిన్లు నశించకుండా తాజాగా అందించబడుతుంది. ఎటువంటి ప్రిజర్వేటివ్‌లు లేవు.',
        'Finely stone-ground from premium selected whole grains. Retains natural dietary fiber, essential vitamins, and nutrients for healthy family meals with zero preservatives.',
      );
    }
    if (c.contains('CAKE')) {
      return _t(
        'గానుగ నూనె తీసిన తర్వాత లభించే పోషక విలువలు గల స్వచ్ఛమైన చెక్క గానుగ చెక్క. పశువుల పోషణకు మరియు సేంద్రీయ వ్యవసాయ ఎరువుగా అత్యుత్తమమైనది.',
        'Nutrient-rich, unadulterated cold pressed oil cake ideal for dairy livestock feed and organic farming nourishment.',
      );
    }
    return _t(
      'UNIK NATURALS నుండి విశ్వసనీయమైన, సహజసిద్ధమైన నాణ్యమైన ఉత్పత్తి. సహజ పద్ధతులలో శుద్ధి చేసినది.',
      'Premium natural and wholesome quality product from UNIK NATURALS. Prepared using traditional hygienic standards.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final displayName = widget.isTe
        ? (p['name_te'] ?? p['name'] ?? '').toString()
        : (p['name'] ?? p['name_te'] ?? '').toString();
    final subName = widget.isTe
        ? (p['name'] != null && p['name'].toString() != displayName ? p['name'].toString() : null)
        : (p['name_te'] != null && p['name_te'].toString() != displayName ? p['name_te'].toString() : null);

    final price = (p['selling_price'] as num?)?.toDouble() ?? 0;
    final unit = (p['unit'] ?? '').toString();
    final category = (p['category'] ?? '').toString().toUpperCase();
    final imgUrl = _getFullImageUrl(p['image_url'] as String?);
    final stock = (p['stock_qty'] as num?)?.toInt() ?? 0;
    final variant = (p['variant_name'] ?? '').toString();

    final itemTotalPrice = (price * (_qty > 0 ? _qty : 1)).toInt();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF064E3B),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          displayName,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          // WhatsApp share / enquire button
          IconButton(
            icon: const Icon(Icons.chat_outlined, color: Color(0xFF25D366)),
            tooltip: _t('వాట్సాప్‌లో అడగండి', 'Enquire on WhatsApp'),
            onPressed: () {
              final msg = widget.isTe
                  ? 'నమస్తే UNIK NATURALS, నాకు "$displayName" (ధర: ₹${price.toInt()}) గురించి మరింత సమాచారం కావాలి.'
                  : 'Hello UNIK NATURALS, I would like more information about "$displayName" (Price: ₹${price.toInt()}).';
              try {
                html.window.open('https://wa.me/919848012345?text=${Uri.encodeComponent(msg)}', '_blank');
              } catch (_) {}
            },
          ),
          // Cart Button
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            child: Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.shopping_bag_outlined, color: Colors.white),
                  onPressed: widget.onOpenCart,
                ),
                if (_qty > 0 || widget.cartTotalCount > 0)
                  Positioned(
                    top: 8,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Color(0xFFFBBF24),
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                      child: Center(
                        child: Text(
                          '${widget.cartTotalCount > 0 ? widget.cartTotalCount : _qty}',
                          style: const TextStyle(
                            color: Color(0xFF064E3B),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Hero Image Section
            Container(
              height: 320,
              color: Colors.white,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (imgUrl != null && imgUrl.isNotEmpty)
                    Image.network(
                      imgUrl,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => _buildDetailIllustration(category),
                    )
                  else
                    _buildDetailIllustration(category),

                  // Stock Badge (Top Left)
                  Positioned(
                    top: 14,
                    left: 14,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: stock > 0 ? const Color(0xFF059669) : const Color(0xFFE11D48),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            stock > 0 ? Icons.check_circle : Icons.cancel,
                            size: 13,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            stock > 0
                                ? _t('స్టాక్‌లో ఉంది', 'In Stock')
                                : _t('అయిపోయింది', 'Out of Stock'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Category Badge (Top Right)
                  Positioned(
                    top: 14,
                    right: 14,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF064E3B),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: Text(
                        _getCategoryLabel(category),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Product Details Card
            Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x0D000000),
                    blurRadius: 10,
                    offset: Offset(0, -3),
                  ),
                ],
              ),
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    displayName,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F172A),
                      height: 1.3,
                    ),
                  ),
                  if (subName != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      subName,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),

                  // Price Row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '₹${price.toInt()}',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF047857),
                        ),
                      ),
                      if (unit.isNotEmpty) ...[
                        Text(
                          ' / $unit',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFA7F3D0)),
                        ),
                        child: Text(
                          _t('ఉత్తమ ధర', 'Best Value'),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF047857),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _t('అన్ని పన్నులతో కలిపి • హోమ్ డెలివరీ అందుబాటులో ఉంది', 'Inclusive of all taxes • Doorstep delivery available'),
                    style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                  ),

                  const SizedBox(height: 18),
                  const Divider(),
                  const SizedBox(height: 14),

                  // 4 Quality Highlights Badges
                  Row(
                    children: [
                      Expanded(
                        child: _buildQualityPill(
                          Icons.eco,
                          _t('100% స్వచ్ఛం', '100% Pure'),
                          _t('ఎటువంటి కల్తీ లేదు', 'Chemical Free'),
                          const Color(0xFF047857),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildQualityPill(
                          Icons.verified,
                          _t('గానుగ పద్ధతి', 'Wood Pressed'),
                          _t('సహజ పోషకాలు', 'Natural Vitality'),
                          const Color(0xFFD97706),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _buildQualityPill(
                          Icons.local_shipping,
                          _t('వేగవంతమైన డెలివరీ', 'Fast Delivery'),
                          _t('ఇంటి వద్దకే', 'Doorstep Service'),
                          const Color(0xFF2563EB),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildQualityPill(
                          Icons.health_and_safety,
                          _t('ఆరోగ్యకరం', 'Wholesome'),
                          _t('సంపూర్ణ నాణ్యత', 'Top Hygiene'),
                          const Color(0xFF7C3AED),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 14),

                  // Description
                  Text(
                    _t('ఉత్పత్తి వివరణ & విశేషాలు', 'Product Description & Benefits'),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Text(
                      _getProductDescription(category, displayName),
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.6,
                        color: Color(0xFF334155),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 14),

                  // Specifications Table
                  Text(
                    _t('ఉత్పత్తి వివరాలు', 'Specifications'),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildSpecRow(_t('బ్రాండ్', 'Brand'), 'UNIK NATURALS'),
                  _buildSpecRow(_t('కేటగిరీ', 'Category'), _getCategoryLabel(category)),
                  _buildSpecRow(_t('పరిమాణం / యూనిట్', 'Net Quantity'), variant.isNotEmpty ? '$variant ($unit)' : unit),
                  _buildSpecRow(_t('తయారీ పద్ధతి', 'Extraction Method'), _t('సంప్రదాయ చెక్క గానుగ', 'Traditional Cold-Pressed')),
                  _buildSpecRow(_t('ప్యాకేజింగ్', 'Packaging'), _t('ఆహార భద్రత ప్రమాణాల బాటిల్ / ప్యాక్', 'Food-Grade Hygienic Pack')),
                  _buildSpecRow(_t('నిల్వ సూచన', 'Storage'), _t('చల్లని, పొడి ప్రదేశంలో నిల్వ చేయండి', 'Store in a cool, dry place away from sunlight')),

                  const SizedBox(height: 20),

                  // WhatsApp Direct Enquiry Card
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFBBF7D0)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: Color(0xFF25D366),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.chat, color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _t('ఏదైనా సందేహం ఉందా?', 'Have questions about this item?'),
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF14532D)),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _t('షాప్‌తో నేరుగా వాట్సాప్‌లో మాట్లాడండి.', 'Chat directly with UNIK Naturals on WhatsApp.'),
                                style: const TextStyle(fontSize: 11, color: Color(0xFF166534)),
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          style: TextButton.styleFrom(
                            backgroundColor: const Color(0xFF047857),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () {
                            final msg = widget.isTe
                                ? 'నమస్తే UNIK NATURALS, నాకు "$displayName" గురించి సమాచారం కావాలి.'
                                : 'Hello UNIK NATURALS, I would like information about "$displayName".';
                            try {
                              html.window.open('https://wa.me/919848012345?text=${Uri.encodeComponent(msg)}', '_blank');
                            } catch (_) {}
                          },
                          child: Text(
                            _t('చాట్ చేయండి', 'Chat'),
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 80), // Space for sticky bottom bar
                ],
              ),
            ),
          ],
        ),
      ),

      // Sticky Bottom Add to Cart Bar
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: SafeArea(
          child: Row(
            children: [
              // Price summary
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _t('మొత్తం:', 'Total:'),
                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                    Text(
                      '₹$itemTotalPrice',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF047857),
                      ),
                    ),
                  ],
                ),
              ),

              // Action Buttons
              if (_qty == 0)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF047857),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  onPressed: stock > 0
                      ? () {
                          setState(() => _qty = 1);
                          widget.onAddToCart();
                        }
                      : null,
                  icon: const Icon(Icons.add_shopping_cart, size: 18),
                  label: Text(
                    stock > 0
                        ? _t('కార్ట్‌కి చేర్చండి', 'Add to Cart')
                        : _t('అందుబాటులో లేదు', 'Out of Stock'),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                )
              else
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Stepper
                    Container(
                      height: 42,
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF047857), width: 1.5),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove, size: 18, color: Color(0xFF047857)),
                            onPressed: () {
                              setState(() {
                                if (_qty > 0) _qty--;
                              });
                              widget.onRemoveFromCart();
                            },
                            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                            padding: EdgeInsets.zero,
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Text(
                              '$_qty',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF047857),
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add, size: 18, color: Color(0xFF047857)),
                            onPressed: () {
                              setState(() => _qty++);
                              widget.onAddToCart();
                            },
                            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                            padding: EdgeInsets.zero,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF59E0B),
                        foregroundColor: const Color(0xFF0F172A),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      onPressed: widget.onOpenCart,
                      child: Text(
                        _t('ఆర్డర్ చేయండి', 'View Cart'),
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQualityPill(IconData icon, String title, String subtitle, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpecRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailIllustration(String cat) {
    String emoji = '🌿';
    if (cat.contains('OIL')) emoji = '🛢️';
    else if (cat.contains('CAKE')) emoji = '🥜';
    else if (cat.contains('REPACK') || cat.contains('FLOUR')) emoji = '🌾';
    else if (cat.contains('SNACK')) emoji = '🍿';

    return Center(
      child: Text(
        emoji,
        style: const TextStyle(fontSize: 90),
      ),
    );
  }
}

class _CartCheckoutSheet extends StatefulWidget {
  final String apiBase;
  final Map<int, Map<String, dynamic>> cart;
  final VoidCallback onCartUpdated;
  final Function(Map<String, dynamic>) onOrderSuccess;
  final Map<String, dynamic>? customer;
  final VoidCallback? onRequireLogin;
  final bool isTe;

  const _CartCheckoutSheet({
    required this.apiBase,
    required this.cart,
    required this.onCartUpdated,
    required this.onOrderSuccess,
    this.customer,
    this.onRequireLogin,
    this.isTe = true,
  });

  @override
  State<_CartCheckoutSheet> createState() => _CartCheckoutSheetState();
}

class _CartCheckoutSheetState extends State<_CartCheckoutSheet> {
  String _deliveryType = 'DELIVERY'; // DELIVERY or PICKUP
  String _paymentMode = 'COD'; // COD, UPI, or KHATA
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  int? _khataDue;
  String? _khataCustomerName;
  bool _isCheckingKhata = false;

  bool _isSubmitting = false;
  String _formError = '';

  bool get _isTe => widget.isTe;
  String _t(String te, String en) => _isTe ? te : en;

  @override
  void initState() {
    super.initState();
    try {
      if (widget.customer != null) {
        _nameController.text = widget.customer!['name'] ?? '';
        final p = widget.customer!['phone'] ?? '';
        _phoneController.text = p;
        _addressController.text = widget.customer!['address'] ?? '';
        if (p.length >= 10) {
          _checkKhata(p);
        }
      } else {
        _nameController.text = html.window.localStorage['unik_customer_name'] ?? '';
        final p = html.window.localStorage['unik_customer_phone'] ?? '';
        _phoneController.text = p;
        _addressController.text = html.window.localStorage['unik_customer_address'] ?? '';
        if (p.length >= 10) {
          _checkKhata(p);
        }
      }
    } catch (_) {}
  }

  void _checkKhata(String phone) async {
    final clean = phone.trim();
    if (clean.length < 10) {
      if (_khataDue != null && mounted) {
        setState(() {
          _khataDue = null;
          _khataCustomerName = null;
        });
      }
      return;
    }
    setState(() => _isCheckingKhata = true);
    try {
      final res = await http.get(Uri.parse('${widget.apiBase}/customer/khata-check/$clean'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['found'] == true && mounted) {
          setState(() {
            _khataDue = (data['total_credit_due'] as num?)?.toInt() ?? 0;
            _khataCustomerName = (_isTe ? (data['name_te'] ?? data['name']) : (data['name'] ?? data['name_te'])).toString();
            if (_nameController.text.trim().isEmpty) {
              _nameController.text = data['name'] ?? '';
            }
          });
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _isCheckingKhata = false);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  double get _subtotal {
    double total = 0;
    widget.cart.forEach((_, item) {
      final p = (item['product']['selling_price'] as num).toDouble();
      final q = (item['qty'] as num).toDouble();
      total += p * q;
    });
    return total;
  }

  Future<void> _submitOrder() async {
    setState(() {
      _formError = '';
    });

    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final address = _addressController.text.trim();
    final notes = _notesController.text.trim();

    if (name.isEmpty) {
      setState(() => _formError = _t('దయచేసి మీ పూర్తి పేరు నమోదు చేయండి', 'Please enter your full name'));
      return;
    }
    if (phone.length < 10) {
      setState(() => _formError = _t('దయచేసి సరైన 10 అంకెల మొబైల్ నంబర్ నమోదు చేయండి', 'Please enter a valid 10-digit mobile number'));
      return;
    }
    if (_deliveryType == 'DELIVERY' && address.isEmpty) {
      setState(() => _formError = _t('హోమ్ డెలివరీ కోసం చిరునామా తప్పనిసరి', 'Delivery address is required for Home Delivery'));
      return;
    }

    // Save for convenience
    try {
      html.window.localStorage['unik_customer_name'] = name;
      html.window.localStorage['unik_customer_phone'] = phone;
      html.window.localStorage['unik_customer_address'] = address;
    } catch (_) {}

    setState(() => _isSubmitting = true);

    try {
      final itemsPayload = widget.cart.values.map((val) {
        final prod = val['product'] as Map<String, dynamic>;
        final qty = val['qty'] as int;
        return {
          'item_id': prod['id'],
          'name': prod['name'],
          'name_te': prod['name_te'],
          'variant': prod['variant_name'] ?? prod['unit'],
          'unit_price': prod['selling_price'],
          'quantity': qty,
          'image_url': prod['image_url'],
        };
      }).toList();

      final body = {
        'customer_name': name,
        'customer_phone': phone,
        'delivery_type': _deliveryType,
        'delivery_address': _deliveryType == 'DELIVERY' ? address : null,
        'payment_mode': _paymentMode,
        'notes': notes.isNotEmpty ? notes : null,
        'items': itemsPayload,
      };

      final res = await http.post(
        Uri.parse('${widget.apiBase}/customer/orders'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      final data = jsonDecode(res.body);

      if (res.statusCode == 200 && data['success'] == true) {
        widget.onOrderSuccess(data['order']);
      } else {
        setState(() {
          _formError = data['error'] ?? _t('ఆర్డర్ సమర్పించడంలో లోపం ఏర్పడింది', 'Failed to place order');
          _isSubmitting = false;
        });
      }
    } catch (e) {
      setState(() {
        _formError = _t('సర్వర్ కనెక్ట్ కావడం లేదు: $e', 'Could not connect to server: $e');
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.cart.values.toList();

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle Bar & Title
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.shopping_bag, color: Color(0xFF047857)),
                    const SizedBox(width: 8),
                    Text(
                      _isTe ? 'మీ కార్ట్ (${items.length} ఉత్పత్తులు)' : 'Your Cart (${items.length} items)',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Scrollable Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Item list
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const Divider(height: 16),
                    itemBuilder: (ctx, idx) {
                      final item = items[idx];
                      final prod = item['product'] as Map<String, dynamic>;
                      final id = prod['id'] as int;
                      final qty = item['qty'] as int;
                      final price = (prod['selling_price'] as num).toDouble();
                      final prodName = _isTe ? (prod['name_te'] ?? prod['name']) : (prod['name'] ?? prod['name_te']);

                      return Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  prodName,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                                Text(
                                  '₹${price.toInt()} × $qty = ₹${(price * qty).toInt()}',
                                  style: const TextStyle(color: Color(0xFF047857), fontWeight: FontWeight.w600, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFF3F4F6),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove, size: 16),
                                  onPressed: () {
                                    if (qty > 1) {
                                      setState(() {
                                        widget.cart[id]!['qty'] = qty - 1;
                                      });
                                    } else {
                                      setState(() {
                                        widget.cart.remove(id);
                                      });
                                    }
                                    widget.onCartUpdated();
                                  },
                                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                  padding: EdgeInsets.zero,
                                ),
                                Text('$qty', style: const TextStyle(fontWeight: FontWeight.bold)),
                                IconButton(
                                  icon: const Icon(Icons.add, size: 16),
                                  onPressed: () {
                                    setState(() {
                                      widget.cart[id]!['qty'] = qty + 1;
                                    });
                                    widget.onCartUpdated();
                                  },
                                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                  padding: EdgeInsets.zero,
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 20),
                  const Divider(thickness: 1.5),
                  const SizedBox(height: 10),

                  // Customer Auth Banner
                  if (widget.customer != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFA7F3D0)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.verified_user, color: Color(0xFF047857), size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _isTe
                                  ? 'లాగిన్ అయిన ఖాతా: ${widget.customer!['name']} (${widget.customer!['phone']})'
                                  : 'Logged in: ${widget.customer!['name']} (${widget.customer!['phone']})',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF065F46)),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, color: Color(0xFFD97706), size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _t('ఖాతా ఉందా? చిరునామా ఆటోమేటిక్‌గా నిండటానికి లాగిన్ అవ్వండి.', 'Have an account? Log in to auto-fill address.'),
                              style: const TextStyle(fontSize: 11, color: Color(0xFF92400E)),
                            ),
                          ),
                          TextButton(
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              foregroundColor: const Color(0xFF047857),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            ),
                            onPressed: widget.onRequireLogin,
                            child: Text(_t('లాగిన్', 'Login'), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),

                  // Delivery Type Selector
                  Text(_t('డెలివరీ విధానం:', 'Delivery Method:'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => setState(() => _deliveryType = 'DELIVERY'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                            decoration: BoxDecoration(
                              color: _deliveryType == 'DELIVERY' ? const Color(0xFFDCFCE7) : Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: _deliveryType == 'DELIVERY' ? const Color(0xFF16A34A) : const Color(0xFFD1D5DB),
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.delivery_dining, size: 18, color: _deliveryType == 'DELIVERY' ? const Color(0xFF047857) : Colors.grey),
                                const SizedBox(width: 6),
                                Text(
                                  _t('🚚 హోమ్ డెలివరీ', '🚚 Home Delivery'),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: _deliveryType == 'DELIVERY' ? const Color(0xFF047857) : const Color(0xFF4B5563),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: InkWell(
                          onTap: () => setState(() => _deliveryType = 'PICKUP'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                            decoration: BoxDecoration(
                              color: _deliveryType == 'PICKUP' ? const Color(0xFFDCFCE7) : Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: _deliveryType == 'PICKUP' ? const Color(0xFF16A34A) : const Color(0xFFD1D5DB),
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.storefront, size: 18, color: _deliveryType == 'PICKUP' ? const Color(0xFF047857) : Colors.grey),
                                const SizedBox(width: 6),
                                Text(
                                  _t('🏪 షాప్ పికప్', '🏪 Store Pickup'),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: _deliveryType == 'PICKUP' ? const Color(0xFF047857) : const Color(0xFF4B5563),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Customer Details Form
                  Text(_t('మీ వివరాలు:', 'Your Details:'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 8),

                  TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: _t('పూర్తి పేరు *', 'Full Name *'),
                      prefixIcon: const Icon(Icons.person_outline, size: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 10),

                  TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: _t('మొబైల్ నంబర్ *', 'Mobile Number *'),
                      hintText: _t('10 అంకెల మొబైల్ నంబర్', '10 digit mobile number'),
                      prefixIcon: const Icon(Icons.phone_outlined, size: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      suffixIcon: _isCheckingKhata
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: Padding(
                                padding: EdgeInsets.all(10),
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          : null,
                    ),
                    onChanged: (val) => _checkKhata(val),
                  ),
                  if (_khataDue != null)
                    Container(
                      margin: const EdgeInsets.only(top: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFAF5FF),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFD8B4FE)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.verified, size: 16, color: Color(0xFF7C3AED)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _t('గుర్తించబడిన ఖాతాదారుడు: $_khataCustomerName • ప్రస్తుత బాకీ: ₹$_khataDue', 'Verified Khata Member: $_khataCustomerName • Current Due: ₹$_khataDue'),
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF581C87)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 10),

                  if (_deliveryType == 'DELIVERY') ...[
                    TextField(
                      controller: _addressController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: _t('డెలివరీ చిరునామా *', 'Delivery Address *'),
                        hintText: _t('ఇంటి నంబర్, వీధి, ల్యాండ్‌మార్క్, ప్రాంతం...', 'House no, street, landmark, area...'),
                        prefixIcon: const Icon(Icons.location_on_outlined, size: 20),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],

                  TextField(
                    controller: _notesController,
                    decoration: InputDecoration(
                      labelText: _t('సూచనలు (ఐచ్ఛికం)', 'Delivery Notes (Optional)'),
                      hintText: _t('ఉదా: సాయంత్రం 5 తర్వాత డెలివరీ చేయండి...', 'e.g., Deliver after 5 PM...'),
                      prefixIcon: const Icon(Icons.notes_outlined, size: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Payment Method
                  Text(_t('చెల్లింపు విధానం:', 'Payment Method:'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 8),
                  Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: RadioListTile<String>(
                              value: 'COD',
                              groupValue: _paymentMode,
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                _deliveryType == 'DELIVERY'
                                    ? _t('💵 క్యాష్ ఆన్ డెలివరీ', '💵 Cash on Delivery')
                                    : _t('💵 షాప్‌లో నగదు', '💵 Pay at Store'),
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                              onChanged: (val) => setState(() => _paymentMode = val!),
                            ),
                          ),
                          Expanded(
                            child: RadioListTile<String>(
                              value: 'UPI',
                              groupValue: _paymentMode,
                              contentPadding: EdgeInsets.zero,
                              title: const Text('📱 UPI / PhonePe', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              onChanged: (val) => setState(() => _paymentMode = val!),
                            ),
                          ),
                        ],
                      ),
                      RadioListTile<String>(
                        value: 'KHATA',
                        groupValue: _paymentMode,
                        contentPadding: EdgeInsets.zero,
                        title: Row(
                          children: [
                            Text(
                              _t('📒 ఖాతా / ఉద్దెర', '📒 Store Khata (Credit)'),
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF6D28D9)),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEDE9FE),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                _t('ఖాతాదారులకు', 'Members'),
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF6D28D9)),
                              ),
                            ),
                          ],
                        ),
                        onChanged: (val) => setState(() => _paymentMode = val!),
                      ),
                    ],
                  ),

                  if (_paymentMode == 'KHATA')
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFAF5FF),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFD8B4FE)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.menu_book, color: Color(0xFF7C3AED), size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _t(
                                'ఈ ఆర్డర్ మొత్తం మీ ఖాతా పుస్తకంలో బాకీగా నమోదు చేయబడుతుంది. డెలివరీ సమయంలో చెల్లించనవసరం లేదు, తర్వాత చెల్లించవచ్చు.' +
                                    (_khataDue != null ? '\n(మీ ప్రస్తుత బాకీ: ₹$_khataDue)' : ''),
                                'This order amount will be added to your khata ledger due. No immediate payment needed upon delivery.' +
                                    (_khataDue != null ? '\n(Current balance due: ₹$_khataDue)' : ''),
                              ),
                              style: const TextStyle(fontSize: 11, color: Color(0xFF581C87), height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ),

                  if (_paymentMode == 'UPI')
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF93C5FD)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.qr_code_2, color: Color(0xFF1D4ED8)),
                              const SizedBox(width: 8),
                              Text(_t('UPI చెల్లింపు సూచనలు', 'UPI Payment Instructions'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1D4ED8))),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _t(
                              'మొత్తం: ₹${_subtotal.toInt()}\nఆర్డర్ నిర్ధారించిన తర్వాత డెలివరీ వద్ద PhonePe / GPay QR కోడ్ స్కాన్ చేసి లేదా షాప్ UPI కి చెల్లించవచ్చు.',
                              'Total: ₹${_subtotal.toInt()}\nScan PhonePe / GPay QR code upon delivery to complete your payment.',
                            ),
                            style: const TextStyle(fontSize: 11, color: Color(0xFF1E3A8A)),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 16),

                  // Price Breakdown
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
                            Text(_t('ఉత్పత్తుల మొత్తం:', 'Items Subtotal:'), style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                            Text('₹${_subtotal.toInt()}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(_t('డెలివరీ ఛార్జీ:', 'Delivery Charges:'), style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                            Text(_t('ఉచితం', 'FREE'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF16A34A))),
                          ],
                        ),
                        const Divider(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(_t('మొత్తం చెల్లించాల్సింది:', 'Total to Pay:'), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                            Text('₹${_subtotal.toInt()}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF047857))),
                          ],
                        ),
                      ],
                    ),
                  ),

                  if (_formError.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(_formError, style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 12), textAlign: TextAlign.center),
                    ),
                  ],

                  const SizedBox(height: 20),

                  // Place Order Button
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF047857),
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    onPressed: _isSubmitting ? null : _submitOrder,
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                          )
                        : Text(
                            _t('✅ ఆర్డర్ ఖరారు చేయండి', '✅ Place Order'),
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomerOrderTrackerDialog extends StatefulWidget {
  final String apiBase;
  final bool isTe;

  const _CustomerOrderTrackerDialog({required this.apiBase, this.isTe = true});

  @override
  State<_CustomerOrderTrackerDialog> createState() => _CustomerOrderTrackerDialogState();
}

class _CustomerOrderTrackerDialogState extends State<_CustomerOrderTrackerDialog> {
  final TextEditingController _phoneController = TextEditingController();
  List<Map<String, dynamic>> _orders = [];
  bool _isLoading = false;
  bool _hasSearched = false;
  String _errorMessage = '';

  bool get _isTe => widget.isTe;
  String _t(String te, String en) => _isTe ? te : en;

  @override
  void initState() {
    super.initState();
    try {
      final savedPhone = html.window.localStorage['unik_customer_phone'];
      if (savedPhone != null && savedPhone.isNotEmpty) {
        _phoneController.text = savedPhone;
        _fetchOrders(savedPhone);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _fetchOrders(String phone) async {
    final cleanPhone = phone.trim();
    if (cleanPhone.isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _hasSearched = true;
    });

    try {
      final res = await http.get(Uri.parse('${widget.apiBase}/customer/orders/$cleanPhone'));
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        setState(() {
          _orders = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = _t('ఆర్డర్లు పొందలేకపోయాము', 'Could not retrieve orders');
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = _t('సర్వర్ కనెక్ట్ కాలేదు: $e', 'Could not connect to server: $e');
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 500,
        height: 600,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.receipt_long, color: Color(0xFF047857)),
                    const SizedBox(width: 8),
                    Text(
                      _t('నా ఆర్డర్లు', 'My Orders'),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Phone search input
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      hintText: _t('మీ మొబైల్ నంబర్ నమోదు చేయండి', 'Enter your mobile number'),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF047857),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => _fetchOrders(_phoneController.text),
                  child: Text(_t('చూడండి', 'Search')),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Results
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF047857)))
                  : _errorMessage.isNotEmpty
                      ? Center(child: Text(_errorMessage, style: const TextStyle(color: Colors.red)))
                      : !_hasSearched
                          ? Center(
                              child: Text(
                                _t('ఆర్డర్ల వివరాలు చూడటానికి మీ ఫోన్ నంబర్ నమోదు చేసి చూడండి నొక్కండి.', 'Enter your mobile number and tap Search to see orders.'),
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.grey),
                              ),
                            )
                          : _orders.isEmpty
                              ? Center(
                                  child: Text(
                                    _t('ఈ నంబర్‌పై ఎటువంటి ఆర్డర్లు లభించలేదు.', 'No orders found for this number.'),
                                    style: const TextStyle(color: Colors.grey),
                                  ),
                                )
                              : ListView.builder(
                                  itemCount: _orders.length,
                                  itemBuilder: (ctx, idx) {
                                    final o = _orders[idx];
                                    return _OrderHistoryCard(order: o, isTe: _isTe);
                                  },
                                ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderHistoryCard extends StatelessWidget {
  final Map<String, dynamic> order;
  final bool isTe;

  const _OrderHistoryCard({required this.order, this.isTe = true});

  @override
  Widget build(BuildContext context) {
    final orderNum = order['order_number'] ?? 'ORD-000';
    final total = order['total_amount'] ?? 0;
    final status = (order['order_status'] ?? 'NEW').toString();
    final items = (order['items'] as List?) ?? [];
    final rawDel = (order['delivery_type'] ?? 'DELIVERY').toString().toUpperCase();
    final delType = isTe
        ? (rawDel == 'PICKUP' ? '🏪 షాప్ పికప్' : '🚚 హోమ్ డెలివరీ')
        : (rawDel == 'PICKUP' ? '🏪 Store Pickup' : '🚚 Home Delivery');
    final createdAt = order['created_at']?.toString() ?? '';

    String dateStr = '';
    try {
      final dt = DateTime.parse(createdAt).toLocal();
      dateStr = DateFormat('dd MMM, hh:mm a').format(dt);
    } catch (_) {
      dateStr = createdAt;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  orderNum,
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Color(0xFF047857)),
                ),
                _buildStatusChip(status),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '$delType • $dateStr',
              style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
            ),
            const Divider(height: 16),

            // Items snippet
            Column(
              children: items.map<Widget>((it) {
                final itName = isTe ? (it['name_te'] ?? it['name']) : (it['name'] ?? it['name_te']);
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '$itName × ${it['quantity']}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      Text(
                        '₹${it['total_price']}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),

            const Divider(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(isTe ? 'మొత్తం:' : 'Total:', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                Text(
                  '₹$total',
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Color(0xFF047857)),
                ),
              ],
            ),

            const SizedBox(height: 8),
            // Progress Step Bar
            _buildOrderStatusTracker(status),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color bg;
    Color fg;
    String label;

    switch (status) {
      case 'NEW':
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFFB45309);
        label = isTe ? 'ఆర్డర్ అందింది' : 'Order Placed';
        break;
      case 'ACCEPTED':
        bg = const Color(0xFFDBEAFE);
        fg = const Color(0xFF1D4ED8);
        label = isTe ? 'అంగీకరించబడింది' : 'Accepted';
        break;
      case 'PACKING':
        bg = const Color(0xFFFFEDD5);
        fg = const Color(0xFFC2410C);
        label = isTe ? 'ప్యాకింగ్ అవుతోంది' : 'Packing';
        break;
      case 'OUT_FOR_DELIVERY':
        bg = const Color(0xFFF3E8FF);
        fg = const Color(0xFF7E22CE);
        label = isTe ? 'డెలివరీలో ఉంది' : 'Out for Delivery';
        break;
      case 'DELIVERED':
        bg = const Color(0xFFDCFCE7);
        fg = const Color(0xFF15803D);
        label = isTe ? 'పూర్తయింది' : 'Delivered';
        break;
      case 'CANCELLED':
        bg = const Color(0xFFFEE2E2);
        fg = const Color(0xFFB91C1C);
        label = isTe ? 'రద్దు చేయబడింది' : 'Cancelled';
        break;
      default:
        bg = Colors.grey.shade200;
        fg = Colors.black87;
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(label, style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildOrderStatusTracker(String status) {
    if (status == 'CANCELLED') {
      return Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(6)),
        child: Text(
          isTe ? '⚠️ ఈ ఆర్డర్ రద్దు చేయబడింది.' : '⚠️ This order was cancelled.',
          style: const TextStyle(color: Colors.red, fontSize: 11),
        ),
      );
    }

    final steps = ['NEW', 'ACCEPTED', 'PACKING', 'OUT_FOR_DELIVERY', 'DELIVERED'];
    final labels = isTe
        ? ['అందింది', 'ఓకే', 'ప్యాకింగ్', 'డెలివరీ', 'పూర్తి']
        : ['Placed', 'Accepted', 'Packing', 'Delivery', 'Delivered'];
    final currentIndex = steps.indexOf(status);

    return Row(
      children: List.generate(steps.length, (idx) {
        final isCompleted = currentIndex >= idx;
        return Expanded(
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 4,
                      color: idx == 0
                          ? Colors.transparent
                          : (currentIndex >= idx ? const Color(0xFF16A34A) : const Color(0xFFE5E7EB)),
                    ),
                  ),
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isCompleted ? const Color(0xFF16A34A) : const Color(0xFFE5E7EB),
                    ),
                    child: isCompleted
                        ? const Icon(Icons.check, size: 10, color: Colors.white)
                        : null,
                  ),
                  Expanded(
                    child: Container(
                      height: 4,
                      color: idx == steps.length - 1
                          ? Colors.transparent
                          : (currentIndex > idx ? const Color(0xFF16A34A) : const Color(0xFFE5E7EB)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                labels[idx],
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: isCompleted ? FontWeight.bold : FontWeight.normal,
                  color: isCompleted ? const Color(0xFF047857) : const Color(0xFF9CA3AF),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

// ==========================================
// CUSTOMER AUTHENTICATION (LOGIN & REGISTRATION)
// ==========================================

class _CustomerAuthDialog extends StatefulWidget {
  final String apiBase;
  final bool initialRegister;
  final bool isTe;

  const _CustomerAuthDialog({
    required this.apiBase,
    this.initialRegister = false,
    this.isTe = true,
  });

  @override
  State<_CustomerAuthDialog> createState() => _CustomerAuthDialogState();
}

class _CustomerAuthDialogState extends State<_CustomerAuthDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  String _t(String te, String en) => widget.isTe ? te : en;

  // Login
  final TextEditingController _loginUserCtrl = TextEditingController();
  final TextEditingController _loginPassCtrl = TextEditingController();
  bool _loginObscure = true;
  bool _loginLoading = false;
  String? _loginError;

  // Register
  final TextEditingController _regNameCtrl = TextEditingController();
  final TextEditingController _regPhoneCtrl = TextEditingController();
  final TextEditingController _regUserCtrl = TextEditingController();
  final TextEditingController _regPassCtrl = TextEditingController();
  final TextEditingController _regAddressCtrl = TextEditingController();
  bool _regObscure = true;
  bool _regLoading = false;
  String? _regError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialRegister ? 1 : 0,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
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
      setState(() => _loginError = _t(
            'యూజర్‌నేమ్ / మొబైల్ మరియు పాస్‌వర్డ్ ఇవ్వండి',
            'Please enter username / mobile and password',
          ));
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
        if (mounted) {
          Navigator.pop(context, data);
        }
        return;
      }

      setState(() {
        _loginLoading = false;
        _loginError = data['error'] ??
            _t('లాగిన్ విఫలమైంది (${res.statusCode})', 'Login failed (${res.statusCode})');
      });
    } catch (e) {
      setState(() {
        _loginLoading = false;
        _loginError = _t('సర్వర్ కనెక్ట్ కాలేదు: $e', 'Could not connect to server: $e');
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
      setState(() => _regError = _t('దయచేసి పూర్తి పేరు నమోదు చేయండి', 'Please enter full name'));
      return;
    }
    if (phone.length < 10) {
      setState(() => _regError =
          _t('దయచేసి సరైన 10 అంకెల మొబైల్ నంబర్ నమోదు చేయండి', 'Please enter valid 10-digit mobile number'));
      return;
    }
    if (pass.length < 4) {
      setState(() => _regError =
          _t('పాస్‌వర్డ్ కనీసం 4 అక్షరాలు ఉండాలి', 'Password must be at least 4 characters'));
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
        if (mounted) {
          Navigator.pop(context, data);
        }
        return;
      }

      setState(() {
        _regLoading = false;
        _regError = data['error'] ??
            _t('నమోదు విఫలమైంది (${res.statusCode})', 'Registration failed (${res.statusCode})');
      });
    } catch (e) {
      setState(() {
        _regLoading = false;
        _regError = _t('సర్వర్ కనెక్ట్ కాలేదు: $e', 'Could not connect to server: $e');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460, maxHeight: 620),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Modal Header
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF064E3B), Color(0xFF047857)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.storefront, color: Color(0xFFFBBF24), size: 20),
                          const SizedBox(width: 8),
                          Text(
                            _t('UNIK NATURALS • కస్టమర్ పోర్టల్', 'UNIK NATURALS • Customer Portal'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                        onPressed: () => Navigator.pop(context),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  TabBar(
                    controller: _tabController,
                    indicatorColor: const Color(0xFFFBBF24),
                    indicatorWeight: 3,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white70,
                    labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    tabs: [
                      Tab(icon: const Icon(Icons.login, size: 16), text: _t('లాగిన్', 'Login')),
                      Tab(icon: const Icon(Icons.person_add_alt_1, size: 16), text: _t('కొత్త రిజిస్ట్రేషన్', 'Register')),
                    ],
                  ),
                ],
              ),
            ),

            // Tab Views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Tab 1: Login
                  _buildLoginTab(),
                  // Tab 2: Register
                  _buildRegisterTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
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

          TextField(
            controller: _loginUserCtrl,
            decoration: InputDecoration(
              labelText: _t('యూజర్‌నేమ్ లేదా మొబైల్ నంబర్', 'Username or Mobile Number'),
              prefixIcon: const Icon(Icons.person_outline, size: 20),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _loginPassCtrl,
            obscureText: _loginObscure,
            decoration: InputDecoration(
              labelText: _t('పాస్‌వర్డ్', 'Password'),
              prefixIcon: const Icon(Icons.lock_outline, size: 20),
              suffixIcon: IconButton(
                icon: Icon(_loginObscure ? Icons.visibility_off : Icons.visibility, size: 20),
                onPressed: () => setState(() => _loginObscure = !_loginObscure),
              ),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF047857),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 1,
            ),
            onPressed: _loginLoading ? null : _handleLogin,
            child: _loginLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Text(
                    _t('లాగిన్ అవ్వండి', 'Login Now'),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_t('ఇంకా ఖాతా లేదా? ', "Don't have an account? "),
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              TextButton(
                onPressed: () => _tabController.animateTo(1),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  foregroundColor: const Color(0xFF047857),
                  padding: EdgeInsets.zero,
                ),
                child: Text(
                  _t('కొత్త ఖాతా రిజిస్టర్ చేసుకోండి', 'Register New Account'),
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRegisterTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
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

          TextField(
            controller: _regNameCtrl,
            decoration: InputDecoration(
              labelText: _t('పూర్తి పేరు *', 'Full Name *'),
              prefixIcon: const Icon(Icons.badge_outlined, size: 20),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _regPhoneCtrl,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: _t('మొబైల్ నంబర్ (10 అంకెలు) *', 'Mobile Number (10 Digits) *'),
              prefixIcon: const Icon(Icons.phone_outlined, size: 20),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _regUserCtrl,
            decoration: InputDecoration(
              labelText: _t('యూజర్‌నేమ్ (ఐచ్ఛికం)', 'Username (Optional)'),
              prefixIcon: const Icon(Icons.account_circle_outlined, size: 20),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _regPassCtrl,
            obscureText: _regObscure,
            decoration: InputDecoration(
              labelText: _t('పాస్‌వర్డ్ *', 'Password *'),
              prefixIcon: const Icon(Icons.lock_outline, size: 20),
              suffixIcon: IconButton(
                icon: Icon(_regObscure ? Icons.visibility_off : Icons.visibility, size: 20),
                onPressed: () => setState(() => _regObscure = !_regObscure),
              ),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _regAddressCtrl,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: _t('డెలివరీ చిరునామా', 'Delivery Address'),
              prefixIcon: const Icon(Icons.location_on_outlined, size: 20),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
          ),
          const SizedBox(height: 18),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF047857),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 1,
            ),
            onPressed: _regLoading ? null : _handleRegister,
            child: _regLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Text(
                    _t('ఖాతా సృష్టించండి', 'Create Account'),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_t('ఇప్పటికే ఖాతా ఉందా? ', 'Already have an account? '),
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              TextButton(
                onPressed: () => _tabController.animateTo(0),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  foregroundColor: const Color(0xFF047857),
                  padding: EdgeInsets.zero,
                ),
                child: Text(
                  _t('లాగిన్ అవ్వండి', 'Login Now'),
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ==========================================
// CUSTOMER PROFILE & LOGOUT SHEET
// ==========================================

class _CustomerProfileSheet extends StatelessWidget {
  final Map<String, dynamic> customer;
  final VoidCallback onViewOrders;
  final VoidCallback onLogout;
  final bool isTe;

  const _CustomerProfileSheet({
    required this.customer,
    required this.onViewOrders,
    required this.onLogout,
    this.isTe = true,
  });

  String _t(String te, String en) => isTe ? te : en;

  @override
  Widget build(BuildContext context) {
    final name = customer['name'] ?? _t('కస్టమర్', 'Customer');
    final phone = customer['phone'] ?? '';
    final username = customer['username'] ?? '';
    final address = customer['address'] ?? '';

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // User Card
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: const Color(0xFF047857),
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : 'C',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '📱 $phone • @$username',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _t('🌿 UNIK Naturals కస్టమర్ ఖాతా', '🌿 UNIK Naturals Customer Account'),
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF047857)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 10),

          // Saved Address Display
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.location_on_outlined, size: 18, color: Color(0xFF047857)),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _t('డెలివరీ చిరునామా:', 'Delivery Address:'),
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        address.isNotEmpty
                            ? address
                            : _t('చిరునామా నమోదు కాలేదు. ఆర్డర్ చేసేటప్పుడు ఇవ్వవచ్చు.',
                                'No address saved yet. You can provide one during checkout.'),
                        style: TextStyle(
                          fontSize: 12,
                          color: address.isNotEmpty ? const Color(0xFF1E293B) : const Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Action: View My Orders
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.receipt_long, color: Color(0xFF2563EB), size: 20),
            ),
            title: Text(_t('నా ఆర్డర్లు', 'My Orders'),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            subtitle: Text(_t('ఆర్డర్ స్టేటస్, వివరాలు మరియు ట్రాకింగ్', 'Order status, details and tracking'),
                style: const TextStyle(fontSize: 11)),
            trailing: const Icon(Icons.arrow_forward_ios, size: 14),
            onTap: onViewOrders,
          ),

          const Divider(),
          const SizedBox(height: 10),

          // Logout Button
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFDC2626),
              side: const BorderSide(color: Color(0xFFFCA5A5)),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: onLogout,
            icon: const Icon(Icons.logout, size: 16),
            label: Text(
              _t('ఖాతా నుండి లాగౌట్', 'Log Out'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

