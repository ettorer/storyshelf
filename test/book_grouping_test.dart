import 'package:audiobook_player/state/app_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('epub-to-audio books', () {
    const folder = '/books/Daniel Kahneman - Pensieri lenti e veloci';
    final tracks = [
      trackFromTags(
        path: '$folder/02 - VIII. Come si formano i giudizi.mp3',
        title: 'VIII. Come si formano i giudizi',
        album: 'Pensieri lenti e veloci',
        albumArtist: 'Daniel Kahneman',
        trackArtist: 'Daniel Kahneman',
        trackNumber: 2,
        duration: const Duration(minutes: 16),
        lyrics: '[06:40.35]images/02-01.jpg\n[07:20.66]images/02-02.jpg',
      ),
      trackFromTags(
        path: '$folder/10 - Conclusioni.mp3',
        title: 'Conclusioni',
        album: 'Pensieri lenti e veloci',
        albumArtist: 'Daniel Kahneman',
        trackNumber: 10,
      ),
      trackFromTags(
        path: '$folder/01 - I. I personaggi della storia.mp3',
        title: 'I. I personaggi della storia',
        album: 'Pensieri lenti e veloci',
        trackArtist: 'Daniel Kahneman',
        trackNumber: 1,
        duration: const Duration(minutes: 24),
      ),
      trackFromTags(
        path: '$folder/other.mp3',
        title: 'Something else',
        album: 'Another book',
        albumArtist: 'Daniel Kahneman',
        trackNumber: 1,
      ),
    ];

    test('groups by album + author and orders by track number', () {
      final books = groupTracksIntoBooks(tracks);
      expect(books, hasLength(2));
      final book = books.firstWhere(
        (b) => b.title == 'Pensieri lenti e veloci',
      );
      expect(book.author, 'Daniel Kahneman');
      expect(book.parts.map((part) => part.trackNumber), [1, 2, 10]);
      expect(book.parts.map((part) => part.chapterTitle), [
        'I. I personaggi della storia',
        'VIII. Come si formano i giudizi',
        'Conclusioni',
      ]);
    });

    test('image references in the lyrics are not chapters', () {
      expect(tracks.first.chapters, isEmpty);
      final book = groupTracksIntoBooks(tracks)
          .firstWhere((b) => b.title == 'Pensieri lenti e veloci');
      expect(book.chapters.map((c) => c.title), [
        'I. I personaggi della storia',
        'VIII. Come si formano i giudizi',
        'Conclusioni',
      ]);
      expect(book.chapters[1].absoluteOffset, const Duration(minutes: 24));
    });

    test('duplicate copies of a chapter are kept once', () {
      final copy = trackFromTags(
        path: '/library/123_copy/01 - I. I personaggi della storia.mp3',
        title: 'I. I personaggi della storia',
        album: 'Pensieri lenti e veloci',
        albumArtist: 'Daniel Kahneman',
        trackNumber: 1,
      );
      final book = groupTracksIntoBooks([...tracks, copy])
          .firstWhere((b) => b.title == 'Pensieri lenti e veloci');
      expect(book.parts, hasLength(3));
    });
  });

  group('fallbacks', () {
    test('missing track number uses the leading filename number', () {
      final track = trackFromTags(
        path: '/b/07 - Il capitolo.mp3',
        title: 'Il capitolo',
        album: 'Libro',
        albumArtist: 'Autore',
      );
      expect(track.trackNumber, 7);
      expect(track.chapterTitle, 'Il capitolo');
    });

    test('title tag equal to the book uses the filename as chapter', () {
      final track = trackFromTags(
        path: '/b/03 - Terzo.mp3',
        title: 'Libro',
        albumArtist: 'Autore',
      );
      expect(track.title, 'Libro');
      expect(track.chapterTitle, 'Terzo');
    });

    test('old style numbered files without tags form one book', () {
      final tracks = [
        for (final name in ['Book 10.mp3', 'Book 2.mp3', 'Book 1.mp3'])
          trackFromTags(path: '/old/$name'),
      ];
      final books = groupTracksIntoBooks(tracks);
      expect(books, hasLength(1));
      expect(books.single.title, 'Book');
      expect(books.single.parts.map((part) => part.trackNumber), [1, 2, 10]);
    });

    test('untagged chapter files group by folder', () {
      final tracks = [
        trackFromTags(path: '/x/My Book/02 - Secondo.mp3'),
        trackFromTags(path: '/x/My Book/01 - Primo.mp3'),
        trackFromTags(path: '/x/Other/01 - Altro.mp3'),
      ];
      final books = groupTracksIntoBooks(tracks);
      expect(books, hasLength(2));
      final book = books.firstWhere((b) => b.title == 'My Book');
      expect(book.parts.map((part) => part.chapterTitle), ['Primo', 'Secondo']);
      expect(sameBookTracks(tracks[0], tracks[1]), isTrue);
      expect(sameBookTracks(tracks[0], tracks[2]), isFalse);
    });

    test('tagged and untagged files are never mixed', () {
      final tagged = trackFromTags(
        path: '/b/01.mp3',
        album: 'B',
        albumArtist: 'A',
      );
      final untagged = trackFromTags(path: '/b/02.mp3');
      expect(sameBookTracks(tagged, untagged), isFalse);
    });
  });
}
