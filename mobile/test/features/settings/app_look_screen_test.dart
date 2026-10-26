import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pasal_mobile/core/settings/settings.dart';
import 'package:pasal_mobile/features/settings/presentation/app_look_screen.dart';

import '../../helpers/pump_app.dart';

void main() {
  testWidgets('a new colour, theme and language are saved in the settings at once', (tester) async {
    final container = await pumpApp(tester, const AppLookScreen());

    expect(container.read(settingsProvider).seed, seedColors.first.toARGB32());

    await tester.tap(find.byKey(ValueKey('seed-${seedColors[1].toARGB32()}')));
    await tester.pumpAndSettle();
    expect(container.read(settingsProvider).seed, seedColors[1].toARGB32());

    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();
    expect(container.read(settingsProvider).theme, ThemeChoice.dark);

    await tester.tap(find.text('नेपाली'));
    await tester.pumpAndSettle();
    expect(container.read(settingsProvider).ne, isTrue);

    await tester.tap(find.text('AD'));
    await tester.pumpAndSettle();
    expect(container.read(settingsProvider).bsDates, isFalse);
  });
}
