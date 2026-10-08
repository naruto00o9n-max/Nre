import 'package:flutter_test/flutter_test.dart';
import 'package:example/main.dart';

void main() {
  testWidgets('Launches with all official designs and local image inputs', (tester) async {
    await tester.pumpWidget(const TrialApp());
    await tester.pumpAndSettle();
    expect(find.text('Grounded'), findsOneWidget);
    expect(find.text('Frosted Glass'), findsOneWidget);
    expect(find.text('WhatsApp'), findsOneWidget);
    expect(find.text('الصور'), findsOneWidget);
    expect(find.text('الملفات'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
