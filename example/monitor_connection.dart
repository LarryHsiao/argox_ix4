// example/monitor_connection.dart
// Polls the printer's connection state without try/catch, using the
// ArgoxConnection convenience layer. connected() reports USB presence;
// status() returns a real PrinterStatus or a DisconnectedStatus — never throws.
import 'dart:async';
import 'package:argox_ix4/argox_ix4.dart';

Future<void> main() async {
  const connection = ArgoxConnection();

  Timer.periodic(const Duration(seconds: 2), (_) async {
    if (!await connection.connected()) {
      print('printer: disconnected');
      return;
    }
    final status = await connection.status();
    print('printer: connected  ok=${status.ok()}  '
        'mediaOut=${status.mediaOut()}  headOpen=${status.headOpen()}');
  });
}
