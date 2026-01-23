import 'package:flutter/material.dart';
import '../services/api_service.dart';

class AdminUsersScreen extends StatefulWidget {
  @override
  _AdminUsersScreenState createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  List<dynamic> _pendingUsers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() async {
    setState(() => _isLoading = true);
    final data = await ApiService.getPendingUsers();
    setState(() {
      _pendingUsers = data;
      _isLoading = false;
    });
  }

  void _approve(String id) async {
    bool success = await ApiService.approveUser(id);
    if (success) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("✅ Staff Approved!")));
      _loadData();
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Failed to approve")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Pending Staff Requests")),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _pendingUsers.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 60,
                    color: Colors.green,
                  ),
                  Text("All staff approved!"),
                ],
              ),
            )
          : ListView.builder(
              itemCount: _pendingUsers.length,
              itemBuilder: (ctx, i) {
                final user = _pendingUsers[i];
                return Card(
                  child: ListTile(
                    leading: Icon(Icons.person_add, color: Colors.orange),
                    title: Text(user['name']),
                    subtitle: Text(user['email']),
                    trailing: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () => _approve(user['_id']),
                      child: Text("Approve"),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
