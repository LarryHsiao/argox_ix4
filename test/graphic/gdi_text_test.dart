// test/graphic/gdi_text_test.dart
@TestOn('windows')
library;

import 'package:argox_ix4/src/graphic/gdi_text.dart';
import 'package:test/test.dart';

void main() {
  test('GdiText renders a glyph to a non-empty raster', () {
    final bitmap = GdiText('A', sizePt: 18);
    expect(bitmap.widthPixels(), greaterThan(0));
    expect(bitmap.heightPixels(), greaterThan(0));
    expect(
      bitmap.bits().length,
      bitmap.widthBytes() * bitmap.heightPixels(),
    );
    // 'A' draws black pixels (bit 0), so not every byte is 0xFF (all white).
    expect(bitmap.bits().any((b) => b != 0xFF), isTrue);
  });
}
