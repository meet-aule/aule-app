import 'package:aule/core/widgets/buttons.dart';
import 'package:aule/core/widgets/check_row.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../harness.dart';

void main() {
  testWidgets('a primary button presses, and not while disabled or busy', (
    tester,
  ) async {
    var presses = 0;
    Widget page({required bool enabled, bool busy = false}) => Scaffold(
      body: PrimaryButton(
        label: 'Continuar',
        busy: busy,
        onPressed: enabled ? () => presses++ : null,
      ),
    );

    await pumpScreen(tester, page(enabled: true));
    await tester.tap(find.text('Continuar'));
    expect(presses, 1);

    await pumpScreen(tester, page(enabled: false));
    await tester.tap(find.byType(PrimaryButton));
    expect(presses, 1);

    // The loading indicator animates indefinitely; one frame renders the busy state.
    await pumpScreen(tester, page(enabled: true, busy: true), settle: false);
    // The spinner replaces the label, which screen readers still hear.
    expect(find.text('Continuar'), findsNothing);
    expect(find.bySemanticsLabel('Continuar'), findsOneWidget);
    await tester.tap(find.byType(PrimaryButton));
    expect(presses, 1);
  });

  testWidgets('primary buttons are at least 52 px tall', (tester) async {
    await pumpScreen(
      tester,
      Scaffold(
        body: PrimaryButton(label: 'Guardar', onPressed: () {}),
      ),
    );
    expect(
      tester.getSize(find.byType(PrimaryButton)).height,
      greaterThanOrEqualTo(52),
    );
  });

  testWidgets('a check row toggles from its text', (tester) async {
    var value = false;
    await pumpScreen(
      tester,
      Scaffold(
        body: StatefulBuilder(
          builder: (context, setState) => CheckRow(
            value: value,
            label: 'Recordar entre sesiones',
            onChanged: (next) => setState(() => value = next),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Recordar entre sesiones'));
    await tester.pump();
    expect(value, isTrue);
    expect(tester.widget<CheckRow>(find.byType(CheckRow)).value, isTrue);
  });
}
