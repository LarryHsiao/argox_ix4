// Prints a simple label over USB. Requires media loaded; with no paper the
// printer holds the job and reports media-out.
import 'package:argox_ix4/argox_ix4.dart';

Future<void> main() async {
  final label = CommandLabel(const [
    BufferClear(),
    LabelDimensions(length: 100, gap: 20),
    Text(x: 50, y: 30, font: 3, data: 'BILBO iX4'),
    Barcode1d(x: 50, y: 80, type: '1', height: 60, data: '0123456789'),
    Copies(1),
  ]);
  await const UsbPrinter().print(label);
  print('label sent');
}
