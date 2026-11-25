import 'package:aule/core/widgets/code_boxes.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../harness.dart';

void main() {
  group('CodeFormatter', () {
    test('a pasted sign-in code keeps only its digits', () {
      final digits = CodeFormatter(length: 6, allowed: RegExp('[0-9]'));
      expect(digits.clean('123 456'), '123456');
      expect(digits.clean('Tu código: 12-34-56.'), '123456');
      expect(digits.clean('1234567'), '123456');
      expect(digits.clean('12a'), '12');
    });

    test('a device code is upper case, without 0, 1, I or O', () {
      final claim = CodeFormatter(
        length: 6,
        allowed: RegExp('[A-HJ-NP-Z2-9]'),
        uppercase: true,
      );
      expect(claim.clean('k7q-m2x'), 'K7QM2X');
      expect(claim.clean('io01W8PZ3R'), 'W8PZ3R');
    });
  });

  testWidgets('typing or pasting fills every box and completes', (
    tester,
  ) async {
    final changes = <String>[];
    String? completed;
    await pumpScreen(
      tester,
      Scaffold(
        body: CodeBoxes(
          length: 6,
          allowed: RegExp('[0-9]'),
          keyboardType: TextInputType.number,
          semanticLabel: 'Código de 6 dígitos',
          onChanged: changes.add,
          onCompleted: (value) => completed = value,
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), '12 34 56');
    await tester.pump();
    expect(changes.last, '123456');
    expect(completed, '123456');
    for (final digit in <String>['1', '2', '3', '4', '5', '6']) {
      expect(find.text(digit), findsOneWidget);
    }
  });
}
