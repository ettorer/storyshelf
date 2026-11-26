import 'package:audiobook_player/state/jump_history.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const a = Spot(0, 60000);
  const b = Spot(1, 0);
  const c = Spot(2, 120000);
  const now = Spot(3, 5000);

  test('record, undo and redo behave like a standard stack', () {
    final history = JumpHistory();
    expect(history.canUndo, isFalse);
    history
      ..record(a)
      ..record(b);

    expect(history.undo(c), b);
    expect(history.canRedo, isTrue);
    expect(history.undo(b), a);
    expect(history.canUndo, isFalse);

    expect(history.redo(a), b);
    expect(history.redo(b), c);
    expect(history.canRedo, isFalse);
    expect(history.undoSpots, [a, b]);
  });

  test('undo and redo return null when empty', () {
    final history = JumpHistory();
    expect(history.undo(now), isNull);
    expect(history.redo(now), isNull);
  });

  test('a new jump clears redo', () {
    final history = JumpHistory()
      ..record(a)
      ..record(b);
    history.undo(c);
    expect(history.canRedo, isTrue);
    history.record(const Spot(5, 0));
    expect(history.canRedo, isFalse);
  });

  test('near duplicates of the last entry are skipped', () {
    final history = JumpHistory();
    expect(history.record(a), isTrue);
    expect(history.record(const Spot(0, 63000)), isFalse);
    expect(history.record(const Spot(0, 57000)), isFalse);
    expect(history.record(const Spot(0, 66000)), isTrue);
    // Same offset but another part is a different place.
    expect(history.record(const Spot(1, 66000)), isTrue);
    expect(history.undoSpots.length, 3);
  });

  test('keeps only the newest 20 entries', () {
    final history = JumpHistory();
    for (var i = 0; i < 30; i++) {
      history.record(Spot(0, i * 60000));
    }
    expect(history.undoSpots.length, 20);
    expect(history.undoSpots.first, const Spot(0, 10 * 60000));
    expect(history.undoSpots.last, const Spot(0, 29 * 60000));
  });

  test('jumpTo an older entry keeps newer ones and the current spot for redo',
      () {
    final history = JumpHistory()
      ..record(a)
      ..record(b)
      ..record(c);

    expect(history.jumpTo(0, now), a);
    expect(history.undoSpots, isEmpty);
    // Going forward again walks b, c, then the spot we left.
    expect(history.redo(a), b);
    expect(history.redo(b), c);
    expect(history.redo(c), now);
    expect(history.jumpTo(7, now), isNull);
  });

  test('persists as JSON per book and survives damaged data', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final history = JumpHistory()
      ..record(a)
      ..record(b);
    history.undo(c);
    await history.save(preferences, 'author|book');

    final loaded = JumpHistory.load(preferences, 'author|book');
    expect(loaded.undoSpots, [a]);
    expect(loaded.redoSpots, [c]);
    expect(JumpHistory.load(preferences, 'other').canUndo, isFalse);

    await preferences.setString(JumpHistory.key('bad'), '{not json');
    expect(JumpHistory.load(preferences, 'bad').canUndo, isFalse);
    await preferences.setString(JumpHistory.key('odd'), '{"u":[[1],"x",[2,3]]}');
    expect(JumpHistory.load(preferences, 'odd').undoSpots, [const Spot(2, 3)]);

    await JumpHistory().save(preferences, 'author|book');
    expect(preferences.containsKey(JumpHistory.key('author|book')), isFalse);
  });
}
