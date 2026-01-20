import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  //  Your Ngrok URL (Correctly set)
  static String baseUrl = "https://hardened-wallace-mimickingly.ngrok-free.dev";

  // Helper to get token from storage
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  // 1. LOGIN
  static Future<Map<String, dynamic>> login(
    String email,
    String password,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": email, "password": password}),
      );

      print("Login Status: ${response.statusCode}");
      print("Login Body: ${response.body}");

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        // Return the error message from backend
        return jsonDecode(response.body);
      }
    } catch (e) {
      return {"success": false, "message": "Connection error: $e"};
    }
  }

  // 2. GET ALL PRODUCTS
  static Future<List<dynamic>> getProducts() async {
    final token = await getToken();

    if (token == null) {
      throw Exception("User not logged in");
    }

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/allProducts'),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body)['products'];
      } else {
        throw Exception('Failed to load products: ${response.body}');
      }
    } catch (e) {
      throw Exception('Connection Error: $e');
    }
  }

  // 3. ADD PRODUCT (Scanner Logic)
  static Future<void> addProduct(String id, String name, String expiry) async {
    final token = await getToken();

    // SAFETY CHECK: Ensure ID is a valid number before sending
    // If scanner picks up "Milk", int.parse crashes. This prevents that.
    int? numericId = int.tryParse(id);
    if (numericId == null) {
      throw Exception("Invalid ID: Barcode must be numeric numbers only.");
    }

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/addProduct'),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode({"id": numericId, "name": name, "expiry": expiry}),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to add product: ${response.body}');
      }
    } catch (e) {
      print("Add Product Error: $e");
      rethrow;
    }
  }

  // 4. RECYCLE PRODUCT (Admin Only)
  static Future<void> recycleProduct(int id) async {
    final token = await getToken();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/recycleProduct/$id'),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to recycle product');
      }
    } catch (e) {
      print("Recycle Error: $e");
      rethrow;
    }
  }
}
