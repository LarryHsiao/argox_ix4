// lib/src/graphic/gdi_raster.dart
// Shared GDI rasterization helpers for GdiText and GdiParagraph.
import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

/// iX4-350 print resolution.
const int gdiNominalDpi = 300;

// LOGFONT.lfWeight values (not exported by win32 5.5.0).
const int gdiFwNormal = 400;
const int gdiFwBold = 700;

// DEFAULT_PITCH (0x00) | FF_DONTCARE (0x00).
const int _pitchAndFamily = 0;

// COLORREF 0x00BBGGRR.
const int gdiWhite = 0x00FFFFFF;
const int gdiBlack = 0x00000000;

final DynamicLibrary _gdi32 = DynamicLibrary.open('gdi32.dll');

final int Function(int, Pointer<Utf16>, int, Pointer<SIZE>)
    _getTextExtentPoint32 = _gdi32.lookupFunction<
        Int32 Function(
            IntPtr hdc, Pointer<Utf16> lpString, Int32 c, Pointer<SIZE> psizl),
        int Function(int hdc, Pointer<Utf16> lpString, int c,
            Pointer<SIZE> psizl)>('GetTextExtentPoint32W');

final int Function() gdiFlush =
    _gdi32.lookupFunction<Int32 Function(), int Function()>('GdiFlush');

/// LOGFONT lfHeight for [sizePt] at 300 dpi (negative = character height).
int gdiFontHeight(double sizePt) => -((sizePt * gdiNominalDpi / 72).round());

/// Allocate + fill a LOGFONT. Caller frees with `calloc.free`.
Pointer<LOGFONT> gdiLogFont(double sizePt, String face, {required bool bold}) {
  final lf = calloc<LOGFONT>();
  lf.ref
    ..lfHeight = gdiFontHeight(sizePt)
    ..lfWeight = bold ? gdiFwBold : gdiFwNormal
    ..lfItalic = FALSE
    ..lfUnderline = FALSE
    ..lfStrikeOut = FALSE
    ..lfCharSet = FONT_CHARSET.DEFAULT_CHARSET
    ..lfOutPrecision = FONT_OUTPUT_PRECISION.OUT_DEFAULT_PRECIS
    ..lfClipPrecision = FONT_CLIP_PRECISION.CLIP_DEFAULT_PRECIS
    ..lfQuality = FONT_QUALITY.NONANTIALIASED_QUALITY
    ..lfPitchAndFamily = _pitchAndFamily
    ..lfFaceName = face;
  return lf;
}

SIZE _extent(int hdc, String s) {
  final ptr = s.toNativeUtf16();
  final size = calloc<SIZE>();
  try {
    if (_getTextExtentPoint32(hdc, ptr, s.length, size) == FALSE) {
      throw StateError('GetTextExtentPoint32 failed (${GetLastError()}).');
    }
    return size.ref;
  } finally {
    calloc.free(size);
    calloc.free(ptr);
  }
}

/// Rendered width of [s] in pixels under the font currently selected in [hdc].
int gdiTextWidth(int hdc, String s) => s.isEmpty ? 0 : _extent(hdc, s).cx;

/// Rendered height (line height) of [s] in pixels under the current font.
int gdiTextHeight(int hdc, String s) => s.isEmpty ? 0 : _extent(hdc, s).cy;

/// A 1-bpp top-down BITMAPINFO with a black(0)/white(1) colour table.
/// Caller frees with `calloc.free`.
Pointer<BITMAPINFO> gdiMonochromeBmi(int width, int height) {
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
    ..biCompression = BI_COMPRESSION.BI_RGB
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

/// Copies each DWORD-aligned DIB row to a byte-padded GW row, setting the
/// trailing pad bits of the last byte to 1 (white).
List<int> gdiPackRows(Pointer<Uint8> src, int width, int height, int stride) {
  final widthBytes = (width + 7) ~/ 8;
  final padBits = width % 8;
  final padMask = padBits == 0 ? 0 : (0xFF >> padBits);
  final out = <int>[];
  for (var y = 0; y < height; y++) {
    final rowStart = y * stride;
    for (var b = 0; b < widthBytes; b++) {
      var byte = src[rowStart + b];
      if (b == widthBytes - 1 && padMask != 0) {
        byte |= padMask;
      }
      out.add(byte);
    }
  }
  return out;
}
