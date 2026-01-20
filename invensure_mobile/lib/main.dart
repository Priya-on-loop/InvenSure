import 'package:flutter/material.dart';
import 'screens/login_screen.dart';

void main() {
  runApp(InvenSureApp());
}

class InvenSureApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'InvenSure',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: false, // Keeps things simple
      ),
      home: LoginScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}