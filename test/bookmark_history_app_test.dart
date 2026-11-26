import 'package:audiobook_player/audio/playback_backend.dart';
import 'package:audiobook_player/l10n/app_localizations.dart';
import 'package:audiobook_player/main.dart';
import 'package:audiobook_player/models/audiobook.dart';
import 'package:audiobook_player/state/app_state.dart';
import 'package:audiobook_player/state/bookmarks.dart';
import 'package:audiobook_player/state/jump_history.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_backend.dart';

AudioBook book() => AudioBook(
  id: 'author|book',
  title: 'Test Book',
  author: 'Author',
  coverBytes: null,
  parts: [
    for (var i = 0; i < 3; i++)
      AudioPart(
        path: '/books/0${i + 1}.mp3',
        chapterTitle: 'Chapter ${i + 1}',
        trackNumber: i + 1,
        duration: const Duration(minutes: 10),
        chapters: i == 1
            ? const [
                PartChapter(title: 'Part two start', offset: Duration.zero),
                PartChapter(
                  title: 'Part two middle',
                  offset: Duration(minutes: 5),
                ),
              ]
            : const [],
      ),
  ],
);

Future<(AudiobookAppState, FakeAudioPlaybackBackend, SharedPreferences)>
setup({int startPart = 0, Duration start = Duration.zero}) async {
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  final fake = FakeAudioPlaybackBackend();
  final app = AudiobookAppState(player: fake)..attachPreferences(preferences);
  await app.playBook(book());
  if (startPart != 0 || start != Duration.zero) {
    fake.emit(
      PlaybackSnapshot(
        partIndex: startPart,
        localPosition: start,
        partDuration: const Duration(minutes: 10),
        playing: true,
        completed: false,
      ),
    );
    await Future<void>.delayed(Duration.zero);
  }
  return (app, fake, preferences);
}

