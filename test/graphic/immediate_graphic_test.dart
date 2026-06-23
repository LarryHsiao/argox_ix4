import 'package:argox_ix4/src/graphic/bitmap.dart';
import 'package:argox_ix4/src/graphic/immediate_graphic.dart';
import 'package:test/test.dart';

void main() {
  test('ImmediateGraphic frames the GW header, raster, and LF', () {
    const bitmap = ConstBitmap(
      widthPixels: 16,
      heightPixels: 2,
      bits: [0x00, 0xFF, 0xAA, 0x55],
    );
    final expected = <int>[
      ...'GW30,40,2,2,'.codeUnits,
      0x00, 0xFF, 0xAA, 0x55,
      0x0A, // LF
    ];
    final actual = const ImmediateGraphic(x: 30, y: 40, bitmap: bitmap).bytes();
    expect(actual, expected);
  });
}
