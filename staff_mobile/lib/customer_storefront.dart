import 'dart:convert';
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class CustomerStorefrontView extends StatefulWidget {
  final String apiBase;
  final VoidCallback onStaffLoginRequested;

  const CustomerStorefrontView({
    super.key,
    required this.apiBase,
    required this.onStaffLoginRequested,
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

  // Cart: Map<int, Map<String, dynamic>> where key is item id
  final Map<int, Map<String, dynamic>> _cart = {};

  final TextEditingController _searchController = TextEditingController();

  final List<Map<String, String>> _categories = [
    {'key': 'ALL', 'name_te': '🌟 అన్నీ', 'name_en': 'All'},
    {'key': 'OIL', 'name_te': '🛢️ గానుగ నూనెలు', 'name_en': 'Oils'},
    {'key': 'FLOUR', 'name_te': '🌾 పిండి మిల్లు', 'name_en': 'Flour'},
    {'key': 'CAKE', 'name_te': '🥜 పల్లీ/నూనె చెక్క', 'name_en': 'Cakes'},
    {'key': 'PACKAGED', 'name_te': '🥨 తాజా స్నాక్స్', 'name_en': 'Snacks'},
  ];

  @override
  void initState() {
    super.initState();
    _fetchProducts();
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
        if (_selectedCategory == 'FLOUR' && !cat.contains('FLOUR')) return false;
        if (_selectedCategory == 'CAKE' && !cat.contains('CAKE')) return false;
        if (_selectedCategory == 'PACKAGED' && !cat.contains('PACKAGED') && !cat.contains('SNACK')) return false;
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

  void _openOrderTrackerDialog() {
    showDialog(
      context: context,
      builder: (ctx) => _CustomerOrderTrackerDialog(apiBase: widget.apiBase),
    );
  }

  void _showOrderSuccessDialog(Map<String, dynamic> order) {
    final orderNum = order['order_number'] ?? 'ORD-000';
    final total = order['total_amount'] ?? 0;
    final delType = order['delivery_type'] == 'PICKUP' ? 'షాప్ పికప్ (Store Pickup)' : 'హోమ్ డెలివరీ (Home Delivery)';

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
            const Text(
              '🎉 ఆర్డర్ నమోదైంది!',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF164610)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            const Text(
              'మీ ఆర్డర్ షాప్‌కు చేరింది. మేము త్వరలోనే సిద్ధం చేస్తాము.',
              style: TextStyle(fontSize: 13, color: Color(0xFF4B5563)),
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
                      const Text('ఆర్డర్ నంబర్:', style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
                      Text(orderNum, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF1F2937))),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('మొత్తం చెల్లింపు:', style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
                      Text('₹$total', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF16A34A))),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('రకం:', style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
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
                final msg = 'నమస్తే UNIK NATURALS, నేను ఆన్‌లైన్ ద్వారా ఆర్డర్ చేసాను. ఆర్డర్ నంబర్: $orderNum, మొత్తం: ₹$total. దయచేసి నిర్ధారించండి.';
                try {
                  final url = 'https://wa.me/919848012345?text=${Uri.encodeComponent(msg)}';
                  html.window.open(url, '_blank');
                } catch (_) {}
              },
              icon: const Icon(Icons.chat, size: 18),
              label: const Text('💬 షాప్‌కు వాట్సాప్‌లో చెప్పండి', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(42),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('సరే (పూర్తయింది)', style: TextStyle(fontWeight: FontWeight.bold)),
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
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0E1F12),
        elevation: 2,
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
                errorBuilder: (ctx, err, st) => const Center(
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
                  'గానుగ నూనెలు & మిల్లింగ్ ఉత్పత్తులు',
                  style: TextStyle(color: Color(0xFFF59E0B), fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
        ),
        actions: [
          // My Orders Tracker Button
          TextButton.icon(
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            ),
            onPressed: _openOrderTrackerDialog,
            icon: const Icon(Icons.receipt_long_outlined, size: 18, color: Color(0xFFF59E0B)),
            label: const Text(
              'నా ఆర్డర్లు',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),

          // Staff Login Switch Button
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFF59E0B),
                side: const BorderSide(color: Color(0xFFF59E0B), width: 1.2),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: widget.onStaffLoginRequested,
              icon: const Icon(Icons.lock_outline, size: 14, color: Color(0xFFF59E0B)),
              label: const Text(
                'స్టాఫ్ లాగిన్',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchProducts,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Hero Banner
              Container(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF0E1F12), Color(0xFF1E3A1A), Color(0xFF164610)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFF59E0B), width: 1),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('🌿 ', style: TextStyle(fontSize: 12)),
                              Text(
                                '100% ప్యూర్ & కోల్డ్ ప్రెస్డ్',
                                style: TextStyle(color: Color(0xFFFCD34D), fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFF10B981), width: 1),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.delivery_dining, size: 14, color: Color(0xFF6EE7B7)),
                              SizedBox(width: 4),
                              Text(
                                'హోమ్ డెలివరీ లభ్యం',
                                style: TextStyle(color: Color(0xFF6EE7B7), fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'గానుగ నూనెలు & మిల్లింగ్ పిండ్లు\nఇంటి వద్దకే డెలివరీ!',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'పల్లీ నూనె, నువ్వుల నూనె, దీపం నూనె, పిండి మిల్లు ఉత్పత్తులు & తాజా స్నాక్స్ సులభంగా ఆర్డర్ చేయండి.',
                      style: TextStyle(color: Color(0xFFD1D5DB), fontSize: 12),
                    ),
                    const SizedBox(height: 16),

                    // Search Field
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: '🔍 నూనె, పిండి, స్నాక్స్ వెతకండి...',
                          hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
                          prefixIcon: const Icon(Icons.search, color: Color(0xFF164610)),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
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

              // Categories Horizontal List
              Container(
                height: 52,
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  itemCount: _categories.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (ctx, idx) {
                    final cat = _categories[idx];
                    final isSelected = _selectedCategory == cat['key'];
                    return ChoiceChip(
                      selected: isSelected,
                      label: Text(
                        cat['name_te']!,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                          color: isSelected ? Colors.white : const Color(0xFF374151),
                        ),
                      ),
                      selectedColor: const Color(0xFF164610),
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                          color: isSelected ? const Color(0xFF164610) : const Color(0xFFE5E7EB),
                          width: 1.2,
                        ),
                      ),
                      onSelected: (selected) {
                        if (selected) {
                          setState(() => _selectedCategory = cat['key']!);
                        }
                      },
                    );
                  },
                ),
              ),

              // Product Catalog Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'ఉత్పత్తులు (${products.length})',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF111827),
                      ),
                    ),
                    if (_selectedCategory != 'ALL' || _searchQuery.isNotEmpty)
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _selectedCategory = 'ALL';
                            _searchQuery = '';
                            _searchController.clear();
                          });
                        },
                        child: const Text('అన్నీ చూపించు', style: TextStyle(fontSize: 12)),
                      ),
                  ],
                ),
              ),

              // Product Listing
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 60),
                  child: Center(child: CircularProgressIndicator(color: Color(0xFF164610))),
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
                          onPressed: _fetchProducts,
                          child: const Text('తిరిగి ప్రయత్నించండి'),
                        ),
                      ],
                    ),
                  ),
                )
              else if (products.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 60),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey),
                        SizedBox(height: 10),
                        Text('ఏ ఉత్పత్తులు కనుగొనబడలేదు', style: TextStyle(color: Colors.grey)),
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
                            product: p,
                            inCartQty: inCartQty,
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

      // Sticky Bottom Cart Summary Bar
      bottomSheet: hasItemsInCart
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF0E1F12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 10,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF164610),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFF59E0B), width: 1.2),
                      ),
                      child: const Icon(Icons.shopping_cart, color: Color(0xFFF59E0B), size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$_cartTotalCount ఐటమ్స్ • ₹${_cartTotalPrice.toInt()}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const Text(
                            'ఉచిత డెలివరీ వర్తిస్తుంది',
                            style: TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF59E0B),
                        foregroundColor: const Color(0xFF09130B),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 3,
                      ),
                      onPressed: _openCartSheet,
                      icon: const Icon(Icons.arrow_forward, size: 16, color: Color(0xFF09130B)),
                      label: const Text(
                        'కార్ట్ చూడండి',
                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }
}

