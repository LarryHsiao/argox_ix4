@TestOn('windows')
library;

import 'package:argox_ix4/src/graphic/gdi_paragraph.dart';
import 'package:test/test.dart';

void main() {
  test('invariants throw', () {
    expect(() => GdiParagraph('x', maxWidthDots: 0), throwsArgumentError);
    expect(() => GdiParagraph('x', maxWidthDots: 100, minLines: 3, maxLines: 2),
        throwsArgumentError);
    expect(() => GdiParagraph('x', maxWidthDots: 100, sizePt: 6, minSizePt: 8),
        throwsArgumentError);
  });

  test('short text reserves the minLines height (blank lines kept)', () {
    final one = GdiParagraph('A',
        maxWidthDots: 600, sizePt: 16, minLines: 1, maxLines: 1);
    final two = GdiParagraph('A',
        maxWidthDots: 600, sizePt: 16, minLines: 2, maxLines: 2);
    final expected = one.heightPixels() * 2;
    expect(two.heightPixels(), expected);
    expect(two.widthPixels() <= 600, isTrue);
  });

  test('a long line wraps to multiple lines within the box', () {
    const long = 'wrapping should break this sentence across several lines';
    final p = GdiParagraph(long,
        maxWidthDots: 200, sizePt: 12, minLines: 1, maxLines: 5);
    final single = GdiParagraph('M', maxWidthDots: 200, sizePt: 12);
    expect(p.heightPixels() > single.heightPixels(), isTrue);
    expect(p.widthPixels() <= 200, isTrue);
    expect(p.bits().length, p.widthBytes() * p.heightPixels());
  });

  test('content over maxLines is capped at the maxLines height', () {
    const long = 'one two three four five six seven eight nine ten eleven';
    final p = GdiParagraph(long,
        maxWidthDots: 120, sizePt: 12, minLines: 2, maxLines: 2, minSizePt: 8);
    final oneLine = GdiParagraph('M', maxWidthDots: 120, sizePt: 12);
    final expected = oneLine.heightPixels() * 2;
    expect(p.heightPixels(), expected);
  });
}
