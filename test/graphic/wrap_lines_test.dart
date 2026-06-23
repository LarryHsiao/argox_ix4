import 'package:argox_ix4/src/graphic/wrap_lines.dart';
import 'package:test/test.dart';

// Each rune (and space) is 10 wide.
int _measure(String s) => s.runes.length * 10;

void main() {
  test('empty text yields a single empty line', () {
    final expected = [''];
    expect(wrapLines('', maxWidth: 100, measure: _measure), expected);
  });

  test('words wrap on spaces, kept whole', () {
    // 'aaa bbb' = 7 runes = 70; adding ' ccc' = 11 runes = 110 > 70.
    final expected = ['aaa bbb', 'ccc'];
    expect(wrapLines('aaa bbb ccc', maxWidth: 70, measure: _measure), expected);
  });

  test('a word wider than the box is char-broken', () {
    // maxWidth 30 = 3 runes per line.
    final expected = ['aaa', 'aaa', 'aa'];
    expect(wrapLines('aaaaaaaa', maxWidth: 30, measure: _measure), expected);
  });

  test('CJK (no spaces) char-breaks', () {
    final expected = ['中文', '字測', '試'];
    expect(wrapLines('中文字測試', maxWidth: 25, measure: _measure), expected);
  });

  test('a single rune wider than the box still emits alone', () {
    final expected = ['x'];
    expect(wrapLines('x', maxWidth: 5, measure: _measure), expected);
  });
}
