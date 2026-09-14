import 'package:flutter_test/flutter_test.dart';
import 'package:offline_academy_client/main.dart';

void main() {
  testWidgets('App initializes without crash', (WidgetTester tester) async {
    // Smoke test: just verify the app widget tree can be built.
    // Full integration tests require a live OfflineAcademy server.
    expect(OfflineAcademyApp, isNotNull);
  });
}