class _ProductCard extends StatelessWidget {
  final Map<String, dynamic> product;
  final int inCartQty;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  const _ProductCard({
    required this.product,
    required this.inCartQty,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final nameTe = (product['name_te'] ?? product['name'] ?? '').toString();
    final nameEn = (product['name'] ?? '').toString();
    final price = (product['selling_price'] as num?)?.toDouble() ?? 0;
    final unit = (product['unit'] ?? '').toString();
    final imgUrl = product['image_url'] as String?;
    final stock = (product['stock_qty'] as num?)?.toInt() ?? 0;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: inCartQty > 0 ? const Color(0xFF16A34A) : const Color(0xFFE5E7EB),
          width: inCartQty > 0 ? 1.8 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Image / Thumbnail
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (imgUrl != null && imgUrl.isNotEmpty)
                    Image.network(
                      imgUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _buildFallbackThumbnail(),
                    )
                  else
                    _buildFallbackThumbnail(),

                  // Stock Badge
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: stock > 0 ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        stock > 0 ? 'స్టాక్ ఉంది' : 'స్టాక్ లేదు',
                        style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),

                  // In Cart Tag
                  if (inCartQty > 0)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF164610),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$inCartQty కార్ట్‌లో',
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Details Section
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nameTe,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF111827),
                  ),
                ),
                Text(
                  nameEn,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF6B7280),
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
                        color: Color(0xFF164610),
                      ),
                    ),
                    if (unit.isNotEmpty)
                      Text(
                        ' / $unit',
                        style: const TextStyle(fontSize: 10, color: Color(0xFF6B7280)),
                      ),
                  ],
                ),
                const SizedBox(height: 8),

                // Add to Cart Button or Stepper
                if (inCartQty == 0)
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF164610),
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(34),
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: stock > 0 ? onAdd : null,
                    child: Text(
                      stock > 0 ? '🛒 కొనండి' : 'అందుబాటులో లేదు',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  )
                else
                  Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF16A34A), width: 1.2),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove, size: 16, color: Color(0xFF16A34A)),
                            onPressed: onRemove,
                            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                            padding: EdgeInsets.zero,
                          ),
                          Text(
                            '$inCartQty',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF164610),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add, size: 16, color: Color(0xFF16A34A)),
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
    );
  }

  Widget _buildFallbackThumbnail() {
    return Center(
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: const Color(0xFFFDE68A),
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFD97706), width: 1.5),
        ),
        child: const Center(
          child: Text('🌿', style: TextStyle(fontSize: 24)),
        ),
      ),
    );
  }
}

