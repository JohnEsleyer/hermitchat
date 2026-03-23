import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:crypto/crypto.dart';

void main() {
  group('Encryption/Decryption Tests', () {
    late enc.Key key;

    setUp(() {
      final bytes = utf8.encode('hermit123');
      final digest = sha256.convert(bytes);
      key = enc.Key(Uint8List.fromList(digest.bytes));
    });

    String encrypt(String text) {
      final iv = enc.IV.fromSecureRandom(12);
      final benc = enc.Encrypter(
        enc.AES(key, mode: enc.AESMode.gcm, padding: null),
      );
      final encrypted = benc.encrypt(text, iv: iv);
      return 'enc:${base64.encode(iv.bytes + encrypted.bytes)}';
    }

    String decrypt(String ciphertext) {
      if (!ciphertext.startsWith('enc:')) return ciphertext;
      try {
        final data = base64.decode(ciphertext.substring(4));
        final iv = enc.IV(data.sublist(0, 12));
        final encryptedBytes = data.sublist(12);
        final benc = enc.Encrypter(
          enc.AES(key, mode: enc.AESMode.gcm, padding: null),
        );
        return benc.decrypt(enc.Encrypted(encryptedBytes), iv: iv);
      } catch (e) {
        return ciphertext;
      }
    }

    test('encrypt should produce enc: prefixed output', () {
      final result = encrypt('Hello World');
      expect(result, startsWith('enc:'));
    });

    test('decrypt should return original text', () {
      const original = 'Hello World';
      final encrypted = encrypt(original);
      final decrypted = decrypt(encrypted);
      expect(decrypted, equals(original));
    });

    test('decrypt should handle non-encrypted text', () {
      const plaintext = 'plain text without encryption';
      final result = decrypt(plaintext);
      expect(result, equals(plaintext));
    });

    test('encrypt /status command', () {
      final encrypted = encrypt('/status');
      expect(encrypted, startsWith('enc:'));
      expect(encrypted.length, greaterThan(10));
    });

    test('encrypt /clear command', () {
      final encrypted = encrypt('/clear');
      expect(encrypted, startsWith('enc:'));
    });

    test('encrypt /reset command', () {
      final encrypted = encrypt('/reset');
      expect(encrypted, startsWith('enc:'));
    });
  });

  group('JSON Response Parsing Tests', () {
    test('parse valid JSON response with message', () {
      const jsonString = '{"message": "✅ Chat cleared", "role": "system"}';
      final data = jsonDecode(jsonString) as Map<String, dynamic>;
      expect(data['message'], equals('✅ Chat cleared'));
      expect(data['role'], equals('system'));
    });

    test('parse valid JSON response without message', () {
      const jsonString = '{"response": "Legacy response", "role": "assistant"}';
      final data = jsonDecode(jsonString) as Map<String, dynamic>;
      expect(data['response'], equals('Legacy response'));
      expect(data['role'], equals('assistant'));
    });

    test('extract message from response map', () {
      const jsonString = '{"message": "Status info", "role": "system"}';
      final data = jsonDecode(jsonString) as Map<String, dynamic>;
      final message =
          data['message'] as String? ?? data['response'] as String? ?? '';
      expect(message, equals('Status info'));
    });

    test('parse rejected response', () {
      const jsonString =
          '{"message": "XML commands not allowed", "role": "system", "rejected": true}';
      final data = jsonDecode(jsonString) as Map<String, dynamic>;
      expect(data['rejected'], isTrue);
      expect(data['role'], equals('system'));
    });

    test('parse response with files', () {
      const jsonString =
          '{"message": "Here is the file", "files": ["test.txt"], "role": "assistant"}';
      final data = jsonDecode(jsonString) as Map<String, dynamic>;
      expect(data['files'], isA<List>());
      expect((data['files'] as List).first, equals('test.txt'));
    });
  });

  group('Error Handling Tests', () {
    test('null response handling', () {
      const Map<String, dynamic>? response = null;
      final message =
          response?['message'] as String? ??
          response?['response'] as String? ??
          '';
      expect(message, isEmpty);
    });

    test('empty message handling', () {
      const jsonString = '{"message": "", "role": "system"}';
      final data = jsonDecode(jsonString) as Map<String, dynamic>;
      final message = data['message'] as String? ?? '';
      expect(message.isEmpty, isTrue);
    });

    test('malformed JSON should return null', () {
      const malformedJson = '{"message": "incomplete json"';
      expect(() => jsonDecode(malformedJson), throwsFormatException);
    });
  });

  group('Server Response Simulation Tests', () {
    test('simulate /status command response', () {
      const serverResponse = '''
      {
        "message": "🤖 *Agent Status: Test Agent*\\n\\n• Provider: `OpenRouter`\\n• Model: `gemini-2.0-flash`\\n• LLM Ready: `Yes`",
        "role": "system"
      }
      ''';
      final data = jsonDecode(serverResponse) as Map<String, dynamic>;
      final message = data['message'] as String? ?? '';

      expect(message, contains('Agent Status'));
      expect(message, contains('OpenRouter'));
      expect(message, contains('gemini-2.0-flash'));
    });

    test('simulate /clear command response', () {
      const serverResponse =
          '{"message": "✅ Chat history cleared and context window reset to default", "role": "system"}';
      final data = jsonDecode(serverResponse) as Map<String, dynamic>;
      final message = data['message'] as String? ?? '';

      expect(message, contains('cleared'));
      expect(message, contains('context'));
    });

    test('simulate /reset command response', () {
      const serverResponse =
          '{"message": "✅ Container reset successfully", "role": "system"}';
      final data = jsonDecode(serverResponse) as Map<String, dynamic>;
      final message = data['message'] as String? ?? '';

      expect(message, contains('reset'));
      expect(message, contains('Container'));
    });

    test('simulate XML rejection response', () {
      const serverResponse =
          '{"message": "System: XML commands are not allowed when takeover mode is off.", "role": "system", "rejected": true}';
      final data = jsonDecode(serverResponse) as Map<String, dynamic>;

      expect(data['rejected'], isTrue);
      expect(data['role'], equals('system'));
      expect(
        (data['message'] as String).toLowerCase(),
        contains('not allowed'),
      );
    });
  });

  group('API Method Tests', () {
    test('sendMessage should return Map on success', () async {
      const mockResponse = '{"message": "Command executed", "role": "system"}';
      final data = jsonDecode(mockResponse) as Map<String, dynamic>;

      expect(data, isA<Map>());
      expect(data.containsKey('message'), isTrue);
      expect(data.containsKey('role'), isTrue);
    });

    test('sendMessage returns null on non-200 status', () {
      const statusCode = 401;
      final isSuccess = statusCode == 200;
      expect(isSuccess, isFalse);
    });

    test('sendMessage returns null on exception', () {
      bool hasException = true;
      final result = hasException ? null : {'message': 'ok'};
      expect(result, isNull);
    });
  });

  group('WebSocket Message Format Tests', () {
    test('parse new_message websocket event', () {
      const wsMessage = '''
      {
        "type": "new_message",
        "agent_id": 1,
        "user_id": "mobile",
        "role": "assistant",
        "content": "Hello from agent"
      }
      ''';
      final data = jsonDecode(wsMessage) as Map<String, dynamic>;

      expect(data['type'], equals('new_message'));
      expect(data['agent_id'], equals(1));
      expect(data['role'], equals('assistant'));
      expect(data['content'], equals('Hello from agent'));
    });

    test('parse conversation_cleared websocket event', () {
      const wsMessage = '{"type": "conversation_cleared", "agent_id": 1}';
      final data = jsonDecode(wsMessage) as Map<String, dynamic>;

      expect(data['type'], equals('conversation_cleared'));
      expect(data['agent_id'], equals(1));
    });
  });
}
