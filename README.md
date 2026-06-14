# argox_ix4

**Windows USB driver for ARGOX iX4-series PPLB label printers.** It opens the
inbox **`usbprint.sys`** device interface directly (`dart:ffi` + `win32`) — so
it needs **no vendor driver, no Seagull/ARGOX SDK, and no print queue**. Just
plug the printer in.

> ⚠️ **Early release (0.1.x) — not yet complete.** USB discovery and status
> read-back are hardware-verified on an ARGOX iX4-350, but **physical label
> printing has not yet been confirmed on real media** — only that the byte
> stream transmits. Tested on a single model and environment; the API may change
> before 1.0.

Built on [`pplb`](https://pub.dev/packages/pplb) (the command/label layer),
which this package re-exports — one import gives you both.

> **Platform: Windows only** (Windows 7 SP1+ when built with Flutter 3.19 /
> Dart 3.3; Windows 10+ on Dart 3.4+). `UsbPrinter` throws `UnsupportedError`
> elsewhere. The `pplb` command layer it builds on is cross-platform.

## Usage

```dart
import 'package:argox_ix4/argox_ix4.dart'; // re-exports pplb too

Future<void> main() async {
  final printer = LoggedPrinter(
    RetryPrinter(const UsbPrinter(), attempts: 2),
    print,
  );

  // Read status (no paper -> code 7, media out)
  final status = await printer.status();
  print('ok: ${status.ok()}  mediaOut: ${status.mediaOut()}');

  // Print a label
  await printer.print(CommandLabel(const [
    BufferClear(),
    LabelDimensions(length: 100, gap: 20),
    Text(x: 50, y: 30, font: 3, data: 'ARGOX iX4'),
    Barcode1d(x: 50, y: 80, type: '1', height: 60, data: '0123456789'),
    Copies(1),
  ]));
}
```

> **Flutter consumers:** the re-exported `pplb` includes a class named `Text`
> (PPLB `A` command) that clashes with Flutter's `Text` widget. Import with a
> prefix — `import 'package:argox_ix4/argox_ix4.dart' as ix4;` — and use
> `ix4.Text(...)`, `ix4.UsbPrinter()`, etc.

## How it works

`UsbPrinter` enumerates the `usbprint.sys` device-interface class, selects the
ARGOX device by USB vendor id `0x1664`, opens its device path with `CreateFile`
(overlapped), writes `label.bytes()`, and for `status()` writes `^ee` and reads
the reply — mapping it to a `PrinterStatus`. Verified against an ARGOX iX4-350.

## License

MIT — see [LICENSE](LICENSE).
