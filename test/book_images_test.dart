import 'dart:io';
import 'dart:typed_data';

import 'package:audiobook_player/images/book_images.dart';
import 'package:audiobook_player/models/audiobook.dart';
import 'package:audiobook_player/state/app_state.dart';
import 'package:flutter_test/flutter_test.dart';

/// Builds an ID3v2.3 tag with one SYLT frame (UTF-16 with BOM, ms stamps).
Uint8List buildSyltTag(
  List<(String, int)> entries, {
  String descriptor = 'images',
  int version = 3,
}) {
  List<int> utf16(String text) => [
    0xFF,
    0xFE,
    for (final unit in text.codeUnits) ...[unit & 0xff, unit >> 8],
    0,
    0,
  ];
  List<int> be32(int v) => [
    v >> 24 & 0xff,
    v >> 16 & 0xff,
    v >> 8 & 0xff,
    v & 0xff,
  ];
  List<int> synchsafe(int v) => [
    v >> 21 & 0x7f,
    v >> 14 & 0x7f,
    v >> 7 & 0x7f,
    v & 0x7f,
  ];
  final body = <int>[
    1,
    ...'ita'.codeUnits,
    2,
    1,
    ...utf16(descriptor),
    for (final (text, ms) in entries) ...[...utf16(text), ...be32(ms)],
  ];
  final otherFrame = <int>[
    ...'TIT2'.codeUnits,
    ...(version == 4 ? synchsafe(4) : be32(4)),
    0,
    0,
    3,
    ...'abc'.codeUnits,
  ];
  final frame = <int>[
    ...'SYLT'.codeUnits,
    ...(version == 4 ? synchsafe(body.length) : be32(body.length)),
    0,
    0,
    ...body,
  ];
  final frames = [...otherFrame, ...frame, ...List.filled(32, 0)];
  return Uint8List.fromList([
    ...'ID3'.codeUnits,
    version,
    0,
    0,
    ...synchsafe(frames.length),
    ...frames,
  ]);
}

List<List<PartImage>> sampleImages() => [
  [
    const PartImage(
      path: '/b/images/01-01.jpg',
      time: Duration(milliseconds: 9820),
    ),
    const PartImage(
      path: '/b/images/01-02.jpg',
      time: Duration(milliseconds: 872520),
    ),
    const PartImage(
      path: '/b/images/01-03.jpg',
      time: Duration(milliseconds: 1020910),
    ),
  ],
  [],
  [
    const PartImage(
      path: '/b/images/03-01.jpg',
      time: Duration(milliseconds: 400350),
    ),
    const PartImage(
      path: '/b/images/03-02.jpg',
      time: Duration(milliseconds: 440660),
    ),
  ],
];

