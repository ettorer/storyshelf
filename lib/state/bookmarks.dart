import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// "3:07", "1:02:45": the clock format used for positions in the player.
String formatClock(Duration duration) {
  final totalSeconds = duration.inSeconds < 0 ? 0 : duration.inSeconds;
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  final seconds = totalSeconds % 60;
  final mm = minutes.toString().padLeft(2, '0');
  final ss = seconds.toString().padLeft(2, '0');
  return hours > 0 ? '$hours:$mm:$ss' : '$minutes:$ss';
}

/// A saved spot in one book: the part (MP3) index and the position inside it.
class Bookmark {
  const Bookmark({
    required this.id,
    required this.partIndex,
    required this.offsetMs,
    required this.chapterTitle,
    required this.label,
    this.note = '',
    this.createdMs = 0,
  });

  final String id;
  final int partIndex;
  final int offsetMs;
  final String chapterTitle;
  final String label;
  final String note;
  final int createdMs;

  Duration get offset => Duration(milliseconds: offsetMs);

  Bookmark copyWith({String? label, String? note}) => Bookmark(
    id: id,
    partIndex: partIndex,
    offsetMs: offsetMs,
    chapterTitle: chapterTitle,
    label: label ?? this.label,
    note: note ?? this.note,
    createdMs: createdMs,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'part': partIndex,
    'ms': offsetMs,
    'chapter': chapterTitle,
    'label': label,
    'note': note,
    'created': createdMs,
  };

  static Bookmark? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final part = json['part'];
    final ms = json['ms'];
    if (id is! String || part is! int || ms is! int) return null;
    final chapter = json['chapter'];
    final label = json['label'];
    final note = json['note'];
    final created = json['created'];
    return Bookmark(
      id: id,
      partIndex: part < 0 ? 0 : part,
      offsetMs: ms < 0 ? 0 : ms,
      chapterTitle: chapter is String ? chapter : '',
      label: label is String ? label : '',
      note: note is String ? note : '',
      createdMs: created is int ? created : 0,
    );
  }
}

/// Bookmarks of every book, one JSON list per book id in SharedPreferences.
class BookmarkStore {
  static String key(String bookId) => 'bookmarks.$bookId';

  static String encode(List<Bookmark> bookmarks) =>
      jsonEncode([for (final bookmark in bookmarks) bookmark.toJson()]);

  /// Tolerates missing or damaged data by returning what can be read.
  static List<Bookmark> decode(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    try {
      final data = jsonDecode(raw);
      if (data is! List) return [];
      return sorted(data.map(Bookmark.fromJson).whereType<Bookmark>());
    } on FormatException {
      return [];
    }
  }

  /// Book order: by part, then by position inside it.
  static List<Bookmark> sorted(Iterable<Bookmark> bookmarks) {
    final result = bookmarks.toList();
    result.sort((a, b) {
      final byPart = a.partIndex.compareTo(b.partIndex);
      return byPart != 0 ? byPart : a.offsetMs.compareTo(b.offsetMs);
    });
    return result;
  }

  static List<Bookmark> load(SharedPreferences preferences, String bookId) =>
      decode(preferences.getString(key(bookId)));

  static Future<void> save(
    SharedPreferences preferences,
    String bookId,
    List<Bookmark> bookmarks,
  ) async {
    if (bookmarks.isEmpty) {
      await preferences.remove(key(bookId));
    } else {
      await preferences.setString(key(bookId), encode(bookmarks));
    }
  }

  static Future<void> remove(SharedPreferences preferences, String bookId) =>
      preferences.remove(key(bookId));
}
