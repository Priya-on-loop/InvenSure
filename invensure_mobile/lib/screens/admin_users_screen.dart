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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  void _loadData() async {
    setState(() => _isLoading = true);
    final pending = await ApiService.getUsers('pending');
    final active = await ApiService.getUsers('active');
    setState(() {
      _pendingUsers = pending;
      _activeUsers = active;
      _isLoading = false;
    });
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
        title: Text("Staff Management"),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(icon: Icon(Icons.person_add), text: "Pending"),
            Tab(icon: Icon(Icons.people), text: "Active Staff"),
          ],
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                // 1. Pending List
                _buildList(_pendingUsers, isPending: true),
                // 2. Active List
                _buildList(_activeUsers, isPending: false),
              ],
            ),
    );
  }

  Widget _buildList(List<dynamic> users, {required bool isPending}) {
    if (users.isEmpty) return Center(child: Text("No users found here."));
    return ListView.builder(
      itemCount: users.length,
      itemBuilder: (ctx, i) {
        final u = users[i];
        // Don't let admin delete themselves from list
        if (!isPending && u['role'] == 'admin') return SizedBox.shrink();

        return Card(
          child: ListTile(
            leading: Icon(
              isPending ? Icons.person_add : Icons.person,
              color: isPending ? Colors.orange : Colors.blue,
            ),
            title: Text(u['name'] ?? "Unknown"),
            subtitle: Text(u['email'] ?? ""),
            trailing: isPending
                ? ElevatedButton(
                    onPressed: () => _approve(u['_id']),
                    child: Text("Approve"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                  )
                : IconButton(
                    icon: Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _delete(u['_id'], u['name']),
                  ),
          ),
        );
      },
    );
  }
}
