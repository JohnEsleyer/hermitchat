import 'dart:convert';
import 'dart:async';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:image_picker/image_picker.dart'; // XFile
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
  bool _shouldReconnect = false;
  final _messageController = StreamController<Map<String, dynamic>>.broadcast();
  final _healthController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;
  Stream<Map<String, dynamic>> get healthStream => _healthController.stream;

  enc.Key _deriveKey(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return enc.Key(Uint8List.fromList(digest.bytes));
  }

  String _encrypt(String text) {
    try {
      final key = _deriveKey("hermit123");
      final iv = enc.IV.fromSecureRandom(16);
      final benc = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
      final encrypted = benc.encrypt(text, iv: iv);
      return "cbc:${base64.encode(iv.bytes + encrypted.bytes)}";
    } catch (e) {
      return text;
    }
  }

  String _decrypt(String ciphertext) {
    try {
      final key = _deriveKey("hermit123");

      if (ciphertext.startsWith("cbc:")) {
        final data = base64.decode(ciphertext.substring(4));
        final iv = enc.IV(Uint8List.fromList(data.sublist(0, 16)));
        final encryptedBytes = Uint8List.fromList(data.sublist(16));
        final benc = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
        return benc.decrypt(enc.Encrypted(encryptedBytes), iv: iv);
      } else if (ciphertext.startsWith("enc:")) {
        // Old GCM format - just return as-is, server will handle
        return ciphertext;
      }
    } catch (e) {
      // Log error
    }
    return ciphertext;
  }

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    baseUrl = prefs.getString('server_url');
    token = prefs.getString('auth_token');
    if (baseUrl != null) {
      _shouldReconnect = true;
      _connectWebSocket();
    }
  }

  void _connectWebSocket() {
    if (baseUrl == null) return;
    _channel?.sink.close();
    final wsUrl = '${baseUrl!.replaceFirst('http', 'ws')}/api/ws';
    _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
    _channel!.stream.listen(
      (message) {
        try {
          final data = jsonDecode(message);
          if (data['type'] == 'system_health') {
            _healthController.add(data['health'] as Map<String, dynamic>);
          } else if (data['type'] == 'new_message') {
            // Decrypt content if it's encrypted
            if (data['content'] != null) {
              data['content'] = _decrypt(data['content']);
            }
            _messageController.add(data);
          } else {
            _messageController.add(data);
          }
        } catch (e) {
          // log error
        }
      },
      onDone: () {
        _channel = null;
        if (_shouldReconnect && baseUrl != null) {
          Future.delayed(const Duration(seconds: 5), () {
            if (_shouldReconnect && _channel == null && baseUrl != null) {
              _connectWebSocket();
            }
          });
        }
      },
    );
  }

  Future<void> logout() async {
    _shouldReconnect = false;
    await _channel?.sink.close();
    _channel = null;
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
      final response = await http
          .post(
            Uri.parse('$url/api/auth/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'username': username, 'password': password}),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          _shouldReconnect = false;
          await _channel?.sink.close();
          _channel = null;
          baseUrl = url;
          token = data['token']?.toString();

          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('server_url', url);
          if (token != null) {
            await prefs.setString('auth_token', token!);
          }
          _shouldReconnect = true;
          _connectWebSocket();
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
      final response = await http
          .get(Uri.parse('$baseUrl/api/agents'), headers: _headers)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        return decoded != null ? (decoded as List<dynamic>) : [];
      }
    } catch (e) {
      // log error
    }
    return [];
  }

  Future<Map<String, dynamic>?> sendMessage(
    String agentId,
    String message,
  ) async {
    if (baseUrl == null) return null;
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/agents/$agentId/chat'),
            headers: _headers,
            body: jsonEncode({'message': _encrypt(message)}),
          )
          .timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['response'] != null) {
          data['response'] = _decrypt(data['response']);
        }
        if (data['message'] != null) {
          data['message'] = _decrypt(data['message']);
        }
        return data;
      } else {
        // Return error info so the client can display meaningful messages
        final body = jsonDecode(response.body);
        if (body is Map && body['error'] != null) {
          return {'error': body['error'], 'statusCode': response.statusCode};
        }
      }
    } catch (e) {
      // Log error for debugging
      debugPrint('sendMessage error: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>?> getMetrics() async {
    if (baseUrl == null) return null;
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/api/metrics'), headers: _headers)
          .timeout(const Duration(seconds: 10));

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
      final response = await http
          .get(Uri.parse('$baseUrl/api/apps'), headers: _headers)
          .timeout(const Duration(seconds: 10));

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
      final response = await http
          .get(Uri.parse('$baseUrl/api/settings'), headers: _headers)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      // log error
    }
    return null;
  }

  Future<Map<String, dynamic>?> getServerTime() async {
    if (baseUrl == null) return null;
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/api/time'), headers: _headers)
          .timeout(const Duration(seconds: 5));

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
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/settings'),
            headers: _headers,
            body: jsonEncode(settings),
          )
          .timeout(const Duration(seconds: 10));

      return response.statusCode == 200;
    } catch (e) {
      // log error
      return false;
    }
  }

  Future<List<dynamic>> getCalendarEvents() async {
    if (baseUrl == null) return [];
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/api/calendar'), headers: _headers)
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        return decoded != null ? (decoded as List<dynamic>) : [];
      }
    } catch (e) {
      // log error
    }
    return [];
  }

  Future<bool> updateAgent(String id, Map<String, dynamic> agentData) async {
    if (baseUrl == null) return false;
    try {
      final response = await http
          .put(
            Uri.parse('$baseUrl/api/agents/$id'),
            headers: _headers,
            body: jsonEncode(agentData),
          )
          .timeout(const Duration(seconds: 30));

      return response.statusCode == 200;
    } catch (e) {
      // log error
      return false;
    }
  }

  Future<String?> uploadImage(XFile file) async {
    if (baseUrl == null) return null;
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/api/images/upload'),
      );
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      if (kIsWeb) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'file',
            await file.readAsBytes(),
            filename: file.name,
          ),
        );
      } else {
        request.files.add(await http.MultipartFile.fromPath('file', file.path));
      }

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['url'] as String?;
      }
    } catch (e) {
      // log error
    }
    return null;
  }

  Future<bool> uploadFileToContainer(String containerId, XFile file) async {
    if (baseUrl == null) return false;
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/api/containers/$containerId/upload'),
      );
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      if (kIsWeb) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'file',
            await file.readAsBytes(),
            filename: file.name,
          ),
        );
      } else {
        request.files.add(await http.MultipartFile.fromPath('file', file.path));
      }

      var streamedResponse = await request.send();
      return streamedResponse.statusCode == 200;
    } catch (e) {
      // log error
    }
    return false;
  }

  Future<bool> createCalendarEvent(
    int agentId,
    String date,
    String time,
    String prompt,
  ) async {
    if (baseUrl == null) return false;
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/calendar'),
            headers: _headers,
            body: jsonEncode({
              'agentId': agentId,
              'date': date,
              'time': time,
              'prompt': prompt,
            }),
          )
          .timeout(const Duration(seconds: 10));
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      // log error
    }
    return false;
  }

  Future<bool> deleteCalendarEvent(int id) async {
    if (baseUrl == null) return false;
    try {
      final response = await http
          .delete(Uri.parse('$baseUrl/api/calendar/$id'), headers: _headers)
          .timeout(const Duration(seconds: 10));
      return response.statusCode == 200;
    } catch (e) {
      // log error
    }
    return false;
  }

  Future<Map<String, dynamic>?> createAgent(
    Map<String, dynamic> agentData,
  ) async {
    if (baseUrl == null) return null;
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/agents'),
            headers: _headers,
            body: jsonEncode(agentData),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (e) {
      // log error
    }
    return null;
  }

  Future<bool> deleteAgent(String id) async {
    if (baseUrl == null) return false;
    try {
      final response = await http
          .delete(Uri.parse('$baseUrl/api/agents/$id'), headers: _headers)
          .timeout(const Duration(seconds: 30));
      return response.statusCode == 200;
    } catch (e) {
      // log error
    }
    return false;
  }

  Future<bool> resetContainer(String containerId) async {
    if (baseUrl == null) return false;
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/containers/$containerId'),
            headers: _headers,
            body: jsonEncode({'action': 'reset'}),
          )
          .timeout(const Duration(seconds: 30));
      return response.statusCode == 200;
    } catch (e) {
      // log error
    }
    return false;
  }

  Future<Map<String, dynamic>?> getAgentStats(String agentId) async {
    if (baseUrl == null) return null;
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/api/agents/$agentId/stats'),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (e) {
      // log error
    }
    return null;
  }

  Future<Map<String, dynamic>?> getAgentContextWindow(String agentId) async {
    if (baseUrl == null) return null;
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/api/agents/$agentId/context'),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (e) {
      // log error
    }
    return null;
  }

  Future<int> getUnreadCount(String agentId) async {
    if (baseUrl == null) return 0;
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/api/agents/$agentId/unread'),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['unread'] as int? ?? 0;
      }
    } catch (e) {
      // log error
    }
    return 0;
  }

  Future<String?> getLastMessage(String agentId) async {
    if (baseUrl == null) return null;
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/api/agents/$agentId/last-message'),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['content'] as String?;
      }
    } catch (e) {
      // log error
    }
    return null;
  }

  Future<bool> markMessagesSeen(String agentId) async {
    if (baseUrl == null) return false;
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/agents/$agentId/mark-seen'),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 5));

      return response.statusCode == 200;
    } catch (e) {
      // log error
    }
    return false;
  }

  Future<bool> checkServerConnection() async {
    if (baseUrl == null) return false;
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/api/time'), headers: _headers)
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      // log error
    }
    return false;
  }

  Future<Map<String, dynamic>?> getLocalSettings() async {
    if (baseUrl == null) return null;
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/api/settings'), headers: _headers)
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (e) {
      // log error
    }
    return null;
  }

  bool get hasApiKey {
    // Check if any API key is configured
    return _headers.containsKey('Authorization') && token != null;
  }
}
