import 'package:argox_ix4/argox_ix4.dart';
import 'package:test/test.dart';

/// A [UsbDevices] that yields a fixed device list (no FFI).
class _FixedDevices extends UsbDevices {
  const _FixedDevices(this._devices);
  final List<UsbDevice> _devices;
  @override
  Future<List<UsbDevice>> value() async => _devices;
}

/// A [Printer] whose reads fail, as if no printer were reachable.
class _ThrowingPrinter implements Printer {
  const _ThrowingPrinter();
  @override
  Future<void> print(Label label) async => throw StateError('no printer');
  @override
  Future<PrinterStatus> status() async => throw StateError('no printer');
}

/// A [Printer] that reports a healthy status.
class _OkPrinter implements Printer {
  const _OkPrinter();
  @override
  Future<void> print(Label label) async {}
  @override
  Future<PrinterStatus> status() async => const PplbStatus(0);
}

const _argoxPath =
    r'\\?\usb#vid_1664&pid_2011#26bf3b100523#{28d78fad-5a12-11d1-ae5b-0000f803a8c2}';
const _otherPath =
    r'\\?\usb#vid_03f0&pid_0001#abc#{28d78fad-5a12-11d1-ae5b-0000f803a8c2}';

void main() {
  test('connected() is true when an ARGOX device is present', () async {
    const expected = true;
    final connection =
        ArgoxConnection(devices: _FixedDevices([RawUsbDevice(_argoxPath)]));
    expect(await connection.connected(), expected);
  });

  test('connected() is false when no ARGOX device is present', () async {
    const expected = false;
    final connection =
        ArgoxConnection(devices: _FixedDevices([RawUsbDevice(_otherPath)]));
    expect(await connection.connected(), expected);
  });

  test('status() returns the printer status when reachable', () async {
    const expectedCode = 0;
    final connection = ArgoxConnection(printer: const _OkPrinter());
    final status = await connection.status();
    expect(status.code(), expectedCode);
    expect(status.ok(), isTrue);
  });

  test('status() returns DisconnectedStatus when the printer is unreachable',
      () async {
    final connection = ArgoxConnection(printer: const _ThrowingPrinter());
    final status = await connection.status();
    expect(status, isA<DisconnectedStatus>());
    expect(status.ok(), isFalse);
  });
}
