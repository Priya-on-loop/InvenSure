import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/api_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

class AddProductScreen extends StatefulWidget {
  @override
  _AddProductScreenState createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _idController = TextEditingController();
  final _nameController = TextEditingController();
  final _expiryController = TextEditingController();

  // ✅ NEW: Category State
  String _selectedCategory = "General";
  final List<String> _categories = [
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

  bool _isScanning = false;
  bool _isSubmitting = false;
  File? _selectedImage;
  String? _base64Image;

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final XFile? photo = await picker.pickImage(source: source);

    if (photo != null) {
      final result = await FlutterImageCompress.compressWithFile(
        photo.path,
        minWidth: 500,
        minHeight: 500,
        quality: 50,
      );

      if (result != null) {
        setState(() {
          _selectedImage = File(photo.path);
          _base64Image = base64Encode(result);
        });
      }
    }
  }

  void _handleScan(BarcodeCapture capture) {
    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      if (barcode.rawValue != null) {
        setState(() {
          _isScanning = false;
          _idController.text = barcode.rawValue!;
        });
      }
    }
  }

  void _submit() async {
    if (_idController.text.isEmpty ||
        _nameController.text.isEmpty ||
        _expiryController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Fill all fields")));
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      // ✅ UPDATED: Pass category to API
      await ApiService.addProduct(
        _idController.text,
        _nameController.text,
        _expiryController.text,
        _selectedCategory, // <--- Passing the selected category
        _base64Image,
      );
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("✅ Added Product!")));
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Failed: $e")));
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isScanning) {
      return Scaffold(
        appBar: AppBar(
          title: Text("Scan QR/Barcode"),
          leading: IconButton(
            icon: Icon(Icons.close),
            onPressed: () => setState(() => _isScanning = false),
          ),
        ),
        body: MobileScanner(onDetect: _handleScan),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text("Add Product")),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            // IMAGE BOX
            GestureDetector(
              onTap: () {
                showModalBottomSheet(
                  context: context,
                  builder: (context) => Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                        leading: Icon(Icons.camera),
                        title: Text("Take Photo"),
                        onTap: () {
                          Navigator.pop(context);
                          _pickImage(ImageSource.camera);
                        },
                      ),
                      ListTile(
                        leading: Icon(Icons.image),
                        title: Text("Gallery"),
                        onTap: () {
                          Navigator.pop(context);
                          _pickImage(ImageSource.gallery);
                        },
                      ),
                    ],
                  ),
                );
              },
              child: Container(
                height: 150,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey),
                ),
                child: _selectedImage == null
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_a_photo, size: 40, color: Colors.grey),
                          Text("Tap to add photo"),
                        ],
                      )
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.file(_selectedImage!, fit: BoxFit.cover),
                      ),
              ),
            ),

            SizedBox(height: 20),

            // BARCODE & NAME
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _idController,
                    decoration: InputDecoration(
                      labelText: "Barcode ID",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                SizedBox(width: 10),
                IconButton(
                  icon: Icon(Icons.qr_code_scanner, size: 30),
                  color: Colors.blue,
                  onPressed: () => setState(() => _isScanning = true),
                ),
              ],
            ),
            SizedBox(height: 15),

            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: "Product Name",
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 15),

            // ✅ CATEGORY DROPDOWN
            InputDecorator(
              decoration: InputDecoration(
                labelText: "Category",
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedCategory,
                  isExpanded: true,
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedCategory = val);
                  },
                  items: _categories
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                ),
              ),
            ),

            SizedBox(height: 15),

            // EXPIRY
            TextField(
              controller: _expiryController,
              decoration: InputDecoration(
                labelText: "Expiry Date",
                border: OutlineInputBorder(),
                suffixIcon: Icon(Icons.calendar_today),
              ),
              onTap: () async {
                DateTime? pickedDate = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2101),
                );
                if (pickedDate != null)
                  _expiryController.text = pickedDate.toString().split(' ')[0];
              },
            ),

            SizedBox(height: 30),
            _isSubmitting
                ? CircularProgressIndicator()
                : SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _submit,
                      child: Padding(
                        padding: const EdgeInsets.all(15.0),
                        child: Text(
                          "ADD TO INVENTORY",
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
