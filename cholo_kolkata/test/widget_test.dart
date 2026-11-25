import 'package:flutter_test/flutter_test.dart';
import 'package:cholo_kolkata/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const CholoKolkataApp());
    expect(find.text('CholoKolkata'), findsOneWidget);
  });
}
