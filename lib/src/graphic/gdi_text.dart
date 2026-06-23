// lib/src/graphic/gdi_text.dart
import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';
import 'auto_font.dart';
import 'bitmap.dart';
import 'gdi_raster.dart';
import '../usb_printer.dart' show ensureWindowsPlatform;

/// A [Bitmap] produced by rasterizing [text] as a single line with the Windows
/// GDI font stack. Windows-only. If `font` is null, [AutoFont] picks the face
/// by the text's dominant script. One line only — no wrapping. For wrapped,
/// multi-line text use `GdiParagraph`.
class GdiText implements Bitmap {
  GdiText(String text, {String? font, double sizePt = 12, bool bold = false}) {
    ensureWindowsPlatform(isWindows: Platform.isWindows);
    _rasterize(text, font ?? AutoFont(text).name(), sizePt, bold);
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

  void _rasterize(String text, String face, double sizePt, bool bold) {
    final hdc = CreateCompatibleDC(NULL);
    if (hdc == NULL) {
      throw StateError('CreateCompatibleDC failed (${GetLastError()}).');
    }
    final textPtr = text.toNativeUtf16();
    final lf = gdiLogFont(sizePt, face, bold: bold);
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
      _widthPixels = gdiTextWidth(hdc, text);
      _heightPixels = gdiTextHeight(hdc, text);

      bmi = gdiMonochromeBmi(_widthPixels, _heightPixels);
      ppvBits = calloc<Pointer<NativeType>>();
      hBitmap = CreateDIBSection(
          hdc, bmi, DIB_USAGE.DIB_RGB_COLORS, ppvBits.cast(), NULL, 0);
      if (hBitmap == NULL) {
        throw StateError('CreateDIBSection failed (${GetLastError()}).');
      }
      oldBitmap = SelectObject(hdc, hBitmap);

      final stride = ((_widthPixels + 31) ~/ 32) * 4;
      final raw = ppvBits.value.cast<Uint8>();
      final total = stride * _heightPixels;
      for (var i = 0; i < total; i++) {
        raw[i] = 0xFF;
      }

      SetBkMode(hdc, BACKGROUND_MODE.TRANSPARENT);
      SetTextColor(hdc, gdiBlack);
      SetBkColor(hdc, gdiWhite);
      ExtTextOut(hdc, 0, 0, 0, nullptr, textPtr, text.length, nullptr);
      gdiFlush();

      _bits = gdiPackRows(raw, _widthPixels, _heightPixels, stride);
    } finally {
      if (oldBitmap != NULL) SelectObject(hdc, oldBitmap);
      if (oldFont != NULL) SelectObject(hdc, oldFont);
      if (hBitmap != NULL) DeleteObject(hBitmap);
      if (hFont != NULL) DeleteObject(hFont);
      if (ppvBits != nullptr) calloc.free(ppvBits);
      if (bmi != nullptr) calloc.free(bmi);
      calloc.free(lf);
      calloc.free(textPtr);
      DeleteDC(hdc);
    }
  }
}
