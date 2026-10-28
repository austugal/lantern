import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Bounded arithmetic parser. No code evaluation or network access.
double calculateExpression(String input) => _Arithmetic(input).calculate();

class _Arithmetic {
  _Arithmetic(String input)
    : source = input
          .replaceAll('×', '*')
          .replaceAll('÷', '/')
          .replaceAll('−', '-')
          .replaceAll(',', '.');
  final String source;
  int at = 0;
  int depth = 0;

  Never fail(String message) => throw FormatException(message);
  void spaces() {
    while (at < source.length && source[at].trim().isEmpty) {
      at++;
    }
  }

  bool take(String value) {
    spaces();
    if (at < source.length && source[at] == value) {
      at++;
      return true;
    }
    return false;
  }

  double finite(double value) {
    if (!value.isFinite) fail('Result is too large.');
    return value;
  }

  double calculate() {
    if (source.isEmpty || source.length > 160) {
      fail('Enter an expression of 1–160 characters.');
    }
    final result = sum();
    spaces();
    if (at != source.length) fail('Use numbers, +, −, *, / and parentheses.');
    return finite(result);
  }

  double sum() {
    var value = product();
    while (true) {
      if (take('+')) {
        value = finite(value + product());
      } else if (take('-')) {
        value = finite(value - product());
      } else {
        return value;
      }
    }
  }

  double product() {
    var value = number();
    while (true) {
      if (take('*')) {
        value = finite(value * number());
      } else if (take('/')) {
        final divisor = number();
        if (divisor == 0) fail('Cannot divide by zero.');
        value = finite(value / divisor);
      } else {
        return value;
      }
    }
  }

  double number() {
    var sign = 1;
    while (true) {
      if (take('-')) {
        sign = -sign;
      } else if (!take('+')) {
        break;
      }
    }
    if (take('(')) {
      if (++depth > 16) fail('Use at most 16 nested parentheses.');
      final value = sum();
      if (!take(')')) fail('Close the parentheses.');
      depth--;
      return finite(sign * value);
    }
    spaces();
    final start = at;
    while (at < source.length && RegExp(r'[0-9.]').hasMatch(source[at])) {
      at++;
    }
    final value = double.tryParse(source.substring(start, at));
    if (value == null) fail('Enter a valid number.');
    return finite(sign * value);
  }
}

enum MeasureKind { length, area, volume }

enum MeasureUnit {
  millimetres(MeasureKind.length, 'mm', .001),
  centimetres(MeasureKind.length, 'cm', .01),
  metres(MeasureKind.length, 'm', 1),
  kilometres(MeasureKind.length, 'km', 1000),
  inches(MeasureKind.length, 'in', .0254),
  feet(MeasureKind.length, 'ft', .3048),
  yards(MeasureKind.length, 'yd', .9144),
  miles(MeasureKind.length, 'mi', 1609.344),
  squareMetres(MeasureKind.area, 'm²', 1),
  squareFeet(MeasureKind.area, 'ft²', .09290304),
  hectares(MeasureKind.area, 'ha', 10000),
  acres(MeasureKind.area, 'acres', 4046.8564224),
  millilitres(MeasureKind.volume, 'ml', .000001),
  litres(MeasureKind.volume, 'litres', .001),
  cubicMetres(MeasureKind.volume, 'm³', 1),
  cubicFeet(MeasureKind.volume, 'ft³', .028316846592),
  usGallons(MeasureKind.volume, 'US gal', .003785411784);

  const MeasureUnit(this.kind, this.symbol, this.baseFactor);
  final MeasureKind kind;
  final String symbol;
  final double baseFactor;
}

double convertMeasurement(double value, MeasureUnit from, MeasureUnit to) {
  if (!value.isFinite || value < 0 || value > 1e12) {
    throw const FormatException('Enter a value from 0 to 1,000,000,000,000.');
  }
  if (from.kind != to.kind) {
    throw const FormatException('Choose units of the same measurement type.');
  }
  return value * from.baseFactor / to.baseFactor;
}

({double area, double perimeter, double? volume}) measureRectangle(
  double length,
  double width, {
  double? height,
}) {
  for (final dimension in [length, width, if (height != null) height]) {
    if (!dimension.isFinite || dimension <= 0 || dimension > 1e6) {
      throw const FormatException(
        'Each dimension must be above 0 and at most 1,000,000 metres.',
      );
    }
  }
  return (
    area: length * width,
    perimeter: 2 * (length + width),
    volume: height == null ? null : length * width * height,
  );
}

String _display(double value) {
  if (value == 0) return '0';
  final parts = value.toStringAsPrecision(10).split('e');
  var mantissa = parts.first;
  if (mantissa.contains('.')) {
    mantissa = mantissa
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }
  return parts.length == 1 ? mantissa : '${mantissa}e${parts.last}';
}

class MeasurementToolsScreen extends StatefulWidget {
  const MeasurementToolsScreen({super.key});
  @override
  State<MeasurementToolsScreen> createState() => _MeasurementToolsScreenState();
}

