# CJK Bitmap Text Printing Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Print arbitrary text (Chinese/Japanese/Korean/Latin) on the ARGOX iX4 by rasterizing it with Windows GDI and sending the PPLB `GW` (Print Immediate Graphics) command.

**Architecture:** A `Bitmap` seam with a literal concrete (`ConstBitmap`) and a GDI concrete (`GdiText`); an `ImmediateGraphic` `Command` that frames the `GW` bytes; an `AutoFont` that picks a Windows font face from a string's dominant script. The pure pieces (`ImmediateGraphic`, `AutoFont`, `ConstBitmap`) are CI-testable; `GdiText`'s FFI path is Windows-guarded and verified on hardware.

**Tech Stack:** Dart 3.3, `package:pplb` (the `Command` interface), `package:win32` (gdi32 bindings), `package:ffi`.

## Global Constraints

Copied verbatim from the spec and the codebase conventions. Every task's requirements implicitly include this section.

- **SDK floor:** `environment: sdk: ^3.3.0`. Dependencies already present: `pplb ^0.1.0`, `ffi ^2.1.0`, `win32 ^5.5.0`. **Add no new dependency.**
- **Platform:** the GDI path is Windows-only. Off Windows, `GdiText` throws `UnsupportedError` via the existing `ensureWindowsPlatform(isWindows: Platform.isWindows)` in `lib/src/usb_printer.dart`.
- **Domain-object style** (`docs/style/oo.md`): names are nouns; no `-er`/`-or` suffixes; no statics in domain code; prefer `final` fields; concretes immutable. Exact public names: `Bitmap`, `ConstBitmap`, `GdiText`, `ImmediateGraphic`, `AutoFont`, `Script`.
- **Tests** (`docs/style/general.md`): every new branch lands with a test; each test declares a `final expected = …` (or `const`) before exercising the unit and asserts against it.
- **GW wire format:** `GWx,y,widthBytes,heightPixels,<raster>` then LF. Raster is row-by-row, each row padded to a whole byte, **bit 1 = white/blank, bit 0 = black**; trailing pad bits in the last byte of a row are set to **1** (white).
- **Rendering resolution:** 300 dpi (iX4-350). `sizePt → dots = round(sizePt / 72 * 300)`.
- **Imports in tests** reach into `package:argox_ix4/src/...` directly, matching the existing `test/usb/usb_device_test.dart`.

---

### Task 1: `Bitmap` seam + `ConstBitmap`

**Files:**
- Create: `lib/src/graphic/bitmap.dart`
- Test: `test/graphic/bitmap_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces: `abstract interface class Bitmap { int widthPixels(); int heightPixels(); int widthBytes(); List<int> bits(); }` and `class ConstBitmap implements Bitmap` with constructor `const ConstBitmap({required int widthPixels, required int heightPixels, required List<int> bits})`.

- [ ] **Step 1: Write the failing test**

```dart
// test/graphic/bitmap_test.dart
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `dart test test/graphic/bitmap_test.dart`
Expected: FAIL — `Error: Couldn't resolve the package 'argox_ix4' ... bitmap.dart` / "Bitmap isn't defined".

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/src/graphic/bitmap.dart
/// A 1-bit-per-pixel raster, already in PPLB `GW` form: bit 1 = white/blank,
/// bit 0 = black, each row padded to a whole byte.
abstract interface class Bitmap {
  /// Width of the image in pixels.
  int widthPixels();

  /// Height of the image in pixels (= number of raster rows).
  int heightPixels();

  /// Width of one raster row in bytes (`widthPixels` rounded up to a byte).
  int widthBytes();

  /// Packed raster bytes, `widthBytes() * heightPixels()` long.
  List<int> bits();
}

/// A [Bitmap] backed by literal dimensions and packed bytes.
class ConstBitmap implements Bitmap {
  const ConstBitmap({
    required int widthPixels,
    required int heightPixels,
    required List<int> bits,
  })  : _widthPixels = widthPixels,
        _heightPixels = heightPixels,
        _bits = bits;

