import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';
import 'auto_font.dart';
import 'bitmap.dart';
import 'gdi_raster.dart';
import 'wrap_lines.dart';
import '../usb_printer.dart' show ensureWindowsPlatform;

/// A [Bitmap] of [text] wrapped to [maxWidthDots] and rasterized with GDI.
///
/// Words break on spaces; a word wider than the box breaks between characters
/// (so CJK wraps). If the wrapped text needs more than [maxLines] at [sizePt],
/// the font shrinks (down to [minSizePt]) until it fits, then any overflow is
/// clipped. The bitmap height is fixed at
/// `clamp(lineCount, minLines, maxLines) * nominalLineHeight` (nominal = the
/// line height at the requested [sizePt]), so it does not change when the font
/// shrinks — a consumer's layout below stays put. Windows-only.
class GdiParagraph implements Bitmap {
  GdiParagraph(
    String text, {
    required int maxWidthDots,
    String? font,
    double sizePt = 12,
    int minLines = 1,
    int maxLines = 1,
    double minSizePt = 8,
    bool bold = false,
  }) {
    if (maxWidthDots <= 0) {
      throw ArgumentError.value(maxWidthDots, 'maxWidthDots', 'must be > 0');
    }
    if (minLines < 1 || minLines > maxLines) {
      throw ArgumentError('require 1 <= minLines <= maxLines '
          '(got minLines=$minLines, maxLines=$maxLines)');
    }
    if (minSizePt <= 0 || minSizePt > sizePt) {
      throw ArgumentError('require 0 < minSizePt <= sizePt '
          '(got minSizePt=$minSizePt, sizePt=$sizePt)');
    }
    ensureWindowsPlatform(isWindows: Platform.isWindows);
    _rasterize(text, font ?? AutoFont(text).name(), maxWidthDots, sizePt,
        minLines, maxLines, minSizePt, bold);
  }

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

  void _rasterize(String text, String face, int maxWidthDots, double sizePt,
      int minLines, int maxLines, double minSizePt, bool bold) {
    final hdc = CreateCompatibleDC(NULL);
    if (hdc == NULL) {
      throw StateError('CreateCompatibleDC failed (${GetLastError()}).');
    }
    try {
      // Nominal line height (at the requested sizePt) fixes the reserved slot.
      final nominalLineHeight =
          _measureLineHeight(hdc, face, sizePt, bold: bold);

      // Largest size in [minSizePt, sizePt] whose wrap fits maxLines.
      var chosenSize = sizePt;
      var lines =
          _wrapAt(hdc, text, face, chosenSize, maxWidthDots, bold: bold);
      while (lines.length > maxLines && chosenSize > minSizePt) {
        chosenSize = (chosenSize - 1).clamp(minSizePt, sizePt).toDouble();
        lines = _wrapAt(hdc, text, face, chosenSize, maxWidthDots, bold: bold);
      }
      if (lines.length > maxLines) {
        lines = lines.sublist(0, maxLines); // clip overflow at the floor
      }

      final reservedLines = lines.length.clamp(minLines, maxLines);
      final chosenLineHeight =
          _measureLineHeight(hdc, face, chosenSize, bold: bold);

      _renderLines(hdc, face, chosenSize, bold, lines, maxWidthDots,
          reservedLines, nominalLineHeight, chosenLineHeight);
    } finally {
      DeleteDC(hdc);
    }
  }

  int _measureLineHeight(int hdc, String face, double sizePt,
      {required bool bold}) {
    final lf = gdiLogFont(sizePt, face, bold: bold);
    final hFont = CreateFontIndirect(lf);
    final old = SelectObject(hdc, hFont);
    try {
      return gdiTextHeight(hdc, 'Ag');
    } finally {
      SelectObject(hdc, old);
      DeleteObject(hFont);
      calloc.free(lf);
    }
  }

  List<String> _wrapAt(
      int hdc, String text, String face, double sizePt, int maxWidthDots,
      {required bool bold}) {
    final lf = gdiLogFont(sizePt, face, bold: bold);
    final hFont = CreateFontIndirect(lf);
    final old = SelectObject(hdc, hFont);
    try {
      return wrapLines(text,
          maxWidth: maxWidthDots, measure: (s) => gdiTextWidth(hdc, s));
    } finally {
      SelectObject(hdc, old);
      DeleteObject(hFont);
      calloc.free(lf);
    }
  }

  void _renderLines(
    int hdc,
    String face,
    double chosenSize,
    bool bold,
    List<String> lines,
    int maxWidthDots,
    int reservedLines,
    int nominalLineHeight,
    int chosenLineHeight,
  ) {
    final lf = gdiLogFont(chosenSize, face, bold: bold);
    final hFont = CreateFontIndirect(lf);
    final oldFont = SelectObject(hdc, hFont);

    var width = 1;
    for (final line in lines) {
      final w = gdiTextWidth(hdc, line);
      if (w > width) width = w;
    }
    if (width > maxWidthDots) width = maxWidthDots;
    final height = reservedLines * nominalLineHeight;

    final bmi = gdiMonochromeBmi(width, height);
    final ppvBits = calloc<Pointer<NativeType>>();
    var hBitmap = NULL;
    var oldBitmap = NULL;
    try {
      hBitmap = CreateDIBSection(
          hdc, bmi, DIB_USAGE.DIB_RGB_COLORS, ppvBits.cast(), NULL, 0);
      if (hBitmap == NULL) {
        throw StateError('CreateDIBSection failed (${GetLastError()}).');
      }
      oldBitmap = SelectObject(hdc, hBitmap);

      final stride = ((width + 31) ~/ 32) * 4;
      final raw = ppvBits.value.cast<Uint8>();
      final total = stride * height;
      for (var i = 0; i < total; i++) {
        raw[i] = 0xFF; // white background
      }

      SetBkMode(hdc, BACKGROUND_MODE.TRANSPARENT);
      SetTextColor(hdc, gdiBlack);
      SetBkColor(hdc, gdiWhite);
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (line.isEmpty) continue;
        final ptr = line.toNativeUtf16();
        try {
          ExtTextOut(hdc, 0, i * chosenLineHeight, 0, nullptr, ptr, line.length,
              nullptr);
        } finally {
          calloc.free(ptr);
        }
      }
      gdiFlush();

      _widthPixels = width;
      _heightPixels = height;
      _bits = gdiPackRows(raw, width, height, stride);
    } finally {
      if (oldBitmap != NULL) SelectObject(hdc, oldBitmap);
      SelectObject(hdc, oldFont);
      if (hBitmap != NULL) DeleteObject(hBitmap);
      DeleteObject(hFont);
      calloc.free(ppvBits);
      calloc.free(bmi);
      calloc.free(lf);
    }
  }
}
