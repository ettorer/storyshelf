import 'package:audiobook_player/models/audiobook.dart';
import 'package:audiobook_player/state/app_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses timed chapter lines and keeps them in timestamp order', () {
    final chapters = parseChapters('''
[00:42.5]The crossing
[00:03.250]Before dawn
[01:10]The arrival
[01:20.00]
''');

    expect(chapters.map((chapter) => chapter.title), [
      'Before dawn',
      'The crossing',
      'The arrival',
    ]);
    expect(chapters[0].offset.inMilliseconds, 3250);
    expect(chapters[1].offset.inMilliseconds, 42500);
  });

  test('matches sibling tracks by book tags and orders numbered parts', () {
    final selected = _track(
      path: '/books/02 - The crossing.mp3',
      title: 'The Book',
      author: 'A. Writer',
      trackNumber: 2,
    );
    final firstPart = _track(
      path: '/books/01 - Before dawn.mp3',
      title: 'the book',
      author: 'a. writer',
      trackNumber: 1,
    );
    final otherBook = _track(
      path: '/books/03 - Another story.mp3',
      title: 'Another story',
      author: 'A. Writer',
      trackNumber: 3,
    );

    expect(sameBookTracks(selected, firstPart), isTrue);
    expect(sameBookTracks(selected, otherBook), isFalse);
    expect(orderBookTracks([selected, firstPart]), [firstPart, selected]);
    expect(chapterNumberFromFilename(selected.path), 2);
    expect(chapterTitleFromFilename(selected.path), 'The crossing');
  });

  test('uses the filename as a chapter when a part has no lyrics chapters', () {
    final book = AudioBook(
      id: 'a writer|the book',
      title: 'The Book',
      author: 'A. Writer',
      coverBytes: null,
      parts: [
        AudioPart(
          path: '/books/01 - Before dawn.mp3',
          chapterTitle: 'Before dawn',
          trackNumber: 1,
          duration: const Duration(minutes: 5),
          chapters: const [],
        ),
        AudioPart(
          path: '/books/02 - The crossing.mp3',
          chapterTitle: 'The crossing',
          trackNumber: 2,
          duration: const Duration(minutes: 4),
          chapters: const [],
        ),
      ],
    );

    expect(book.chapters.map((chapter) => chapter.title), [
      'Before dawn',
      'The crossing',
    ]);
    expect(book.chapters[1].partIndex, 1);
    expect(book.chapters[1].absoluteOffset, const Duration(minutes: 5));
  });
}

ImportedTrack _track({
  required String path,
  required String title,
  required String author,
  required int? trackNumber,
}) {
  return ImportedTrack(
    path: path,
    title: title,
    author: author,
    chapterTitle: chapterTitleFromFilename(path),
    trackNumber: trackNumber,
    duration: Duration.zero,
    coverBytes: null,
    chapters: const [],
  );
}
