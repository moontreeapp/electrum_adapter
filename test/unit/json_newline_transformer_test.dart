import 'package:electrum_adapter/client/json_newline_transformer.dart';
import 'package:test/test.dart';

void main() {
  group('ContinuousJsonDecoder numbers', () {
    test('parses scientific notation', () {
      expect(
        const ContinuousJsonDecoder().convert(
          '{"small":1e-7,"large":6.02214076e23,"signed":-2.5E+3}',
        ),
        {
          'small': 1e-7,
          'large': 6.02214076e23,
          'signed': -2.5e3,
        },
      );
    });

    test('uses the platform parser for boundary values', () {
      expect(
        const ContinuousJsonDecoder().convert(
          '[5e-324,1.7976931348623157e308]',
        ),
        [5e-324, 1.7976931348623157e308],
      );
    });
  });
}
