import 'package:flutter_test/flutter_test.dart';

import 'package:hermitchat/main.dart';

void main() {
  testWidgets('HermitChat app loads', (WidgetTester tester) async {
    await tester.pumpWidget(const HermitChatApp());

    expect(find.text('hermitchat'), findsOneWidget);
    expect(find.text('Connect to OS'), findsOneWidget);
  });
}
