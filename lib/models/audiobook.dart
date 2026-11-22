import 'dart:typed_data';

import '../images/book_images.dart';

class AudioPart {
  AudioPart({
    required this.path,
    required this.chapterTitle,
    required this.trackNumber,
    required this.duration,
    required this.chapters,
    this.images = const [],
  });

  final String path;
  final String chapterTitle;
  final int? trackNumber;
  final Duration duration;
  final List<PartChapter> chapters;

  /// Timed images of this chapter (epub-to-audio SYLT/LRC/JSON).
  final List<PartImage> images;
}

class PartChapter {
  const PartChapter({required this.title, required this.offset});

  final String title;
  final Duration offset;
}

class AudioBook {
  AudioBook({
    required this.id,
    required this.title,
    required this.author,
    required this.parts,
    required this.coverBytes,
  });

  final String id;
  final String title;
  final String author;
  final List<AudioPart> parts;
  final Uint8List? coverBytes;

  Duration get duration =>
      parts.fold(Duration.zero, (total, part) => total + part.duration);

  List<List<PartImage>> get imagesByPart =>
      parts.map((part) => part.images).toList();

  /// Every image of the book in chapter order, then time order.
  List<PartImage> get images => [for (final part in parts) ...part.images];

  List<BookChapter> get chapters {
    final result = <BookChapter>[];
    var partStart = Duration.zero;
    for (var partIndex = 0; partIndex < parts.length; partIndex++) {
      final part = parts[partIndex];
      final partChapters = part.chapters.isEmpty
          ? [PartChapter(title: part.chapterTitle, offset: Duration.zero)]
          : part.chapters;
      for (final chapter in partChapters) {
        result.add(
          BookChapter(
            title: chapter.title,
            partIndex: partIndex,
            offset: chapter.offset,
            absoluteOffset: partStart + chapter.offset,
          ),
        );
      }
      partStart += part.duration;
    }
    return result;
  }
}

class BookChapter {
  const BookChapter({
    required this.title,
    required this.partIndex,
    required this.offset,
    required this.absoluteOffset,
  });

  final String title;
  final int partIndex;
  final Duration offset;
  final Duration absoluteOffset;
}

class ImportedTrack {
  const ImportedTrack({
    required this.path,
    required this.title,
    required this.author,
    required this.chapterTitle,
    required this.trackNumber,
    required this.duration,
    required this.coverBytes,
    required this.chapters,
    this.hasBookTags = true,
    this.images = const [],
  });

  final String path;
  final String title;
  final String author;
  final String chapterTitle;
  final int? trackNumber;
  final Duration duration;
  final Uint8List? coverBytes;
  final List<PartChapter> chapters;

  /// False when neither album nor title tag names the book, so the title was
  /// derived from the file or folder name.
  final bool hasBookTags;
  final List<PartImage> images;
}
