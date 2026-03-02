import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import 'recycler_dashboard.dart'; // ✅ Required for navigation
import 'dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLogin = true;
  String _selectedRole = 'staff';

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;

  void _submit() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Please fill all fields")));
      return;
    }

    setState(() => _isLoading = true);

    Map<String, dynamic> data;

    if (_isLogin) {
      // LOGIN
      data = await ApiService.login(
        _emailController.text,
        _passwordController.text,
      );
    } else {
      // REGISTER
      data = await ApiService.register(
        _nameController.text,
        _emailController.text,
        _passwordController.text,
        _selectedRole,
      );
    }

    setState(() => _isLoading = false);

    if (data['success'] == true) {
      if (_isLogin) {
        // --- LOGIN SUCCESS ---
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', data['token']);

        // Ensure role is consistent (lowercase)
        String role = (data['role'] ?? 'staff').toString().toLowerCase();
        await prefs.setString('role', role);

        // ✅ FIXED NAVIGATION LOGIC
        if (role == 'recycler') {
          print("Routing to Recycler Dashboard");
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => RecyclerDashboard()),
          );
        } else {
          print("Routing to Staff/Admin Dashboard");
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => DashboardScreen()),
          );
        }
      } else {
        // --- REGISTER SUCCESS ---
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              data['message'] ?? "Registered! Wait for Admin approval.",
            ),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 4),
          ),
        );

        setState(() {
          _isLogin = true;
          _passwordController.clear();
        });
      }
    } else {
      // Error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(data['message'] ?? 'Action failed'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(_isLogin ? "InvenSure Login" : "Create Account"),
        elevation: 0,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
                ),
                child: Image.asset('assets/logo.png', height: 140),
              ),
              SizedBox(height: 10),
              Column(
                children: [
                  Text(
                    "InvenSure",
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2C3E50),
                      letterSpacing: 1.2,
                    ),
                  ),
                  Container(
                    margin: EdgeInsets.only(top: 5),
                    height: 4,
                    width: 120,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2),
                      gradient: LinearGradient(
                        colors: [Colors.lightBlue, Colors.greenAccent],
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 40),

              // Register Fields
              if (!_isLogin) ...[
                TextField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: "Full Name",
                    border: OutlineInputBorder(),
                  ),
                ),
                SizedBox(height: 10),

                // ROLE SELECTOR
                DropdownButtonFormField<String>(
                  value: _selectedRole,
                  decoration: InputDecoration(
                    labelText: "I am a...",
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: "staff",
                      child: Text("Staff Member"),
                    ),
                    DropdownMenuItem(
                      value: "recycler",
                      child: Text("Recycling Partner"),
                    ),
                  ],
                  onChanged: (val) => setState(() => _selectedRole = val!),
                ),
                SizedBox(height: 10),
              ],

              TextField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: _isLogin ? "Email OR Full Name" : "Email Address",
                  prefixIcon: Icon(_isLogin ? Icons.person : Icons.email),
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 10),
              TextField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: "Password",
                  prefixIcon: Icon(Icons.lock),
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              ),

              SizedBox(height: 25),
              _isLoading
                  ? CircularProgressIndicator()
                  : SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _submit,
                        child: Padding(
                          padding: EdgeInsets.all(14),
                          child: Text(
                            _isLogin ? "LOGIN" : "REGISTER",
                            style: TextStyle(fontSize: 16),
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),

              SizedBox(height: 20),
              TextButton(
                onPressed: () => setState(() => _isLogin = !_isLogin),
                child: Text(
                  _isLogin ? "New User? Register Here" : "Back to Login",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
