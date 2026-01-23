import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import 'login_screen.dart';

class RecyclerDashboard extends StatefulWidget {
  @override
  _RecyclerDashboardState createState() => _RecyclerDashboardState();
}

class _RecyclerDashboardState extends State<RecyclerDashboard> {
  List<dynamic> _tasks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  void _loadTasks() async {
    setState(() => _isLoading = true);
    try {
      // ✅ FIX 1: Correct function name 'getRecyclerTasks'
      final tasks = await ApiService.getRecyclerTasks();
      setState(() => _tasks = tasks);
    } catch (e) {
      print("Error loading tasks: $e");
    }
    setState(() => _isLoading = false);
  }

  void _completeTask(int id) async {
    // ✅ FIX 2: Correct function name 'completeRecycleTask'
    bool success = await ApiService.completeRecycleTask(id);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("✅ Collected & Logged on Blockchain!")),
      );
      _loadTasks(); // Refresh list
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Failed to complete task.")));
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
    return Scaffold(
      appBar: AppBar(
        title: Text("My Collection Tasks"),
        actions: [IconButton(icon: Icon(Icons.logout), onPressed: _logout)],
        backgroundColor: Colors.green, // Differentiate from Admin/Staff
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _tasks.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.thumb_up, size: 50, color: Colors.green),
                  SizedBox(height: 10),
                  Text("No pending tasks!"),
                ],
              ),
            )
          : ListView.builder(
              itemCount: _tasks.length,
              itemBuilder: (ctx, i) {
                final p = _tasks[i];
                return Card(
                  color: Colors.green[50], // Light green for tasks
                  margin: EdgeInsets.all(8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.white,
                      child: Icon(Icons.recycling, color: Colors.green),
                    ),
                    title: Text(
                      p['name'] ?? "Unknown Item",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text("ID: ${p['id']} \nExpiry: ${p['expiry']}"),
                    isThreeLine: true,
                    trailing: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                      child: Text("Collect"),
                      onPressed: () => _completeTask(p['id']),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
