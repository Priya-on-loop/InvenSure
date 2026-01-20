import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import 'dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;

  void _login() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Please fill all fields")));
      return;
    }

    setState(() => _isLoading = true);
    
    final data = await ApiService.login(_emailController.text, _passwordController.text);
    
    setState(() => _isLoading = false);

    if (data['success'] == true && data['token'] != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', data['token']);
      // Assuming role is sent, if not default to staff
      await prefs.setString('role', data['role'] ?? 'staff');
      
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => DashboardScreen()));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['message'] ?? 'Login failed')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("InvenSure Login")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory, size: 80, color: Colors.blue),
            SizedBox(height: 20),
            TextField(controller: _emailController, decoration: InputDecoration(labelText: "Email", border: OutlineInputBorder())),
            SizedBox(height: 10),
            TextField(controller: _passwordController, decoration: InputDecoration(labelText: "Password", border: OutlineInputBorder()), obscureText: true),
            SizedBox(height: 20),
            _isLoading 
              ? CircularProgressIndicator() 
              : ElevatedButton(
                  onPressed: _login, 
                  child: Padding(padding: EdgeInsets.all(12), child: Text("LOGIN")),
                  style: ElevatedButton.styleFrom(minimumSize: Size(double.infinity, 50)),
                )
          ],
        ),
      ),
    );
  }
}