void main() {
  test('big jumps are recorded, small skips are not', () async {
    final (app, fake, _) = await setup(
      startPart: 0,
      start: const Duration(minutes: 3),
    );

    await app.seekBy(const Duration(seconds: 30));
    await app.seekBy(const Duration(seconds: -10));
    expect(app.canUndoJump, isFalse);

    await app.nextChapter();
    expect(app.history.undoSpots.length, 1);
    expect(app.history.undoSpots.single.partIndex, 0);
    // 3:00 + 30 s - 10 s
    expect(app.history.undoSpots.single.offsetMs, 200000);

    await app.seek(const Duration(minutes: 25));
    expect(app.history.undoSpots.length, 2);
    expect(app.history.undoSpots.last, const Spot(1, 0));

    await app.previousChapter();
    await app.seekChapter(app.currentBook!.chapters.first);
    expect(app.history.undoSpots.length, 4);
    expect(fake.seeks.isNotEmpty, isTrue);
    app.dispose();
  });

  test('undo returns to the spot before an accidental next chapter, redo goes back',
      () async {
    final (app, fake, _) = await setup(
      startPart: 0,
      start: const Duration(minutes: 7, seconds: 12),
    );
    await app.nextChapter();
    expect(app.currentPartIndex, 1);

    await app.undoJump();
    expect(fake.seeks.last, (0, const Duration(minutes: 7, seconds: 12)));
    expect(app.currentPartIndex, 0);
    expect(app.position, const Duration(minutes: 7, seconds: 12));
    expect(app.canRedoJump, isTrue);
    expect(app.canUndoJump, isFalse);

    await app.redoJump();
    expect(app.currentPartIndex, 1);
    expect(app.position, const Duration(minutes: 10));
    expect(app.canRedoJump, isFalse);
    expect(app.canUndoJump, isTrue);
    app.dispose();
  });

  test('picking an older history entry works and redo still reaches the present',
      () async {
    final (app, fake, _) = await setup();
    await app.seek(const Duration(minutes: 4));
    await app.seek(const Duration(minutes: 14));
    await app.seek(const Duration(minutes: 24));
    expect(app.history.undoSpots, [
      const Spot(0, 0),
      const Spot(0, 240000),
      const Spot(1, 240000),
    ]);

    await app.jumpToHistory(1);
    expect(app.position, const Duration(minutes: 4));
    expect(fake.seeks.last, (0, const Duration(minutes: 4)));

    await app.redoJump();
    expect(app.position, const Duration(minutes: 14));
    await app.redoJump();
    expect(app.position, const Duration(minutes: 24));
    app.dispose();
  });

  test('history is saved per book and restored when the book is opened again',
      () async {
    final (app, fake, preferences) = await setup(
      startPart: 0,
      start: const Duration(minutes: 2),
    );
    await app.nextChapter();
    expect(preferences.getString(JumpHistory.key('author|book')), isNotNull);

    final again = AudiobookAppState(player: FakeAudioPlaybackBackend())
      ..attachPreferences(preferences);
    await again.playBook(book());
    expect(again.history.undoSpots, [const Spot(0, 120000)]);
    again.dispose();
    app.dispose();
    expect(fake, isNotNull);
  });

  test('restarting a finished book is a recorded jump', () async {
    final (app, fake, _) = await setup();
    fake.emit(
      const PlaybackSnapshot(
        partIndex: 2,
        localPosition: Duration(minutes: 10),
        partDuration: Duration(minutes: 10),
        playing: false,
        completed: true,
      ),
    );
    await Future<void>.delayed(Duration.zero);
    await app.togglePlayPause();
    expect(app.history.undoSpots.single, const Spot(2, 600000));
    expect(app.position, Duration.zero);
    app.dispose();
  });

  test('bookmark saves part, offset, chapter title and default label', () async {
    final (app, _, preferences) = await setup(
      startPart: 1,
      start: const Duration(minutes: 6, seconds: 5),
    );

    expect(app.defaultBookmarkLabel(), 'Part two middle · 16:05');
    await app.addBookmark(label: '', note: '  remember this  ');
    final saved = app.bookmarks.single;
    expect(saved.partIndex, 1);
    expect(saved.offsetMs, 365000);
    expect(saved.chapterTitle, 'Part two middle');
    expect(saved.label, 'Part two middle · 16:05');
    expect(saved.note, 'remember this');
    expect(
      BookmarkStore.load(preferences, 'author|book').single.id,
      saved.id,
    );
    app.dispose();
  });

  test('bookmarks can be renamed, deleted, restored and jumped to', () async {
    final (app, fake, preferences) = await setup(
      startPart: 1,
      start: const Duration(minutes: 1),
    );
    await app.addBookmark(label: 'First', note: '');
    final id = app.bookmarks.single.id;

    await app.updateBookmark(id, label: 'Renamed', note: 'with a note');
    expect(app.bookmarks.single.label, 'Renamed');
    expect(app.bookmarks.single.note, 'with a note');
    // An empty name keeps the old one.
    await app.updateBookmark(id, label: '   ');
    expect(app.bookmarks.single.label, 'Renamed');

    final removed = app.bookmarks.single;
    await app.deleteBookmark(id);
    expect(app.bookmarks, isEmpty);
    expect(preferences.containsKey(BookmarkStore.key('author|book')), isFalse);
    await app.restoreBookmark(removed);
    expect(app.bookmarks.single.id, id);

    // Jump somewhere else, then back to the bookmark: that is a recorded jump.
    await app.seek(const Duration(minutes: 25));
    final before = app.history.undoSpots.length;
    await app.jumpToBookmark(removed);
    expect(app.history.undoSpots.length, before + 1);
    expect(fake.seeks.last, (1, const Duration(minutes: 1)));
    expect(app.position, const Duration(minutes: 11));
    expect(app.playing, isTrue);
    app.dispose();
  });

  test('bookmarks are kept per book and reloaded', () async {
    final (app, _, preferences) = await setup();
    await app.addBookmark(label: 'Keep me');
    app.dispose();

    final again = AudiobookAppState(player: FakeAudioPlaybackBackend())
      ..attachPreferences(preferences);
    await again.playBook(book());
    expect(again.bookmarks.map((b) => b.label), ['Keep me']);
    again.dispose();
  });

  Future<AudiobookAppState> pumpPlayer(WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final app = AudiobookAppState(player: FakeAudioPlaybackBackend())
      ..attachPreferences(preferences);
    await app.playBook(book());
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ListenableBuilder(
            listenable: app,
            builder: (_, _) => PlayingPage(app: app),
          ),
          bottomNavigationBar: const SizedBox(height: 64),
        ),
      ),
    );
    await tester.pump();
    return app;
  }

  testWidgets('player tools row fits and undo is enabled only after a jump',
      (tester) async {
    final app = await pumpPlayer(tester);
    expect(tester.takeException(), isNull);
    expect(find.byIcon(Icons.undo_rounded), findsOneWidget);
    expect(find.byIcon(Icons.bookmark_add_outlined), findsOneWidget);

    final undo = tester.widget<InkResponse>(
      find.descendant(
        of: find.byKey(const ValueKey('undo-jump')),
        matching: find.byType(InkResponse),
      ),
    );
    expect(undo.onTap, isNull);

    await app.nextChapter();
    await tester.pump();
    final enabled = tester.widget<InkResponse>(
      find.descendant(
        of: find.byKey(const ValueKey('undo-jump')),
        matching: find.byType(InkResponse),
      ),
    );
    expect(enabled.onTap, isNotNull);

    // Row stays inside the screen and above the controls.
    final row = tester.getRect(find.byKey(const ValueKey('playing-tools-row')));
    expect(row.left, greaterThanOrEqualTo(0));
    expect(row.right, lessThanOrEqualTo(360));
    app.dispose();
  });

  testWidgets('bookmark dialog saves a note; the sheet lists, edits and deletes',
      (tester) async {
    final app = await pumpPlayer(tester);

    await tester.tap(find.byKey(const ValueKey('add-bookmark')));
    await tester.pumpAndSettle();
    expect(find.text('New bookmark'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('bookmark-note')),
      'the clue',
    );
    await tester.tap(find.byKey(const ValueKey('bookmark-save')));
    await tester.pumpAndSettle();
    expect(app.bookmarks.single.note, 'the clue');
    expect(app.bookmarks.single.label, 'Chapter 1 · 0:00');

    await tester.tap(find.byKey(const ValueKey('show-bookmarks')));
    await tester.pumpAndSettle();
    expect(find.text('Chapter 1 · 0:00'), findsOneWidget);
    expect(find.text('the clue'), findsOneWidget);

    // Swipe away, then undo from the snackbar.
    await tester.drag(find.text('the clue'), const Offset(-500, 0));
    await tester.pumpAndSettle();
    expect(app.bookmarks, isEmpty);
    expect(find.text('Bookmark deleted'), findsOneWidget);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(app.bookmarks.length, 1);
    expect(find.byKey(const ValueKey('bookmarks-empty')), findsNothing);

    // Rename through the menu.
    await tester.tap(
      find.byKey(ValueKey('bookmark-menu-${app.bookmarks.single.id}')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('bookmark-name')),
      'Plot twist',
    );
    await tester.tap(find.byKey(const ValueKey('bookmark-save')));
    await tester.pumpAndSettle();
    expect(app.bookmarks.single.label, 'Plot twist');
    expect(find.text('Plot twist'), findsOneWidget);
    app.dispose();
  });

  testWidgets('long-press on undo opens the history; picking an entry jumps',
      (tester) async {
    final app = await pumpPlayer(tester);
    await app.seek(const Duration(minutes: 15));
    await app.seek(const Duration(minutes: 25));
    await tester.pump();

    await tester.longPress(find.byKey(const ValueKey('undo-jump')));
    await tester.pumpAndSettle();
    expect(find.text('Jump history'), findsOneWidget);
    // Newest first: the spot at 15:00 is in "Part two middle" (part 2, 5:00).
    expect(find.text('Part two middle'), findsOneWidget);
    expect(find.text('15:00'), findsOneWidget);
    expect(find.text('0:00'), findsOneWidget);

    await tester.tap(find.text('15:00'));
    await tester.pumpAndSettle();
    expect(app.position, const Duration(minutes: 15));
    expect(app.canRedoJump, isTrue);
    app.dispose();
  });

  testWidgets('Italian strings are used on an Italian phone', (tester) async {
    tester.platformDispatcher.localesTestValue = [const Locale('it', 'IT')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    final app = await pumpPlayerIt(tester);
    await tester.tap(find.byKey(const ValueKey('add-bookmark')));
    await tester.pumpAndSettle();
    expect(find.text('Nuovo segnalibro'), findsOneWidget);
    expect(find.text('Nota (facoltativa)'), findsOneWidget);
    expect(find.text('Salva'), findsOneWidget);
    app.dispose();
  });
}

Future<AudiobookAppState> pumpPlayerIt(WidgetTester tester) async {
  tester.view.physicalSize = const Size(360, 640);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final app = AudiobookAppState(player: FakeAudioPlaybackBackend());
  await app.playBook(book());
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      localeListResolutionCallback: (locales, _) => resolveAppLocale(locales),
      home: Scaffold(body: PlayingPage(app: app)),
    ),
  );
  await tester.pump();
  return app;
}
