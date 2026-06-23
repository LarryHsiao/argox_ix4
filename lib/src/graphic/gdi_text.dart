// lib/src/graphic/gdi_text.dart
import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';
import 'auto_font.dart';
import 'bitmap.dart';
import '../usb_printer.dart' show ensureWindowsPlatform;

// ---------- constants absent from win32 5.5.0 ----------
// Font weight (LOGFONT.lfWeight). Not exported by win32 5.5.0.
const _fwNormal = 400;
const _fwBold = 700;

// Pitch and family byte (LOGFONT.lfPitchAndFamily).
// DEFAULT_PITCH (0x00) | FF_DONTCARE (0x00) = 0. Not exported by win32 5.5.0.
const _pitchAndFamily = 0;
// -------------------------------------------------------

// ---------- manual FFI bindings absent from win32 5.5.0 ----------
final _gdi32 = DynamicLibrary.open('gdi32.dll');

/// `BOOL GetTextExtentPoint32W(HDC hdc, LPCWSTR lpString, int c, LPSIZE psizl)`
final _getTextExtentPoint32 = _gdi32.lookupFunction<
    Int32 Function(
        IntPtr hdc, Pointer<Utf16> lpString, Int32 c, Pointer<SIZE> psizl),
    int Function(int hdc, Pointer<Utf16> lpString, int c,
        Pointer<SIZE> psizl)>('GetTextExtentPoint32W');

/// `BOOL GdiFlush()`
final _gdiFlush =
    _gdi32.lookupFunction<Int32 Function(), int Function()>('GdiFlush');
// -----------------------------------------------------------------

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
    final textPtr = text.toNativeUtf16();
    final size = calloc<SIZE>();
    final lf = calloc<LOGFONT>();
    final cHeight = -((sizePt * _dpi / 72).round());
    lf.ref
      ..lfHeight = cHeight
      ..lfWeight = bold ? _fwBold : _fwNormal
      ..lfItalic = FALSE
      ..lfUnderline = FALSE
      ..lfStrikeOut = FALSE
      ..lfCharSet = FONT_CHARSET.DEFAULT_CHARSET
      ..lfOutPrecision = FONT_OUTPUT_PRECISION.OUT_DEFAULT_PRECIS
      ..lfClipPrecision = FONT_CLIP_PRECISION.CLIP_DEFAULT_PRECIS
      ..lfQuality = FONT_QUALITY.NONANTIALIASED_QUALITY
      ..lfPitchAndFamily = _pitchAndFamily
      ..lfFaceName = face;
    final hFont = CreateFontIndirect(lf);
    var hBitmap = NULL;
    var oldFont = NULL;
    var oldBitmap = NULL;
    Pointer<BITMAPINFO> bmi = nullptr;
    Pointer<Pointer<NativeType>> ppvBits = nullptr;
    try {
      if (hFont == NULL) {
        throw StateError('CreateFontIndirect failed (${GetLastError()}).');
      }
      oldFont = SelectObject(hdc, hFont);
      if (_getTextExtentPoint32(hdc, textPtr, text.length, size) == FALSE) {
        throw StateError('GetTextExtentPoint32 failed (${GetLastError()}).');
      }
      _widthPixels = size.ref.cx;
      _heightPixels = size.ref.cy;

      bmi = _monochromeBmi(_widthPixels, _heightPixels);
      ppvBits = calloc<Pointer<NativeType>>();
      hBitmap = CreateDIBSection(
          hdc, bmi, DIB_USAGE.DIB_RGB_COLORS, ppvBits.cast(), NULL, 0);
      if (hBitmap == NULL) {
        throw StateError('CreateDIBSection failed (${GetLastError()}).');
      }
      oldBitmap = SelectObject(hdc, hBitmap);

      // DIB rows are DWORD-aligned. Pre-fill white so the background is bit 1.
      final stride = ((_widthPixels + 31) ~/ 32) * 4;
      final raw = ppvBits.value.cast<Uint8>();
      final total = stride * _heightPixels;
      for (var i = 0; i < total; i++) {
        raw[i] = 0xFF;
      }

      SetBkMode(hdc, BACKGROUND_MODE.TRANSPARENT);
      SetTextColor(hdc, _black);
      SetBkColor(hdc, _white);
      ExtTextOut(hdc, 0, 0, 0, nullptr, textPtr, text.length, nullptr);
      _gdiFlush();

      _bits = _packRows(raw, _widthPixels, _heightPixels, stride);
    } finally {
      if (oldBitmap != NULL) SelectObject(hdc, oldBitmap);
      if (oldFont != NULL) SelectObject(hdc, oldFont);
      if (hBitmap != NULL) DeleteObject(hBitmap);
      if (hFont != NULL) DeleteObject(hFont);
      if (ppvBits != nullptr) calloc.free(ppvBits);
      if (bmi != nullptr) calloc.free(bmi);
      calloc.free(lf);
      calloc.free(size);
      calloc.free(textPtr);
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
