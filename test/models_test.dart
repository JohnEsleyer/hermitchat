import 'package:flutter_test/flutter_test.dart';
import 'package:hermitchat/main.dart';

void main() {
  group('ChatMessage', () {
    test('ChatMessage can be created with required fields', () {
      final message = ChatMessage(
        role: 'user',
        content: 'Hello, world!',
        timestamp: DateTime(2024, 1, 1, 12, 0),
      );

      expect(message.role, 'user');
      expect(message.content, 'Hello, world!');
      expect(message.isRead, false);
      expect(message.files, isNull);
    });

    test('ChatMessage can be created with all fields', () {
      final message = ChatMessage(
        role: 'system',
        content: 'System message',
        timestamp: DateTime(2024, 1, 1, 12, 0),
        isRead: true,
        files: ['file1.txt', 'file2.txt'],
      );

      expect(message.role, 'system');
      expect(message.content, 'System message');
      expect(message.isRead, true);
      expect(message.files, ['file1.txt', 'file2.txt']);
    });

    test('ChatMessage with system role is identified correctly', () {
      final systemMessage = ChatMessage(
        role: 'system',
        content: 'Processing command...',
        timestamp: DateTime.now(),
      );

      expect(systemMessage.role, 'system');
    });

    test('ChatMessage with assistant role is identified correctly', () {
      final assistantMessage = ChatMessage(
        role: 'assistant',
        content: 'Response from agent',
        timestamp: DateTime.now(),
      );

      expect(assistantMessage.role, 'assistant');
    });
  });

  group('Agent', () {
    test('Agent can be created with required fields', () {
      final agent = Agent(
        id: '1',
        name: 'Test Agent',
        role: 'assistant',
        status: 'running',
        model: 'gpt-4',
        platform: 'hermitchat',
        containerId: 'test-container',
        personality: 'helpful',
      );

      expect(agent.id, '1');
      expect(agent.name, 'Test Agent');
      expect(agent.status, 'running');
      expect(agent.provider, 'openrouter');
      expect(agent.background, 'doodle');
    });

    test('Agent.fromJson parses JSON correctly', () {
      final json = {
        'id': 123,
        'name': 'Ralph',
        'role': 'code assistant',
        'status': 'running',
        'model': 'gpt-4',
        'platform': 'hermitchat',
        'container_id': 'container-123',
        'personality': 'helpful',
        'provider': 'openai',
        'background': 'minimal',
      };

      final agent = Agent.fromJson(json);

      expect(agent.id, '123');
      expect(agent.name, 'Ralph');
      expect(agent.provider, 'openai');
      expect(agent.background, 'minimal');
    });
  });

  group('CalendarEventModel', () {
    test('CalendarEventModel.fromJson parses JSON correctly', () {
      final json = {
        'id': 1,
        'agentId': 10,
        'agent': 'Test Agent',
        'date': '2024-01-15',
        'time': '14:30',
        'prompt': 'Review code',
        'executed': false,
      };

      final event = CalendarEventModel.fromJson(json);

      expect(event.id, 1);
      expect(event.agentId, 10);
      expect(event.agent, 'Test Agent');
      expect(event.date, '2024-01-15');
      expect(event.time, '14:30');
      expect(event.prompt, 'Review code');
      expect(event.executed, false);
    });

    test('CalendarEventModel.startsAt returns correct DateTime', () {
      final event = CalendarEventModel(
        id: 1,
        agentId: 10,
        agent: 'Test Agent',
        date: '2024-01-15',
        time: '14:30',
        prompt: 'Review code',
        executed: false,
      );

      final startsAt = event.startsAt;

      expect(startsAt, isNotNull);
      expect(startsAt!.year, 2024);
      expect(startsAt.month, 1);
      expect(startsAt.day, 15);
      expect(startsAt.hour, 14);
      expect(startsAt.minute, 30);
    });

    test('CalendarEventModel.startsAt handles empty time', () {
      final event = CalendarEventModel(
        id: 1,
        agentId: 10,
        agent: 'Test Agent',
        date: '2024-01-15',
        time: '',
        prompt: 'Review code',
        executed: false,
      );

      final startsAt = event.startsAt;

      expect(startsAt, isNotNull);
      expect(startsAt!.hour, 0);
      expect(startsAt.minute, 0);
    });
  });
}
