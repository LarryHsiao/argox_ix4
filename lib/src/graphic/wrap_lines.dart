/// Breaks [text] into lines that each measure at most [maxWidth] under
/// [measure]. Space-separated words are kept whole when they fit; a word wider
/// than [maxWidth] on its own is broken between characters (runes). Returns at
/// least one line — `['']` for empty input.
List<String> wrapLines(
  String text, {
  required int maxWidth,
  required int Function(String) measure,
}) {
  if (text.isEmpty) {
    return [''];
  }
  final lines = <String>[];
  var current = '';
  for (final word in text.split(' ')) {
    final candidate = current.isEmpty ? word : '$current $word';
    if (measure(candidate) <= maxWidth) {
      current = candidate;
      continue;
    }
    if (current.isNotEmpty) {
      lines.add(current);
      current = '';
    }
    if (measure(word) <= maxWidth) {
      current = word;
    } else {
      // Word alone is too wide: break it between runes.
      final pieces = _breakWord(word, maxWidth: maxWidth, measure: measure);
      // All but the last piece are full lines; the last continues `current`.
      lines.addAll(pieces.sublist(0, pieces.length - 1));
      current = pieces.last;
    }
  }
  lines.add(current);
  return lines;
}

List<String> _breakWord(
  String word, {
  required int maxWidth,
  required int Function(String) measure,
}) {
  final pieces = <String>[];
  var piece = '';
  for (final rune in word.runes) {
    final ch = String.fromCharCode(rune);
    final candidate = piece + ch;
    if (piece.isNotEmpty && measure(candidate) > maxWidth) {
      pieces.add(piece);
      piece = ch;
    } else {
      piece = candidate; // single rune always accepted, even if over width
    }
  }
  pieces.add(piece);
  return pieces;
}
