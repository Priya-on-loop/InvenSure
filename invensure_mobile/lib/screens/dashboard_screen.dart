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

class DashboardScreen extends StatefulWidget {
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
            _applyFilters();
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
        // print("Date error: $e");
      }
    }

    if (alertCount > 0) {
      Future.delayed(Duration.zero, () {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("🔔 Alert: $alertCount items expiring soon!"),
              backgroundColor: Colors.blueAccent,
              duration: Duration(seconds: 4),
            ),
          );
        }
      });

      NotificationService.showNotification(
        id: 101,
        title: "InvenSure Alert",
        body:
            "Action Required: $alertCount items expiring within $userDaysSetting days.",
      );
    }
  }

  void _applyFilters() {
    String query = _searchController.text.toLowerCase();
    setState(() {
      _filteredProducts = _allProducts.where((p) {
        if (_selectedStatus != "All" && p['status'] != _selectedStatus)
          return false;
        String name = p['name'].toString().toLowerCase();
        String id = p['id'].toString();
        return name.contains(query) || id.contains(query);
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
            pw.Table.fromTextArray(
              headers: ["ID", "Product Name", "Expiry", "Status"],
              data: _filteredProducts
                  .map(
                    (p) => [
                      p['id'].toString(),
                      p['name'].toString(),
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

  // ✅ UPDATED LOGIC: Prompt to Assign Recycler
  void _assignRecycle(int prodId) async {
    // 1. Fetch Recyclers list from backend
    List<dynamic> recyclers = await ApiService.getRecyclersList();

    if (recyclers.isEmpty) {
      // Fallback if no recyclers exist -> Do old immediate delete
      _directRecycle(prodId);
      return;
    }

    // 2. Show Assignment Dialog
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
                  Navigator.pop(context); // Close dialog
                  await ApiService.assignTask(prodId, r['_id']);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Job assigned to ${r['name']}")),
                  );
                  _loadProducts(); // Refresh list
                },
              );
            }).toList(),
            // Option to cancel
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

  // Legacy fallback if no recyclers registered (or for immediate trash)
  void _directRecycle(int id) async {
    bool confirm =
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text("No Recyclers Found"),
            content: Text(
              "Do you want to recycle this item immediately on the Blockchain?",
            ),
            actions: [
              TextButton(
                child: Text("Cancel"),
                onPressed: () => Navigator.pop(context, false),
              ),
              TextButton(
                child: Text("Recycle Now"),
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
    int fresh = _allProducts.where((p) => p['status'] == 'Fresh').length;
    int near = _allProducts.where((p) => p['status'] == 'Near Expiry').length;
    int expired = _allProducts.where((p) => p['status'] == 'Expired').length;

    return Scaffold(
      appBar: AppBar(
        title: Text("Dashboard"),
        actions: [
          IconButton(icon: Icon(Icons.picture_as_pdf), onPressed: _generatePdf),
          IconButton(
            icon: Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => SettingsScreen()),
              ).then((_) => _loadProducts());
            },
          ),

          if (_userRole == 'admin')
            IconButton(
              icon: Icon(Icons.manage_accounts, color: Colors.redAccent),
              tooltip: "Manage Staff",
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => AdminUsersScreen()),
                );
              },
            ),

          IconButton(icon: Icon(Icons.logout), onPressed: _logout),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.qr_code_scanner),
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
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                _buildStatCard("Fresh", fresh, Colors.green),
                _buildStatCard("Warning", near, Colors.orange),
                _buildStatCard("Expired", expired, Colors.red),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: 10),
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
          SizedBox(height: 5),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: "Search...",
                prefixIcon: Icon(Icons.search),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onChanged: (val) => _applyFilters(),
            ),
          ),
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: _filteredProducts.length,
                    itemBuilder: (context, index) {
                      final p = _filteredProducts[index];
                      return Card(
                        margin: EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        child: ListTile(
                          leading: Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.grey[200],
                            ),
                            child: ClipOval(
                              child:
                                  (p['image'] != null &&
                                      p['image'].toString().length > 100)
                                  ? Image.memory(
                                      base64Decode(p['image']),
                                      fit: BoxFit.cover,
                                      errorBuilder: (ctx, err, stack) =>
                                          _fallbackIcon(p['status']),
                                    )
                                  : _fallbackIcon(p['status']),
                            ),
                          ),
                          title: Text(
                            p['name'],
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text("Expires: ${p['expiry']}"),
                          trailing:
                              // ✅ Updated to call Assign function instead of Direct Delete
                              (_userRole == 'admin' &&
                                  p['status'] != 'Recycled')
                              ? IconButton(
                                  icon: Icon(Icons.delete, color: Colors.red),
                                  onPressed: () => _assignRecycle(
                                    p['id'],
                                  ), // <-- Calls new assignment flow
                                )
                              : null,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // Helpers
  Widget _fallbackIcon(String status) {
    return CircleAvatar(
      backgroundColor: _getStatusColor(status),
      child: Icon(Icons.inventory_2, color: Colors.white, size: 20),
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
        onSelected: (s) {
          setState(() {
            _selectedStatus = label;
            _applyFilters();
          });
        },
      ),
    );
  }

  Widget _buildStatCard(String title, int count, Color color) {
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
          margin: EdgeInsets.all(4),
          padding: EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Column(
            children: [
              Text(
                count.toString(),
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.black54,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    if (status == 'Fresh') return Colors.green;
    if (status == 'Near Expiry') return Colors.orange;
    if (status == 'Expired') return Colors.red;
    return Colors.grey;
  }
}
