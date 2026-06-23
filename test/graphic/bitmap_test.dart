import 'package:argox_ix4/src/graphic/bitmap.dart';
import 'package:test/test.dart';

void main() {
  test('ConstBitmap rounds width up to whole bytes', () {
    const expected = 2; // 9 pixels -> 2 bytes
    final actual =
        const ConstBitmap(widthPixels: 9, heightPixels: 1, bits: [0, 0])
            .widthBytes();
    expect(actual, expected);
  });

  test('ConstBitmap exposes its dimensions and bits verbatim', () {
    const bitmap =
        ConstBitmap(widthPixels: 8, heightPixels: 2, bits: [0xFF, 0x00]);
    expect(bitmap.widthPixels(), 8);
    expect(bitmap.heightPixels(), 2);
    expect(bitmap.bits(), [0xFF, 0x00]);
  });
}
