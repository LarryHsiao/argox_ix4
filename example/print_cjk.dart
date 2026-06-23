// example/print_cjk.dart
// Prints four lines — Chinese, Japanese, Korean, ASCII — each rasterized with
// Windows GDI and sent via the PPLB GW command. Requires a connected iX4 with
// media loaded. Pure ASCII could also use the lighter resident Text (A) command.
import 'package:argox_ix4/argox_ix4.dart';

Future<void> main() async {
  final label = CommandLabel([
    const BufferClear(),
    const LabelWidth(990),
    const LabelDimensions(length: 630, gap: 35),
    ImmediateGraphic(x: 45, y: 45, bitmap: GdiText('中文標籤', sizePt: 18)),
    ImmediateGraphic(x: 45, y: 140, bitmap: GdiText('日本語ラベル', sizePt: 18)),
    ImmediateGraphic(x: 45, y: 235, bitmap: GdiText('한국어 라벨', sizePt: 18)),
    ImmediateGraphic(x: 45, y: 330, bitmap: GdiText('ASCII 123', sizePt: 18)),
    const Copies(1),
  ]);

  await const UsbPrinter().print(label);
  print('CJK label sent');
}
