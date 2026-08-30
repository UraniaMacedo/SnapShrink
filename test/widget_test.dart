import 'package:flutter_test/flutter_test.dart';
import 'package:reduzir_app/main.dart';

void main() {
  testWidgets('SnapShrink abre sem erro', (WidgetTester tester) async {
    await tester.pumpWidget(const ReduzirApp());

    expect(find.text('SnapShrink'), findsOneWidget);
  });
}
