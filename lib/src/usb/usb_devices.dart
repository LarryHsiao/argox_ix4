import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';
import 'usb_device.dart';

/// Enumerates USB printer devices via the Windows `usbprint.sys` device
/// interface class. Produces one [UsbDevice] per present device.
class UsbDevices {
  const UsbDevices();

  /// GUID_DEVINTERFACE_USBPRINT.
  static const _usbPrintGuid = '{28D78FAD-5A12-11D1-AE5B-0000F803A8C2}';

  Future<List<UsbDevice>> value() async {
    final devices = <UsbDevice>[];
    final guid = calloc<GUID>()..ref.setGUID(_usbPrintGuid);
    final hDevInfo = SetupDiGetClassDevs(
      guid,
      nullptr,
      NULL,
      SETUP_DI_GET_CLASS_DEVS_FLAGS.DIGCF_PRESENT |
          SETUP_DI_GET_CLASS_DEVS_FLAGS.DIGCF_DEVICEINTERFACE,
    );
    if (hDevInfo == INVALID_HANDLE_VALUE) {
      calloc.free(guid);
      return devices;
    }

    final interfaceData = calloc<SP_DEVICE_INTERFACE_DATA>()
      ..ref.cbSize = sizeOf<SP_DEVICE_INTERFACE_DATA>();
    try {
      var index = 0;
      while (SetupDiEnumDeviceInterfaces(
            hDevInfo,
            nullptr,
            guid,
            index,
            interfaceData,
          ) ==
          TRUE) {
        final path = _interfacePath(hDevInfo, interfaceData);
        if (path != null) {
          devices.add(RawUsbDevice(path));
        }
        index++;
      }
    } finally {
      calloc.free(interfaceData);
      calloc.free(guid);
      SetupDiDestroyDeviceInfoList(hDevInfo);
    }
    return devices;
  }

  /// Resolves the device-interface detail path for one interface.
  String? _interfacePath(
    int hDevInfo,
    Pointer<SP_DEVICE_INTERFACE_DATA> interfaceData,
  ) {
    final requiredSize = calloc<Uint32>();
    try {
      SetupDiGetDeviceInterfaceDetail(
        hDevInfo,
        interfaceData,
        nullptr,
        0,
        requiredSize,
        nullptr,
      );
      final size = requiredSize.value;
      if (size == 0) {
        return null;
      }
      // Allocate `size` BYTES for the variable-length detail struct.
      final detail = calloc<Uint8>(size);
      // cbSize is the fixed header size: 8 on 64-bit, 6 on 32-bit.
      detail.cast<Uint32>().value = sizeOf<IntPtr>() == 8 ? 8 : 6;
      try {
        final ok = SetupDiGetDeviceInterfaceDetail(
          hDevInfo,
          interfaceData,
          detail.cast<SP_DEVICE_INTERFACE_DETAIL_DATA_>(),
          size,
          nullptr,
          nullptr,
        );
        if (ok != TRUE) {
          return null;
        }
        // The DevicePath (wide string) begins after the 4-byte cbSize field.
        return (detail + 4).cast<Utf16>().toDartString();
      } finally {
        calloc.free(detail);
      }
    } finally {
      calloc.free(requiredSize);
    }
  }
}
