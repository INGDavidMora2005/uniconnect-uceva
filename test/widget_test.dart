import 'package:flutter_test/flutter_test.dart';
import 'package:uniconnect_app/main.dart';

void main() {
  testWidgets('UniConnect app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const UniConnectApp());
    expect(find.byType(UniConnectApp), findsOneWidget);
  });
}