  final int _widthPixels;
  final int _heightPixels;
  final List<int> _bits;

  @override
  int widthPixels() => _widthPixels;

  @override
  int heightPixels() => _heightPixels;

  @override
  int widthBytes() => (_widthPixels + 7) ~/ 8;

  @override
  List<int> bits() => _bits;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `dart test test/graphic/bitmap_test.dart`
Expected: PASS — `+2: All tests passed!`

- [ ] **Step 5: Commit**

```bash
git add lib/src/graphic/bitmap.dart test/graphic/bitmap_test.dart
git commit -m "feat: add Bitmap seam and ConstBitmap concrete"
```

---

### Task 2: `ImmediateGraphic` command (`GW`)

**Files:**
- Create: `lib/src/graphic/immediate_graphic.dart`
- Test: `test/graphic/immediate_graphic_test.dart`

**Interfaces:**
- Consumes: `Bitmap` from Task 1; `Command` from `package:pplb/pplb.dart` (`abstract interface class Command { List<int> bytes(); }`).
- Produces: `class ImmediateGraphic implements Command` with constructor `const ImmediateGraphic({required int x, required int y, required Bitmap bitmap})`.

- [ ] **Step 1: Write the failing test**

```dart
// test/graphic/immediate_graphic_test.dart
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
    final actual =
        const ImmediateGraphic(x: 30, y: 40, bitmap: bitmap).bytes();
    expect(actual, expected);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `dart test test/graphic/immediate_graphic_test.dart`
Expected: FAIL — "ImmediateGraphic isn't defined".

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/src/graphic/immediate_graphic.dart
import 'dart:convert';
import 'package:pplb/pplb.dart';
import 'bitmap.dart';

/// PPLB `GW` — prints an immediate (one-shot) 1-bpp graphic.
///
/// `GWx,y,widthBytes,heightPixels,<raster bytes>` then LF. The image is
/// cleared by the printer after printing and cannot be recalled.
class ImmediateGraphic implements Command {
  const ImmediateGraphic({
    required this.x,
    required this.y,
    required this.bitmap,
  });

  /// X origin in dots.
  final int x;

  /// Y origin in dots.
  final int y;

  /// The raster to print.
  final Bitmap bitmap;

  @override
  List<int> bytes() => [
        ...ascii.encode(
          'GW$x,$y,${bitmap.widthBytes()},${bitmap.heightPixels()},',
        ),
        ...bitmap.bits(),
        ...ascii.encode('\n'),
      ];
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `dart test test/graphic/immediate_graphic_test.dart`
Expected: PASS — `+1: All tests passed!`

- [ ] **Step 5: Commit**

```bash
git add lib/src/graphic/immediate_graphic.dart test/graphic/immediate_graphic_test.dart
git commit -m "feat: add ImmediateGraphic GW command"
```

---

### Task 3: `Script` + `AutoFont`

**Files:**
- Create: `lib/src/graphic/auto_font.dart`
- Test: `test/graphic/auto_font_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces: `enum Script { hangul, kana, han, latin }` and `class AutoFont` with constructor `const AutoFont(String text, {Map<Script, String> faces})` and method `String name()`.

- [ ] **Step 1: Write the failing test**

```dart
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `dart test test/graphic/auto_font_test.dart`
Expected: FAIL — "AutoFont isn't defined" / "Script isn't defined".

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/src/graphic/auto_font.dart
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
  String name() => _faces[_script()]!;

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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `dart test test/graphic/auto_font_test.dart`
Expected: PASS — `+6: All tests passed!`

- [ ] **Step 5: Commit**

```bash
git add lib/src/graphic/auto_font.dart test/graphic/auto_font_test.dart
git commit -m "feat: add AutoFont script-to-face detection"
```

---

### Task 4: `GdiText` GDI rasterizer (Windows-only, FFI)

**Files:**
- Create: `lib/src/graphic/gdi_text.dart`
- Test: `test/graphic/gdi_text_test.dart`

**Interfaces:**
- Consumes: `Bitmap` (Task 1), `AutoFont` (Task 3), `ensureWindowsPlatform(isWindows: bool)` from `lib/src/usb_printer.dart`.
- Produces: `class GdiText implements Bitmap` with constructor `GdiText(String text, {String? font, double sizePt = 12, bool bold = false})`.

**Note on win32 symbol names:** this task uses gdi32 bindings and constants from `package:win32`. Some constant names shifted across win32 5.x. Step 5 compiles the file and Step 6 fixes any symbol-name mismatches before the test runs — that is a real verification step, not a placeholder.

- [ ] **Step 1: Write the failing test (Windows-guarded smoke test)**

```dart
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `dart test test/graphic/gdi_text_test.dart`
Expected: FAIL — "GdiText isn't defined" (on Windows). On non-Windows the file is skipped via `@TestOn('windows')`; develop/verify this task on Windows.

- [ ] **Step 3: Write the implementation**

```dart
// lib/src/graphic/gdi_text.dart
import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';
import 'auto_font.dart';
import 'bitmap.dart';
import '../usb_printer.dart' show ensureWindowsPlatform;

/// A [Bitmap] produced by rasterizing [text] with the Windows GDI font stack.
///
/// Windows-only: constructing off Windows throws [UnsupportedError]. The raster
/// is built once, in the constructor, already in PPLB `GW` form (1 = white,
/// 0 = black, rows byte-padded). If `font` is null, [AutoFont] picks the face
/// by the text's dominant script. One line only — no embedded newlines.
class GdiText implements Bitmap {
  GdiText(
    String text, {
    String? font,
    double sizePt = 12,
    bool bold = false,
  }) {
    ensureWindowsPlatform(isWindows: Platform.isWindows);
    _rasterize(text, font ?? AutoFont(text).name(), sizePt, bold);
  }

  /// iX4-350 print resolution.
  static const _dpi = 300;
  static const _white = 0x00FFFFFF; // COLORREF 0x00BBGGRR
  static const _black = 0x00000000;

  late final int _widthPixels;
  late final int _heightPixels;
  late final List<int> _bits;

  @override
  int widthPixels() => _widthPixels;

  @override
  int heightPixels() => _heightPixels;

  @override
  int widthBytes() => (_widthPixels + 7) ~/ 8;

  @override
  List<int> bits() => _bits;

  void _rasterize(String text, String face, double sizePt, bool bold) {
    final hdc = CreateCompatibleDC(NULL);
    if (hdc == NULL) {
      throw StateError('CreateCompatibleDC failed (${GetLastError()}).');
    }
    final facePtr = face.toNativeUtf16();
    final textPtr = text.toNativeUtf16();
    final size = calloc<SIZE>();
    final cHeight = -((sizePt * _dpi / 72).round());
    final hFont = CreateFont(
      cHeight, 0, 0, 0,
      bold ? FW_BOLD : FW_NORMAL,
      FALSE, FALSE, FALSE,
      DEFAULT_CHARSET,
      OUT_DEFAULT_PRECIS,
      CLIP_DEFAULT_PRECIS,
      NONANTIALIASED_QUALITY,
      DEFAULT_PITCH | FF_DONTCARE,
      facePtr,
    );
    var hBitmap = NULL;
    Pointer<BITMAPINFO> bmi = nullptr;
    Pointer<Pointer<Void>> ppvBits = nullptr;
    try {
      final oldFont = SelectObject(hdc, hFont);
      if (GetTextExtentPoint32(hdc, textPtr, text.length, size) == FALSE) {
        throw StateError('GetTextExtentPoint32 failed (${GetLastError()}).');
      }
      _widthPixels = size.ref.cx;
      _heightPixels = size.ref.cy;

      bmi = _monochromeBmi(_widthPixels, _heightPixels);
      ppvBits = calloc<Pointer<Void>>();
      hBitmap = CreateDIBSection(hdc, bmi, DIB_RGB_COLORS, ppvBits, NULL, 0);
      if (hBitmap == NULL) {
        throw StateError('CreateDIBSection failed (${GetLastError()}).');
      }
      final oldBitmap = SelectObject(hdc, hBitmap);

      // DIB rows are DWORD-aligned. Pre-fill white so the background is bit 1.
      final stride = ((_widthPixels + 31) ~/ 32) * 4;
      final raw = ppvBits.value.cast<Uint8>();
      final total = stride * _heightPixels;
      for (var i = 0; i < total; i++) {
        raw[i] = 0xFF;
      }

      SetBkMode(hdc, TRANSPARENT);
      SetTextColor(hdc, _black);
      SetBkColor(hdc, _white);
      ExtTextOut(hdc, 0, 0, 0, nullptr, textPtr, text.length, nullptr);
      GdiFlush();

      _bits = _packRows(raw, _widthPixels, _heightPixels, stride);

      SelectObject(hdc, oldBitmap);
      SelectObject(hdc, oldFont);
    } finally {
      if (hBitmap != NULL) DeleteObject(hBitmap);
      if (hFont != NULL) DeleteObject(hFont);
      if (ppvBits != nullptr) calloc.free(ppvBits);
      if (bmi != nullptr) calloc.free(bmi);
      calloc.free(size);
      calloc.free(textPtr);
      calloc.free(facePtr);
      DeleteDC(hdc);
    }
  }

  /// A 1-bpp top-down [BITMAPINFO] with a black(0)/white(1) color table.
  Pointer<BITMAPINFO> _monochromeBmi(int width, int height) {
    final headerSize = sizeOf<BITMAPINFOHEADER>();
    final quadSize = sizeOf<RGBQUAD>();
    final mem = calloc<Uint8>(headerSize + 2 * quadSize);
    final bmi = mem.cast<BITMAPINFO>();
    bmi.ref.bmiHeader
      ..biSize = headerSize
      ..biWidth = width
      ..biHeight = -height // negative => top-down
      ..biPlanes = 1
      ..biBitCount = 1
      ..biCompression = BI_RGB
      ..biClrUsed = 2
      ..biClrImportant = 2;
    final colors = (mem + headerSize).cast<RGBQUAD>();
    colors[0]
      ..rgbBlue = 0
      ..rgbGreen = 0
      ..rgbRed = 0
      ..rgbReserved = 0; // index 0 = black
    colors[1]
      ..rgbBlue = 0xFF
      ..rgbGreen = 0xFF
      ..rgbRed = 0xFF
      ..rgbReserved = 0; // index 1 = white
    return bmi;
  }

  /// Copies each DWORD-aligned DIB row down to a byte-padded GW row, setting the
  /// trailing pad bits of the last byte to 1 (white).
  List<int> _packRows(Pointer<Uint8> src, int width, int height, int stride) {
    final widthBytes = (width + 7) ~/ 8;
    final padBits = width % 8; // valid leading bits in the last byte
    final padMask = padBits == 0 ? 0 : (0xFF >> padBits);
    final out = <int>[];
    for (var y = 0; y < height; y++) {
      final rowStart = y * stride;
      for (var b = 0; b < widthBytes; b++) {
        var byte = src[rowStart + b];
        if (b == widthBytes - 1 && padMask != 0) {
          byte |= padMask; // pad with white
        }
        out.add(byte);
      }
    }
    return out;
  }
}
```

- [ ] **Step 4: Analyze for symbol-name correctness**

Run: `dart analyze lib/src/graphic/gdi_text.dart`
Expected: ideally "No issues found!". If win32 reports an undefined name (e.g. a constant moved into an enum, or `GetTextExtentPoint32` exported under a variant name), open the win32 package source and correct the symbol, keeping the same value/behavior. Re-run until clean. Common ones to verify in the installed `win32 ^5.5.0`: `CreateFont`, `GetTextExtentPoint32`, `ExtTextOut`, `CreateDIBSection`, `GdiFlush`, `SIZE`, `BITMAPINFO`, `BITMAPINFOHEADER`, `RGBQUAD`, `FW_BOLD`, `FW_NORMAL`, `DEFAULT_CHARSET`, `OUT_DEFAULT_PRECIS`, `CLIP_DEFAULT_PRECIS`, `NONANTIALIASED_QUALITY`, `DEFAULT_PITCH`, `FF_DONTCARE`, `BI_RGB`, `DIB_RGB_COLORS`, `TRANSPARENT`, `NULL`, `FALSE`.

- [ ] **Step 5: Run test to verify it passes (on Windows)**

Run: `dart test test/graphic/gdi_text_test.dart`
Expected: PASS — `+1: All tests passed!` (a glyph rendered to a non-empty, correctly-sized raster).

- [ ] **Step 6: Commit**

```bash
git add lib/src/graphic/gdi_text.dart test/graphic/gdi_text_test.dart
git commit -m "feat: add GdiText GDI rasterizer"
```

---

### Task 5: Wire up exports, example, and docs

**Files:**
- Modify: `lib/argox_ix4.dart` (add three exports)
- Create: `example/print_cjk.dart`
- Modify: `CHANGELOG.md:1` (new entry), `README.md` (new section)
- Test: full suite + analyze (no new test file; this task wires existing units together)

**Interfaces:**
- Consumes: everything from Tasks 1–4.
- Produces: public exports of `bitmap.dart`, `immediate_graphic.dart`, `auto_font.dart`, `gdi_text.dart`.

- [ ] **Step 1: Add the exports**

Append to `lib/argox_ix4.dart`, after the existing `export 'src/usb_printer.dart';`:

```dart
export 'src/graphic/bitmap.dart';
export 'src/graphic/immediate_graphic.dart';
export 'src/graphic/auto_font.dart';
export 'src/graphic/gdi_text.dart';
```

- [ ] **Step 2: Verify the package still analyzes and all tests pass**

Run: `dart analyze`
Expected: "No issues found!"

Run: `dart test`
Expected: PASS — all existing tests plus `bitmap_test`, `immediate_graphic_test`, `auto_font_test` (the `gdi_text_test` runs only on Windows). `All tests passed!`

- [ ] **Step 3: Create the example (manual hardware verification artifact)**

```dart
// example/print_cjk.dart
// Prints four lines — Chinese, Japanese, Korean, ASCII — each rasterized with
// Windows GDI and sent via the PPLB GW command. Requires a connected iX4 with
// media loaded. Pure ASCII could also use the lighter resident Text (A) command.
import 'package:argox_ix4/argox_ix4.dart';

Future<void> main() async {
  final label = CommandLabel([
    const BufferClear(),
    const LabelWidth(990),
    const LabelDimensions(length: 630, gap: 35),
    ImmediateGraphic(x: 45, y: 45, bitmap: GdiText('中文標籤', sizePt: 18)),
    ImmediateGraphic(x: 45, y: 140, bitmap: GdiText('日本語ラベル', sizePt: 18)),
    ImmediateGraphic(x: 45, y: 235, bitmap: GdiText('한국어 라벨', sizePt: 18)),
    ImmediateGraphic(x: 45, y: 330, bitmap: GdiText('ASCII 123', sizePt: 18)),
    const Copies(1),
  ]);

  await const UsbPrinter().print(label);
  print('CJK label sent');
}
```

- [ ] **Step 4: Verify the example compiles**

Run: `dart analyze example/print_cjk.dart`
Expected: "No issues found!"

- [ ] **Step 5: Update CHANGELOG and README**

Prepend to `CHANGELOG.md` (above the top entry):

```markdown
## 0.2.0

- Add bitmap text printing: `GdiText` rasterizes any string (CJK/Latin) with the
  Windows GDI font stack, `ImmediateGraphic` sends it via the PPLB `GW` command,
  and `AutoFont` picks a font face by the text's dominant script. The iX4-350 has
  no Asian font board, so CJK is printed as a 1-bpp graphic. `Bitmap`/`ConstBitmap`
  expose the raster seam.

```

Add a section to `README.md` after the existing usage block:

```markdown
## Printing CJK / non-Latin text

The resident printer fonts are Latin-only and this unit has no Asian font board,
so Chinese/Japanese/Korean text is printed as a bitmap: `GdiText` renders the
string with a Windows font (GDI), and `ImmediateGraphic` sends it via the PPLB
`GW` command. `AutoFont` picks the face by dominant script (override with `font:`).

```dart
await const UsbPrinter().print(CommandLabel([
  const BufferClear(),
  const LabelWidth(990),
  const LabelDimensions(length: 630, gap: 35),
  ImmediateGraphic(x: 45, y: 45, bitmap: GdiText('中文標籤', sizePt: 18)),
  ImmediateGraphic(x: 45, y: 140, bitmap: GdiText('日本語ラベル', sizePt: 18)),
  ImmediateGraphic(x: 45, y: 235, bitmap: GdiText('한국어 라벨', sizePt: 18)),
  const Copies(1),
]));
```

> Han-only text can't be distinguished as Chinese vs Japanese (Han unification);
> it defaults to a Chinese face — pass `font: 'MS Gothic'` (etc.) to override.
```

- [ ] **Step 6: Bump the package version**

In `pubspec.yaml`, set `version: 0.2.0` (matching the new CHANGELOG heading).

- [ ] **Step 7: Final full verification**

Run: `dart analyze`
Expected: "No issues found!"

Run: `dart test`
Expected: PASS — `All tests passed!`

- [ ] **Step 8: Commit**

```bash
git add lib/argox_ix4.dart example/print_cjk.dart CHANGELOG.md README.md pubspec.yaml
git commit -m "feat: expose CJK bitmap printing; example, docs, version 0.2.0"
```

- [ ] **Step 9: Hardware verification (manual — cannot be automated)**

With an iX4 connected and media loaded, run: `dart run example/print_cjk.dart`
Expected: a label bearing four legible lines — `中文標籤`, `日本語ラベル`, `한국어 라벨`, `ASCII 123`. This is the true verification of the GDI path; confirm by eye. If a CJK line prints as tofu (□), the chosen font lacks those glyphs — pass an explicit `font:`.

---

## Self-Review

**1. Spec coverage:**
- `Bitmap` seam + `ConstBitmap` → Task 1. ✓
- `ImmediateGraphic` / `GW` framing → Task 2. ✓
- `AutoFont` + `Script` (dominant-script, defaults, override, Han-unification note) → Task 3. ✓
- `GdiText` approach-A GDI rasterization, eager-in-constructor, `UnsupportedError` off Windows, `StateError` on GDI failure, `finally` cleanup, 1=white/0=black color table, byte-padded rows with pad=1 → Task 4. ✓
- Exports, four-line sample (incl. ASCII line), docs → Task 5. ✓
- Testing split (pure on CI, GDI Windows-guarded + hardware) → Tasks 1–4 tests + Task 5 Step 9. ✓
- No new dependency, SDK floor, 300 dpi → Global Constraints + Task 4. ✓

**2. Placeholder scan:** No "TBD"/"handle edge cases"/"similar to Task N". The one judgement step (Task 4 Step 4, win32 symbol verification) shows the exact command and the named symbols to check — a real step, not a placeholder.

**3. Type consistency:** `Bitmap` methods (`widthPixels`/`heightPixels`/`widthBytes`/`bits`) are identical across `ConstBitmap` (Task 1), `ImmediateGraphic`'s usage (Task 2), and `GdiText` (Task 4). `AutoFont(text, {faces}).name()` and `Script` match between Task 3 and Task 4's call `AutoFont(text).name()`. `ImmediateGraphic({x, y, bitmap})` matches between Task 2 and Task 5's example. `GdiText(text, {font, sizePt, bold})` matches Task 4 and Task 5.
