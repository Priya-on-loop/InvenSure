import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/api_service.dart';

class AddProductScreen extends StatefulWidget {
  @override
  _AddProductScreenState createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _idController = TextEditingController();
  final _nameController = TextEditingController();
  final _expiryController = TextEditingController();
  bool _isScanning = false;
  bool _isSubmitting = false;

  void _handleScan(BarcodeCapture capture) {
    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      if (barcode.rawValue != null) {
        setState(() {
          _isScanning = false; 
          try {
            final data = jsonDecode(barcode.rawValue!);
            if(data['id'] != null) _idController.text = data['id'].toString();
            if(data['name'] != null) _nameController.text = data['name'];
            if(data['expiry'] != null) _expiryController.text = data['expiry'];
          } catch (e) {
            _idController.text = barcode.rawValue!;
          }
        });
      }
    }
  }

  void _submit() async {
    if (_idController.text.isEmpty || _nameController.text.isEmpty || _expiryController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Fill all fields")));
      return;
    }
    
    setState(() => _isSubmitting = true);
    try {
      await ApiService.addProduct(_idController.text, _nameController.text, _expiryController.text);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("✅ Added to Blockchain!")));
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to add")));
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isScanning) {
      return Scaffold(
        appBar: AppBar(title: Text("Scan QR/Barcode"), leading: IconButton(icon: Icon(Icons.close), onPressed: () => setState(() => _isScanning = false))),
        body: MobileScanner(onDetect: _handleScan),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text("Add Product")),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            ElevatedButton.icon(
              icon: Icon(Icons.camera_alt),
              label: Text("Scan Barcode"),
              onPressed: () => setState(() => _isScanning = true),
              style: ElevatedButton.styleFrom(minimumSize: Size(double.infinity, 50), backgroundColor: Colors.orange),
            ),
            SizedBox(height: 20),
            TextField(controller: _idController, decoration: InputDecoration(labelText: "ID / Barcode")),
            TextField(controller: _nameController, decoration: InputDecoration(labelText: "Product Name")),
            TextField(
              controller: _expiryController, 
              decoration: InputDecoration(labelText: "Expiry (YYYY-MM-DD)", suffixIcon: Icon(Icons.calendar_today)),
              onTap: () async {
                DateTime? pickedDate = await showDatePicker(
                    context: context, initialDate: DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2101));
                if (pickedDate != null) {
                   _expiryController.text = pickedDate.toIso8601String().split('T')[0];
                }
              },
            ),
            SizedBox(height: 30),
            _isSubmitting ? CircularProgressIndicator() :
            ElevatedButton(onPressed: _submit, child: Text("Add to Inventory"), style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, minimumSize: Size(double.infinity, 50), foregroundColor: Colors.white)),
          ],
        ),
      ),
    );
  }
}