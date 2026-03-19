import 'dart:convert';
import 'dart:async';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:crypto/crypto.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  String? baseUrl;
  String? token;
  WebSocketChannel? _channel;
  final _messageController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;

  enc.Key _deriveKey(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return enc.Key(Uint8List.fromList(digest.bytes));
  }

  String _encrypt(String text) {
    try {
      final key = _deriveKey("hermit123");
      final iv = enc.IV.fromSecureRandom(12); // GCM typical nonce size
      final benc = enc.Encrypter(enc.AES(key, mode: enc.AESMode.gcm, padding: null));
      final encrypted = benc.encrypt(text, iv: iv);
      // Combine IV + Ciphertext for the server
      return "enc:${base64.encode(iv.bytes + encrypted.bytes)}";
    } catch (e) {
      // log error
      return text;
    }
  }

  String _decrypt(String ciphertext) {
    if (!ciphertext.startsWith("enc:")) return ciphertext;
    try {
      final key = _deriveKey("hermit123");
      final data = base64.decode(ciphertext.substring(4));
      final iv = enc.IV(data.sublist(0, 12));
      final encryptedBytes = data.sublist(12);
      final benc = enc.Encrypter(enc.AES(key, mode: enc.AESMode.gcm, padding: null));
      return benc.decrypt(enc.Encrypted(encryptedBytes), iv: iv);
    } catch (e) {
      // log error
      return ciphertext;
    }
  }

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    baseUrl = prefs.getString('server_url');
    token = prefs.getString('auth_token');
    if (baseUrl != null) {
      _connectWebSocket();
    }
  }

  void _connectWebSocket() {
    if (baseUrl == null) return;
    final wsUrl = baseUrl!.replaceFirst('http', 'ws') + '/api/ws';
    _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
    _channel!.stream.listen((message) {
      try {
        final data = jsonDecode(message);
        if (data['type'] == 'new_message') {
           // Decrypt content if it's encrypted
           if (data['content'] != null) {
             data['content'] = _decrypt(data['content']);
           }
        }
        _messageController.add(data);
      } catch (e) {
        // log error
      }
    }, onDone: () {
      Future.delayed(const Duration(seconds: 5), _connectWebSocket);
    });
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
      // log error
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
        final decoded = jsonDecode(response.body);
        return decoded != null ? (decoded as List<dynamic>) : [];
      }
    } catch (e) {
      // log error
    }
    return [];
  }

  Future<Map<String, dynamic>?> sendMessage(String agentId, String message) async {
    if (baseUrl == null) return null;
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/agents/$agentId/chat'),
        headers: _headers,
        body: jsonEncode({'message': _encrypt(message)}),
      ).timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['response'] != null) {
          data['response'] = _decrypt(data['response']);
        }
        if (data['message'] != null) {
          data['message'] = _decrypt(data['message']);
        }
        return data;
      }
    } catch (e) {
      // log error
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
      // log error
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
      // log error
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
      // log error
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
      // log error
      return false;
    }
  }

  Future<List<dynamic>> getCalendarEvents() async {
    if (baseUrl == null) return [];
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/calendar'), headers: _headers).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        return decoded != null ? (decoded as List<dynamic>) : [];
      }
    } catch (e) {
      // log error
    }
    return [];
  }

  Future<bool> createCalendarEvent(int agentId, String date, String time, String prompt) async {
    if (baseUrl == null) return false;
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/calendar'),
        headers: _headers,
        body: jsonEncode({
          'agentId': agentId,
          'date': date,
          'time': time,
          'prompt': prompt,
        }),
      ).timeout(const Duration(seconds: 10));
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      // log error
    }
    return false;
  }

  Future<bool> deleteCalendarEvent(int id) async {
    if (baseUrl == null) return false;
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/api/calendar/$id'),
        headers: _headers,
      ).timeout(const Duration(seconds: 10));
      return response.statusCode == 200;
    } catch (e) {
      // log error
    }
    return false;
  }
}
