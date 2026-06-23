/// A writing system, used to pick a font face for a string.
enum Script { hangul, kana, han, latin }

/// Picks a Windows font face for a string by its dominant script.
///
/// Detection is unambiguous-first: any Hangul -> Korean; else any Kana ->
/// Japanese; else any Han -> Chinese; else Latin. Han-only text cannot be told
/// apart as zh vs ja (Han unification) and falls to Chinese — pass an explicit
/// `font:` to [GdiText] for Japanese Han-only text.
class AutoFont {
  const AutoFont(this._text, {Map<Script, String> faces = _defaults})
      : _faces = faces;

  final String _text;
  final Map<Script, String> _faces;

  static const Map<Script, String> _defaults = {
    Script.hangul: 'Malgun Gothic',
    Script.kana: 'MS Gothic',
    Script.han: 'Microsoft JhengHei',
    Script.latin: 'Segoe UI',
  };

  /// The chosen font face name.
  String name() => _faces[_script()] ?? _defaults[_script()]!;

  Script _script() {
    var hasKana = false;
    var hasHan = false;
    for (final rune in _text.runes) {
      if (_isHangul(rune)) return Script.hangul; // highest priority
      if (_isKana(rune)) hasKana = true;
      if (_isHan(rune)) hasHan = true;
    }
    if (hasKana) return Script.kana;
    if (hasHan) return Script.han;
    return Script.latin;
  }

  bool _isHangul(int r) =>
      (r >= 0xAC00 && r <= 0xD7A3) || // Hangul syllables
      (r >= 0x1100 && r <= 0x11FF) || // Jamo
      (r >= 0x3130 && r <= 0x318F); // compatibility Jamo

  bool _isKana(int r) =>
      (r >= 0x3040 && r <= 0x309F) || // Hiragana
      (r >= 0x30A0 && r <= 0x30FF); // Katakana

  bool _isHan(int r) =>
      (r >= 0x4E00 && r <= 0x9FFF) || // CJK Unified Ideographs
      (r >= 0x3400 && r <= 0x4DBF); // Extension A
}