void main() {
  group('SYLT', () {
    test('reads UTF-16 entries with millisecond times (v2.3 and v2.4)', () {
      for (final version in [3, 4]) {
        final refs = parseSyltImages(
          buildSyltTag([
            ('images/01-02.jpg', 872520),
            ('images/01-01.jpg', 9820),
          ], version: version),
        );
        expect(refs.map((r) => r.file), [
          'images/01-01.jpg',
          'images/01-02.jpg',
        ]);
        expect(refs.map((r) => r.time.inMilliseconds), [9820, 872520]);
      }
    });

    test('ignores non-ID3 data and non-image text', () {
      expect(parseSyltImages(Uint8List.fromList(List.filled(20, 0))), isEmpty);
      expect(parseSyltImages(buildSyltTag([('Hello', 100)])), isEmpty);
    });
  });

  test('LRC fallback accepts minutes above 59 and skips other lines', () {
    final refs = parseLrcImages(
      '[00:09.82]images/01-01.jpg\n[61:02.5]images/01-02.png\n[01:00]Chapter',
    );
    expect(refs.map((r) => r.file), ['images/01-01.jpg', 'images/01-02.png']);
    expect(
      refs[1].time,
      const Duration(minutes: 61, seconds: 2, milliseconds: 500),
    );
  });

  test('JSON sidecar gives captions; SYLT timing wins', () {
    final sidecar = parseSidecarImages('''
{"images": [
  {"file": "images/01-01.jpg", "time_ms": 9800, "caption": "Figura 1.1."},
  {"file": "images/01-02.jpg", "time_ms": 872523, "caption": " "}
]}''');
    expect(sidecar, hasLength(2));
    expect(sidecar[1].caption, isNull);
    expect(parseSidecarImages('not json'), isEmpty);

    final merged = mergeImageSources(
      sylt: const [
        TimedImageRef(
          file: 'images/01-01.jpg',
          time: Duration(milliseconds: 9820),
        ),
      ],
      lrc: parseLrcImages('[00:01.00]images/01-01.jpg'),
      sidecar: sidecar,
    );
    expect(merged.single.time.inMilliseconds, 9820);
    expect(merged.single.caption, 'Figura 1.1.');
    expect(mergeImageSources(sidecar: sidecar), hasLength(2));
  });

  test('missing image files and unsafe paths are skipped', () {
    final images = resolveImages('/books/x/01 - A.mp3', const [
      TimedImageRef(file: 'images/01-01.jpg', time: Duration.zero),
      TimedImageRef(file: 'images/missing.jpg', time: Duration.zero),
      TimedImageRef(file: '../secret.jpg', time: Duration.zero),
    ], exists: (path) => !path.contains('missing'));
    expect(images.map((i) => i.path), ['/books/x/images/01-01.jpg']);
  });

  group('image at position', () {
    final images = sampleImages();
    test('cover before the first image, latest reached image after', () {
      expect(autoImageIndex(images, 0, Duration.zero), 0);
      expect(autoImageIndex(images, 0, const Duration(milliseconds: 9819)), 0);
      expect(autoImageIndex(images, 0, const Duration(milliseconds: 9820)), 1);
      expect(autoImageIndex(images, 0, const Duration(minutes: 16)), 2);
      expect(autoImageIndex(images, 0, const Duration(hours: 1)), 3);
    });

    test(
      'a new chapter starts on the cover; indexes continue across chapters',
      () {
        expect(autoImageIndex(images, 1, const Duration(minutes: 30)), 0);
        expect(autoImageIndex(images, 2, Duration.zero), 0);
        expect(
          autoImageIndex(images, 2, const Duration(milliseconds: 400350)),
          4,
        );
        expect(
          autoImageIndex(images, 2, const Duration(milliseconds: 440660)),
          5,
        );
        expect(firstImageIndexOfPart(images, 2), 4);
      },
    );

    test('book images are listed in chapter then time order', () {
      final book = AudioBook(
        id: 'a|b',
        title: 'B',
        author: 'A',
        coverBytes: null,
        parts: [
          for (var i = 0; i < images.length; i++)
            AudioPart(
              path: '/b/0$i.mp3',
              chapterTitle: '$i',
              trackNumber: i + 1,
              duration: const Duration(minutes: 30),
              chapters: const [],
              images: images[i],
            ),
        ],
      );
      expect(book.images.map((i) => i.path.split('/').last), [
        '01-01.jpg',
        '01-02.jpg',
        '01-03.jpg',
        '03-01.jpg',
        '03-02.jpg',
      ]);
    });
  });

  group('manual swipe vs auto sync', () {
    test('a swipe is kept until the next image time is reached', () {
      final sync = ImageSync();
      expect(sync.update(1), 1);
      sync.swipeTo(4);
      expect(sync.update(1), 4);
      expect(sync.isPinned, isTrue);
      expect(sync.update(2), 2);
      expect(sync.isPinned, isFalse);
    });

    test('chapter change or seek resets to the automatic image', () {
      final sync = ImageSync();
      sync.update(3);
      sync.swipeTo(5);
      sync.reset(0);
      expect(sync.displayed, 0);
      expect(sync.update(0), 0);
      expect(sync.update(4), 4);
    });

    test('swiping back to the automatic image unpins', () {
      final sync = ImageSync()..update(2);
      sync.swipeTo(3);
      sync.swipeTo(2);
      expect(sync.isPinned, isFalse);
    });
  });

  test('import copies images/ and JSON sidecars next to the MP3s', () async {
    final root = await Directory.systemTemp.createTemp('companions');
    addTearDown(() => root.delete(recursive: true));
    final source = Directory('${root.path}/src')..createSync();
    Directory('${source.path}/images').createSync();
    File('${source.path}/01 - A.mp3').writeAsStringSync('x');
    File('${source.path}/01 - A.json').writeAsStringSync('{}');
    File('${source.path}/images/01-01.jpg').writeAsStringSync('jpg');
    File('${source.path}/images/notes.txt').writeAsStringSync('no');
    final library = Directory('${root.path}/lib')..createSync();
    final copy = File('${library.path}/01 - A.mp3')..writeAsStringSync('x');
    final failures = <String>[];
    await copyCompanionFiles({source.path}, [copy.path], failures);
    expect(failures, isEmpty);
    expect(File('${library.path}/01 - A.json').existsSync(), isTrue);
    expect(File('${library.path}/images/01-01.jpg').existsSync(), isTrue);
    expect(File('${library.path}/images/notes.txt').existsSync(), isFalse);
  });

  group('real epub-to-audio files', () {
    const folder = '/tmp/epub-to-audio-imgtest';
    final available = Directory(folder).existsSync();
    test('SYLT, LRC-free read and JSON captions', () async {
      final mp3s =
          Directory(folder)
              .listSync()
              .whereType<File>()
              .where((f) => f.path.endsWith('.mp3'))
              .map((f) => f.path)
              .toList()
            ..sort();
      final sylt = [for (final m in mp3s) await readSyltImagesFromFile(m)];
      // SYLT keeps exact milliseconds; the LRC lines round to 1/100 s.
      void near(List<TimedImageRef> refs, List<int> expected) {
        expect(refs, hasLength(expected.length));
        for (var i = 0; i < expected.length; i++) {
          expect(
            (refs[i].time.inMilliseconds - expected[i]).abs(),
            lessThan(10),
          );
        }
      }

      near(sylt[0], [9820, 872520, 1020910]);
      near(sylt[1], [400350, 440660]);
      expect(sylt[1].map((r) => r.file), [
        'images/02-01.jpg',
        'images/02-02.jpg',
      ]);

      final images = [for (final m in mp3s) await readPartImages(m)];
      expect(images.map((i) => i.length), [3, 2]);
      expect(images[0].first.caption, startsWith('Figura 1.1.'));
      expect(images[0].every((i) => File(i.path).existsSync()), isTrue);
    }, skip: available ? false : 'sample files not present');
  });
}
