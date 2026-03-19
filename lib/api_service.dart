import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  String? baseUrl;
  String? token;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    baseUrl = prefs.getString('server_url');
    token = prefs.getString('auth_token');
  }

  Future<void> logout() async {
    baseUrl = null;
    token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('server_url');
    await prefs.remove('auth_token');
  }

  Future<bool> login(String url, String username, String password) async {
    if (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    if (!url.startsWith('http')) {
      url = 'http://$url';
    }
    try {
      final response = await http.post(
        Uri.parse('$url/api/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username, 'password': password}),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          baseUrl = url;
          token = data['token']?.toString();
          
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('server_url', url);
          if (token != null) {
            await prefs.setString('auth_token', token!);
          }
          return true;
        }
      }
    } catch (e) {
      print('Login error: $e');
    }
    return false;
  }

  Map<String, String> get _headers {
    final headers = {'Content-Type': 'application/json'};
    if (token != null) {
      headers['Authorization'] = 'Bearer $token'; 
    }
    return headers;
  }

  Future<List<dynamic>> getAgents() async {
    if (baseUrl == null) return [];
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/agents'),
        headers: _headers,
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as List<dynamic>;
      }
    } catch (e) {
      print('Get agents error: $e');
    }
    return [];
  }

  Future<String?> sendMessage(String agentId, String message) async {
    if (baseUrl == null) return null;
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/agents/$agentId/chat'),
        headers: _headers,
        body: jsonEncode({'message': message}),
      ).timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['response']; 
      }
    } catch (e) {
      print('Send msg error: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>?> getMetrics() async {
    if (baseUrl == null) return null;
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/metrics'),
        headers: _headers,
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (e) {
      print('Get metrics error: $e');
    }
    return null;
  }

  Future<List<dynamic>> getApps() async {
    if (baseUrl == null) return [];
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/apps'),
        headers: _headers,
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as List<dynamic>;
      }
    } catch (e) {
      print('Get apps error: $e');
    }
    return [];
  }

  Future<Map<String, dynamic>?> getSettings() async {
    if (baseUrl == null) return null;
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/settings'),
        headers: _headers,
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      print('Get settings error: $e');
    }
    return null;
  }

  Future<bool> updateSettings(Map<String, dynamic> settings) async {
    if (baseUrl == null) return false;
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/settings'),
        headers: _headers,
        body: jsonEncode(settings),
      ).timeout(const Duration(seconds: 10));

      return response.statusCode == 200;
    } catch (e) {
      print('Update settings error: $e');
      return false;
    }
  }
}
