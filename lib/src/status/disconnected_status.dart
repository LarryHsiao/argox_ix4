import 'package:pplb/pplb.dart';

/// Sentinel code for "no printer reachable". PPLB status codes are
/// non-negative, so -1 cannot collide with a real reply.
const _disconnectedCode = -1;

/// A [PrinterStatus] for when no printer is reachable: not ok, the
/// [_disconnectedCode] sentinel, and every condition flag false. Lets a status
/// read report absence without throwing.
class DisconnectedStatus implements PrinterStatus {
  const DisconnectedStatus();

  @override
  int code() => _disconnectedCode;

  @override
  bool ok() => false;

  @override
  bool mediaOut() => false;

  @override
  bool headOpen() => false;

  @override
  bool paused() => false;
}
