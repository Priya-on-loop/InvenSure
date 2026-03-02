import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // ✅ Ensure this is your active Cloud Render URL
  static String baseUrl = "https://invensure-xv6j.onrender.com";

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  // 1. REGISTER
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
      return jsonDecode(response.body);
    } catch (e) {
      return {"success": false, "message": "Connection error"};
    }
  }

  // 2. LOGIN
  static Future<Map<String, dynamic>> login(
    String input,
    String password,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": input, "password": password}),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {"success": false, "message": "Connection error"};
    }
  }

  // --- ADMIN USER MANAGEMENT ---

  // 3. GET USERS
  static Future<List<dynamic>> getUsers(String type) async {
    final token = await getToken();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/admin/users?type=$type'),
        headers: {"Authorization": "Bearer $token"},
      );
      if (response.statusCode == 200) return jsonDecode(response.body)['users'];
      return [];
    } catch (e) {
      return [];
    }
  }

  // 4. APPROVE USER
  static Future<bool> approveUser(String userId) async {
    final token = await getToken();
    final res = await http.post(
      Uri.parse('$baseUrl/admin/approve'),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode({"userId": userId}),
    );
    return res.statusCode == 200;
  }

  // 5. DELETE USER
  static Future<bool> deleteUser(String userId) async {
    final token = await getToken();
    final res = await http.post(
      Uri.parse('$baseUrl/admin/delete'),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode({"userId": userId}),
    );
    return res.statusCode == 200;
  }

  // ✅ 6. ASSIGN SECTION TO STAFF (NEW FEATURE)
  static Future<bool> assignUserSection(String userId, String section) async {
    final token = await getToken();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/admin/assign-section'),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode({"userId": userId, "section": section}),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // --- RECYCLER WORKFLOW ---

  // 7. GET RECYCLERS LIST
  static Future<List<dynamic>> getRecyclersList() async {
    final token = await getToken();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/recyclers/list'),
        headers: {"Authorization": "Bearer $token"},
      );
      if (response.statusCode == 200)
        return jsonDecode(response.body)['recyclers'];
      return [];
    } catch (e) {
      return [];
    }
  }

  // 8. ASSIGN RECYCLE TASK
  static Future<bool> assignTask(int productId, String recyclerMongoId) async {
    final token = await getToken();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/assign-recycle/$productId'),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode({"recyclerId": recyclerMongoId}),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // 9. GET ASSIGNED TASKS
  static Future<List<dynamic>> getRecyclerTasks() async {
    final token = await getToken();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/recycler/tasks'),
        headers: {"Authorization": "Bearer $token"},
      );
      if (response.statusCode == 200) return jsonDecode(response.body)['tasks'];
      return [];
    } catch (e) {
      return [];
    }
  }

  // 10. COMPLETE RECYCLE
  static Future<bool> completeRecycleTask(int productId) async {
    final token = await getToken();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/recycler/complete/$productId'),
        headers: {"Authorization": "Bearer $token"},
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // --- PRODUCT MANAGEMENT ---

  static Future<List<dynamic>> getProducts() async {
    final token = await getToken();
    if (token == null) throw Exception("User not logged in");
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/allProducts'),
        headers: {"Authorization": "Bearer $token"},
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body)['products'];
      } else {
        throw Exception("Failed load");
      }
    } catch (e) {
      throw Exception("Connection Error");
    }
  }

  static Future<void> addProduct(
    String id,
    String name,
    String expiry,
    String category,
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
        "category": category,
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
