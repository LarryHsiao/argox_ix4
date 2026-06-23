import 'package:pplb/pplb.dart';
import '../status/disconnected_status.dart';
import '../usb_printer.dart';
import 'usb_device.dart';
import 'usb_devices.dart';

/// Connection-state view of the ARGOX printer: presence on the USB bus and a
/// non-throwing status read.
///
/// Neither method throws — both report a quiet, negative answer when the
/// printer is absent or unreachable, so an app can poll them on a timer without
/// try/catch. Construction injects the [Printer] and [UsbDevices] so the
/// connection can be exercised with fakes.
class ArgoxConnection {
  const ArgoxConnection({
    Printer printer = const UsbPrinter(),
    UsbDevices devices = const UsbDevices(),
  })  : _printer = printer,
        _devices = devices;

  final Printer _printer;
  final UsbDevices _devices;

  /// True when an ARGOX printer (vendor id [argoxVendorId]) is present on the
  /// USB bus. Returns false rather than throwing if enumeration fails.
  Future<bool> connected() async {
    try {
      final all = await _devices.value();
      return all.any((d) => d.vendorId() == argoxVendorId);
    } catch (_) {
      return false;
    }
  }

  /// The printer status, or a [DisconnectedStatus] when the printer is absent
  /// or unreachable. Never throws.
  Future<PrinterStatus> status() async {
    try {
      return await _printer.status();
    } catch (_) {
      return const DisconnectedStatus();
    }
  }
}
