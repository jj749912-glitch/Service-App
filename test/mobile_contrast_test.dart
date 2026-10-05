import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solarcare/mobile/design.dart';

double contrast(Color foreground, Color background) {
  final a = foreground.computeLuminance(), b = background.computeLuminance();
  return ((a > b ? a : b) + .05) / ((a < b ? a : b) + .05);
}

void main() {
  for (final worker in [false, true]) {
    testWidgets(
      '${worker ? 'Worker' : 'Customer'} chips render readable selected and unselected labels',
      (t) async {
        await t.pumpWidget(
          MaterialApp(
            theme: solarServeTheme(worker: worker),
            home: Scaffold(
              body: Wrap(
                children: [
                  ChoiceChip(
                    label: const Text('Selected service'),
                    selected: true,
                    onSelected: (_) {},
                  ),
                  FilterChip(
                    label: const Text('Other service'),
                    selected: false,
                    onSelected: (_) {},
                  ),
                ],
              ),
            ),
          ),
        );
        await t.pumpAndSettle();
        for (final entry in [
          ('Selected service', serveBlue),
          ('Other service', Colors.white),
        ]) {
          final rich = t.widget<RichText>(
            find.descendant(
              of: find.text(entry.$1),
              matching: find.byType(RichText),
            ),
          );
          expect(
            contrast(rich.text.style!.color!, entry.$2),
            greaterThanOrEqualTo(4.5),
          );
        }
        expect(t.takeException(), isNull);
      },
    );
    test(
      '${worker ? 'Worker' : 'Customer'} active controls and text meet contrast thresholds',
      () {
        final theme = solarServeTheme(worker: worker);
        final scheme = theme.colorScheme;
        expect(
          contrast(
            theme.filledButtonTheme.style!.foregroundColor!.resolve({
              WidgetState.disabled,
            })!,
            theme.filledButtonTheme.style!.backgroundColor!.resolve({
              WidgetState.disabled,
            })!,
          ),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          contrast(
            theme.outlinedButtonTheme.style!.foregroundColor!.resolve({
              WidgetState.disabled,
            })!,
            Colors.white,
          ),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          contrast(scheme.onPrimary, scheme.primary),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          contrast(scheme.onSecondary, scheme.secondary),
          greaterThanOrEqualTo(4.5),
        );
        for (final background in [Colors.white, serveBackground]) {
          for (final foreground in [
            serveNavy,
            serveMuted,
            serveBlue,
            serveError,
            serveSuccess,
          ]) {
            expect(
              contrast(foreground, background),
              greaterThanOrEqualTo(4.5),
              reason: '$foreground on $background must remain readable',
            );
          }
        }
        for (final selected in [false, true]) {
          final states = <WidgetState>{if (selected) WidgetState.selected};
          final labelColor = WidgetStateProperty.resolveAs<Color>(
            theme.chipTheme.labelStyle!.color!,
            states,
          );
          final background = selected
              ? theme.chipTheme.selectedColor!
              : theme.chipTheme.backgroundColor!;
          expect(contrast(labelColor, background), greaterThanOrEqualTo(4.5));
          if (selected) {
            expect(
              contrast(theme.chipTheme.checkmarkColor!, background),
              greaterThanOrEqualTo(3),
            );
          }
        }
        expect(
          contrast(theme.inputDecorationTheme.hintStyle!.color!, Colors.white),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          contrast(theme.inputDecorationTheme.labelStyle!.color!, Colors.white),
          greaterThanOrEqualTo(4.5),
        );
        final border =
            theme.inputDecorationTheme.enabledBorder! as OutlineInputBorder;
        expect(
          contrast(border.borderSide.color, Colors.white),
          greaterThanOrEqualTo(3),
        );
      },
    );
  }
  test(
    'White summary text and photo captions remain readable at the lightest backgrounds',
    () {
      for (final background in [serveTealStart, serveTealEnd]) {
        expect(contrast(Colors.white, background), greaterThanOrEqualTo(4.5));
      }
      // A white image pixel is the worst case beneath the weakest photo scrim.
      final photo = Color.alphaBlend(
        servePhotoShade.withValues(alpha: .8),
        Colors.white,
      );
      expect(contrast(Colors.white, photo), greaterThanOrEqualTo(4.5));
      final glass = Color.alphaBlend(
        servePhotoShade.withValues(alpha: .85),
        Colors.white,
      );
      expect(contrast(Colors.white, glass), greaterThanOrEqualTo(4.5));
      expect(
        contrast(serveNavy, const Color(0xFFFFBB18)),
        greaterThanOrEqualTo(4.5),
      );
    },
  );
}
