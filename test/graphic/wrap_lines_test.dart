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

  test('a fitting word followed by an over-wide word: flush then char-break',
      () {
    // 'ab' (20) fits maxWidth 30; 'xxxxxxxx' (80) alone exceeds it and breaks
    // into 3-rune pieces. 'ab' is flushed first, then the pieces follow.
    final expected = ['ab', 'xxx', 'xxx', 'xx'];
    expect(wrapLines('ab xxxxxxxx', maxWidth: 30, measure: _measure), expected);
  });

  test('consecutive spaces are preserved when the line still fits', () {
    // 'a  b' (two spaces) = 4 runes = 40 <= 100, so it stays one line.
    final expected = ['a  b'];
    expect(wrapLines('a  b', maxWidth: 100, measure: _measure), expected);
  });
}
