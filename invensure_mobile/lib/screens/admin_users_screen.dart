import 'package:flutter/material.dart';
import '../services/api_service.dart';

class AdminUsersScreen extends StatefulWidget {
  @override
  _AdminUsersScreenState createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<dynamic> _pendingUsers = [];
  List<dynamic> _activeUsers = [];
  bool _isLoading = true;

  // ✅ List of Sections (Matches your Add Product Categories)
  final List<String> _sections = [
    "All",
    "General",
    "Dairy",
    "Vegetables",
    "Fruits",
    "Meat",
    "Medicine",
    "Beverages",
    "Snacks",
    "Household",
    "Bakery",
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  // Reloads the lists from Cloud
  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final pending = await ApiService.getUsers('pending');
      final active = await ApiService.getUsers('active');
      setState(() {
        _pendingUsers = pending;
        _activeUsers = active;
      });
    } catch (e) {
      print("Error loading users: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ✅ NEW: Logic to Assign Section
  void _showSectionDialog(dynamic user) {
    showDialog(
      context: context,
      builder: (ctx) {
        return SimpleDialog(
          title: Text("Assign Section to ${user['name']}"),
          children: _sections.map((section) {
            return SimpleDialogOption(
              padding: EdgeInsets.symmetric(vertical: 12, horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(section, style: TextStyle(fontSize: 16)),
                  // Show checkmark if already assigned
                  if ((user['assignedSection'] ?? 'All') == section)
                    Icon(Icons.check, color: Colors.green),
                ],
              ),
              onPressed: () async {
                Navigator.pop(ctx); // Close dialog
                bool success = await ApiService.assignUserSection(
                  user['_id'],
                  section,
                );
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Updated to $section")),
                  );
                  _loadData(); // Refresh UI
                } else {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text("Update Failed")));
                }
              },
            );
          }).toList(),
        );
      },
    );
  }

  void _approve(String id) async {
    await ApiService.approveUser(id);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text("✅ Approved!")));
    _loadData();
  }

  void _delete(String id, String name) async {
    bool confirm =
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text("Fire Staff?"),
            content: Text("This will prevent $name from logging in."),
            actions: [
              TextButton(
                child: Text("Cancel"),
                onPressed: () => Navigator.pop(context, false),
              ),
              TextButton(
                child: Text("Delete", style: TextStyle(color: Colors.red)),
                onPressed: () => Navigator.pop(context, true),
              ),
            ],
          ),
        ) ??
        false;

    if (confirm) {
      await ApiService.deleteUser(id);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("❌ Access Revoked")));
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Staff & Sections"),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(icon: Icon(Icons.person_add), text: "Pending"),
            Tab(icon: Icon(Icons.people), text: "Active Staff"),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: _isLoading
            ? Center(child: CircularProgressIndicator())
            : TabBarView(
                controller: _tabController,
                children: [
                  _buildList(_pendingUsers, isPending: true),
                  _buildList(_activeUsers, isPending: false),
                ],
              ),
      ),
    );
  }

  Widget _buildList(List<dynamic> users, {required bool isPending}) {
    if (users.isEmpty) {
      return ListView(
        physics: AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: 100),
          Center(
            child: Text(
              "No users found here.",
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      physics: AlwaysScrollableScrollPhysics(),
      itemCount: users.length,
      itemBuilder: (ctx, i) {
        final u = users[i];
        if (!isPending && u['role'] == 'admin')
          return SizedBox.shrink(); // Don't show admin in delete list

        return Card(
          child: ListTile(
            leading: Icon(
              isPending ? Icons.person_add : Icons.person,
              color: isPending ? Colors.orange : Colors.blue,
            ),
            title: Text(u['name'] ?? "Unknown"),
            // ✅ Show Assigned Section in subtitle
            subtitle: Text(
              "${u['email']}\nSection: ${u['assignedSection'] ?? 'All'}",
            ),
            isThreeLine: true,
            trailing: isPending
                ? ElevatedButton(
                    onPressed: () => _approve(u['_id']),
                    child: Text("Approve"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ✅ ASSIGN SECTION BUTTON
                      IconButton(
                        icon: Icon(Icons.store, color: Colors.blueAccent),
                        tooltip: "Assign Section",
                        onPressed: () => _showSectionDialog(u),
                      ),
                      // DELETE BUTTON
                      IconButton(
                        icon: Icon(Icons.delete, color: Colors.red),
                        tooltip: "Revoke Access",
                        onPressed: () => _delete(u['_id'], u['name']),
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }
}
