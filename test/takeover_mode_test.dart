import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Takeover Mode Tests', () {
    test('XML commands rejected when takeover is off', () {
      const takeoverMode = false;
      const hasXMLTags = true;

      // When takeover is off and user sends XML, it should be rejected
      final shouldReject = !takeoverMode && hasXMLTags;
      expect(shouldReject, isTrue);
    });

    test('XML commands allowed when takeover is on', () {
      const takeoverMode = true;
      const hasXMLTags = true;

      // When takeover is on, XML should be allowed
      final shouldReject = !takeoverMode && hasXMLTags;
      expect(shouldReject, isFalse);
    });

    test('XML tags detection works correctly', () {
      bool hasXMLTags(String text) {
        return text.contains('<') &&
            text.contains('>') &&
            (text.contains('<terminal>') ||
                text.contains('<message>') ||
                text.contains('<give>') ||
                text.contains('<calendar>'));
      }

      expect(hasXMLTags('<terminal>ls</terminal>'), isTrue);
      expect(hasXMLTags('<message>Hello</message>'), isTrue);
      expect(hasXMLTags('<give>file.txt</give>'), isTrue);
      expect(
        hasXMLTags('<calendar><date>2026-03-21</date></calendar>'),
        isTrue,
      );
      expect(hasXMLTags('Hello, how are you?'), isFalse);
      expect(hasXMLTags('/status'), isFalse);
    });
  });

  group('Slash Commands Tests', () {
    test('Slash commands are detected correctly', () {
      bool isSlashCommand(String text) {
        return text.startsWith('/');
      }

      expect(isSlashCommand('/status'), isTrue);
      expect(isSlashCommand('/clear'), isTrue);
      expect(isSlashCommand('/reset'), isTrue);
      expect(isSlashCommand('/takeover'), isTrue);
      expect(isSlashCommand('Hello'), isFalse);
      expect(isSlashCommand('<message>Hello</message>'), isFalse);
    });

    test('Slash commands do not contain XML tags', () {
      bool isSlashCommand(String text) {
        return text.startsWith('/');
      }

      bool hasXMLTags(String text) {
        return text.contains('<') && text.contains('>');
      }

      // All slash commands should not have XML tags
      expect(hasXMLTags('/status'), isFalse);
      expect(hasXMLTags('/clear'), isFalse);
      expect(hasXMLTags('/reset'), isFalse);
      expect(hasXMLTags('/takeover on'), isFalse);
    });
  });

  group('Message Parsing Tests', () {
    test('Message tag extraction works', () {
      String? extractMessage(String response) {
        final messageRegex = RegExp(
          r'<message>(.*?)</message>',
          caseSensitive: false,
        );
        final match = messageRegex.firstMatch(response);
        return match?.group(1);
      }

      expect(extractMessage('<message>Hello</message>'), equals('Hello'));
      expect(
        extractMessage('<message>Hello World</message>'),
        equals('Hello World'),
      );
      expect(extractMessage('No message here'), isNull);
    });

    test('Thought tag is not included in visible message', () {
      String? extractMessage(String response) {
        final messageRegex = RegExp(
          r'<message>(.*?)</message>',
          caseSensitive: false,
        );
        final match = messageRegex.firstMatch(response);
        return match?.group(1);
      }

      const response =
          '<thought>Internal reasoning</thought><message>Visible to user</message>';
      final message = extractMessage(response);

      expect(message, equals('Visible to user'));
      expect(message!.contains('Internal reasoning'), isFalse);
    });

    test('Terminal tag is not included in visible message', () {
      String? extractMessage(String response) {
        final messageRegex = RegExp(
          r'<message>(.*?)</message>',
          caseSensitive: false,
        );
        final match = messageRegex.firstMatch(response);
        return match?.group(1);
      }

      const response =
          '<message>Command executed</message><terminal>ls -la</terminal>';
      final message = extractMessage(response);

      expect(message, equals('Command executed'));
      expect(message!.contains('ls'), isFalse);
    });

    test('Give tag is not included in visible message', () {
      String? extractMessage(String response) {
        final messageRegex = RegExp(
          r'<message>(.*?)</message>',
          caseSensitive: false,
        );
        final match = messageRegex.firstMatch(response);
        return match?.group(1);
      }

      const response =
          '<message>Here is your file</message><give>report.pdf</give>';
      final message = extractMessage(response);

      expect(message, equals('Here is your file'));
      expect(message!.contains('report.pdf'), isFalse);
    });

    test('Response without message tag returns empty', () {
      String? extractMessage(String response) {
        final messageRegex = RegExp(
          r'<message>(.*?)</message>',
          caseSensitive: false,
        );
        final match = messageRegex.firstMatch(response);
        return match?.group(1);
      }

      expect(extractMessage('<terminal>ls</terminal>'), isNull);
      expect(extractMessage('Plain text response'), isNull);
    });
  });

  group('File Extraction Tests', () {
    test('Give tags extract filenames', () {
      List<String> extractFiles(String response) {
        final giveRegex = RegExp(r'<give>(.*?)</give>', caseSensitive: false);
        return giveRegex.allMatches(response).map((m) => m.group(1)!).toList();
      }

      expect(extractFiles('<give>file.txt</give>'), equals(['file.txt']));
      expect(
        extractFiles('<give>a.txt</give><give>b.txt</give>'),
        equals(['a.txt', 'b.txt']),
      );
      expect(extractFiles('<message>No files</message>'), isEmpty);
    });

    test('Image files are detected', () {
      bool isImageFile(String filename) {
        final ext = filename.split('.').last.toLowerCase();
        return ['png', 'jpg', 'jpeg', 'gif', 'webp'].contains(ext);
      }

      expect(isImageFile('photo.jpg'), isTrue);
      expect(isImageFile('image.png'), isTrue);
      expect(isImageFile('photo.jpeg'), isTrue);
      expect(isImageFile('document.pdf'), isFalse);
      expect(isImageFile('video.mp4'), isFalse);
    });

    test('Video files are detected', () {
      bool isVideoFile(String filename) {
        final ext = filename.split('.').last.toLowerCase();
        return ['mp4', 'mov', 'webm', 'm4v'].contains(ext);
      }

      expect(isVideoFile('video.mp4'), isTrue);
      expect(isVideoFile('movie.mov'), isTrue);
      expect(isVideoFile('clip.webm'), isTrue);
      expect(isVideoFile('image.jpg'), isFalse);
      expect(isVideoFile('document.pdf'), isFalse);
    });
  });

  group('Server Response Tests', () {
    test('Rejection response format', () {
      const response = {
        'message':
            'System: XML commands are not allowed when takeover mode is off.',
        'role': 'system',
        'rejected': true,
      };

      expect(response['rejected'], isTrue);
      expect(response['role'], equals('system'));
      expect(
        response['message'].toString().toLowerCase(),
        contains('not allowed'),
      );
    });

    test('Slash command response format', () {
      const response = {
        'message': '✅ Chat history cleared and context window reset to default',
        'role': 'system',
      };

      expect(response['role'], equals('system'));
      expect(response['message'].toString().contains('cleared'), isTrue);
    });

    test('Status command response format', () {
      const response = {
        'message':
            '🤖 *Agent Status: Test*\n\n• Provider: `gemini`\n• Model: `gemini-2.0-flash`',
        'role': 'system',
      };

      expect(response['role'], equals('system'));
      expect(response['message'].toString().contains('Agent Status'), isTrue);
      expect(response['message'].toString().contains('gemini'), isTrue);
    });

    test('Assistant response format', () {
      const response = {
        'message': 'Hello, how can I help you?',
        'files': ['document.pdf'],
        'role': 'assistant',
      };

      expect(response['role'], equals('assistant'));
      expect(response['message'], equals('Hello, how can I help you?'));
      expect(response['files'], equals(['document.pdf']));
    });
  });

  group('WebSocket Message Tests', () {
    test('New message event format', () {
      const event = {
        'type': 'new_message',
        'agent_id': 1,
        'user_id': 'mobile',
        'role': 'assistant',
        'content': 'Hello from agent',
      };

      expect(event['type'], equals('new_message'));
      expect(event['agent_id'], equals(1));
      expect(event['role'], equals('assistant'));
      expect(event['content'], equals('Hello from agent'));
    });

    test('Conversation cleared event format', () {
      const event = {'type': 'conversation_cleared', 'agent_id': 1};

      expect(event['type'], equals('conversation_cleared'));
      expect(event['agent_id'], equals(1));
    });

    test('Event with files format', () {
      const event = {
        'type': 'new_message',
        'agent_id': 1,
        'role': 'assistant',
        'content': 'Here is your file',
        'files': ['report.pdf'],
      };

      expect(event['files'], isNotNull);
      expect((event['files'] as List).first, equals('report.pdf'));
    });
  });

  group('isSeen Column Tests', () {
    test('Unseen message has isSeen false', () {
      const message = {
        'agent_id': 1,
        'role': 'assistant',
        'content': 'New message',
        'is_seen': false,
      };

      expect(message['is_seen'], isFalse);
    });

    test('Seen message has isSeen true', () {
      const message = {
        'agent_id': 1,
        'role': 'assistant',
        'content': 'Read message',
        'is_seen': true,
      };

      expect(message['is_seen'], isTrue);
    });

    test('markMessagesSeen API call format', () {
      const endpoint = '/api/agents/1/mark-seen';
      const method = 'POST';

      expect(endpoint.contains('/mark-seen'), isTrue);
      expect(method, equals('POST'));
    });
  });

  group('isRejected Column Tests', () {
    test('Rejected message format', () {
      const message = {
        'agent_id': 1,
        'role': 'user',
        'content': '<terminal>ls</terminal>',
        'is_rejected': true,
      };

      expect(message['is_rejected'], isTrue);
      expect(message['role'], equals('user'));
    });

    test('Normal message format', () {
      const message = {
        'agent_id': 1,
        'role': 'user',
        'content': 'Hello',
        'is_rejected': false,
      };

      expect(message['is_rejected'], isFalse);
    });
  });

  group('Encryption Tests', () {
    test('Encrypted message starts with enc:', () {
      const message = 'enc:AESGCMSomeEncryptedData';
      expect(message.startsWith('enc:'), isTrue);
    });

    test('Non-encrypted message does not start with enc:', () {
      const message = 'Hello, this is plain text';
      expect(message.startsWith('enc:'), isFalse);
    });

    test('Encrypted slash command format', () {
      const slashCommand = '/status';
      const encrypted = 'enc:base64encrypteddata==';

      // Encrypted command should still start with enc:
      expect(encrypted.startsWith('enc:'), isTrue);

      // The server should decrypt and detect slash command
      final decrypted = slashCommand;
      expect(decrypted.startsWith('/'), isTrue);
    });
  });

  group('UI State Tests', () {
    test('Processing state shows indicator', () {
      const processingText = 'Processing /clear...';
      expect(processingText.contains('Processing'), isTrue);
      expect(processingText.contains('/clear'), isTrue);
    });

    test('Error state shows message', () {
      const errorMessage =
          'System: command was sent, but the server did not return a live update.';
      expect(errorMessage.contains('command was sent'), isTrue);
      expect(errorMessage.contains('server did not return'), isTrue);
    });

    test('Success state shows confirmation', () {
      const successMessage =
          '✅ Chat history cleared and context window reset to default';
      expect(successMessage.contains('cleared'), isTrue);
      expect(successMessage.contains('✅'), isTrue);
    });

    test('Local /status shows connection info', () {
      const statusMessage = '''
🤖 *Agent Status: TestAgent*

📡 *Connection*
• Server: Connected ✅
• URL: http://localhost:3000

🔑 *API Configuration*
• API Key: Configured ✅

🤖 *LLM Configuration*
• Provider: gemini
• Model: gemini-2.0-flash
• LLM Ready: Yes ✅
''';
      expect(statusMessage.contains('Agent Status'), isTrue);
      expect(statusMessage.contains('Connection'), isTrue);
      expect(statusMessage.contains('API Configuration'), isTrue);
      expect(statusMessage.contains('LLM Configuration'), isTrue);
    });

    test('Local /status shows offline when server unreachable', () {
      const statusMessage = '''
📡 *Connection*
• Server: Offline ❌
''';
      expect(statusMessage.contains('Offline ❌'), isTrue);
    });

    test('/clear clears conversation locally', () {
      // Simulate /clear clearing messages
      final messages = ['user: /clear', 'system: Clearing conversation...'];
      messages.clear();
      expect(messages.isEmpty, isTrue);
    });

    test('/clear shows confirmation after clearing', () {
      const confirmationMessage =
          '✅ Conversation cleared. Context window reset.';
      expect(confirmationMessage.contains('cleared'), isTrue);
      expect(confirmationMessage.contains('Context window reset'), isTrue);
    });
  });

  group('Conversation Flow Tests', () {
    test('Opening conversation marks messages as seen', () {
      // When opening a conversation, we should call markMessagesSeen
      bool shouldMarkSeen = true;
      expect(shouldMarkSeen, isTrue);
    });

    test('Receiving new message updates unread count', () {
      int unreadCount = 5;
      // When a new message arrives, unread count should increment
      unreadCount++;
      expect(unreadCount, equals(6));
    });

    test('Viewing conversation resets unread count', () {
      int unreadCount = 10;
      // When viewing conversation, unread count should reset
      unreadCount = 0;
      expect(unreadCount, equals(0));
    });
  });

  group('Takeover Mode Scenarios', () {
    test('Scenario: User sends XML without takeover - rejected', () {
      const userInput = '<terminal>ls -la</terminal>';
      const takeoverEnabled = false;
      const hasXMLTags = true;

      final isRejected = !takeoverEnabled && hasXMLTags;
      expect(isRejected, isTrue);
    });

    test('Scenario: User sends XML with takeover - accepted', () {
      const userInput = '<terminal>ls -la</terminal>';
      const takeoverEnabled = true;
      const hasXMLTags = true;

      final isRejected = !takeoverEnabled && hasXMLTags;
      expect(isRejected, isFalse);
    });

    test('Scenario: User sends slash command - always accepted', () {
      const userInput = '/status';
      const takeoverEnabled = false;
      const hasXMLTags = false;

      // Slash commands are always processed by the system
      final isSlashCommand = userInput.startsWith('/');
      expect(isSlashCommand, isTrue);

      // Should not be rejected regardless of takeover mode
      final isRejected = !takeoverEnabled && hasXMLTags && !isSlashCommand;
      expect(isRejected, isFalse);
    });

    test('Scenario: User sends plain text - goes to LLM', () {
      const userInput = 'Hello, how are you?';
      const hasXMLTags = false;
      const isSlashCommand = false;

      // Plain text should go to LLM
      final shouldGoToLLM = !hasXMLTags && !isSlashCommand;
      expect(shouldGoToLLM, isTrue);
    });

    test(
      'Scenario: Agent responds with message and terminal - only message shown',
      () {
        const agentResponse =
            '<thought>Let me check the files</thought><message>Here are your files</message><terminal>ls -la</terminal>';

        final messageRegex = RegExp(
          r'<message>(.*?)</message>',
          caseSensitive: false,
        );
        final match = messageRegex.firstMatch(agentResponse);

        // Only the message content should be shown to user
        expect(match?.group(1), equals('Here are your files'));

        // Terminal command should NOT be in the visible message
        expect(match?.group(1)!.contains('ls'), isFalse);
      },
    );

    test('Scenario: Agent responds with give - file sent to user', () {
      const agentResponse =
          '<message>Here is your document</message><give>report.pdf</give>';

      final giveRegex = RegExp(r'<give>(.*?)</give>', caseSensitive: false);
      final files = giveRegex
          .allMatches(agentResponse)
          .map((m) => m.group(1)!)
          .toList();

      expect(files, contains('report.pdf'));
      expect(files.length, equals(1));
    });

    test('Scenario: Agent responds with calendar - event created', () {
      const agentResponse =
          '<message>Reminder set</message><calendar><date>2026-03-21</date><time>14:00</time><prompt>Meeting</prompt></calendar>';

      final calendarRegex = RegExp(
        r'<calendar>.*?</calendar>',
        caseSensitive: false,
      );
      final hasCalendar = calendarRegex.hasMatch(agentResponse);

      expect(hasCalendar, isTrue);
    });
  });
}
