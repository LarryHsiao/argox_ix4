import 'package:argox_ix4/src/usb_printer.dart';
import 'package:test/test.dart';

void main() {
  test('ensureWindowsPlatform throws UnsupportedError off Windows', () {
    expect(
      () => ensureWindowsPlatform(isWindows: false),
      throwsA(isA<UnsupportedError>()),
    );
  });

  test('ensureWindowsPlatform returns normally on Windows', () {
    expect(() => ensureWindowsPlatform(isWindows: true), returnsNormally);
  });
}
