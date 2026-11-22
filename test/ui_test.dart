import 'dart:io';

import 'package:audiobook_player/images/book_images.dart';
import 'package:audiobook_player/l10n/app_localizations.dart';
import 'package:audiobook_player/main.dart';
import 'package:audiobook_player/models/audiobook.dart';
import 'package:audiobook_player/state/app_state.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

const longTitle =
    'Pensieri lenti e veloci (Saggi) (Italian Edition) — edizione '
    'integrale con appendici, note e tutte le figure originali del libro';

AudioBook sampleBook({String title = longTitle, int parts = 3}) => AudioBook(
  id: 'daniel kahneman|$title',
  title: title,
  author: 'Daniel Kahneman',
  coverBytes: null,
  parts: [
    for (var i = 1; i <= parts; i++)
      AudioPart(
        path: '/lib/book/0$i - Capitolo $i.mp3',
        chapterTitle:
            'Parte prima - I due sistemi - $i. Un capitolo dal titolo lungo',
        trackNumber: i,
        duration: const Duration(minutes: 20),
        chapters: const [],
      ),
  ],
);

void mockPlugins() {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  for (final name in [
    'xyz.luan/audioplayers',
    'xyz.luan/audioplayers.global',
  ]) {
    messenger.setMockMethodCallHandler(MethodChannel(name), (_) async => null);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(mockPlugins);

  for (final size in const [Size(360, 640), Size(412, 915)]) {
    testWidgets(
      'playing page fits a long title at ${size.width}x${size.height}',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final app = AudiobookAppState()
          ..currentBook = sampleBook()
          ..duration = const Duration(hours: 1)
          ..position = const Duration(minutes: 3);
        // Same frame as the app: app bar, page, navigation bar.
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
            home: Scaffold(
              appBar: AppBar(title: const Text('STORYSHELF')),
              body: SafeArea(top: false, child: PlayingPage(app: app)),
              bottomNavigationBar: const SizedBox(height: 64),
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);

        final title = tester.renderObject<RenderParagraph>(
          find.byKey(const ValueKey('playing-title')),
        );
        // Two full lines, ellipsized beyond that, and none of it clipped.
        expect(title.didExceedMaxLines, isTrue);
        final lineHeight = title.getFullHeightForCaret(
          const TextPosition(offset: 0),
        );
        expect(title.size.height, greaterThanOrEqualTo(lineHeight * 2 - 0.5));
        final titleBox = tester.getRect(
          find.byKey(const ValueKey('playing-title')),
        );
        final author = tester.getRect(find.text('Daniel Kahneman').last);
        expect(author.top, greaterThanOrEqualTo(titleBox.bottom));

        // Controls stay on screen without scrolling.
        final play = tester.getRect(find.byIcon(Icons.play_arrow_rounded));
        final bodyBottom = size.height - 64;
        expect(play.bottom, lessThanOrEqualTo(bodyBottom));
        // Controls sit close to the navigation bar (20 px margin + button
        // padding), and the artwork takes the rest of the height.
        final controls = tester.getRect(find.byType(FilledButton).last);
        expect(bodyBottom - controls.bottom, inInclusiveRange(16, 32));
        final art = tester.getRect(
          find.byKey(const ValueKey('playing-artwork')),
        );
        expect(art.height, greaterThan(size.height * 0.3));
        expect(art.width / art.height, closeTo(0.68, 0.01));
        expect(art.right, lessThanOrEqualTo(size.width));
        // ignore: avoid_print
        print(
          '${size.width}x${size.height}: artwork ${art.size}, gap ${bodyBottom - controls.bottom}',
        );
        app.dispose();
      },
    );
  }

  testWidgets('artwork size does not depend on title lengths', (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    Future<Rect> artFor(String title, String chapter) async {
      final book = AudioBook(
        id: 'a|$title',
        title: title,
        author: 'Daniel Kahneman',
        coverBytes: null,
        parts: [
          for (var i = 1; i <= 2; i++)
            AudioPart(
              path: '/lib/b/0$i.mp3',
              chapterTitle: chapter,
              trackNumber: i,
              duration: const Duration(minutes: 20),
              chapters: const [],
            ),
        ],
      );
      final app = AudiobookAppState()
        ..currentBook = book
        ..duration = const Duration(minutes: 40);
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            appBar: AppBar(title: const Text('STORYSHELF')),
            body: PlayingPage(app: app),
            bottomNavigationBar: const SizedBox(height: 64),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      final rect = tester.getRect(
        find.byKey(const ValueKey('playing-artwork')),
      );
      final chapterBox = tester.getRect(
        find.byKey(const ValueKey('playing-chapter-box')),
      );
      final chapterText = tester.getRect(
        find.byKey(const ValueKey('playing-chapter-title')),
      );
      expect(chapterText.bottom, lessThanOrEqualTo(chapterBox.bottom + 0.5));
      app.dispose();
      return rect;
    }

    final short = await artFor('Breve', 'Uno');
    final long = await artFor(
      longTitle,
      'Parte prima - I due sistemi - I. I personaggi della storia, con un '
      'titolo di capitolo molto lungo che va a capo',
    );
    final single = await artFor('Breve', 'Breve');
    expect(long, short);
    expect(single, short);
  });

  testWidgets('drags starting in the side margin reach 0 and the end', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final seeks = <Duration>[];
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.fromLTRB(8, 200, 8, 0),
            child: SeekBar(
              position: const Duration(minutes: 10),
              duration: const Duration(minutes: 40),
              onSeek: (d) async => seeks.add(d),
            ),
          ),
        ),
      ),
    );
    final slider = tester.getRect(find.byType(Slider));
    // Inside the left margin, outside the track.
    await tester.dragFrom(
      Offset(slider.left + 6, slider.center.dy),
      const Offset(-4, 0),
    );
    await tester.pump();
    await tester.tapAt(Offset(slider.left + 4, slider.center.dy));
    await tester.pump();
    await tester.tapAt(Offset(slider.right - 4, slider.center.dy));
    await tester.pump();
    expect(seeks.first, Duration.zero);
    expect(seeks.last, const Duration(minutes: 40));
  });

  testWidgets('very short windows scroll instead of overflowing', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final app = AudiobookAppState()
      ..currentBook = sampleBook()
      ..duration = const Duration(hours: 1);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          appBar: AppBar(title: const Text('STORYSHELF')),
          body: PlayingPage(app: app),
          bottomNavigationBar: const SizedBox(height: 64),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);

    expect(find.byType(SingleChildScrollView), findsOneWidget);
    app.dispose();
  });

  testWidgets('long-press on a cover removes the book after confirming', (
    tester,
  ) async {
    var removed = 0;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 146,
              height: 260,
              child: BookTile(
                book: sampleBook(title: 'Libro'),
                progress: 0,
                onTap: () {},
                onRemove: () async => removed++,
              ),
            ),
          ),
        ),
      ),
    );
    final cover = find.byType(CoverArt);
    await tester.longPress(cover);
    await tester.pumpAndSettle();
    expect(find.text('Remove from library'), findsOneWidget);

    await tester.tap(find.text('Remove from library'));
    await tester.pumpAndSettle();
    expect(find.text('Remove from library?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(removed, 0);

    await tester.longPress(cover);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove from library'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
    await tester.pumpAndSettle();
    expect(removed, 1);
  });

  testWidgets('book list rows offer the same menu', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: BookListRow(
            book: sampleBook(title: 'Libro'),
            progress: 0,
            onTap: () {},
            onRemove: () async {},
          ),
        ),
      ),
    );
    await tester.longPress(find.byType(CoverArt));
    await tester.pumpAndSettle();
    expect(find.text('Remove from library'), findsOneWidget);
  });

  testWidgets(
    'dragging the progress bar shows the target time and seeks on release',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final seeks = <Duration>[];
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.fromLTRB(8, 200, 8, 0),
              child: SeekBar(
                position: const Duration(minutes: 10),
                duration: const Duration(minutes: 40),
                onSeek: (d) async => seeks.add(d),
              ),
            ),
          ),
        ),
      );
      expect(find.byKey(const ValueKey('seek-bubble')), findsNothing);
      final slider = tester.getRect(find.byType(Slider));
      // A 28 dp margin on each side of the bar.
      expect(
        tester.widget<Slider>(find.byType(Slider)).padding,
        const EdgeInsets.symmetric(horizontal: 28),
      );
      final gesture = await tester.startGesture(slider.center);
      await tester.pump(const Duration(milliseconds: 150));
      // The bubble stays centred over the thumb.
      expect(
        tester.getCenter(find.byKey(const ValueKey('seek-bubble'))).dx,
        closeTo(slider.center.dx, 1),
      );
      // Drag all the way to the right edge.
      await gesture.moveTo(Offset(slider.right + 20, slider.center.dy));
      await tester.pump();
      expect(seeks, isEmpty);
      final bubble = tester.getRect(find.byKey(const ValueKey('seek-bubble')));
      expect(bubble.right, lessThanOrEqualTo(360));
      expect(bubble.bottom, lessThanOrEqualTo(slider.top));
      expect(find.text('40:00'), findsWidgets);
      expect(find.text('40:00 / 40:00'), findsOneWidget);
      expect(find.byKey(const ValueKey('seek-readout')), findsOneWidget);

      await gesture.moveTo(Offset(slider.left - 20, slider.center.dy));
      await tester.pump();
      expect(
        tester.getRect(find.byKey(const ValueKey('seek-bubble'))).left,
        greaterThanOrEqualTo(0),
      );
      await gesture.up();
      await tester.pump();
      expect(seeks, [Duration.zero]);
      expect(find.byKey(const ValueKey('seek-bubble')), findsNothing);
    },
  );

  test('removing a book deletes only its files inside the library', () async {
    final root = await Directory.systemTemp.createTemp('remove');
    addTearDown(() => root.delete(recursive: true));
    final library = Directory('${root.path}/library')..createSync();
    final bookDir = Directory('${library.path}/123_Libro')..createSync();
    Directory('${bookDir.path}/images').createSync();
    final mp3 = File('${bookDir.path}/01 - A.mp3')..writeAsStringSync('x');
    File('${bookDir.path}/01 - A.json').writeAsStringSync('{}');
    final image = File('${bookDir.path}/images/01-01.jpg')
      ..writeAsStringSync('j');
    final otherDir = Directory('${library.path}/456_Altro')..createSync();
    final otherMp3 = File('${otherDir.path}/01 - B.mp3')
      ..writeAsStringSync('x');
    final original = File('${root.path}/original.mp3')..writeAsStringSync('x');

    final book = AudioBook(
      id: 'a|libro',
      title: 'Libro',
      author: 'A',
      coverBytes: null,
      parts: [
        AudioPart(
          path: mp3.path,
          chapterTitle: 'A',
          trackNumber: 1,
          duration: Duration.zero,
          chapters: const [],
          images: [PartImage(path: image.path, time: Duration.zero)],
        ),
        AudioPart(
          path: original.path,
          chapterTitle: 'Outside',
          trackNumber: 2,
          duration: Duration.zero,
          chapters: const [],
        ),
      ],
    );
    await deleteImportedBookFiles(
      book: book,
      libraryPath: library.path,
      keptPaths: {otherMp3.path},
    );
    expect(bookDir.existsSync(), isFalse);
    expect(otherMp3.existsSync(), isTrue);
    expect(original.existsSync(), isTrue);
  });
}
