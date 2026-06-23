// test/graphic/auto_font_test.dart
import 'package:argox_ix4/src/graphic/auto_font.dart';
import 'package:test/test.dart';

void main() {
  test('Han text picks the Chinese face', () {
    final expected = 'Microsoft JhengHei';
    expect(const AutoFont('中文標籤').name(), expected);
  });

  test('Kana presence picks the Japanese face', () {
    final expected = 'MS Gothic';
    expect(const AutoFont('日本語ラベル').name(), expected);
  });

  test('Hangul presence picks the Korean face', () {
    final expected = 'Malgun Gothic';
    expect(const AutoFont('한국어 라벨').name(), expected);
  });

  test('Plain ASCII picks the Latin face', () {
    final expected = 'Segoe UI';
    expect(const AutoFont('ASCII 123').name(), expected);
  });

  test('Hangul outranks kana regardless of order', () {
    final expected = 'Malgun Gothic';
    expect(const AutoFont('カ한').name(), expected);
  });

  test('an explicit faces map overrides the defaults', () {
    final expected = 'Noto Sans CJK';
    final actual = const AutoFont('中文', faces: {
      Script.hangul: 'Malgun Gothic',
      Script.kana: 'MS Gothic',
      Script.han: 'Noto Sans CJK',
      Script.latin: 'Segoe UI',
    }).name();
    expect(actual, expected);
  });
}
