// example/print_combined.dart
// One 3.3" x 2.1" label (300 dpi) combining the package's full toolkit:
//   - a GDI bitmap title line (mixed CJK + ASCII) via GdiText + ImmediateGraphic
//   - a native Code128 1-D barcode (PPLB `B` command) via Barcode1d
//   - a native QR code (PPLB `b` command) via Barcode2d.qr
// Requires a connected iX4 with media loaded. Barcode/QR payloads are ASCII —
// the printer renders them natively; only non-ASCII *text* needs the bitmap path.
import 'package:argox_ix4/argox_ix4.dart';

Future<void> main() async {
  final label = CommandLabel([
    const BufferClear(),
    const LabelWidth(990), // 3.3" at 300 dpi
    const LabelDimensions(length: 630, gap: 35), // 2.1" label, ~3 mm gap

    // Title — GDI bitmap, mixed CJK + ASCII in one face.
    ImmediateGraphic(
      x: 45,
      y: 40,
      bitmap: GdiText('iX4 標籤 / Label', sizePt: 11),
    ),

    // Code128 1-D barcode with the human-readable line.
    const Barcode1d(
      x: 45,
      y: 120,
      type: '1', // Code128
      narrow: 3,
      wide: 3,
      height: 90,
      data: '012345678905',
    ),

    // QR code (native PPLB `b` command).
    const Barcode2d.qr(
      x: 700,
      y: 120,
      scale: 5,
      data: 'https://github.com/LarryHsiao/argox_ix4',
    ),

    const Copies(1),
  ]);

  await const UsbPrinter().print(label);
  print('combined label sent');
}
