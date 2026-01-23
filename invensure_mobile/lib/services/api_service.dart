import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static String baseUrl = "https://invensure-xv6j.onrender.com";

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  // REGISTER (No role param anymore)
  static Future<Map<String, dynamic>> register(
    String name,
    String email,
    String password,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/register'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"name": name, "email": email, "password": password}),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {"success": false, "message": "Error: $e"};
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
      return jsonDecode(response.body);
    } catch (e) {
      return {"success": false, "message": "Error: $e"};
    }
  }

  // FETCH PENDING STAFF (For Admin Dashboard)
  static Future<List<dynamic>> getPendingUsers() async {
    final token = await getToken();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/admin/pending'),
        headers: {"Authorization": "Bearer $token"},
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body)['users'];
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // APPROVE STAFF
  static Future<bool> approveUser(String userId) async {
    final token = await getToken();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/admin/approve'),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode({"userId": userId}),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // ... keep getProducts, addProduct, recycleProduct same as before ...
  // (Paste them here from previous file)

  static Future<List<dynamic>> getProducts() async {
    final token = await getToken();
    if (token == null) throw Exception("User not logged in");
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/allProducts'),
        headers: {"Authorization": "Bearer $token"},
      );
      if (response.statusCode == 200)
        return jsonDecode(response.body)['products'];
      else
        throw Exception('Failed load');
    } catch (e) {
      throw Exception('Connection Error');
    }
  }

  static Future<void> addProduct(
    String id,
    String name,
    String expiry,
    String? img,
  ) async {
    final token = await getToken();
    int? numericId = int.tryParse(id);
    if (numericId == null) throw Exception("ID must be number");
    await http.post(
      Uri.parse('$baseUrl/addProduct'),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode({
        "id": numericId,
        "name": name,
        "expiry": expiry,
        "image": img ?? "",
      }),
    );
  }

  static Future<void> recycleProduct(int id) async {
    final token = await getToken();
    await http.post(
      Uri.parse('$baseUrl/recycleProduct/$id'),
      headers: {"Authorization": "Bearer $token"},
    );
  }
}
