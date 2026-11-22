import 'package:audiobook_player/l10n/app_localizations.dart';
import 'package:audiobook_player/main.dart';
import 'package:audiobook_player/models/audiobook.dart';
import 'package:audiobook_player/state/app_state.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

AudioBook book() => AudioBook(
  id: 'a|b',
  title: 'Il nome della rosa',
  author: 'Umberto Eco',
  coverBytes: null,
  parts: [
    for (var i = 1; i <= 3; i++)
      AudioPart(
        path: '/lib/book/0$i.mp3',
        chapterTitle: 'Capitolo $i',
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

/// The shell configured like the real app, on a device with [deviceLocale].
Future<AudiobookAppState> pumpShell(
  WidgetTester tester,
  Locale deviceLocale, {
  List<AudioBook> books = const [],
  int tab = 0,
}) async {
  tester.view.physicalSize = const Size(412, 915);
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.localesTestValue = [deviceLocale];
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearLocalesTestValue);
  final app = AudiobookAppState()..books = [...books];
  app.selectedTab = tab;
  if (tab == 3 && books.isNotEmpty) {
    app
      ..currentBook = books.first
      ..duration = const Duration(minutes: 20);
  }
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      localeListResolutionCallback: (locales, _) => resolveAppLocale(locales),
      home: AppShell(app: app),
    ),
  );
  await tester.pump();
  return app;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(mockPlugins);

  test('device language picks the app language, English otherwise', () {
    expect(resolveAppLocale(const [Locale('it', 'IT')]), const Locale('it'));
    expect(resolveAppLocale(const [Locale('en', 'GB')]), const Locale('en'));
    expect(resolveAppLocale(const [Locale('de', 'DE')]), const Locale('en'));
    expect(resolveAppLocale(null), const Locale('en'));
  });

  testWidgets('English UI', (tester) async {
    final app = await pumpShell(
      tester,
      const Locale('en', 'US'),
      books: [book()],
    );
    for (final label in ['Home', 'Books', 'Authors', 'Playing']) {
      expect(find.text(label), findsWidgets);
    }
    expect(find.text('1 book'), findsOneWidget);
    expect(find.byTooltip('Add audiobook'), findsOneWidget);
    app.dispose();
  });

  testWidgets('Italian UI', (tester) async {
    final app = await pumpShell(
      tester,
      const Locale('it', 'IT'),
      books: [book()],
    );
    for (final label in ['Home', 'Libri', 'Autori', 'In ascolto']) {
      expect(find.text(label), findsWidgets);
    }
    expect(find.text('1 libro'), findsOneWidget);
    expect(find.byTooltip('Aggiungi audiolibro'), findsOneWidget);
    expect(find.text('1 book'), findsNothing);
    app.dispose();
  });

  testWidgets('Italian player strings', (tester) async {
    final app = await pumpShell(
      tester,
      const Locale('it', 'IT'),
      books: [book()],
      tab: 3,
    );
    expect(find.text('Capitolo 1 di 3'), findsOneWidget);
    expect(find.byTooltip('Capitolo successivo'), findsOneWidget);
    app.dispose();
  });

  testWidgets('unsupported languages fall back to English', (tester) async {
    final app = await pumpShell(
      tester,
      const Locale('de', 'DE'),
      books: [book()],
    );
    expect(find.text('Authors'), findsWidgets);
    expect(find.text('Autori'), findsNothing);
    expect(find.text('1 book'), findsOneWidget);
    app.dispose();
  });

  for (final (locale, hint) in [
    (const Locale('en'), 'Tap + at the top right'),
    (const Locale('it'), 'Tocca + in alto a destra'),
  ]) {
    testWidgets('import hint only on an empty library ($locale)', (
      tester,
    ) async {
      final empty = await pumpShell(tester, locale);
      final hintBox = find.byKey(const ValueKey('empty-library-hint'));
      expect(hintBox, findsOneWidget);
      expect(find.textContaining(hint), findsOneWidget);
      expect(find.textContaining('A good story starts here'), findsNothing);
      empty.dispose();

      final full = await pumpShell(tester, locale, books: [book()]);
      expect(find.byKey(const ValueKey('empty-library-hint')), findsNothing);
      expect(find.textContaining(hint), findsNothing);
      full.dispose();
    });
  }
}
