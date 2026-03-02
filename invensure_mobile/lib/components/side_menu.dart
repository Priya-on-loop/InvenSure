import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../screens/login_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/dashboard_screen.dart';
import '../services/api_service.dart';

class SideMenu extends StatefulWidget {
  @override
  _SideMenuState createState() => _SideMenuState();
}

class _SideMenuState extends State<SideMenu> {
  String userName = "User";
  String userRole = "Loading...";
  List<String> availableCategories = []; // To store categories found in DB

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadCategories();
  }

  void _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      userName = "Current User";
      userRole = (prefs.getString('role') ?? 'Staff').toUpperCase();
    });
  }

  // ✅ LOGIC: Get all products and extract unique categories
  void _loadCategories() async {
    try {
      List<dynamic> products = await ApiService.getProducts();
      Set<String> uniqueCats = {};
      for (var p in products) {
        if (p['category'] != null) uniqueCats.add(p['category']);
      }
      if (mounted) {
        setState(() {
          availableCategories = uniqueCats.toList();
          availableCategories.sort(); // A-Z sorting
        });
      }
    } catch (e) {
      // Handle error silently for sidebar
    }
  }

  void _logout(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => LoginScreen()),
      (r) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Container(
        color: Color(0xFF1E1E24),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Container(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 40),
              color: Color(0xFF15151A),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundImage: AssetImage('assets/logo.png'),
                    backgroundColor: Colors.white,
                  ),
                  SizedBox(width: 15),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userName,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        userRole,
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: 10),

            // Link to ALL items
            _menuItem(Icons.grid_view_rounded, "All Products", () {
              Navigator.pop(context);
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => DashboardScreen()),
              );
            }),

            // ✅ DYNAMIC CATEGORIES
            Theme(
              data: Theme.of(
                context,
              ).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                leading: Icon(Icons.label_outline, color: Colors.white70),
                title: Text(
                  "Categories",
                  style: TextStyle(color: Colors.white70),
                ),
                iconColor: Colors.greenAccent,
                collapsedIconColor: Colors.white70,
                children: availableCategories.isEmpty
                    ? [
                        Padding(
                          padding: EdgeInsets.all(10),
                          child: Text(
                            "No categories yet",
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      ]
                    : availableCategories.map((cat) {
                        return _subMenuItem(context, cat, () {
                          Navigator.pop(context);
                          // ✅ Pass the Category filter to Dashboard
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  DashboardScreen(filterCategory: cat),
                            ),
                          );
                        });
                      }).toList(),
              ),
            ),

            Divider(color: Colors.grey.shade800),

            _menuItem(Icons.settings, "Settings", () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => SettingsScreen()),
              );
            }),

            SizedBox(height: 100),
            ListTile(
              leading: Icon(Icons.logout, color: Colors.redAccent),
              title: Text(
                "Logout",
                style: TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onTap: () => _logout(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _menuItem(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: Colors.white70),
      title: Text(title, style: TextStyle(color: Colors.white70)),
      onTap: onTap,
    );
  }

  Widget _subMenuItem(BuildContext context, String title, VoidCallback onTap) {
    return ListTile(
      contentPadding: EdgeInsets.only(left: 50),
      title: Text(title, style: TextStyle(color: Colors.grey)),
      onTap: onTap,
    );
  }
}
