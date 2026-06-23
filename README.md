# argox_ix4

**Windows USB driver for ARGOX iX4-series PPLB label printers.** It opens the
inbox **`usbprint.sys`** device interface directly (`dart:ffi` + `win32`) — so
it needs **no vendor driver, no Seagull/ARGOX SDK, and no print queue**. Just
plug the printer in.

> ⚠️ **Early release (0.1.x).** USB discovery, status read-back, and **physical
> label printing on real media** are all hardware-verified on an ARGOX iX4-350.
> Tested on a single model and environment; the API may change before 1.0.

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

  // Print a label. All coordinates and sizes are in dots (see note below).
  await printer.print(CommandLabel(const [
    BufferClear(),
    LabelWidth(990),                       // 3.3" at 300 dpi
    LabelDimensions(length: 630, gap: 35), // 2.1" label, ~3 mm gap
    Text(x: 40, y: 40, font: 4, data: 'ARGOX iX4'),
    Barcode1d(x: 40, y: 200, type: '1', height: 160, data: '0123456789'),
    Copies(1),
  ]));
}
```

> **Dimensions are in dots, not millimetres.** Convert from the printer's
> resolution: `dots = inches × dpi`. The **iX4-350 is 300 dpi**
> (`dots = inches × 300`, or `mm × 11.81`); the **iX4-250 is 203 dpi**
> (`mm × 8`). After loading media, run the printer's **auto-calibration**
> (Menu → Sensor) so it learns the label-plus-gap length.

> **Flutter consumers:** the re-exported `pplb` includes a class named `Text`
> (PPLB `A` command) that clashes with Flutter's `Text` widget. Import with a
> prefix — `import 'package:argox_ix4/argox_ix4.dart' as ix4;` — and use
> `ix4.Text(...)`, `ix4.UsbPrinter()`, etc.

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

## How it works

`UsbPrinter` enumerates the `usbprint.sys` device-interface class, selects the
ARGOX device by USB vendor id `0x1664`, opens its device path with `CreateFile`
(overlapped), writes `label.bytes()`, and for `status()` writes `^ee` and reads
the reply — mapping it to a `PrinterStatus`. Discovery, status, and printing all
verified against an ARGOX iX4-350.

## License

MIT — see [LICENSE](LICENSE).
