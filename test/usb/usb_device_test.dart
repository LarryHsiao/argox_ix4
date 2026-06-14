import 'package:argox_ix4/src/usb/usb_device.dart';
import 'package:test/test.dart';

void main() {
  test('RawUsbDevice exposes its path verbatim', () {
    const path =
        r'\\?\usb#vid_1664&pid_2011#26bf3b100523#{28d78fad-5a12-11d1-ae5b-0000f803a8c2}';
    final device = RawUsbDevice(path);
    expect(device.path(), path);
  });

  test('RawUsbDevice parses the vendor id from the path', () {
    const path =
        r'\\?\usb#vid_1664&pid_2011#26bf3b100523#{28d78fad-5a12-11d1-ae5b-0000f803a8c2}';
    final expected = 0x1664;
    final actual = RawUsbDevice(path).vendorId();
    expect(actual, expected);
  });

  test('RawUsbDevice yields -1 when no vid is present in the path', () {
    final expected = -1;
    final actual = RawUsbDevice(r'\\?\usb#nonsense').vendorId();
    expect(actual, expected);
  });
}
