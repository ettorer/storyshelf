import 'dart:async';
import 'dart:io';

import 'package:cupertino_ui/cupertino_ui.dart'
    show GlobalCupertinoLocalizations;
import 'package:flutter_localizations/flutter_localizations.dart'
    show GlobalWidgetsLocalizations;
import 'package:just_audio_background/just_audio_background.dart';
import 'package:material_ui/material_ui.dart';

import 'l10n/app_localizations.dart';
import 'models/audiobook.dart';
import 'state/app_state.dart';
import 'state/bookmarks.dart' show formatClock;
import 'ui/bookmark_ui.dart';

/// App strings plus Material/Cupertino/widget localizations. The Material
/// and Cupertino ones come from material_ui/cupertino_ui, which this Flutter
/// version uses instead of the deprecated flutter_localizations copies.
const appLocalizationsDelegates = <LocalizationsDelegate<dynamic>>[
  AppLocalizations.delegate,
  GlobalMaterialLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
];

extension L10nContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

/// "1×", "1.25×", "1.5×": no trailing zeros.
String formatSpeed(double speed) {
  var text = speed.toStringAsFixed(2);
  text = text.replaceFirst(RegExp(r'\.?0+$'), '');
  return '$text×';
}

Future<void> showSpeedSheet(BuildContext context, AudiobookAppState app) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (_) => SpeedSheet(app: app),
  );
}

class SpeedSheet extends StatelessWidget {
  const SpeedSheet({super.key, required this.app});

  final AudiobookAppState app;

  static const presets = [0.75, 1.0, 1.25, 1.5, 2.0];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                context.l10n.speedTooltip,
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                formatSpeed(app.speed),
                key: const ValueKey('speed-value'),
                style: theme.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Slider(
                key: const ValueKey('speed-slider'),
                value: app.speed,
                min: AudiobookAppState.minSpeed,
                max: AudiobookAppState.maxSpeed,
                divisions:
                    ((AudiobookAppState.maxSpeed - AudiobookAppState.minSpeed) /
                            AudiobookAppState.speedStep)
                        .round(),
                label: formatSpeed(app.speed),
                onChanged: app.setSpeed,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(formatSpeed(AudiobookAppState.minSpeed)),
                    Text(formatSpeed(AudiobookAppState.maxSpeed)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (final preset in presets)
                    ChoiceChip(
                      key: ValueKey('speed-preset-$preset'),
                      label: Text(formatSpeed(preset)),
                      showCheckmark: false,
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      labelPadding: const EdgeInsets.symmetric(horizontal: 6),
                      selected: app.speed == preset,
                      onSelected: (_) => app.setSpeed(preset),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Author as shown to the user ("Unknown Author" files are localized).
String authorLabel(BuildContext context, String author) =>
    author == unknownAuthorKey ? context.l10n.unknownAuthor : author;

/// Italian when the device language is Italian, English otherwise.
Locale resolveAppLocale(List<Locale>? deviceLocales) {
  for (final locale in deviceLocales ?? const <Locale>[]) {
    if (locale.languageCode == 'it') return const Locale('it');
    if (locale.languageCode == 'en') return const Locale('en');
  }
  return const Locale('en');
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.example.audiobook_player.channel.audio',
    androidNotificationChannelName: 'Audiobook playback',
    androidNotificationOngoing: true,
    androidStopForegroundOnPause: true,
  );
  runApp(const AudiobookPlayerApp());
}

class AudiobookPlayerApp extends StatefulWidget {
  const AudiobookPlayerApp({super.key});

  @override
  State<AudiobookPlayerApp> createState() => _AudiobookPlayerAppState();
}

class _AudiobookPlayerAppState extends State<AudiobookPlayerApp>
    with WidgetsBindingObserver {
  final AudiobookAppState app = AudiobookAppState();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    app.addListener(_showMessages);
    unawaited(app.initialize());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(app.syncPlaybackState());
      unawaited(app.takePlatformFile());
    }
  }

  void _showMessages() {
    final message = app.takeMessage();
    if (message == null || !mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    app.removeListener(_showMessages);
    app.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFFD8A15D);
    return MaterialApp(
      onGenerateTitle: (context) => context.l10n.appTitle,
      debugShowCheckedModeBanner: false,
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      localeListResolutionCallback: (locales, _) => resolveAppLocale(locales),
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: accent,
          brightness: Brightness.dark,
          surface: const Color(0xFF17191D),
        ),
        scaffoldBackgroundColor: const Color(0xFF101114),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF101114),
          surfaceTintColor: Colors.transparent,
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: const Color(0xFF17191D),
          indicatorColor: accent.withValues(alpha: 0.18),
          labelTextStyle: WidgetStateProperty.resolveWith(
            (states) => TextStyle(
              color: states.contains(WidgetState.selected)
                  ? accent
                  : Colors.white60,
              fontSize: 12,
            ),
          ),
        ),
        sliderTheme: const SliderThemeData(
          activeTrackColor: accent,
          thumbColor: accent,
          inactiveTrackColor: Colors.white24,
        ),
        useMaterial3: true,
      ),
      home: AppShell(app: app),
    );
  }
}

