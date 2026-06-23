import 'package:argox_ix4/argox_ix4.dart';
import 'package:test/test.dart';

void main() {
  test('DisconnectedStatus reports not-ok with a sentinel code and no flags',
      () {
    const expectedCode = -1;
    const status = DisconnectedStatus();
    expect(status.ok(), isFalse);
    expect(status.code(), expectedCode);
    expect(status.mediaOut(), isFalse);
    expect(status.headOpen(), isFalse);
    expect(status.paused(), isFalse);
  });
}
