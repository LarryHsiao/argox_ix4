// Reads the iX4 status over USB. With no paper loaded this prints media-out
// (code 7) — the verification of the FFI transport against hardware.
import 'package:argox_ix4/argox_ix4.dart';

Future<void> main() async {
  final printer = LoggedPrinter(const UsbPrinter(), print);
  final status = await printer.status();
  print('code: ${status.code()}');
  print('ok: ${status.ok()}  mediaOut: ${status.mediaOut()}  '
      'headOpen: ${status.headOpen()}  paused: ${status.paused()}');
}
