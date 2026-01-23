import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // ✅ Ensure this is your active Cloud/Ngrok URL
  static String baseUrl = "https://invensure-xv6j.onrender.com";

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  // 1. REGISTER (Updated to accept 'role')
  static Future<Map<String, dynamic>> register(
    String name,
    String email,
    String password,
    String role, // ✅ NEW: Allows registering as 'staff' or 'recycler'
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

  // 2. LOGIN (Email OR Name)
  static Future<Map<String, dynamic>> login(
    String input,
    String password,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "email": input, // Send input (email/name) to backend check
          "password": password,
        }),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {"success": false, "message": "Connection error"};
    }
  }

  // --- ADMIN USER MANAGEMENT ---

  // 3. GET USERS (pending/active)
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

  // --- RECYCLER WORKFLOW (✅ NEW ADDITIONS) ---

  // 6. GET RECYCLERS LIST (For Admin to select who does the job)
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

  // 7. ASSIGN RECYCLE TASK (Admin)
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

  // 8. GET ASSIGNED TASKS (For Recycler View)
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

  // 9. COMPLETE RECYCLE (Recycler finishes job -> Blockchain)
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

  // Keep for backup/direct delete, though AssignTask is preferred now
  static Future<void> recycleProduct(int id) async {
    final token = await getToken();
    await http.post(
      Uri.parse('$baseUrl/recycleProduct/$id'),
      headers: {"Authorization": "Bearer $token"},
    );
  }
}
