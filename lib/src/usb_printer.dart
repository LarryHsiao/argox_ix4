import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:pplb/pplb.dart';
import 'package:win32/win32.dart';
import 'usb/usb_device.dart';
import 'usb/usb_devices.dart';

const _argoxVendorId = 0x1664;
const _readTimeoutMs = 2500;
const _readBufferSize = 256;

/// A [Printer] over the Windows `usbprint.sys` device interface.
///
/// Discovers the ARGOX device, opens its path with overlapped I/O, writes
/// PPLB bytes, and reads `^ee` status replies back from the reverse channel.
class UsbPrinter implements Printer {
  const UsbPrinter({UsbDevices devices = const UsbDevices()})
      : _devices = devices;

  final UsbDevices _devices;

  Future<UsbDevice> _argox() async {
    final all = await _devices.value();
    final argox = all.where((d) => d.vendorId() == _argoxVendorId);
    if (argox.isEmpty) {
      throw StateError('No ARGOX (vid 0x1664) USB printer found.');
    }
    return argox.first;
  }

  int _open(String path) {
    final lpName = path.toNativeUtf16();
    try {
      final handle = CreateFile(
        lpName,
        GENERIC_ACCESS_RIGHTS.GENERIC_READ | GENERIC_ACCESS_RIGHTS.GENERIC_WRITE,
        FILE_SHARE_MODE.FILE_SHARE_READ | FILE_SHARE_MODE.FILE_SHARE_WRITE,
        nullptr,
        FILE_CREATION_DISPOSITION.OPEN_EXISTING,
        FILE_FLAGS_AND_ATTRIBUTES.FILE_FLAG_OVERLAPPED,
        NULL,
      );
      if (handle == INVALID_HANDLE_VALUE) {
        throw StateError('CreateFile failed for $path (${GetLastError()}).');
      }
      return handle;
    } finally {
      malloc.free(lpName);
    }
  }

  void _write(int handle, List<int> data) {
    final buffer = calloc<Uint8>(data.length);
    final overlapped = calloc<OVERLAPPED>()
      ..ref.hEvent = CreateEvent(nullptr, TRUE, FALSE, nullptr);
    final written = calloc<Uint32>();
    try {
      buffer.asTypedList(data.length).setAll(0, data);
      final ok =
          WriteFile(handle, buffer.cast(), data.length, written, overlapped);
      if (ok != TRUE && GetLastError() == WIN32_ERROR.ERROR_IO_PENDING) {
        final wait = WaitForSingleObject(overlapped.ref.hEvent, _readTimeoutMs);
        if (wait != WAIT_EVENT.WAIT_OBJECT_0) {
          // Cancel the in-flight write before the overlapped struct is freed.
          CancelIoEx(handle, overlapped);
        } else {
          GetOverlappedResult(handle, overlapped, written, FALSE);
        }
      }
    } finally {
      CloseHandle(overlapped.ref.hEvent);
      calloc.free(written);
      calloc.free(overlapped);
      calloc.free(buffer);
    }
  }

  /// Writes a query and reads up to [_readBufferSize] reply bytes, timing out
  /// after [_readTimeoutMs] (then cancelling the read so it cannot hang).
  List<int> _read(int handle) {
    final buffer = calloc<Uint8>(_readBufferSize);
    final overlapped = calloc<OVERLAPPED>()
      ..ref.hEvent = CreateEvent(nullptr, TRUE, FALSE, nullptr);
    final read = calloc<Uint32>();
    try {
      final ok =
          ReadFile(handle, buffer.cast(), _readBufferSize, read, overlapped);
      if (ok != TRUE && GetLastError() == WIN32_ERROR.ERROR_IO_PENDING) {
        final wait = WaitForSingleObject(overlapped.ref.hEvent, _readTimeoutMs);
        if (wait != WAIT_EVENT.WAIT_OBJECT_0) {
          CancelIoEx(handle, overlapped);
          return const [];
        }
        GetOverlappedResult(handle, overlapped, read, FALSE);
      }
      final count = read.value;
      return buffer.asTypedList(count).toList();
    } finally {
      CloseHandle(overlapped.ref.hEvent);
      calloc.free(read);
      calloc.free(overlapped);
      calloc.free(buffer);
    }
  }

  @override
  Future<void> print(Label label) async {
    ensureWindowsPlatform(isWindows: Platform.isWindows);
    final device = await _argox();
    final handle = _open(device.path());
    try {
      _write(handle, label.bytes());
    } finally {
      CloseHandle(handle);
    }
  }

  @override
  Future<PrinterStatus> status() async {
    ensureWindowsPlatform(isWindows: Platform.isWindows);
    final device = await _argox();
    final handle = _open(device.path());
    try {
      _write(handle, const ImmediateStatus().bytes());
      final reply = _read(handle);
      return SafeStatus(PplbStatus(pplbStatusCode(reply)));
    } finally {
      CloseHandle(handle);
    }
  }
}

/// Guards the Windows-only transport. Throws [UnsupportedError] off Windows,
/// where the `usbprint.sys` device interface this driver opens does not exist.
/// The platform is passed in (rather than read here) so the guard is testable.
void ensureWindowsPlatform({required bool isWindows}) {
  if (!isWindows) {
    throw UnsupportedError(
      'argox_ix4 supports Windows only — the USB transport uses the Windows '
      'usbprint.sys device interface.',
    );
  }
}
