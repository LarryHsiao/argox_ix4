# Bitmap text printing via `GW` — design

**Date:** 2026-06-23
**Status:** approved (pending written-spec review)
**Package:** `argox_ix4`

## Problem

The printer cannot render Chinese / Japanese / Korean text.

1. **The command layer can't encode it.** `pplb`'s `Text` (the `A` command)
   calls `ascii.encode()`, which throws on any byte above 127 — CJK never
   reaches the wire. (Verified by dry-run: all of zh/ja/ko fail with
   "Contains invalid characters".)
2. **The printer has no Asian fonts.** The PPLB symbol-set command (`I`) offers
   only Latin/Cyrillic/Greek code pages. CJK is reachable only via the optional
   font board (font IDs 7–12) — which this iX4-350 **does not have** (hardware
   probe printed nothing for fonts 7/9/11).
3. **`pplb` has no graphics command.** Its command set is text, barcodes, lines,
   boxes — no way to send a bitmap.

The remaining route, supported on every iX4 model, is the PPLB `GW` command
(Print Immediate Graphics): rasterize text to a 1-bpp bitmap and send the raster.
Since this package is already Windows-only (`dart:ffi` + `win32`), we rasterize
with the Windows GDI font stack — the OS already carries CJK fonts.

## Scope

A general **"render any string to a bitmap and print it"** capability — it
serves CJK, Latin, mixed scripts, any installed font. The CJK case *is* the
general case here, so there is no extra cost to generality. Out of scope:
arbitrary image/logo files, text rotation, soft-font download, the font board.

## PPLB `GW` — wire format (from the spec, 2016-08-29)

```
GWp1,p2,p3,p4,[...raster image...]
  p1: X coordinate in dots
  p2: Y coordinate in dots
  p3: graphic width in BYTES
  p4: height in PIXELS
  raster: row by row, no compression; each row padded to a byte boundary;
          bit 1 = blank/white pixel, bit 0 = black pixel.
  The image is cleared after printing (cannot be recalled).
```

## Architecture

Domain-object style, consistent with `UsbDevice` / `UsbPrinter`: a seam, concrete
sources, a `Command`. All names are nouns; no statics; no `-er`/`-or` suffixes.

```
Bitmap (abstract interface)   widthPixels() · heightPixels() · widthBytes() · bits()
 ├─ ConstBitmap               literal bits — cross-platform, used by tests
 └─ GdiText                   rasterizes a string via Windows GDI (FFI, Windows-only)

ImmediateGraphic             implements pplb Command — frames the GW bytes
AutoFont                     picks a font face from a string's dominant script
Script (enum)                hangul · kana · han · latin
```

### `Bitmap` seam

```dart
abstract interface class Bitmap {
  int widthPixels();
  int heightPixels();
  int widthBytes();   // ceil(widthPixels / 8)
  List<int> bits();   // packed rows, widthBytes * heightPixels long, GW convention
}
```

`bits()` already follows the `GW` convention (1=white, 0=black, rows
byte-padded), so `ImmediateGraphic` does no transformation.

### `ConstBitmap` concrete

Wraps given dimensions and bytes verbatim. Immutable. Lets tests and callers
build a bitmap without GDI, so the `GW` framing is testable off Windows.

### `GdiText` concrete (Windows-only, FFI)

Constructor: `GdiText(String text, {String? font, double sizePt = 12, bool bold = false})`.
Rasterizes via approach A:

1. `ensureWindowsPlatform(isWindows: Platform.isWindows)` — throws
   `UnsupportedError` off Windows (reuses the existing guard).
2. `CreateCompatibleDC(NULL)` — a memory DC.
3. `CreateFontW(face, heightInDots, bold, …)` where `heightInDots = round(sizePt / 72 * 300)`
   and `face = font ?? AutoFont(text).name()`; `SelectObject` it.
4. `GetTextExtentPoint32W(dc, text, len, size)` — measure width/height in pixels.
5. `CreateDIBSection` — a 1-bpp top-down DIB sized to the measurement, with a
   2-entry color table set so **white → bit 1, black → bit 0** (matches `GW`
   directly; no inversion pass). `SelectObject` it into the DC.
6. `SetBkColor` white, `SetTextColor` black, `SetBkMode(OPAQUE)`.
7. `ExtTextOutW` — draw the string at (0,0).
8. Read the DIB's bit buffer directly (a DIB section exposes a pointer to the
   bits) into `List<int>`, one byte-padded row at a time.
9. Release every GDI object and FFI buffer in `finally` (DC, font, DIB, native
   strings) — the same `calloc`/`free` discipline as `UsbPrinter`.

Rasterization runs once, eagerly in the constructor; the resulting bytes back
`widthPixels`/`heightPixels`/`widthBytes`/`bits`. Constructing a `GdiText` off
Windows therefore throws immediately (via the platform guard), not on first
`bits()` call. `GdiText` is consequently not `const`; `ImmediateGraphic` keeps a
`const` constructor, invoked non-`const` whenever it wraps a `GdiText`.

### `ImmediateGraphic` Command

