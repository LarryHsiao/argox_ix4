/// A USB device exposed through the Windows `usbprint.sys` device interface.
abstract interface class UsbDevice {
  /// The device-interface path, openable with CreateFile.
  String path();

  /// The USB vendor id (e.g. 0x1664 for ARGOX), or -1 if not derivable.
  int vendorId();
}

/// A [UsbDevice] backed by a raw device-interface path string. The vendor id
/// is parsed from the `vid_XXXX` token in the path.
class RawUsbDevice implements UsbDevice {
  const RawUsbDevice(this._path);

  final String _path;

  @override
  String path() => _path;

  @override
  int vendorId() {
    final match = RegExp(r'vid_([0-9a-fA-F]{4})').firstMatch(_path);
    if (match == null) {
      return -1;
    }
    return int.parse(match.group(1)!, radix: 16);
  }
}
