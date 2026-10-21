import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/main.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('App renders without crashing', (WidgetTester tester) async {
    final auth = AuthProvider();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: auth),
        ],
        child: const SmartAttendanceApp(),
      ),
    );
    expect(find.byType(SmartAttendanceApp), findsOneWidget);
  });
}
