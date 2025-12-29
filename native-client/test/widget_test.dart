// Basic Flutter widget test for Ratchet Chat.

import 'package:flutter_test/flutter_test.dart';

import 'package:ratchet_chat/main.dart';

void main() {
  testWidgets('App renders splash screen', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const RatchetChatApp());

    // Verify that splash screen shows app name
    expect(find.text('Ratchet Chat'), findsOneWidget);
    expect(find.text('Secure. Private. Yours.'), findsOneWidget);
  });
}
