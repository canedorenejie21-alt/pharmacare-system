import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacare/main.dart';

void main() {
  testWidgets('shows PharmaCare mobile dashboard', (tester) async {
    await tester.pumpWidget(const PharmaCareApp());

    expect(find.text('Welcome back, Maria'), findsOneWidget);
    expect(find.text('Total Patients'), findsOneWidget);
    expect(find.text('Prescription Overview'), findsOneWidget);
  });
}
