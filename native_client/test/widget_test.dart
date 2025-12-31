import 'package:flutter_test/flutter_test.dart';

import 'package:native_client/main.dart';

void main() {
  testWidgets('Hello world displays', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    expect(find.text('Hello World!'), findsOneWidget);
    expect(find.text('Ratchet Chat'), findsOneWidget);
  });
}
