import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class StaffOnlineOrdersView extends StatefulWidget {
  final String apiBase;

  const StaffOnlineOrdersView({super.key, required this.apiBase});

  @override
  State<StaffOnlineOrdersView> createState() => _StaffOnlineOrdersViewState();
}

class _StaffOnlineOrdersViewState extends State<StaffOnlineOrdersView> {
  List<Map<String, dynamic>> _orders = [];
  bool _isLoading = true;
  String _errorMessage = '';
  String _selectedFilter = 'ALL';
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _fetchOrders();
    // Poll every 15 seconds for incoming live orders
    _pollingTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) {
        _fetchOrders(silent: true);
      }
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchOrders({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });
    }

    try {
      final res = await http.get(Uri.parse('${widget.apiBase}/orders/online'));
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        if (mounted) {
          setState(() {
            _orders = List<Map<String, dynamic>>.from(data);
            _isLoading = false;
          });
        }
      } else {
        if (!silent && mounted) {
          setState(() {
            _errorMessage = 'ఆర్డర్లు పొందలేకపోయాము (Status: ${res.statusCode})';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (!silent && mounted) {
        setState(() {
          _errorMessage = 'సర్వర్ కనెక్ట్ కావడం లేదు: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _updateOrderStatus(int orderId, String newStatus, {String? paymentStatus, bool? addToKhata}) async {
    try {
      final body = <String, dynamic>{'status': newStatus};
      if (paymentStatus != null) {
        body['payment_status'] = paymentStatus;
      }
      if (addToKhata != null) {
        body['add_to_khata'] = addToKhata;
      }

      final res = await http.patch(
        Uri.parse('${widget.apiBase}/orders/online/$orderId/status'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      final data = jsonDecode(res.body);

      if (res.statusCode == 200) {
        final msg = data['message'] ?? 'ఆర్డర్ #$orderId స్టేటస్ "$newStatus" గా మారింది';
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: addToKhata == true ? const Color(0xFF7C3AED) : const Color(0xFF16A34A),
              content: Text(msg),
              duration: const Duration(seconds: 3),
            ),
          );
        }
        _fetchOrders(silent: true);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(backgroundColor: Colors.red, content: Text('స్టేటస్ మార్పు విఫలమైంది: ${res.body}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: Colors.red, content: Text('లోపం: $e')),
        );
      }
    }
  }

  void _sendCustomerWhatsApp(Map<String, dynamic> order, String action) {
    final phone = (order['customer_phone'] ?? '').toString();
    final name = (order['customer_name'] ?? '').toString();
    final ordNum = (order['order_number'] ?? '').toString();
    final total = (order['total_amount'] ?? 0).toString();

    String msg = '';
    if (action == 'ACCEPT') {
      msg = 'నమస్తే $name గారూ, మీ UNIK NATURALS ఆర్డర్ #$ordNum (₹$total) ఆమోదించబడింది! త్వరలోనే ప్యాకింగ్ చేస్తాము. ధన్యవాదాలు!';
    } else if (action == 'PACKING') {
      msg = 'నమస్తే $name గారూ, మీ UNIK NATURALS ఆర్డర్ #$ordNum ప్యాకింగ్ పూర్తవుతోంది. త్వరలోనే డెలివరీకి పంపుతాము.';
    } else if (action == 'OUT_FOR_DELIVERY') {
      msg = 'నమస్తే $name గారూ, మీ UNIK NATURALS ఆర్డర్ #$ordNum డెలివరీకి బయలుదేరింది! దయచేసి అందుబాటులో ఉండండి.';
    } else if (action == 'DELIVERED') {
      msg = 'నమస్తే $name గారూ, మీ UNIK NATURALS ఆర్డర్ #$ordNum విజయవంతంగా డెలివరీ చేయబడింది. మమ్మల్ని ఎంచుకున్నందుకు ధన్యవాదాలు!';
    } else if (action == 'KHATA') {
      msg = 'నమస్తే $name గారూ, మీ UNIK NATURALS ఆర్డర్ #$ordNum (₹$total) డెలివరీ పూర్తయింది. ఈ మొత్తం మీ ఖాతా పుస్తకంలో (Khata) బాకీగా నమోదు చేయబడింది. ధన్యవాదాలు!';
    } else {
      msg = 'నమస్తే $name గారూ, UNIK NATURALS ఆర్డర్ #$ordNum గురించిన సమాచారం.';
    }

    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    final target = cleanPhone.length == 10 ? '91$cleanPhone' : cleanPhone;
    final url = 'https://wa.me/$target?text=${Uri.encodeComponent(msg)}';

    try {
      html.window.open(url, '_blank');
    } catch (_) {
      Clipboard.setData(ClipboardData(text: msg));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('మెసేజ్ కాపీ అయింది. వాట్సాప్‌లో పంపవచ్చు.')),
        );
      }
    }
  }

  List<Map<String, dynamic>> get _filteredOrders {
    if (_selectedFilter == 'ALL') return _orders;
    return _orders.where((o) => (o['order_status'] ?? '').toString().toUpperCase() == _selectedFilter).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredOrders;

    int newCount = 0;
    int acceptedCount = 0;
    int packingCount = 0;
    int outCount = 0;
    int deliveredCount = 0;
    double totalRevenue = 0;

    for (final o in _orders) {
      final st = (o['order_status'] ?? '').toString().toUpperCase();
      final tot = (o['total_amount'] as num?)?.toDouble() ?? 0;
      if (st == 'NEW') newCount++;
      if (st == 'ACCEPTED') acceptedCount++;
      if (st == 'PACKING') packingCount++;
      if (st == 'OUT_FOR_DELIVERY') outCount++;
      if (st == 'DELIVERED') deliveredCount++;
      totalRevenue += tot;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: RefreshIndicator(
        onRefresh: () => _fetchOrders(),
        child: Column(
          children: [
            // Header Stats Bar
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              decoration: const BoxDecoration(
                color: Color(0xFF0E1F12),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.local_shipping, color: Color(0xFFF59E0B), size: 22),
                          SizedBox(width: 8),
                          Text(
                            'ఆన్‌లైన్ ఆర్డర్లు (Customer Orders)',
                            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh, color: Colors.white),
                        tooltip: 'రీఫ్రెష్ చేయండి',
                        onPressed: () => _fetchOrders(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Mini Metric Pills
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _metricBadge('మొత్తం', '${_orders.length}', const Color(0xFF374151), Colors.white),
                        const SizedBox(width: 8),
                        _metricBadge('కొత్తవి', '$newCount', const Color(0xFFFEF3C7), const Color(0xFFB45309)),
                        const SizedBox(width: 8),
                        _metricBadge('ఆమోదించినవి', '$acceptedCount', const Color(0xFFDBEAFE), const Color(0xFF1D4ED8)),
                        const SizedBox(width: 8),
                        _metricBadge('ప్యాకింగ్', '$packingCount', const Color(0xFFFFEDD5), const Color(0xFFC2410C)),
                        const SizedBox(width: 8),
                        _metricBadge('డెలివరీలో', '$outCount', const Color(0xFFF3E8FF), const Color(0xFF7E22CE)),
                        const SizedBox(width: 8),
                        _metricBadge('పూర్తయినవి', '$deliveredCount', const Color(0xFFDCFCE7), const Color(0xFF15803D)),
                        const SizedBox(width: 8),
                        _metricBadge('రెవెన్యూ', '₹${totalRevenue.toInt()}', const Color(0xFF164610), const Color(0xFFF59E0B)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Filter Chips Bar
            Container(
              height: 48,
              padding: const EdgeInsets.symmetric(vertical: 4),
              color: Colors.white,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  _filterChip('ALL', '🌟 అన్నీ (${_orders.length})'),
                  const SizedBox(width: 6),
                  _filterChip('NEW', '🟡 కొత్తవి ($newCount)'),
                  const SizedBox(width: 6),
                  _filterChip('ACCEPTED', '🔵 ఆమోదించినవి ($acceptedCount)'),
                  const SizedBox(width: 6),
                  _filterChip('PACKING', '🟠 ప్యాకింగ్ ($packingCount)'),
                  const SizedBox(width: 6),
                  _filterChip('OUT_FOR_DELIVERY', '🚚 డెలివరీలో ($outCount)'),
                  const SizedBox(width: 6),
                  _filterChip('DELIVERED', '🟢 పూర్తయినవి ($deliveredCount)'),
                ],
              ),
            ),

            // Orders List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF164610)))
                  : _errorMessage.isNotEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.error_outline, size: 48, color: Colors.red),
                              const SizedBox(height: 8),
                              Text(_errorMessage, style: const TextStyle(color: Colors.red)),
                              const SizedBox(height: 10),
                              ElevatedButton(onPressed: () => _fetchOrders(), child: const Text('తిరిగి ప్రయత్నించండి')),
                            ],
                          ),
                        )
                      : filtered.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.inbox_outlined, size: 48, color: Colors.grey),
                                  const SizedBox(height: 8),
                                  Text(
                                    _selectedFilter == 'ALL' ? 'ఇంకా ఆన్‌లైన్ ఆర్డర్లు లేవు' : 'ఈ విభాగంలో ఆర్డర్లు లేవు',
                                    style: const TextStyle(color: Colors.grey),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(12),
                              itemCount: filtered.length,
                              itemBuilder: (ctx, idx) {
                                final order = filtered[idx];
                                return _StaffOrderCard(
                                  order: order,
                                  onStatusChange: (newStatus, {paymentStatus, addToKhata}) {
                                    _updateOrderStatus(order['id'] as int, newStatus, paymentStatus: paymentStatus, addToKhata: addToKhata);
                                  },
                                  onWhatsAppAction: (action) {
                                    _sendCustomerWhatsApp(order, action);
                                  },
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metricBadge(String label, String value, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label: ', style: TextStyle(color: fg.withValues(alpha: 0.8), fontSize: 11)),
          Text(value, style: TextStyle(color: fg, fontWeight: FontWeight.bold, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _filterChip(String key, String label) {
    final isSel = _selectedFilter == key;
    return ChoiceChip(
      selected: isSel,
      label: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
          color: isSel ? Colors.white : const Color(0xFF374151),
        ),
      ),
      selectedColor: const Color(0xFF164610),
      backgroundColor: const Color(0xFFF3F4F6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      onSelected: (_) => setState(() => _selectedFilter = key),
    );
  }
}

class _StaffOrderCard extends StatelessWidget {
  final Map<String, dynamic> order;
  final Function(String, {String? paymentStatus, bool? addToKhata}) onStatusChange;
  final Function(String) onWhatsAppAction;

  const _StaffOrderCard({
    required this.order,
    required this.onStatusChange,
    required this.onWhatsAppAction,
  });

  @override
  Widget build(BuildContext context) {
    final orderNum = (order['order_number'] ?? 'ORD-000').toString();
    final name = (order['customer_name'] ?? 'Customer').toString();
    final phone = (order['customer_phone'] ?? '').toString();
    final delType = (order['delivery_type'] ?? 'DELIVERY').toString();
    final address = order['delivery_address'] as String?;
    final total = (order['total_amount'] ?? 0).toString();
    final payMode = (order['payment_mode'] ?? 'COD').toString();
    final payStatus = (order['payment_status'] ?? 'PENDING').toString();
    final orderStatus = (order['order_status'] ?? 'NEW').toString();
    final notes = order['notes'] as String?;
    final items = (order['items'] as List?) ?? [];
    final createdAt = (order['created_at'] ?? '').toString();
    final khataDue = (order['customer_khata_due'] as num?)?.toDouble();

    String dateStr = '';
    try {
      final dt = DateTime.parse(createdAt).toLocal();
      dateStr = DateFormat('dd MMM, hh:mm a').format(dt);
    } catch (_) {
      dateStr = createdAt;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: orderStatus == 'NEW' ? const Color(0xFFF59E0B) : const Color(0xFFE5E7EB),
          width: orderStatus == 'NEW' ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Bar: Order ID + Status Chip
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      orderNum,
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Color(0xFF164610)),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: delType == 'PICKUP' ? const Color(0xFFDBEAFE) : const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        delType == 'PICKUP' ? '🏪 షాప్ పికప్' : '🚚 హోమ్ డెలివరీ',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: delType == 'PICKUP' ? const Color(0xFF1D4ED8) : const Color(0xFF15803D),
                        ),
                      ),
                    ),
                  ],
                ),
                _buildStatusBadge(orderStatus),
              ],
            ),
            const SizedBox(height: 6),
            Text('నమోదైన సమయం: $dateStr', style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
            const Divider(height: 16),

            // Customer Details Row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: const Color(0xFF164610),
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : 'C',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      if (phone.isNotEmpty)
                        Text(phone, style: const TextStyle(fontSize: 12, color: Color(0xFF4B5563))),
                      if (delType == 'DELIVERY' && address != null && address.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '📍 $address',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF1F2937), fontWeight: FontWeight.w500),
                          ),
                        ),
                      if (notes != null && notes.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text('📝 గమనిక: $notes', style: const TextStyle(fontSize: 11, color: Color(0xFFB45309), fontStyle: FontStyle.italic)),
                        ),
                      if (khataDue != null || payMode == 'KHATA')
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFFBFDBFE)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.menu_book, size: 13, color: Color(0xFF1D4ED8)),
                                const SizedBox(width: 4),
                                Text(
                                  'ఖాతాదారుడు | మునుపటి బాకీ: ₹${khataDue != null ? khataDue.toStringAsFixed(0) : "0"}',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8)),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // Quick WhatsApp Button
                if (phone.isNotEmpty)
                  IconButton(
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366).withValues(alpha: 0.15),
                      foregroundColor: const Color(0xFF128C7E),
                    ),
                    icon: const Icon(Icons.chat, size: 20),
                    tooltip: 'కస్టమర్‌కు వాట్సాప్ పంపండి',
                    onPressed: () => onWhatsAppAction('STATUS'),
                  ),
              ],
            ),

            const SizedBox(height: 10),
            const Divider(height: 16),

            // Ordered Items List
            const Text('ఆర్డర్ చేసిన వస్తువులు:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF374151))),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Column(
                children: items.map<Widget>((it) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE5E7EB),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text('${it['quantity']}x', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            it['name_te'] ?? it['name'],
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),
                        if (it['variant'] != null)
                          Text('(${it['variant']}) ', style: const TextStyle(fontSize: 10, color: Color(0xFF6B7280))),
                        Text('₹${it['total_price']}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 10),

            // Payment and Total Bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      payMode == 'KHATA' ? 'చెల్లింపు: 📒 ఖాతా' : 'చెల్లింపు: $payMode',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: payMode == 'KHATA' ? const Color(0xFF1E40AF) : const Color(0xFF374151),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: payStatus == 'PAID'
                            ? const Color(0xFFDCFCE7)
                            : payStatus == 'KHATA'
                                ? const Color(0xFFDBEAFE)
                                : const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        payStatus == 'PAID'
                            ? 'చెల్లించారు'
                            : payStatus == 'KHATA'
                                ? '📒 ఖాతాలో ఉంది'
                                : 'పెండింగ్',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: payStatus == 'PAID'
                              ? const Color(0xFF15803D)
                              : payStatus == 'KHATA'
                                  ? const Color(0xFF1D4ED8)
                                  : const Color(0xFFB45309),
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  'మొత్తం: ₹$total',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF164610)),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // Action Buttons Workflow
            _buildActionButtons(context, orderStatus, payStatus, payMode),
          ],
        ),
      ),
    );
  }

  void _confirmKhataDelivery(BuildContext context) {
    final name = (order['customer_name'] ?? 'కస్టమర్').toString();
    final phone = (order['customer_phone'] ?? '').toString();
    final total = (order['total_amount'] ?? 0).toString();
    final totalNum = (order['total_amount'] as num?)?.toDouble() ?? 0.0;
    final khataDue = (order['customer_khata_due'] as num?)?.toDouble() ?? 0.0;
    final newBalance = khataDue + totalNum;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.menu_book, color: Color(0xFF1E40AF)),
            SizedBox(width: 8),
            Text('ఖాతాలో నమోదు (Khata Ledger)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('కస్టమర్: $name ($phone)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('ఈ ఆర్డర్ మొత్తం:'),
                      Text('₹$total', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E40AF))),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('మునుపటి బాకీ:'),
                      Text('₹${khataDue.toStringAsFixed(0)}', style: const TextStyle(color: Color(0xFF4B5563))),
                    ],
                  ),
                  const Divider(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('మొత్తం కొత్త బాకీ:', style: TextStyle(fontWeight: FontWeight.bold)),
                      Text('₹${newBalance.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFFB91C1C), fontSize: 16)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'ఈ మొత్తం కస్టమర్ ఖాతా పుస్తకంలో బాకీగా జమ చేయబడి, ఆర్డర్ డెలివరీ పూర్తవుతుంది. కస్టమర్‌కు వాట్సాప్ సందేశం వెళ్తుంది.',
              style: TextStyle(fontSize: 12, color: Color(0xFF4B5563)),
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
              backgroundColor: const Color(0xFF1E40AF),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              onStatusChange('DELIVERED', paymentStatus: 'KHATA', addToKhata: true);
              onWhatsAppAction('KHATA');
            },
            icon: const Icon(Icons.check, size: 16),
            label: const Text('అవును, ఖాతాలో రాయండి', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color fg;
    String label;

    switch (status) {
      case 'NEW':
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFFB45309);
        label = '🟡 కొత్త ఆర్డర్';
        break;
      case 'ACCEPTED':
        bg = const Color(0xFFDBEAFE);
        fg = const Color(0xFF1D4ED8);
        label = '🔵 ఆమోదించబడింది';
        break;
      case 'PACKING':
        bg = const Color(0xFFFFEDD5);
        fg = const Color(0xFFC2410C);
        label = '🟠 ప్యాకింగ్ అవుతోంది';
        break;
      case 'OUT_FOR_DELIVERY':
        bg = const Color(0xFFF3E8FF);
        fg = const Color(0xFF7E22CE);
        label = '🚚 డెలివరీలో ఉంది';
        break;
      case 'DELIVERED':
        bg = const Color(0xFFDCFCE7);
        fg = const Color(0xFF15803D);
        label = '🟢 పూర్తయింది';
        break;
      case 'CANCELLED':
        bg = const Color(0xFFFEE2E2);
        fg = const Color(0xFFB91C1C);
        label = '❌ రద్దు అయింది';
        break;
      default:
        bg = Colors.grey.shade200;
        fg = Colors.black87;
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Text(label, style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildActionButtons(BuildContext context, String status, String payStatus, String payMode) {
    if (status == 'NEW') {
      return Row(
        children: [
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF164610),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                onStatusChange('ACCEPTED');
                onWhatsAppAction('ACCEPT');
              },
              icon: const Icon(Icons.check, size: 16),
              label: const Text('✅ ఆమోదించు (Accept)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => onStatusChange('CANCELLED'),
              child: const Text('రద్దు', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            ),
          ),
        ],
      );
    } else if (status == 'ACCEPTED') {
      return ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFD97706),
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(40),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        onPressed: () {
          onStatusChange('PACKING');
          onWhatsAppAction('PACKING');
        },
        icon: const Icon(Icons.inventory, size: 18),
        label: const Text('📦 ప్యాకింగ్ ప్రారంభించు (Start Packing)', style: TextStyle(fontWeight: FontWeight.bold)),
      );
    } else if (status == 'PACKING') {
      return ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF7C3AED),
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(40),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        onPressed: () {
          onStatusChange('OUT_FOR_DELIVERY');
          onWhatsAppAction('OUT_FOR_DELIVERY');
        },
        icon: const Icon(Icons.delivery_dining, size: 18),
        label: const Text('🚚 డెలివరీకి పంపు (Send Out For Delivery)', style: TextStyle(fontWeight: FontWeight.bold)),
      );
    } else if (status == 'OUT_FOR_DELIVERY') {
      return Column(
        children: [
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(42),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    onStatusChange('DELIVERED', paymentStatus: 'PAID');
                    onWhatsAppAction('DELIVERED');
                  },
                  icon: const Icon(Icons.payments_outlined, size: 16),
                  label: const Text('🟢 నగదు చెల్లింపు', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E40AF),
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(42),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => _confirmKhataDelivery(context),
                  icon: const Icon(Icons.menu_book, size: 16),
                  label: const Text('📒 ఖాతాలో రాయండి', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                ),
              ),
            ],
          ),
          if (payMode == 'KHATA')
            Container(
              margin: const EdgeInsets.only(top: 6),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                '📌 కస్టమర్ ఆర్డర్ చేసేటప్పుడు ఖాతా (బాకీ) ఎంచుకున్నారు.',
                style: TextStyle(fontSize: 11, color: Color(0xFF1E40AF), fontWeight: FontWeight.bold),
              ),
            ),
        ],
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              status == 'DELIVERED' ? Icons.check_circle : Icons.cancel,
              color: status == 'DELIVERED'
                  ? (payStatus == 'KHATA' ? const Color(0xFF1E40AF) : const Color(0xFF16A34A))
                  : Colors.red,
              size: 16,
            ),
            const SizedBox(width: 6),
            Text(
              status == 'DELIVERED'
                  ? (payStatus == 'KHATA'
                      ? '✔️ డెలివరీ పూర్తయింది • బాకీ ఖాతాలో చేర్చబడింది'
                      : '✔️ డెలివరీ & నగదు స్వీకరణ పూర్తయింది')
                  : 'ఈ ఆర్డర్ రద్దు చేయబడింది',
              style: TextStyle(
                color: status == 'DELIVERED'
                    ? (payStatus == 'KHATA' ? const Color(0xFF1E40AF) : const Color(0xFF16A34A))
                    : Colors.red,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }
  }
}
