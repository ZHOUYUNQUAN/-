import 'package:flutter_test/flutter_test.dart';
import 'package:expense_manager/app.dart';

void main() {
  testWidgets('App renders bottom navigation', (WidgetTester tester) async {
    await tester.pumpWidget(const ExpenseApp());
    expect(find.text('首页'), findsOneWidget);
    expect(find.text('记账'), findsOneWidget);
    expect(find.text('报表'), findsOneWidget);
    expect(find.text('设置'), findsOneWidget);
  });
}
