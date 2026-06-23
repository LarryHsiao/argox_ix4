// example/print_cjk.dart
// Prints four lines — Chinese, Japanese, Korean, and a pure-ASCII line — each
// rasterized with Windows GDI and sent via the PPLB GW command. The first three
// lines mix CJK with ASCII to show that AutoFont keeps the whole line in one
// face (CJK fonts carry Latin glyphs too). Requires a connected iX4 with media
// loaded. Pure ASCII could also use the lighter resident Text (A) command.
import 'package:argox_ix4/argox_ix4.dart';

Future<void> main() async {
  const pt = 10.0; // ~42 dots tall at 300 dpi — comfortably legible
  final label = CommandLabel([
    const BufferClear(),
    const LabelWidth(990),
    const LabelDimensions(length: 630, gap: 35),
    ImmediateGraphic(x: 45, y: 45, bitmap: GdiText('中文標籤 ABC 123', sizePt: pt)),
    ImmediateGraphic(x: 45, y: 105, bitmap: GdiText('日本語ラベル Test', sizePt: pt)),
    ImmediateGraphic(x: 45, y: 165, bitmap: GdiText('한국어 라벨 OK', sizePt: pt)),
    ImmediateGraphic(
        x: 45, y: 225, bitmap: GdiText('Plain ASCII 123', sizePt: pt)),
    const Copies(1),
  ]);

  await const UsbPrinter().print(label);
  print('CJK label sent');
}
