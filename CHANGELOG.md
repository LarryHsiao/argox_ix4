## 0.1.2

- Move to a dedicated repository; update the `repository` link. Depend on the
  hosted `pplb` (the local path override is no longer needed).

## 0.1.1

- Docs: mark as an early release — physical label printing is not yet confirmed
  on real media (status read and byte transmission are verified). API may change
  before 1.0.

## 0.1.0

- Initial release.
- `UsbPrinter` — a `pplb` `Printer` over the Windows `usbprint.sys` device
  interface (`dart:ffi` + `win32`): discovers the ARGOX device by vendor id
  (0x1664), opens it with overlapped I/O, writes PPLB bytes, and reads `^ee`
  status replies back. No vendor driver or print queue required.
- `UsbDevices` / `UsbDevice` — `usbprint.sys` device-interface discovery.
- `ensureWindowsPlatform` — throws `UnsupportedError` off Windows.
- Verified against an ARGOX iX4-350 (status read returns media-out code 7).
