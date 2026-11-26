import 'package:audiobook_player/state/bookmarks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Bookmark mark(String id, int part, int ms, {String note = ''}) => Bookmark(
  id: id,
  partIndex: part,
  offsetMs: ms,
  chapterTitle: 'Chapter ${part + 1}',
  label: 'Chapter ${part + 1} · $ms',
  note: note,
  createdMs: 1,
);

void main() {
  test('formatClock drops hours when zero', () {
    expect(formatClock(const Duration(seconds: 7)), '0:07');
    expect(formatClock(const Duration(minutes: 12, seconds: 5)), '12:05');
    expect(formatClock(const Duration(hours: 1, minutes: 2, seconds: 3)), '1:02:03');
  });

  test('bookmarks round-trip through JSON and come back in book order', () {
    final list = [
      mark('b', 2, 1000, note: 'Check "this" — è bello'),
      mark('a', 0, 90000),
      mark('c', 2, 500),
    ];
    final decoded = BookmarkStore.decode(BookmarkStore.encode(list));
    expect(decoded.map((b) => b.id), ['a', 'c', 'b']);
    expect(decoded.last.note, 'Check "this" — è bello');
    expect(decoded.first.partIndex, 0);
    expect(decoded.first.offset, const Duration(seconds: 90));
  });

  test('damaged or partial data is tolerated', () {
    expect(BookmarkStore.decode(null), isEmpty);
    expect(BookmarkStore.decode(''), isEmpty);
    expect(BookmarkStore.decode('not json'), isEmpty);
    expect(BookmarkStore.decode('{"a":1}'), isEmpty);
    final decoded = BookmarkStore.decode(
      '[{"id":"x","part":1,"ms":5},{"id":3},"junk",{"id":"y","part":-4,"ms":-9}]',
    );
    expect(decoded.map((b) => b.id), ['y', 'x']);
    expect(decoded.first.partIndex, 0);
    expect(decoded.first.offsetMs, 0);
  });

  test('stored per book id in SharedPreferences; empty list removes the key',
      () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    await BookmarkStore.save(preferences, 'author|one', [mark('a', 0, 10)]);
    await BookmarkStore.save(preferences, 'author|two', [mark('b', 1, 20)]);

    expect(BookmarkStore.load(preferences, 'author|one').single.id, 'a');
    expect(BookmarkStore.load(preferences, 'author|two').single.id, 'b');
    expect(BookmarkStore.load(preferences, 'author|none'), isEmpty);

    await BookmarkStore.save(preferences, 'author|one', []);
    expect(preferences.containsKey(BookmarkStore.key('author|one')), isFalse);
    await BookmarkStore.remove(preferences, 'author|two');
    expect(BookmarkStore.load(preferences, 'author|two'), isEmpty);
  });

  test('copyWith edits the name and note only', () {
    final edited = mark('a', 3, 400).copyWith(label: 'Mine', note: 'n');
    expect(edited.label, 'Mine');
    expect(edited.note, 'n');
    expect(edited.partIndex, 3);
    expect(edited.offsetMs, 400);
    expect(edited.id, 'a');
  });
}