```dart
class ImmediateGraphic implements Command {
  const ImmediateGraphic({required this.x, required this.y, required this.bitmap});
  final int x; final int y; final Bitmap bitmap;

  @override
  List<int> bytes() => [
    ...ascii.encode('GW$x,$y,${bitmap.widthBytes()},${bitmap.heightPixels()},'),
    ...bitmap.bits(),
    ...ascii.encode('\n'),
  ];
}
```

Pure byte assembly — cross-platform, fully testable. The constructor takes a
named `bitmap` (as shown), `x`, and `y`.

### `AutoFont` + `Script`

`AutoFont(text, {Map<Script,String>? faces})` picks the face by **dominant
script**, unambiguous-first: any Hangul → Korean; else any Kana → Japanese; else
any Han → Chinese; else Latin. `name()` returns the chosen face.

Default faces (chosen for Windows 7+ availability; overridable per call and via
the `faces` map):

| Script | Default face          |
|--------|-----------------------|
| Hangul | `Malgun Gothic`       |
| Kana   | `MS Gothic`           |
| Han    | `Microsoft JhengHei`  |
| Latin  | `Segoe UI`            |

**Known limitation:** Han-only text cannot be classified zh vs ja (Han
unification); it defaults to Chinese. Pass `font:` explicitly for Japanese
Han-only lines. The explicit `font:` parameter always overrides detection.

## Data flow

```
GdiText(text)  --rasterize-->  bits/dims
ImmediateGraphic(x,y,bitmap).bytes()  -->  GW header + bits + LF
CommandLabel([...]).bytes()  -->  concatenated command stream
UsbPrinter.print(label)  -->  usbprint.sys
```

Usage (the four-line verification sample):

```dart
await const UsbPrinter().print(CommandLabel([
  BufferClear(),
  LabelWidth(990),
  LabelDimensions(length: 630, gap: 35),
  ImmediateGraphic(x: 45, y: 45,  bitmap: GdiText('中文標籤', sizePt: 18)),    // Microsoft JhengHei
  ImmediateGraphic(x: 45, y: 140, bitmap: GdiText('日本語ラベル', sizePt: 18)), // MS Gothic
  ImmediateGraphic(x: 45, y: 235, bitmap: GdiText('한국어 라벨', sizePt: 18)),   // Malgun Gothic
  ImmediateGraphic(x: 45, y: 330, bitmap: GdiText('ASCII 123', sizePt: 18)), // Segoe UI
  Copies(1),
]));
```

Pure ASCII can still use the lighter resident `Text` (`A`) command — no bitmap
needed; `GdiText` is the path for anything the resident fonts cannot render.

## Error handling

- **Off Windows:** `GdiText` throws `UnsupportedError` via `ensureWindowsPlatform`.
  `ImmediateGraphic` and `AutoFont` are pure and run on any platform.
- **GDI failure:** a null/`INVALID` handle (`CreateCompatibleDC`,
  `CreateDIBSection`, `CreateFontW`) throws `StateError` carrying `GetLastError()`,
  mirroring `UsbPrinter._open`.
- **Resource safety:** every GDI handle and FFI allocation is released in
  `finally`, even on the throw paths.
- **Missing font:** if the named face is absent, GDI substitutes a default; CJK
  may render as tofu (□). This is a runtime/environment condition, surfaced by
  the printed output, not a thrown error — the `font:` override is the remedy.

## Testing

- **`ImmediateGraphic.bytes()`** — unit tests on CI with a `ConstBitmap` fake.
  Each test names a `final expected` (header string + row bytes) and asserts the
  built bytes equal it. Cross-platform.
- **`AutoFont`** — unit tests: `中文` → Han face, `日本語` (Kana present) → Kana
  face, `한국어` → Hangul face, `ABC` → Latin face, and a mixed-dominant case.
  Pure logic, cross-platform.
- **`GdiText`** — the FFI path cannot run on non-Windows CI. It gets a
  Windows-guarded smoke test (render `'A'`, assert plausible non-zero
  dimensions and a non-empty `bits()`), skipped elsewhere. Its true verification
  is the **printed four-line label**, confirmed on the iX4-350 by eye. This is
  stated plainly; the GDI rasterization is not claimed "tested" on the strength
  of CI alone.

## Files

```
lib/src/graphic/bitmap.dart            Bitmap interface + ConstBitmap
lib/src/graphic/immediate_graphic.dart ImmediateGraphic (Command)
lib/src/graphic/auto_font.dart         AutoFont + Script enum
lib/src/graphic/gdi_text.dart          GdiText (FFI, Windows-only)
test/graphic/immediate_graphic_test.dart
test/graphic/auto_font_test.dart
test/graphic/gdi_text_test.dart        (Windows-guarded smoke test)
```

Exports added to `lib/argox_ix4.dart`. Dependencies already present: `ffi`,
`win32` (gdi32 bindings). No new dependency.

## Out of scope (YAGNI)

Image/logo file printing, stored graphics (`GM`/`GK`), text rotation, soft-font
download, font-board support, antialiasing/grayscale (1-bpp thermal only).