class _MeasurementToolsScreenState extends State<MeasurementToolsScreen> {
  final _expression = TextEditingController();
  final _value = TextEditingController();
  final _length = TextEditingController();
  final _width = TextEditingController();
  final _height = TextEditingController();
  MeasureKind _kind = MeasureKind.length;
  MeasureUnit _from = MeasureUnit.metres;
  MeasureUnit _to = MeasureUnit.feet;
  String _calculation = '';
  String _conversion = '';
  String _dimensions = '';

  @override
  void dispose() {
    for (final controller in [_expression, _value, _length, _width, _height]) {
      controller.dispose();
    }
    super.dispose();
  }

  double _number(TextEditingController controller) {
    final value = double.tryParse(controller.text.trim().replaceAll(',', '.'));
    if (value == null) {
      throw const FormatException('Enter a valid decimal number.');
    }
    return value;
  }

  String _result(String Function() calculate) {
    try {
      return calculate();
    } on FormatException catch (error) {
      return error.message;
    }
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    bool expression = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(
      controller: controller,
      maxLength: expression ? 160 : 24,
      keyboardType: expression
          ? TextInputType.text
          : const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        LengthLimitingTextInputFormatter(expression ? 160 : 24),
      ],
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      onChanged: (_) => setState(() {
        if (expression) {
          _calculation = '';
        } else if (identical(controller, _value)) {
          _conversion = '';
        } else {
          _dimensions = '';
        }
      }),
    ),
  );

  Widget _card(String title, List<Widget> children) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    ),
  );

  Widget _answer(String text) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Semantics(liveRegion: true, child: SelectableText(text)),
  );

  Widget _unitPicker(
    String label,
    MeasureUnit selected,
    ValueChanged<MeasureUnit> change,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: DropdownButtonFormField<MeasureUnit>(
      key: ValueKey('$label-${_kind.name}'),
      initialValue: selected,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      items: MeasureUnit.values
          .where((unit) => unit.kind == _kind)
          .map(
            (unit) => DropdownMenuItem(value: unit, child: Text(unit.symbol)),
          )
          .toList(),
      onChanged: (unit) {
        if (unit != null) {
          setState(() {
            change(unit);
            _conversion = '';
          });
        }
      },
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text(
        'Calculator & measures',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    ),
    body: ListView(
      padding: const EdgeInsets.all(12),
      children: [
        const Padding(
          padding: EdgeInsets.all(8),
          child: Text(
            'Offline calculations from numbers you enter. This does not measure objects through the camera or screen. Results are rounded to 10 significant digits.',
          ),
        ),
        _card('Calculator', [
          _field(_expression, 'Expression', expression: true),
          const Text(
            'Use +, -, × or *, ÷ or /, and parentheses. Decimal point or comma; no thousands separators. Example: (12 + 3) × 2.',
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () => setState(
              () => _calculation = _result(
                () =>
                    'Result: ${_display(calculateExpression(_expression.text))}',
              ),
            ),
            child: const Text('Calculate'),
          ),
          TextButton(
            onPressed: () => setState(() {
              _expression.clear();
              _calculation = '';
            }),
            child: const Text('Clear calculator'),
          ),
          if (_calculation.isNotEmpty) _answer(_calculation),
        ]),
        _card('Unit converter', [
          DropdownButtonFormField<MeasureKind>(
            initialValue: _kind,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Measurement type'),
            items: MeasureKind.values
                .map(
                  (kind) =>
                      DropdownMenuItem(value: kind, child: Text(kind.name)),
                )
                .toList(),
            onChanged: (kind) {
              if (kind == null) return;
              setState(() {
                _kind = kind;
                final units = MeasureUnit.values
                    .where((unit) => unit.kind == kind)
                    .toList();
                _from = units.first;
                _to = units[1];
                _conversion = '';
              });
            },
          ),
          const SizedBox(height: 12),
          _field(_value, 'Value to convert'),
          _unitPicker('From unit', _from, (unit) => _from = unit),
          _unitPicker('To unit', _to, (unit) => _to = unit),
          FilledButton(
            onPressed: () => setState(
              () => _conversion = _result(
                () =>
                    '${_display(convertMeasurement(_number(_value), _from, _to))} ${_to.symbol}',
              ),
            ),
            child: const Text('Convert'),
          ),
          if (_conversion.isNotEmpty) _answer(_conversion),
        ]),
        _card('Rectangle & box', [
          const Text(
            'Enter measured dimensions in metres. Leave height empty for a flat rectangle. This assumes straight sides and right angles.',
          ),
          const SizedBox(height: 12),
          _field(_length, 'Length (m)'),
          _field(_width, 'Width (m)'),
          _field(_height, 'Height (m), optional'),
          FilledButton(
            onPressed: () => setState(
              () => _dimensions = _result(() {
                final result = measureRectangle(
                  _number(_length),
                  _number(_width),
                  height: _height.text.trim().isEmpty ? null : _number(_height),
                );
                return 'Area: ${_display(result.area)} m²\nPerimeter: ${_display(result.perimeter)} m'
                    '${result.volume == null ? '' : '\nVolume: ${_display(result.volume!)} m³'}';
              }),
            ),
            child: const Text('Calculate dimensions'),
          ),
          if (_dimensions.isNotEmpty) _answer(_dimensions),
        ]),
      ],
    ),
  );
}
