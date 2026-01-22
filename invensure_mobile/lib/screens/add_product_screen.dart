import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/api_service.dart';
import 'package:image_picker/image_picker.dart'; // 📸
import 'package:flutter_image_compress/flutter_image_compress.dart'; // 🤏

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
  File? _selectedImage; // To show preview
  String? _base64Image; // To send to database

  // 📸 LOGIC: Pick & Compress Image
  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final XFile? photo = await picker.pickImage(source: source);

    if (photo != null) {
      // Compress the image (MongoDB handles small strings better)
      final result = await FlutterImageCompress.compressWithFile(
        photo.path,
        minWidth: 500, // Make it smaller
        minHeight: 500,
        quality: 50, // Reduce quality to 50%
      );

      if (result != null) {
        setState(() {
          _selectedImage = File(photo.path);
          _base64Image = base64Encode(result); // Convert to String
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
      // ✅ Send image along with details
      await ApiService.addProduct(
        _idController.text,
        _nameController.text,
        _expiryController.text,
        _base64Image,
      );
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("✅ Added with Image!")));
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
            // 📸 IMAGE PREVIEW BOX
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

            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _idController,
                    decoration: InputDecoration(labelText: "Barcode ID"),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.qr_code_scanner),
                  onPressed: () => setState(() => _isScanning = true),
                ),
              ],
            ),

            TextField(
              controller: _nameController,
              decoration: InputDecoration(labelText: "Product Name"),
            ),

            TextField(
              controller: _expiryController,
              decoration: InputDecoration(
                labelText: "Expiry (YYYY-MM-DD)",
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
                : ElevatedButton(
                    onPressed: _submit,
                    child: Text("Add to Inventory"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      minimumSize: Size(double.infinity, 50),
                      foregroundColor: Colors.white,
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