class AppShell extends StatelessWidget {
  const AppShell({required this.app, super.key});

  final AudiobookAppState app;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: app,
      builder: (context, _) {
        app.l10n = context.l10n;
        final onPlayingPage = app.selectedTab == 3;
        return Scaffold(
          appBar: AppBar(
            title: Text(
              context.l10n.appBarTitle,
              style: const TextStyle(
                fontSize: 14,
                letterSpacing: 2.4,
                fontWeight: FontWeight.w700,
              ),
            ),
            actions: [
              IconButton(
                tooltip: context.l10n.addMp3Tooltip,
                onPressed: app.busy ? null : app.pickAudioFiles,
                icon: const Icon(Icons.add_rounded),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: SafeArea(
            top: false,
            child: switch (app.selectedTab) {
              0 => HomePage(app: app),
              1 => BooksPage(app: app),
              2 => AuthorsPage(app: app),
              _ => PlayingPage(app: app),
            },
          ),
          bottomNavigationBar: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!onPlayingPage && app.currentBook != null)
                NowPlayingBar(app: app),
              NavigationBar(
                height: 64,
                labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                selectedIndex: app.selectedTab,
                onDestinationSelected: app.openTab,
                destinations: [
                  NavigationDestination(
                    icon: const Icon(Icons.home_outlined),
                    selectedIcon: const Icon(Icons.home_rounded),
                    label: context.l10n.navHome,
                  ),
                  NavigationDestination(
                    icon: const Icon(Icons.auto_stories_outlined),
                    selectedIcon: const Icon(Icons.auto_stories_rounded),
                    label: context.l10n.navBooks,
                  ),
                  NavigationDestination(
                    icon: const Icon(Icons.person_outline_rounded),
                    selectedIcon: const Icon(Icons.person_rounded),
                    label: context.l10n.navAuthors,
                  ),
                  NavigationDestination(
                    icon: const Icon(Icons.graphic_eq_rounded),
                    selectedIcon: const Icon(Icons.graphic_eq_rounded),
                    label: context.l10n.navPlaying,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({required this.app, super.key});

  final AudiobookAppState app;

  @override
  Widget build(BuildContext context) {
    final recent = app.recentBooks;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      children: [
        if (app.books.isEmpty) ...[
          const SizedBox(height: 24),
          EmptyHint(
            key: const ValueKey('empty-library-hint'),
            icon: Icons.headphones_rounded,
            title: context.l10n.emptyLibraryTitle,
            detail: context.l10n.emptyLibraryHint,
            action: FilledButton.icon(
              onPressed: app.busy ? null : app.pickAudioFiles,
              icon: const Icon(Icons.library_add_rounded),
              label: Text(context.l10n.addAudiobookButton),
            ),
          ),
        ] else ...[
          const SizedBox(height: 8),
          if (recent.isNotEmpty)
            BookShelf(
              app: app,
              title: context.l10n.shelfRecent,
              books: recent,
              showProgress: true,
            ),
          const SizedBox(height: 24),
          BookShelf(
            app: app,
            title: context.l10n.shelfBooks,
            books: app.sortedBooks,
          ),
          const SizedBox(height: 24),
          _AuthorShelf(app: app),
        ],
      ],
    );
  }
}

class BookShelf extends StatelessWidget {
  const BookShelf({
    required this.app,
    required this.title,
    required this.books,
    this.showProgress = false,
    super.key,
  });

  final AudiobookAppState app;
  final String title;
  final List<AudioBook> books;
  final bool showProgress;

  @override
  Widget build(BuildContext context) {
    if (books.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeading(title: title, count: books.length),
        const SizedBox(height: 14),
        SizedBox(
          height: showProgress ? 278 : 254,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: books.length,
            separatorBuilder: (_, _) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              final book = books[index];
              return SizedBox(
                width: 146,
                child: BookTile(
                  book: book,
                  progress: app.progressFor(book),
                  showProgress: showProgress,
                  onTap: () => app.playBook(book),
                  onRemove: () => app.removeBook(book),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _AuthorShelf extends StatelessWidget {
  const _AuthorShelf({required this.app});

  final AudiobookAppState app;

  @override
  Widget build(BuildContext context) {
    final names = app.authors;
    if (names.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeading(title: context.l10n.shelfAuthors, count: names.length),
        const SizedBox(height: 14),
        SizedBox(
          height: 106,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: names.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final name = names[index];
              return SizedBox(
                width: 174,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => app.openAuthor(name),
                  child: Ink(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1B1D21),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.person_rounded,
                          color: Color(0xFFD8A15D),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          authorLabel(context, name),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          context.l10n.bookCount(
                            app.booksByAuthor(name).length,
                          ),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white54,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class BooksPage extends StatelessWidget {
  const BooksPage({required this.app, super.key});

  final AudiobookAppState app;

  @override
  Widget build(BuildContext context) {
    final books = app.selectedAuthor == null
        ? app.sortedBooks
        : app.booksByAuthor(app.selectedAuthor!);
    return Column(
      children: [
        if (app.selectedAuthor != null)
          ListTile(
            leading: IconButton(
              tooltip: context.l10n.allBooksTooltip,
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: app.clearAuthor,
            ),
            title: Text(authorLabel(context, app.selectedAuthor!)),
            subtitle: Text(context.l10n.booksByThisAuthor),
          ),
        Expanded(
          child: books.isEmpty
              ? EmptyHint(
                  icon: Icons.auto_stories_outlined,
                  title: context.l10n.noBooksTitle,
                  detail: context.l10n.noBooksDetail,
                  action: FilledButton.icon(
                    onPressed: app.pickAudioFiles,
                    icon: const Icon(Icons.add_rounded),
                    label: Text(context.l10n.addBooksButton),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
                  itemCount: books.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final book = books[index];
                    return BookListRow(
                      book: book,
                      progress: app.progressFor(book),
                      onTap: () => app.playBook(book),
                      onRemove: () => app.removeBook(book),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class AuthorsPage extends StatelessWidget {
  const AuthorsPage({required this.app, super.key});

  final AudiobookAppState app;

  @override
  Widget build(BuildContext context) {
    final selectedAuthor = app.selectedAuthor;
    if (selectedAuthor != null) {
      final authorBooks = app.booksByAuthor(selectedAuthor);
      return Column(
        children: [
          ListTile(
            leading: IconButton(
              tooltip: context.l10n.allAuthorsTooltip,
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: app.clearAuthor,
            ),
            title: Text(authorLabel(context, selectedAuthor)),
            subtitle: Text(context.l10n.bookCount(authorBooks.length)),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
              itemCount: authorBooks.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final book = authorBooks[index];
                return BookListRow(
                  book: book,
                  progress: app.progressFor(book),
                  onTap: () => app.playBook(book),
                  onRemove: () => app.removeBook(book),
                );
              },
            ),
          ),
        ],
      );
    }

    final authors = app.authors;
    if (authors.isEmpty) {
      return EmptyHint(
        icon: Icons.person_outline_rounded,
        title: context.l10n.noAuthorsTitle,
        detail: context.l10n.noAuthorsDetail,
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
      itemCount: authors.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final author = authors[index];
        final count = app.booksByAuthor(author).length;
        return ListTile(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          tileColor: const Color(0xFF1B1D21),
          leading: CircleAvatar(
            backgroundColor: const Color(0xFFD8A15D).withValues(alpha: 0.16),
            child: const Icon(Icons.person_rounded, color: Color(0xFFD8A15D)),
          ),
          title: Text(authorLabel(context, author)),
          subtitle: Text(context.l10n.bookCount(count)),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => app.openAuthor(author),
        );
      },
    );
  }
}

class PlayingPage extends StatelessWidget {
  const PlayingPage({required this.app, super.key});

  final AudiobookAppState app;

  @override
  Widget build(BuildContext context) {
    final book = app.currentBook;
    if (book == null) {
      return EmptyHint(
        icon: Icons.headphones_rounded,
        title: context.l10n.nothingPlayingTitle,
        detail: context.l10n.nothingPlayingDetail,
      );
    }
    final chapters = book.chapters;

    // Every text block has a fixed height (two lines for the book title and
    // for the chapter title), so the artwork size never depends on titles.
    final scaler = MediaQuery.textScalerOf(context);
    double lines(int count, double fontSize, double lineHeight) =>
        (scaler.scale(fontSize) * lineHeight * count).ceilToDouble() + 2;
    const titleStyle = TextStyle(
      fontSize: 22,
      height: 1.25,
      fontWeight: FontWeight.w700,
    );
    const chapterStyle = TextStyle(
      color: Color(0xFFD8A15D),
      fontSize: 14,
      height: 1.3,
      fontWeight: FontWeight.w600,
    );
    final part = app.currentPart;
    final chapterTitle =
        part != null &&
            part.chapterTitle.toLowerCase() != book.title.toLowerCase()
        ? part.chapterTitle
        : '';
    final details = <Widget>[
      const SizedBox(height: 10),
      SizedBox(
        key: const ValueKey('playing-title-box'),
        height: lines(2, 22, 1.25),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 44),
              child: Text(
                book.title,
                key: const ValueKey('playing-title'),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: titleStyle,
              ),
            ),
            if (chapters.isNotEmpty)
              Positioned(
                right: 0,
                child: IconButton(
                  tooltip: context.l10n.showChaptersTooltip,
                  onPressed: () => _showChapters(context, app),
                  icon: const Icon(Icons.list_rounded),
                ),
              ),
          ],
        ),
      ),
      SizedBox(
        height: lines(1, 14, 1.4),
        child: Text(
          authorLabel(context, book.author),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white60, height: 1.4),
        ),
      ),
      const SizedBox(height: 6),
      SizedBox(
        key: const ValueKey('playing-tools-row'),
        height: 36,
        child: Row(
          children: [
            JumpIconButton(
              key: const ValueKey('undo-jump'),
              icon: Icons.undo_rounded,
              tooltip: context.l10n.undoJumpTooltip,
              onPressed: app.canUndoJump ? app.undoJump : null,
              onLongPress: () => showHistorySheet(context, app),
            ),
            JumpIconButton(
              key: const ValueKey('redo-jump'),
              icon: Icons.redo_rounded,
              tooltip: context.l10n.redoJumpTooltip,
              onPressed: app.canRedoJump ? app.redoJump : null,
            ),
            Expanded(
              child: Text(
                book.parts.length > 1
                    ? context.l10n.chapterOfTotal(
                        app.currentPartIndex + 1,
                        book.parts.length,
                      )
                    : '',
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ),
            JumpIconButton(
              key: const ValueKey('add-bookmark'),
              icon: Icons.bookmark_add_outlined,
              tooltip: context.l10n.addBookmarkTooltip,
              onPressed: () => addBookmarkFlow(context, app),
            ),
            JumpIconButton(
              key: const ValueKey('show-bookmarks'),
              icon: app.bookmarks.isEmpty
                  ? Icons.bookmarks_outlined
                  : Icons.bookmarks_rounded,
              tooltip: context.l10n.bookmarksTooltip,
              onPressed: () => showBookmarksSheet(context, app),
            ),
          ],
        ),
      ),
      const SizedBox(height: 2),
      SizedBox(
        key: const ValueKey('playing-chapter-box'),
        height: lines(2, 14, 1.3),
        child: Align(
          alignment: Alignment.topCenter,
          child: Text(
            chapterTitle,
            key: const ValueKey('playing-chapter-title'),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: chapterStyle,
          ),
        ),
      ),
      const SizedBox(height: 8),
      SeekBar(position: app.position, duration: app.duration, onSeek: app.seek),
      const SizedBox(height: 4),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          CompactPlayerButton(
            icon: Icons.replay_30_rounded,
            tooltip: context.l10n.back30Tooltip,
            onPressed: () => app.seekBy(const Duration(seconds: -30)),
          ),
          CompactPlayerButton(
            icon: Icons.replay_10_rounded,
            tooltip: context.l10n.back10Tooltip,
            onPressed: () => app.seekBy(const Duration(seconds: -10)),
          ),
          CompactPlayerButton(
            icon: Icons.skip_previous_rounded,
            tooltip: context.l10n.previousChapterTooltip,
            onPressed: book.parts.length < 2 ? null : app.previousChapter,
          ),
          FilledButton(
            onPressed: app.busy ? null : app.togglePlayPause,
            style: FilledButton.styleFrom(
              shape: const CircleBorder(),
              minimumSize: const Size(44, 44),
              padding: EdgeInsets.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Icon(
              app.playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
              size: 25,
            ),
          ),
          CompactPlayerButton(
            icon: Icons.skip_next_rounded,
            tooltip: context.l10n.nextChapterTooltip,
            onPressed: book.parts.length < 2 ? null : app.nextChapter,
          ),
          CompactPlayerButton(
            icon: Icons.forward_30_rounded,
            tooltip: context.l10n.forward30Tooltip,
            onPressed: () => app.seekBy(const Duration(seconds: 30)),
          ),
          Tooltip(
            message: context.l10n.speedTooltip,
            child: SizedBox(
              width: 44,
              height: 40,
              child: TextButton(
                key: const ValueKey('speed-button'),
                onPressed: () => showSpeedSheet(context, app),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(44, 40),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  formatSpeed(app.speed),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        // Very short windows: fixed artwork and scrolling, as before.
        if (constraints.maxHeight < 440) {
          const artHeight = 160.0;
          final artWidth = (artHeight * _coverAspect)
              .clamp(100.0, constraints.maxWidth - 16)
              .toDouble();
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
            child: Column(
              children: [
                _artwork(book, artWidth, artHeight, constraints.maxWidth - 16),
                ...details,
              ],
            ),
          );
        }
        // Normal phones: the artwork takes all the height the details and
        // controls leave, so they sit just above the navigation bar.
        return Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, _bottomMargin),
          child: Column(
            children: [
              Expanded(
                child: LayoutBuilder(
                  builder: (context, area) {
                    final coverHeight = area.maxHeight
                        .clamp(0.0, area.maxWidth / _coverAspect)
                        .toDouble();
                    return Center(
                      child: _artwork(
                        book,
                        coverHeight * _coverAspect,
                        coverHeight,
                        area.maxWidth,
                      ),
                    );
                  },
                ),
              ),
              ...details,
            ],
          ),
        );
      },
    );
  }

  /// Portrait book cover proportions (width / height).
  static const _coverAspect = 0.68;

  /// Space between the playback controls and the navigation bar.
  static const _bottomMargin = 20.0;

  Widget _artwork(
    AudioBook book,
    double coverWidth,
    double height,
    double fullWidth,
  ) {
    return SizedBox(
      key: const ValueKey('playing-artwork'),
      width: book.images.isEmpty ? coverWidth : fullWidth,
      height: height,
      child: book.images.isEmpty
          ? CoverArt(book: book, borderRadius: 8, shadow: true)
          : BookImageCarousel(
              key: ValueKey(book.id),
              app: app,
              book: book,
              coverWidth: coverWidth,
            ),
    );
  }

  Future<void> _showChapters(
    BuildContext context,
    AudiobookAppState app,
  ) async {
    final book = app.currentBook;
    if (book == null) return;
    final chapters = book.chapters;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1B1D21),
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.72,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        context.l10n.chaptersTitle,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: chapters.length,
                  itemBuilder: (context, index) {
                    final chapter = chapters[index];
                    final part = book.parts[chapter.partIndex];
                    return ListTile(
                      selected:
                          part.chapters.isEmpty &&
                          chapter.partIndex == app.currentPartIndex,
                      leading: Text(
                        '${index + 1}'.padLeft(2, '0'),
                        style: const TextStyle(color: Color(0xFFD8A15D)),
                      ),
                      title: Text(chapter.title),
                      subtitle:
                          book.parts.length > 1 && part.chapters.isNotEmpty
                          ? Text(part.chapterTitle)
                          : null,
                      trailing: Text(
                        _formatDuration(chapter.absoluteOffset),
                        style: const TextStyle(color: Colors.white54),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        app.seekChapter(chapter);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class NowPlayingBar extends StatelessWidget {
  const NowPlayingBar({required this.app, super.key});

  final AudiobookAppState app;

  @override
  Widget build(BuildContext context) {
    final book = app.currentBook!;
    return Material(
      color: const Color(0xFF23252A),
      child: InkWell(
        onTap: () => app.openTab(3),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 9, 12, 9),
          child: Row(
            children: [
              SizedBox(
                width: 42,
                height: 50,
                child: CoverArt(book: book, borderRadius: 4),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      authorLabel(context, book.author),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: app.playing
                    ? context.l10n.pauseTooltip
                    : context.l10n.playTooltip,
                onPressed: app.togglePlayPause,
                icon: Icon(
                  app.playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                ),
              ),
              IconButton(
                tooltip: context.l10n.stopTooltip,
                onPressed: app.stop,
                icon: const Icon(Icons.stop_rounded),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class BookTile extends StatelessWidget {
  const BookTile({
    required this.book,
    required this.progress,
    required this.onTap,
    this.onRemove,
    this.showProgress = false,
    super.key,
  });

  final AudioBook book;
  final double progress;
  final bool showProgress;
  final VoidCallback onTap;

  /// Long-press on the cover offers to remove the book; null disables it.
  final Future<void> Function()? onRemove;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 0.72,
            child: BookCoverMenu(
              onRemove: onRemove,
              child: CoverArt(book: book, borderRadius: 6, shadow: true),
            ),
          ),
          const SizedBox(height: 9),
          Text(
            book.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          Text(
            authorLabel(context, book.author),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white60, fontSize: 12),
          ),
          if (showProgress) ...[
            const SizedBox(height: 7),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 4,
                      backgroundColor: Colors.white12,
                      valueColor: const AlwaysStoppedAnimation(
                        Color(0xFFD8A15D),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '${(progress * 100).round()}%',
                  style: const TextStyle(color: Colors.white60, fontSize: 11),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class BookListRow extends StatelessWidget {
  const BookListRow({
    required this.book,
    required this.progress,
    required this.onTap,
    this.onRemove,
    super.key,
  });

  final AudioBook book;
  final double progress;
  final VoidCallback onTap;

  /// Long-press on the cover offers to remove the book; null disables it.
  final Future<void> Function()? onRemove;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF1B1D21),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              SizedBox(
                width: 60,
                height: 76,
                child: BookCoverMenu(
                  onRemove: onRemove,
                  child: CoverArt(book: book, borderRadius: 5),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      authorLabel(context, book.author),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 13,
                      ),
                    ),
                    if (book.parts.length > 1) ...[
                      const SizedBox(height: 5),
                      Text(
                        context.l10n.audioFileCount(book.parts.length),
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Text(
                '${(progress * 100).round()}%',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.play_circle_outline_rounded),
              const SizedBox(width: 4),
            ],
          ),
        ),
      ),
    );
  }
}

/// Cover plus the book's images. Swiping browses them; while playing, the
/// page follows [AudiobookAppState.imageIndex] (automatic image sync).
class BookImageCarousel extends StatefulWidget {
  const BookImageCarousel({
    required this.app,
    required this.book,
    required this.coverWidth,
    super.key,
  });

  final AudiobookAppState app;
  final AudioBook book;
  final double coverWidth;

  @override
  State<BookImageCarousel> createState() => _BookImageCarouselState();
}

class _BookImageCarouselState extends State<BookImageCarousel> {
  late final PageController _controller = PageController(
    initialPage: widget.app.imageIndex,
  );

  /// Page being shown programmatically; page changes caused by it are not
  /// manual swipes.
  int? _programmaticTarget;

  @override
  void didUpdateWidget(covariant BookImageCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final index = widget.app.imageIndex;
    if (_programmaticTarget == index) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => _showPage(index));
  }

  Future<void> _showPage(int index) async {
    if (!mounted || !_controller.hasClients) return;
    final current = _controller.page?.round();
    if (current == index || _programmaticTarget == index) return;
    _programmaticTarget = index;
    try {
      if (current == null || (current - index).abs() > 1) {
        _controller.jumpToPage(index);
      } else {
        await _controller.animateToPage(
          index,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOut,
        );
      }
    } finally {
      if (_programmaticTarget == index) _programmaticTarget = null;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final images = widget.book.images;
    final count = images.length + 1;
    return Stack(
      children: [
        PageView.builder(
          controller: _controller,
          itemCount: count,
          onPageChanged: (page) {
            if (_programmaticTarget != null) return;
            widget.app.showImage(page);
          },
          itemBuilder: (context, index) {
            if (index == 0) {
              return Center(
                child: SizedBox(
                  width: widget.coverWidth,
                  child: CoverArt(
                    book: widget.book,
                    borderRadius: 8,
                    shadow: true,
                  ),
                ),
              );
            }
            final image = images[index - 1];
            return Column(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      File(image.path),
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.medium,
                      errorBuilder: (_, _, _) => const Center(
                        child: Icon(
                          Icons.broken_image_outlined,
                          color: Colors.white38,
                          size: 48,
                        ),
                      ),
                    ),
                  ),
                ),
                if (image.caption != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
                    child: Text(
                      image.caption!,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        Positioned(
          top: 4,
          right: 4,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              child: Text(
                context.l10n.imageCounter(widget.app.imageIndex + 1, count),
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Long-press on a book cover: a popup menu with "Remove from library",
/// confirmed by a dialog before [onRemove] runs.
class BookCoverMenu extends StatelessWidget {
  const BookCoverMenu({required this.child, required this.onRemove, super.key});

  final Widget child;
  final Future<void> Function()? onRemove;

  @override
  Widget build(BuildContext context) {
    final remove = onRemove;
    if (remove == null) return child;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPressStart: (details) =>
          _showMenu(context, details.globalPosition, remove),
      child: child,
    );
  }

  Future<void> _showMenu(
    BuildContext context,
    Offset position,
    Future<void> Function() remove,
  ) async {
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final choice = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        position & const Size(1, 1),
        Offset.zero & overlay.size,
      ),
      items: [
        PopupMenuItem(
          value: 'remove',
          child: ListTile(
            leading: const Icon(Icons.delete_outline_rounded),
            title: Text(context.l10n.removeFromLibrary),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    );
    if (choice != 'remove' || !context.mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.removeConfirmTitle),
        content: Text(context.l10n.removeConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.remove),
          ),
        ],
      ),
    );
    if (confirmed == true) await remove();
  }
}

/// Progress bar that seeks on release. While dragging, a bubble above the
/// thumb (kept inside the screen) and a large readout show the target time,
/// so the finger never hides it.
class SeekBar extends StatefulWidget {
  const SeekBar({
    required this.position,
    required this.duration,
    required this.onSeek,
    super.key,
  });

  final Duration position;
  final Duration duration;
  final Future<void> Function(Duration target) onSeek;

  @override
  State<SeekBar> createState() => _SeekBarState();
}

class _SeekBarState extends State<SeekBar> {
  double? _dragValue;

  static const _bubbleWidth = 72.0;

  /// Space left and right of the bar so a thumb can comfortably reach 0 and
  /// the end. Touches in this margin still drive the slider and clamp to the
  /// ends.
  static const _sideMargin = 28.0;

  @override
  Widget build(BuildContext context) {
    final max = widget.duration.inMilliseconds.clamp(1, 1 << 31).toDouble();
    final value = (_dragValue ?? widget.position.inMilliseconds.toDouble())
        .clamp(0.0, max);
    final dragging = _dragValue != null;
    final target = Duration(milliseconds: value.round());
    const small = TextStyle(color: Colors.white60, fontSize: 12);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final inset = _sideMargin;
        final thumbX = inset + value / max * (width - 2 * inset);
        double toValue(double dx) {
          final track = (width - 2 * inset).clamp(1.0, double.infinity);
          return ((dx - inset) / track).clamp(0.0, 1.0) * max;
        }

        void seekTo(double v) =>
            unawaited(widget.onSeek(Duration(milliseconds: v.round())));

        final bubbleLeft = (thumbX - _bubbleWidth / 2)
            .clamp(0.0, (width - _bubbleWidth).clamp(0.0, double.infinity))
            .toDouble();
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // The whole width, margins included, takes the touches: a
                // drag or tap in a margin clamps to 0 or to the end.
                GestureDetector(
                  key: const ValueKey('seek-touch-area'),
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragStart: (d) =>
                      setState(() => _dragValue = toValue(d.localPosition.dx)),
                  onHorizontalDragUpdate: (d) =>
                      setState(() => _dragValue = toValue(d.localPosition.dx)),
                  onHorizontalDragEnd: (_) {
                    final v = _dragValue;
                    setState(() => _dragValue = null);
                    if (v != null) seekTo(v);
                  },
                  onHorizontalDragCancel: () =>
                      setState(() => _dragValue = null),
                  // Show the time bubble as soon as the finger rests on it.
                  onTapDown: (d) =>
                      setState(() => _dragValue = toValue(d.localPosition.dx)),
                  onTapCancel: () => setState(() => _dragValue = null),
                  onTapUp: (d) {
                    setState(() => _dragValue = null);
                    seekTo(toValue(d.localPosition.dx));
                  },
                  child: IgnorePointer(
                    child: Slider(
                      padding: EdgeInsets.symmetric(horizontal: inset),
                      value: value,
                      max: max,
                      onChanged: (_) {},
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: inset),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_formatDuration(widget.position), style: small),
                      Text(_formatDuration(widget.duration), style: small),
                    ],
                  ),
                ),
              ],
            ),
            if (dragging) ...[
              Positioned(
                left: 0,
                right: 0,
                top: -78,
                child: IgnorePointer(
                  child: Center(
                    child: DecoratedBox(
                      key: const ValueKey('seek-readout'),
                      decoration: BoxDecoration(
                        color: const Color(0xEE1B1D21),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 4,
                        ),
                        child: Text(
                          context.l10n.seekReadout(
                            _formatDuration(target),
                            _formatDuration(widget.duration),
                          ),
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: bubbleLeft,
                top: -34,
                width: _bubbleWidth,
                child: IgnorePointer(
                  child: DecoratedBox(
                    key: const ValueKey('seek-bubble'),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD8A15D),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        _formatDuration(target),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class CoverArt extends StatelessWidget {
  const CoverArt({
    required this.book,
    required this.borderRadius,
    this.shadow = false,
    super.key,
  });

  final AudioBook book;
  final double borderRadius;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    final bytes = book.coverBytes;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: shadow
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.32),
                  blurRadius: 18,
                  offset: const Offset(0, 9),
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: bytes != null
            ? Image.memory(
                bytes,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _generatedCover(),
              )
            : _generatedCover(),
      ),
    );
  }

  Widget _generatedCover() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Thumbnails (list rows, mini player) are too small for the text.
        if (constraints.maxHeight < 200 || constraints.maxWidth < 120) {
          return const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF554435),
                  Color(0xFF28221D),
                  Color(0xFF18191C),
                ],
              ),
            ),
            child: Center(
              child: Icon(Icons.auto_stories_rounded, color: Color(0xFFE0B77F)),
            ),
          );
        }
        return _fullGeneratedCover(context);
      },
    );
  }

  Widget _fullGeneratedCover(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF554435), Color(0xFF28221D), Color(0xFF18191C)],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            const Icon(Icons.auto_stories_rounded, color: Color(0xFFE0B77F)),
            const Spacer(),
            Text(
              book.title,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                height: 1.12,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              authorLabel(context, book.author),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class SectionHeading extends StatelessWidget {
  const SectionHeading({required this.title, this.count, super.key});

  final String title;
  final int? count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        if (count != null)
          Text('$count', style: const TextStyle(color: Colors.white38)),
      ],
    );
  }
}

class CompactPlayerButton extends StatelessWidget {
  const CompactPlayerButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    super.key,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: 23),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 36, height: 40),
      visualDensity: VisualDensity.compact,
    );
  }
}

class EmptyHint extends StatelessWidget {
  const EmptyHint({
    required this.icon,
    required this.title,
    required this.detail,
    this.action,
    super.key,
  });

  final IconData icon;
  final String title;
  final String detail;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: const Color(0xFFD8A15D)),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              detail,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white60, height: 1.45),
            ),
            if (action != null) ...[const SizedBox(height: 18), action!],
          ],
        ),
      ),
    );
  }
}

String _formatDuration(Duration duration) => formatClock(duration);
