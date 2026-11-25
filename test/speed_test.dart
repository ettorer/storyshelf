import 'package:audiobook_player/main.dart';
import 'package:audiobook_player/state/app_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('speed snaps to 0.25 steps between 0.5x and 2x', () {
    expect(AudiobookAppState.snapSpeed(0.1), 0.5);
    expect(AudiobookAppState.snapSpeed(1.1), 1.0);
    expect(AudiobookAppState.snapSpeed(1.2), 1.25);
    expect(AudiobookAppState.snapSpeed(1.4), 1.5);
    expect(AudiobookAppState.snapSpeed(3), 2.0);
  });

  test('speed labels drop trailing zeros', () {
    expect(formatSpeed(1), '1×');
    expect(formatSpeed(1.25), '1.25×');
    expect(formatSpeed(1.5), '1.5×');
    expect(formatSpeed(0.75), '0.75×');
    expect(formatSpeed(2), '2×');
  });
}
