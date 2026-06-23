/// Windows USB transport for ARGOX iX4-series PPLB label printers.
///
/// Opens the inbox `usbprint.sys` device interface via `dart:ffi` + `win32` —
/// no vendor driver or print queue needed. Re-exports `package:pplb`, so a
/// single import gives you both the command/label layer and the transport.
///
/// Windows-only: `UsbPrinter` throws `UnsupportedError` on other platforms.
library;

export 'package:pplb/pplb.dart';

export 'src/usb/usb_device.dart';
export 'src/usb/usb_devices.dart';
export 'src/usb_printer.dart';

export 'src/graphic/bitmap.dart';
export 'src/graphic/immediate_graphic.dart';
export 'src/graphic/auto_font.dart';
export 'src/graphic/gdi_text.dart';
