import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lantern/src/measurement_tools.dart';

void main() {
  test('arithmetic honours precedence, grouping and unary signs', () {
    expect(calculateExpression('2 + 3 * 4'), 14);
    expect(calculateExpression('(2 + 3) × 4'), 20);
    expect(calculateExpression('10 / 2 / 5'), 1);
    expect(calculateExpression('8 - 3 - 2'), 3);
    expect(calculateExpression('-2 * -(3 + 4)'), 14);
    expect(calculateExpression(' --2 + +3'), 5);
    expect(calculateExpression('1,5 ÷ .5'), 3);
    expect(calculateExpression('0'), 0);
    expect(calculateExpression('−2 − (−3)'), 1);
  });

  test('invalid or unbounded expressions fail without evaluation', () {
    for (final source in [
      '',
      '1 / 0',
      '1 / -0',
      'NaN',
      'Infinity',
      'print(1)',
      '1e2',
      '1.2.3',
      '(1+2',
      '1+2)',
      '2(3)',
      '2 ** 3',
      '1 +',
      List.filled(161, '1').join(),
      '${List.filled(17, '(').join()}1${List.filled(17, ')').join()}',
      '${List.filled(150, '9').join()} * 9999999999 * 9999999999 * 9999999999',
    ]) {
      expect(
        () => calculateExpression(source),
        throwsFormatException,
        reason: source,
      );
    }
  });

  test('converter uses exact defined unit factors', () {
    expect(
      convertMeasurement(1, MeasureUnit.inches, MeasureUnit.centimetres),
      closeTo(2.54, 1e-12),
    );
    expect(
      convertMeasurement(1, MeasureUnit.miles, MeasureUnit.feet),
      closeTo(5280, 1e-9),
    );
    expect(
      convertMeasurement(1, MeasureUnit.acres, MeasureUnit.squareFeet),
      closeTo(43560, 1e-7),
    );
    expect(
      convertMeasurement(1, MeasureUnit.cubicMetres, MeasureUnit.litres),
      closeTo(1000, 1e-10),
    );
    expect(
      convertMeasurement(1, MeasureUnit.usGallons, MeasureUnit.litres),
      closeTo(3.785411784, 1e-12),
    );
    expect(convertMeasurement(0, MeasureUnit.metres, MeasureUnit.feet), 0);
  });

  test('conversion roundtrips and rejects unlike or invalid dimensions', () {
    for (final from in MeasureUnit.values) {
      for (final to in MeasureUnit.values.where(
        (unit) => unit.kind == from.kind,
      )) {
        final converted = convertMeasurement(12.345, from, to);
        expect(convertMeasurement(converted, to, from), closeTo(12.345, 1e-10));
      }
    }
    for (final value in [-1.0, double.nan, double.infinity, 1e13]) {
      expect(
        () => convertMeasurement(value, MeasureUnit.metres, MeasureUnit.feet),
        throwsFormatException,
      );
    }
    expect(
      () => convertMeasurement(1, MeasureUnit.metres, MeasureUnit.litres),
      throwsFormatException,
    );
  });

  test('rectangle and box formulas use metres and reject bad dimensions', () {
    final rectangle = measureRectangle(3, 4);
    expect(rectangle.area, 12);
    expect(rectangle.perimeter, 14);
    expect(rectangle.volume, isNull);
    expect(measureRectangle(3, 4, height: 2).volume, 24);
    for (final value in [0.0, -1.0, double.nan, double.infinity, 1000001.0]) {
      expect(() => measureRectangle(value, 2), throwsFormatException);
      expect(() => measureRectangle(2, value), throwsFormatException);
      expect(
        () => measureRectangle(2, 3, height: value),
        throwsFormatException,
      );
    }
  });

  testWidgets('calculator reports results, errors and clears stale results', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: MeasurementToolsScreen()));
    await tester.enterText(
      find.widgetWithText(TextField, 'Expression'),
      '1000 * 1000',
    );
    await tester.tap(find.text('Calculate'));
    await tester.pump();
    expect(find.text('Result: 1000000'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, 'Expression'), '1/0');
    await tester.pump();
    expect(find.text('Result: 1000000'), findsNothing);
    await tester.tap(find.text('Calculate'));
    await tester.pump();
    expect(find.text('Cannot divide by zero.'), findsOneWidget);
    await tester.tap(find.text('Clear calculator'));
    await tester.pump();
    expect(find.text('Cannot divide by zero.'), findsNothing);
    expect(
      tester
          .widget<TextField>(find.widgetWithText(TextField, 'Expression'))
          .controller!
          .text,
      isEmpty,
    );
  });

  testWidgets('conversion and geometry work on a small screen at large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(const MaterialApp(home: MeasurementToolsScreen()));
    await tester.scrollUntilVisible(
      find.widgetWithText(TextField, 'Value to convert'),
      200,
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Value to convert'),
      '1',
    );
    await tester.scrollUntilVisible(find.text('Convert'), 100);
    await tester.tap(find.text('Convert'));
    await tester.pump();
    expect(find.text('3.280839895 ft'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.widgetWithText(TextField, 'Length (m)'),
      150,
    );
    await tester.enterText(find.widgetWithText(TextField, 'Length (m)'), '3');
    await tester.scrollUntilVisible(
      find.widgetWithText(TextField, 'Width (m)'),
      100,
    );
    await tester.enterText(find.widgetWithText(TextField, 'Width (m)'), '4');
    await tester.scrollUntilVisible(
      find.widgetWithText(TextField, 'Height (m), optional'),
      100,
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Height (m), optional'),
      '2',
    );
    await tester.scrollUntilVisible(find.text('Calculate dimensions'), 100);
    await tester.tap(find.text('Calculate dimensions'));
    await tester.pump();
    expect(
      find.text('Area: 12 m²\nPerimeter: 14 m\nVolume: 24 m³'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