class _CartCheckoutSheet extends StatefulWidget {
  final String apiBase;
  final Map<int, Map<String, dynamic>> cart;
  final VoidCallback onCartUpdated;
  final Function(Map<String, dynamic>) onOrderSuccess;

  const _CartCheckoutSheet({
    required this.apiBase,
    required this.cart,
    required this.onCartUpdated,
    required this.onOrderSuccess,
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

  @override
  void initState() {
    super.initState();
    try {
      _nameController.text = html.window.localStorage['unik_customer_name'] ?? '';
      final p = html.window.localStorage['unik_customer_phone'] ?? '';
      _phoneController.text = p;
      _addressController.text = html.window.localStorage['unik_customer_address'] ?? '';
      if (p.length >= 10) {
        _checkKhata(p);
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
            _khataCustomerName = (data['name_te'] ?? data['name']).toString();
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
      setState(() => _formError = 'దయచేసి మీ పేరు నమోదు చేయండి (Please enter name)');
      return;
    }
    if (phone.length < 10) {
      setState(() => _formError = 'దయచేసి సరైన 10 అంకెల ఫోన్ నంబర్ నమోదు చేయండి');
      return;
    }
    if (_deliveryType == 'DELIVERY' && address.isEmpty) {
      setState(() => _formError = 'హోమ్ డెలివరీ కోసం చిరునామా తప్పనిసరి (Address required)');
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
          _formError = data['error'] ?? 'ఆర్డర్ సమర్పించడంలో లోపం ఏర్పడింది';
          _isSubmitting = false;
        });
      }
    } catch (e) {
      setState(() {
        _formError = 'సర్వర్ కనెక్ట్ కావడం లేదు: $e';
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
                    const Icon(Icons.shopping_bag, color: Color(0xFF164610)),
                    const SizedBox(width: 8),
                    Text(
                      'మీ కార్ట్ (${items.length} ఉత్పత్తులు)',
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

                      return Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  prod['name_te'] ?? prod['name'],
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                                Text(
                                  '₹${price.toInt()} × $qty = ₹${(price * qty).toInt()}',
                                  style: const TextStyle(color: Color(0xFF164610), fontWeight: FontWeight.w600, fontSize: 12),
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

                  // Delivery Type Selector
                  const Text('డెలివరీ విధానం (Delivery Option):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
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
                                Icon(Icons.delivery_dining, size: 18, color: _deliveryType == 'DELIVERY' ? const Color(0xFF164610) : Colors.grey),
                                const SizedBox(width: 6),
                                Text(
                                  '🚚 హోమ్ డెలివరీ',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: _deliveryType == 'DELIVERY' ? const Color(0xFF164610) : const Color(0xFF4B5563),
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
                                Icon(Icons.storefront, size: 18, color: _deliveryType == 'PICKUP' ? const Color(0xFF164610) : Colors.grey),
                                const SizedBox(width: 6),
                                Text(
                                  '🏪 షాప్ పికప్',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: _deliveryType == 'PICKUP' ? const Color(0xFF164610) : const Color(0xFF4B5563),
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
                  const Text('మీ వివరాలు (Your Details):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 8),

                  TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: '👤 పూర్తి పేరు (Customer Name) *',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 10),

                  TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: '📱 మొబైల్ నంబర్ (Phone Number) *',
                      hintText: '10 అంకెల నంబర్',
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
                              'గుర్తించబడిన ఖాతాదారుడు: $_khataCustomerName • మునుపటి బాకీ: ₹$_khataDue',
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
                        labelText: '📍 డెలివరీ చిరునామా (Delivery Address) *',
                        hintText: 'ఇంటి నంబర్, వీధి, ల్యాండ్‌మార్క్, ప్రాంతం...',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],

                  TextField(
                    controller: _notesController,
                    decoration: InputDecoration(
                      labelText: '📝 గమనికలు / సూచనలు (Optional Notes)',
                      hintText: 'ఉదా: సాయంత్రం 5 తర్వాత డెలివరీ చేయండి...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Payment Method
                  const Text('చెల్లింపు విధానం (Payment Method):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
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
                                _deliveryType == 'DELIVERY' ? '💵 క్యాష్ ఆన్ డెలివరీ' : '💵 షాప్‌లో క్యాష్',
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
                            const Text(
                              '📒 ఖాతా / బాకీ (Add to Khata)',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF6D28D9)),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEDE9FE),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'ఖాతాదారులకు',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF6D28D9)),
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
                              'ఈ ఆర్డర్ మొత్తం మీ కస్టమర్ ఖాతా పుస్తకంలో (Khata Ledger) బాకీగా నమోదు చేయబడుతుంది. డెలివరీ సమయంలో చెల్లించాల్సిన పనిలేదు, మీరు తర్వాత చెల్లించవచ్చు.' +
                                  (_khataDue != null ? '\n(మీ ప్రస్తుత బాకీ: ₹$_khataDue)' : ''),
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
                          const Row(
                            children: [
                              Icon(Icons.qr_code_2, color: Color(0xFF1D4ED8)),
                              SizedBox(width: 8),
                              Text('UPI చెల్లింపు సూచనలు', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1D4ED8))),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'మొత్తం: ₹${_subtotal.toInt()}\nఆర్డర్ నిర్ధారించిన తర్వాత డెలివరీ వద్ద PhonePe / GPay QR కోడ్ స్కాన్ చేసి లేదా షాప్ UPI కి చెల్లించవచ్చు.',
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
                            const Text('ఉత్పత్తుల మొత్తం:', style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                            Text('₹${_subtotal.toInt()}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('డెలివరీ ఛార్జీ:', style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                            Text('ఉచితం (FREE)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF16A34A))),
                          ],
                        ),
                        const Divider(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('మొత్తం చెల్లించాల్సింది:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                            Text('₹${_subtotal.toInt()}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF164610))),
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
                      backgroundColor: const Color(0xFF164610),
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 3,
                    ),
                    onPressed: _isSubmitting ? null : _submitOrder,
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                          )
                        : const Text(
                            '✅ ఆర్డర్ ఖరారు చేయండి (Place Order)',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
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

  const _CustomerOrderTrackerDialog({required this.apiBase});

  @override
  State<_CustomerOrderTrackerDialog> createState() => _CustomerOrderTrackerDialogState();
}

class _CustomerOrderTrackerDialogState extends State<_CustomerOrderTrackerDialog> {
  final TextEditingController _phoneController = TextEditingController();
  List<Map<String, dynamic>> _orders = [];
  bool _isLoading = false;
  bool _hasSearched = false;
  String _errorMessage = '';

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
          _errorMessage = 'ఆర్డర్లు పొందలేకపోయాము (Status: ${res.statusCode})';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'సర్వర్ కనెక్ట్ కాలేదు: $e';
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
                const Row(
                  children: [
                    Icon(Icons.receipt_long, color: Color(0xFF164610)),
                    SizedBox(width: 8),
                    Text(
                      'నా ఆర్డర్లు (My Orders)',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
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
                      hintText: 'మీ మొబైల్ నంబర్ నమోదు చేయండి',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF164610),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => _fetchOrders(_phoneController.text),
                  child: const Text('చూడండి'),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Results
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF164610)))
                  : _errorMessage.isNotEmpty
                      ? Center(child: Text(_errorMessage, style: const TextStyle(color: Colors.red)))
                      : !_hasSearched
                          ? const Center(
                              child: Text(
                                'ఆర్డర్ల వివరాలు చూడటానికి మీ ఫోన్ నంబర్ ఎంటర్ చేసి చూడండి నొక్కండి.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey),
                              ),
                            )
                          : _orders.isEmpty
                              ? const Center(
                                  child: Text(
                                    'ఈ నంబర్‌పై ఎటువంటి ఆర్డర్లు లభించలేదు.',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                )
                              : ListView.builder(
                                  itemCount: _orders.length,
                                  itemBuilder: (ctx, idx) {
                                    final o = _orders[idx];
                                    return _OrderHistoryCard(order: o);
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

  const _OrderHistoryCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final orderNum = order['order_number'] ?? 'ORD-000';
    final total = order['total_amount'] ?? 0;
    final status = (order['order_status'] ?? 'NEW').toString();
    final items = (order['items'] as List?) ?? [];
    final delType = order['delivery_type'] == 'PICKUP' ? '🏪 షాప్ పికప్' : '🚚 హోమ్ డెలివరీ';
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
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Color(0xFF164610)),
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
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${it['name_te'] ?? it['name']} × ${it['quantity']}',
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
                const Text('మొత్తం:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                Text(
                  '₹$total',
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Color(0xFF16A34A)),
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
        label = 'ఆర్డర్ అందింది';
        break;
      case 'ACCEPTED':
        bg = const Color(0xFFDBEAFE);
        fg = const Color(0xFF1D4ED8);
        label = 'అంగీకరించబడింది';
        break;
      case 'PACKING':
        bg = const Color(0xFFFFEDD5);
        fg = const Color(0xFFC2410C);
        label = 'ప్యాకింగ్ అవుతోంది';
        break;
      case 'OUT_FOR_DELIVERY':
        bg = const Color(0xFFF3E8FF);
        fg = const Color(0xFF7E22CE);
        label = 'డెలివరీలో ఉంది';
        break;
      case 'DELIVERED':
        bg = const Color(0xFFDCFCE7);
        fg = const Color(0xFF15803D);
        label = 'పూర్తయింది';
        break;
      case 'CANCELLED':
        bg = const Color(0xFFFEE2E2);
        fg = const Color(0xFFB91C1C);
        label = 'రద్దు చేయబడింది';
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
        child: const Text('⚠️ ఈ ఆర్డర్ రద్దు చేయబడింది.', style: TextStyle(color: Colors.red, fontSize: 11)),
      );
    }

    final steps = ['NEW', 'ACCEPTED', 'PACKING', 'OUT_FOR_DELIVERY', 'DELIVERED'];
    final labels = ['అందింది', 'ఓకే', 'ప్యాకింగ్', 'డెలివరీ', 'పూర్తి'];
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
                  color: isCompleted ? const Color(0xFF164610) : const Color(0xFF9CA3AF),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}
