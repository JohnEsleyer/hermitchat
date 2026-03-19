import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hermitchat/api_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('ApiService Integration Test against local server', () async {
    final api = ApiService();
    await api.init();
    
    print('Testing Login...');
    final loginSuccess = await api.login('http://127.0.0.1:3000', 'admin', 'hermit123');
    expect(loginSuccess, isTrue, reason: 'Login should succeed with default credentials');
    expect(api.baseUrl, 'http://127.0.0.1:3000');
    expect(api.token, isNotNull);

    print('Testing getSettings...');
    final settings = await api.getSettings();
    expect(settings, isNotNull, reason: 'Settings should not be null');
    expect(settings!.containsKey('tunnelEnabled'), true);

    print('Testing getMetrics...');
    final metrics = await api.getMetrics();
    expect(metrics, isNotNull, reason: 'Metrics should not be null');

    print('Testing getApps...');
    final apps = await api.getApps();
    expect(apps, isNotNull, reason: 'Apps should not be null');

    print('Testing getAgents...');
    final agents = await api.getAgents();
    expect(agents, isNotNull, reason: 'Agents should not be null');
    
    print('All tests passed successfully!');
  });
}
