import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// A place in a book: part (MP3) index and milliseconds inside that part.
class Spot {
  const Spot(this.partIndex, this.offsetMs);

  final int partIndex;
  final int offsetMs;

  @override
  bool operator ==(Object other) =>
      other is Spot &&
      other.partIndex == partIndex &&
      other.offsetMs == offsetMs;

  @override
  int get hashCode => Object.hash(partIndex, offsetMs);

  @override
  String toString() => 'Spot($partIndex, ${offsetMs}ms)';
}

/// Undo/redo stack of the places a big jump (next/previous chapter, chapter
/// list, seek bar, bookmark, restart) came from.
///
/// [record] stores where you were before a jump and clears redo. [undo]
/// returns the last stored spot and keeps the current one for [redo].
class JumpHistory {
  JumpHistory({
    List<Spot> undo = const [],
    List<Spot> redo = const [],
    this.maxEntries = 20,
    this.nearDuplicate = const Duration(seconds: 5),
  }) : _undo = [...undo],
       _redo = [...redo] {
    _trim();
  }

  final int maxEntries;

  /// A spot in the same part this close to the latest entry is not recorded.
  final Duration nearDuplicate;

  final List<Spot> _undo;
  final List<Spot> _redo;

  /// Oldest first; the last entry is what [undo] goes back to.
  List<Spot> get undoSpots => List.unmodifiable(_undo);

  /// The last entry is what [redo] goes forward to.
  List<Spot> get redoSpots => List.unmodifiable(_redo);

  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;

  bool _isNear(Spot a, Spot b) =>
      a.partIndex == b.partIndex &&
      (a.offsetMs - b.offsetMs).abs() < nearDuplicate.inMilliseconds;

  /// Remembers [from] as the spot a new jump leaves. Returns false when it
  /// was skipped as a near-duplicate of the latest entry. A new jump always
  /// ends the redo chain.
  bool record(Spot from) {
    _redo.clear();
    if (_undo.isNotEmpty && _isNear(_undo.last, from)) return false;
    _undo.add(from);
    _trim();
    return true;
  }

  /// Goes back: returns the spot to move to, or null when there is none.
  Spot? undo(Spot current) {
    if (_undo.isEmpty) return null;
    final target = _undo.removeLast();
    _redo.add(current);
    _trim();
    return target;
  }

  /// Goes forward again after [undo].
  Spot? redo(Spot current) {
    if (_redo.isEmpty) return null;
    final target = _redo.removeLast();
    _undo.add(current);
    _trim();
    return target;
  }

  /// Picks the older entry at [index] of [undoSpots]. Everything after it,
  /// and [current], stay reachable with redo.
  Spot? jumpTo(int index, Spot current) {
    if (index < 0 || index >= _undo.length) return null;
    final target = _undo[index];
    final newer = _undo.sublist(index + 1);
    _undo.removeRange(index, _undo.length);
    _redo
      ..add(current)
      ..addAll(newer.reversed);
    _trim();
    return target;
  }

  void clear() {
    _undo.clear();
    _redo.clear();
  }

  void _trim() {
    if (_undo.length > maxEntries) {
      _undo.removeRange(0, _undo.length - maxEntries);
    }
    if (_redo.length > maxEntries) {
      _redo.removeRange(0, _redo.length - maxEntries);
    }
  }

  static String key(String bookId) => 'history.$bookId';

  String encode() => jsonEncode({
    'u': [
      for (final spot in _undo) [spot.partIndex, spot.offsetMs],
    ],
    'r': [
      for (final spot in _redo) [spot.partIndex, spot.offsetMs],
    ],
  });

  factory JumpHistory.decode(String? raw, {int maxEntries = 20}) {
    if (raw == null || raw.isEmpty) return JumpHistory(maxEntries: maxEntries);
    List<Spot> spots(Object? list) {
      if (list is! List) return [];
      final result = <Spot>[];
      for (final item in list) {
        if (item is List &&
            item.length == 2 &&
            item[0] is int &&
            item[1] is int) {
          result.add(Spot(item[0] as int, item[1] as int));
        }
      }
      return result;
    }

    try {
      final data = jsonDecode(raw);
      if (data is! Map) return JumpHistory(maxEntries: maxEntries);
      return JumpHistory(
        undo: spots(data['u']),
        redo: spots(data['r']),
        maxEntries: maxEntries,
      );
    } on FormatException {
      return JumpHistory(maxEntries: maxEntries);
    }
  }

  factory JumpHistory.load(SharedPreferences preferences, String bookId) =>
      JumpHistory.decode(preferences.getString(key(bookId)));

  Future<void> save(SharedPreferences preferences, String bookId) async {
    if (_undo.isEmpty && _redo.isEmpty) {
      await preferences.remove(key(bookId));
    } else {
      await preferences.setString(key(bookId), encode());
    }
  }

  static Future<void> remove(SharedPreferences preferences, String bookId) =>
      preferences.remove(key(bookId));
}
