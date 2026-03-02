import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import 'add_product_screen.dart';
import 'login_screen.dart';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../services/notification_service.dart';
import 'settings_screen.dart';
import 'admin_users_screen.dart';
import '../components/side_menu.dart';

class DashboardScreen extends StatefulWidget {
  // ✅ ADDED: Accept category filter from Sidebar
  final String? filterCategory;
  DashboardScreen({this.filterCategory});

  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<dynamic> _allProducts = [];
  List<dynamic> _filteredProducts = [];
  bool _isLoading = true;
  String _userRole = 'staff';

  String _selectedStatus = "All";
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    NotificationService.init();
    _loadRole();
    _loadProducts();
  }

  void _loadRole() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _userRole = prefs.getString('role') ?? 'staff');
  }

  void _loadProducts() {
    setState(() => _isLoading = true);
    ApiService.getProducts()
        .then((data) {
          setState(() {
            _allProducts = data;
            _isLoading = false;
            _applyFilters(); // ✅ Apply filter immediately on load
          });
          _checkAndTriggerNotifications(data);
        })
        .catchError((err) {
          setState(() => _isLoading = false);
        });
  }

  void _checkAndTriggerNotifications(List<dynamic> products) async {
    final prefs = await SharedPreferences.getInstance();
    bool enabled = prefs.getBool('notifications_enabled') ?? true;
    int userDaysSetting = prefs.getInt('notification_days') ?? 3;

    if (!enabled) return;

    int alertCount = 0;
    DateTime now = DateTime.now();

    for (var p in products) {
      try {
        if (p['expiry'] == null) continue;
        DateTime expiry = DateTime.parse(p['expiry'].toString());
        int daysUntil = expiry.difference(now).inDays;

        if (daysUntil >= 0 &&
            daysUntil <= userDaysSetting &&
            p['status'] != 'Recycled') {
          alertCount++;
        }
      } catch (e) {
        // Date error ignored
      }
    }

    if (alertCount > 0) {
      // Logic for popup notification here if needed
    }
  }

  // ✅ UPDATED: Filtering Logic to include Category
  void _applyFilters() {
    String query = _searchController.text.toLowerCase();
    String? categoryFilter = widget.filterCategory?.toLowerCase();

    setState(() {
      _filteredProducts = _allProducts.where((p) {
        // 1. Status Filter (Tabs)
        if (_selectedStatus != "All" && p['status'] != _selectedStatus)
          return false;

        String name = p['name'].toString().toLowerCase();
        String id = p['id'].toString();
        // Safe check for category existence
        String pCategory = (p['category'] ?? "General")
            .toString()
            .toLowerCase();

        // 2. Category Filter (From Sidebar)
        if (categoryFilter != null && categoryFilter.isNotEmpty) {
          if (pCategory != categoryFilter) return false;
        }

        // 3. Search Filter
        bool matchesSearch = name.contains(query) || id.contains(query);
        return matchesSearch;
      }).toList();
    });
  }

  void _generatePdf() async {
    final doc = pw.Document();
    final date = DateTime.now().toString().split(' ')[0];

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [pw.Text("InvenSure Report"), pw.Text("Date: $date")],
              ),
            ),
            pw.Text("Filter: $_selectedStatus Products"),
            if (widget.filterCategory != null)
              pw.Text("Category: ${widget.filterCategory}"),
            pw.SizedBox(height: 10),
            pw.Table.fromTextArray(
              headers: ["ID", "Name", "Category", "Expiry", "Status"],
              data: _filteredProducts
                  .map(
                    (p) => [
                      p['id'].toString(),
                      p['name'].toString(),
                      p['category']?.toString() ?? "-",
                      p['expiry'].toString(),
                      p['status'].toString(),
                    ],
                  )
                  .toList(),
            ),
          ];
        },
      ),
    );
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
      name: 'Report.pdf',
    );
  }

  void _assignRecycle(int prodId) async {
    List<dynamic> recyclers = await ApiService.getRecyclersList();
    if (recyclers.isEmpty) {
      _directRecycle(prodId);
      return;
    }

    showDialog(
      context: context,
      builder: (context) {
        return SimpleDialog(
          title: Text("Assign to Recycler"),
          children: [
            ...recyclers.map((r) {
              return SimpleDialogOption(
                padding: EdgeInsets.all(12),
                child: Text(r['name'], style: TextStyle(fontSize: 16)),
                onPressed: () async {
                  Navigator.pop(context);
                  await ApiService.assignTask(prodId, r['_id']);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Job assigned to ${r['name']}")),
                  );
                  _loadProducts();
                },
              );
            }).toList(),
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: TextButton(
                child: Text("Cancel"),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        );
      },
    );
  }

  void _directRecycle(int id) async {
    bool confirm =
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text("No Recyclers Found"),
            content: Text("Recycle immediately on Blockchain?"),
            actions: [
              TextButton(
                child: Text("Cancel"),
                onPressed: () => Navigator.pop(context, false),
              ),
              TextButton(
                child: Text("Confirm"),
                onPressed: () => Navigator.pop(context, true),
              ),
            ],
          ),
        ) ??
        false;

    if (confirm) {
      try {
        await ApiService.recycleProduct(id);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("✅ Item Recycled!")));
        _loadProducts();
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Failed.")));
      }
    }
  }

  void _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Counts logic...
    int fresh = _allProducts.where((p) => p['status'] == 'Fresh').length;
    int near = _allProducts.where((p) => p['status'] == 'Near Expiry').length;
    int expired = _allProducts.where((p) => p['status'] == 'Expired').length;

    return Scaffold(
      backgroundColor: Color(0xFFF5F7FA),
      drawer: SideMenu(),

      appBar: AppBar(
        // ✅ Dynamic Title: Shows "Dairy Inventory" or just "Dashboard"
        title: Text(
          widget.filterCategory != null
              ? "${widget.filterCategory} Inventory"
              : "Dashboard",
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.black87),
        actions: [
          IconButton(
            icon: Icon(Icons.picture_as_pdf, color: Colors.blueAccent),
            onPressed: _generatePdf,
          ),
          if (_userRole == 'admin')
            IconButton(
              icon: Icon(Icons.manage_accounts, color: Colors.redAccent),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => AdminUsersScreen()),
              ),
            ),
        ],
      ),

      floatingActionButton: FloatingActionButton.extended(
        icon: Icon(Icons.qr_code_scanner),
        label: Text("Scan Item"),
        backgroundColor: Colors.blueAccent,
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => AddProductScreen()),
          );
          _loadProducts();
        },
      ),

      body: Column(
        children: [
          // 1. STATS (Only show on main dashboard, hide if filtered by category to save space)
          if (widget.filterCategory == null)
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  _buildModernStatCard("Fresh", fresh, [
                    Color(0xFF66BB6A),
                    Color(0xFF43A047),
                  ]),
                  SizedBox(width: 8),
                  _buildModernStatCard("Warning", near, [
                    Color(0xFFFFA726),
                    Color(0xFFFB8C00),
                  ]),
                  SizedBox(width: 8),
                  _buildModernStatCard("Expired", expired, [
                    Color(0xFFEF5350),
                    Color(0xFFE53935),
                  ]),
                ],
              ),
            ),

          // 2. SEARCH BAR
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 5,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: "Search inventory...",
                  prefixIcon: Icon(Icons.search, color: Colors.grey),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(15),
                ),
                onChanged: (val) => _applyFilters(),
              ),
            ),
          ),

          // 3. Filters
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            child: Row(
              children: [
                _buildFilterChip("All", Colors.blue),
                _buildFilterChip("Fresh", Colors.green),
                _buildFilterChip("Near Expiry", Colors.orange),
                _buildFilterChip("Expired", Colors.red),
                if (_userRole == 'admin')
                  _buildFilterChip("Recycled", Colors.grey),
              ],
            ),
          ),

          // 4. List View
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator())
                : _filteredProducts.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inbox, size: 50, color: Colors.grey),
                        Text("No products found"),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: () async {
                      _loadProducts();
                    },
                    child: ListView.builder(
                      padding: EdgeInsets.only(bottom: 80),
                      itemCount: _filteredProducts.length,
                      itemBuilder: (context, index) {
                        final p = _filteredProducts[index];
                        return Card(
                          elevation: 2,
                          margin: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: ListTile(
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            leading: Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.grey[100],
                              ),
                              child: ClipOval(
                                child:
                                    (p['image'] != null &&
                                        p['image'].toString().length > 100)
                                    ? Image.memory(
                                        base64Decode(p['image']),
                                        fit: BoxFit.cover,
                                        errorBuilder: (c, e, s) =>
                                            _fallbackIcon(p['status']),
                                      )
                                    : _fallbackIcon(p['status']),
                              ),
                            ),
                            title: Text(
                              p['name'],
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Expires: ${p['expiry']}",
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                                Text(
                                  p['category'] ?? "General",
                                  style: TextStyle(
                                    color: Colors.blueGrey,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ), // Show category
                              ],
                            ),
                            trailing:
                                (_userRole == 'admin' &&
                                    p['status'] != 'Recycled')
                                ? IconButton(
                                    icon: Icon(
                                      Icons.delete_outline,
                                      color: Colors.red,
                                    ),
                                    onPressed: () => _assignRecycle(p['id']),
                                  )
                                : null,
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // ✅ WIDGET HELPERS
  Widget _buildModernStatCard(String title, int count, List<Color> colors) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            if (title == "Warning")
              _selectedStatus = "Near Expiry";
            else if (title == "Fresh")
              _selectedStatus = "Fresh";
            else if (title == "Expired")
              _selectedStatus = "Expired";
            _applyFilters();
          });
        },
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: colors,
            ),
            boxShadow: [
              BoxShadow(
                color: colors[0].withOpacity(0.4),
                blurRadius: 8,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Text(
                count.toString(),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                title,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, Color color) {
    bool isSelected = _selectedStatus == label;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        selectedColor: color,
        backgroundColor: Colors.white,
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : Colors.black87,
        ),
        onSelected: (s) {
          setState(() {
            _selectedStatus = label;
            _applyFilters();
          });
        },
      ),
    );
  }

  Widget _fallbackIcon(String status) {
    return CircleAvatar(
      backgroundColor: Colors.transparent,
      child: Icon(Icons.inventory_2, color: _getStatusColor(status), size: 28),
    );
  }

  Color _getStatusColor(String status) {
    if (status == 'Fresh') return Colors.green;
    if (status == 'Near Expiry') return Colors.orange;
    if (status == 'Expired') return Colors.red;
    return Colors.grey;
  }
}
