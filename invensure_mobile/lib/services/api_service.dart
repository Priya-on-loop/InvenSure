import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static String baseUrl = "https://invensure-xv6j.onrender.com";

  // Get token from storage
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  // REGISTER
  static Future<Map<String, dynamic>> register(
    String name,
    String email,
    String password,
    String role,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/register'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "name": name,
          "email": email,
          "password": password,
          "role": role,
        }),
      );

      print("Register Response: ${response.body}");
      return jsonDecode(response.body);
    } catch (e) {
      return {"success": false, "message": "Connection error: $e"};
    }
  }

  // LOGIN
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
      return jsonDecode(response.body);
    } catch (e) {
      return {"success": false, "message": "Connection error: $e"};
    }
  }

  // GET ALL PRODUCTS
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

  // ADD PRODUCT
  // ✅ UPDATED: Accept imageBase64 string
  static Future<void> addProduct(
    String id,
    String name,
    String expiry,
    String? imageBase64,
  ) async {
    final token = await getToken();

    int? numericId = int.tryParse(id);
    if (numericId == null) throw Exception("Invalid ID");

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/addProduct'),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode({
          "id": numericId,
          "name": name,
          "expiry": expiry,
          "image": imageBase64 ?? "", // ✅ Send the image string
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to add product: ${response.body}');
      }
    } catch (e) {
      rethrow;
    }
  }

  // RECYCLE PRODUCT
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
        throw Exception('Failed to recycle');
      }
    } catch (e) {
      print("Recycle Error: $e");
      rethrow;
    }
  }
}
