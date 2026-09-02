import 'package:flutter_test/flutter_test.dart';
import 'package:sistema_ordeno/main.dart';

void main() {
  testWidgets('App should start', (WidgetTester tester) async {
    await tester.pumpWidget(const SistemaOrdenoApp());
    // Since there are multiple ElevatedButtons we could just check if HomeScreen rendered
    expect(find.text('Inicio - Sistema Ordeño'), findsOneWidget);
  });
}
