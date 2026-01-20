import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import 'add_product_screen.dart';
import 'login_screen.dart';

class DashboardScreen extends StatefulWidget {
  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<List<dynamic>> _productsFuture;
  String _userRole = 'staff'; // Default role

  @override
  void initState() {
    super.initState();
    _loadRole(); // 1. Load User Role
    _refreshProducts();
  }

  void _loadRole() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userRole = prefs.getString('role') ?? 'staff';
    });
  }

  void _refreshProducts() {
    setState(() {
      _productsFuture = ApiService.getProducts().then((data) {
        _checkAndShowAlerts(data);
        return data;
      });
    });
  }

  void _checkAndShowAlerts(List<dynamic> products) {
    List<dynamic> expiringItems = products
        .where((p) => p['status'] == 'Near Expiry')
        .toList();

    if (expiringItems.isNotEmpty) {
      Future.delayed(Duration.zero, () {
        if (mounted) _showExpiryDialog(expiringItems.length);
      });
    }
  }

  void _showExpiryDialog(int count) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.warning, color: Colors.orange),
              SizedBox(width: 10),
              Text("Expiry Alert!"),
            ],
          ),
          content: Text("⚠️ You have $count items expiring soon!"),
          actions: [
            TextButton(
              child: Text("OK"),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }

  // ✅ LOGIC: Recycle Product
  void _recycle(int id) async {
    bool confirm =
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text("Confirm Recycle"),
            content: Text("Mark product ID $id as Recycled on Blockchain?"),
            actions: [
              TextButton(
                child: Text("Cancel"),
                onPressed: () => Navigator.pop(context, false),
              ),
              TextButton(
                child: Text("Recycle"),
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
        ).showSnackBar(SnackBar(content: Text("♻️ Product Recycled!")));
        _refreshProducts();
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Failed to recycle")));
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

  Color _getStatusColor(String status) {
    if (status == 'Fresh') return Colors.green;
    if (status == 'Near Expiry') return Colors.orange;
    if (status == 'Expired') return Colors.red;
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Dashboard ($_userRole)"),
        actions: [IconButton(icon: Icon(Icons.logout), onPressed: _logout)],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: Icon(Icons.qr_code_scanner),
        label: Text("Scan"),
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => AddProductScreen()),
          );
          _refreshProducts();
        },
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _productsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting)
            return Center(child: CircularProgressIndicator());
          if (snapshot.hasError)
            return Center(child: Text("Connection Error."));
          final products = snapshot.data ?? [];
          if (products.isEmpty) return Center(child: Text("No products found"));

          return ListView.builder(
            itemCount: products.length,
            itemBuilder: (context, index) {
              final p = products[index];
              return Card(
                elevation: 3,
                margin: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _getStatusColor(
                      p['status'],
                    ).withOpacity(0.2),
                    child: Icon(
                      Icons.inventory,
                      color: _getStatusColor(p['status']),
                    ),
                  ),
                  title: Text(
                    p['name'],
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text("ID: ${p['id']} \nExp: ${p['expiry']}"),
                  isThreeLine: true,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ✅ THE RECYCLE BUTTON (Visible only to Admins)
                      if (_userRole == 'admin' && p['status'] != 'Recycled')
                        IconButton(
                          icon: Icon(Icons.delete_outline, color: Colors.red),
                          onPressed: () => _recycle(p['id']),
                        ),
                      if (p['status'] == 'Recycled')
                        Icon(Icons.check_circle, color: Colors.grey),
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
}
