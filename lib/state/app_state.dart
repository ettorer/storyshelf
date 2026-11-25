import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../audio/playback_backend.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter/services.dart';
import 'package:haudiotagger/haudiotagger.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../images/book_images.dart';
import '../l10n/app_localizations.dart';
import '../models/audiobook.dart';

class AudiobookAppState extends ChangeNotifier {
  AudiobookAppState({AudioPlaybackBackend? player})
    : _player = player ?? JustAudioPlaybackBackend() {
    _subscriptions.addAll([
      _player.snapshots.listen(_onSnapshot),
      _player.errors.listen((error) => _setMessage(l10n.errPlay(currentBook?.title ?? '', error))),
    ]);
  }

  final AudioPlaybackBackend _player;
  final Map<String, int> _progressMs = {};
  final Map<int, Duration> _actualDurations = {};
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  final ImageSync _imageSync = ImageSync();

  /// Strings for messages produced here; the UI keeps it in sync with the
  /// device language.
  AppLocalizations l10n = lookupAppLocalizations(const Locale('en'));

  SharedPreferences? _preferences;
  Directory? _libraryDirectory;
  StreamSubscription<List<SharedMediaFile>>? _sharingSubscription;
  Timer? _progressSaveTimer;
  bool _disposed = false;
  bool _loadingBook = false;
  bool _seeking = false;
  bool _completed = false;

  List<AudioBook> books = [];
  List<String> _recentIds = [];
  AudioBook? currentBook;
  int currentPartIndex = 0;
  int selectedTab = 0;
  String? selectedAuthor;
  Duration position = Duration.zero;
  Duration duration = Duration.zero;
  double speed = 1;
  bool playing = false;
  bool busy = false;

  List<String> get authors {
    final names = books.map((book) => book.author).toSet().toList();
    names.sort(_compareText);
    return names;
  }

  List<AudioBook> get sortedBooks {
    final result = [...books];
    result.sort((a, b) => _compareText(a.title, b.title));
    return result;
  }

  List<AudioBook> get recentBooks {
    final byId = {for (final book in books) book.id: book};
    return _recentIds.map((id) => byId[id]).whereType<AudioBook>().toList();
  }

  /// Cover (index 0) followed by every chapter image, see [imageIndex].
  int get imageCount => 1 + (currentBook?.images.length ?? 0);

  /// Image currently shown on the playing page: 0 is the cover, then the
  /// book's images in chapter and time order.
  int get imageIndex => _imageSync.displayed.clamp(0, imageCount - 1).toInt();

  /// Manual swipe on the playing page. Automatic sync resumes when the next
  /// image time is reached, the chapter changes or the user seeks.
  void showImage(int index) {
    if (index == imageIndex) return;
    _imageSync.swipeTo(index);
    _notify();
  }

  void _resetImage(Duration localPosition) {
    final book = currentBook;
    _imageSync.reset(
      book == null
          ? 0
          : autoImageIndex(book.imagesByPart, currentPartIndex, localPosition),
    );
  }

  AudioPart? get currentPart {
    final book = currentBook;
    if (book == null || currentPartIndex >= book.parts.length) return null;
    return book.parts[currentPartIndex];
  }

  double progressFor(AudioBook book) {
    final total = _durationForBook(book);
    if (total <= Duration.zero) return 0;
    final value = _progressMs[book.id] ?? 0;
    return (value / total.inMilliseconds).clamp(0, 1).toDouble();
  }

  Future<void> initialize() async {
    _preferences = await SharedPreferences.getInstance();
    _libraryDirectory = Directory(
      p.join((await getApplicationSupportDirectory()).path, 'audiobooks'),
    );
    await _libraryDirectory!.create(recursive: true);
    _recentIds = _preferences!.getStringList('recentBooks') ?? [];
    speed = snapSpeed(_preferences!.getDouble('playback.speed') ?? 1);
    for (final entry in _preferences!.getKeys()) {
      if (entry.startsWith('progress.')) {
        final value = _preferences!.getInt(entry);
        if (value != null) {
          _progressMs[entry.substring('progress.'.length)] = value;
        }
      }
    }

    final storedPaths = _preferences!.getStringList('library.paths') ?? [];
    await _rebuildLibrary(storedPaths);



    _sharingSubscription = ReceiveSharingIntent.instance
        .getMediaStream()
        .listen(
          (files) => unawaited(_openSharedFiles(files)),
          onError: (Object error) => _setMessage(l10n.errReceiveFile('$error')),
        );
    try {
      final initial = await ReceiveSharingIntent.instance.getInitialMedia();
      if (initial.isNotEmpty) await _openSharedFiles(initial);
      await ReceiveSharingIntent.instance.reset();
    } catch (error) {
      _setMessage(l10n.errOpenFile('$error'));
    }
    await takePlatformFile();
  }

  Future<void> takePlatformFile() async {
    if (!Platform.isIOS) return;
    try {
      final path = await const MethodChannel('storyshelf/open_file')
          .invokeMethod<String>('takePendingFile');
      if (path != null && path.isNotEmpty) {
        await importFiles([path], autoplay: true);
      }
    } on PlatformException catch (error) {
      _setMessage(l10n.errOpenFile('${error.message}'));
    }
  }

  Future<void> pickAudioFiles() async {
    try {
      final result = await FilePicker.pickFiles(type: FileType.audio);
      if (result.isEmpty) return;
      final paths = result.map((file) => file.path).whereType<String>();
      await importFiles(paths.toList());
    } catch (error) {
      _setMessage(l10n.errSelectFiles('$error'));
    }
  }

  Future<void> importFiles(
    List<String> incomingPaths, {
    bool autoplay = false,
  }) async {
    if (busy) return;
    busy = true;
    _notify();
    final preferences = _preferences!;
    final paths = preferences.getStringList('library.paths') ?? [];
    final sources = _readSourceMap(preferences.getString('sourceMap'));
    final imported = <String>[];
    final failures = <String>[];
    String? folderAccessNote;
    final pathSet = paths.toSet();
    final importDirectories = <String, Directory>{};
    final temporaryFolders = <String>{};
    // Chapters already in the library, so importing a book again (Android
    // hands us fresh cache copies each time) reuses them instead of
    // duplicating every chapter.
    final libraryParts = <String, String>{
      for (final book in books)
        for (final part in book.parts)
          '${book.id}|${p.basename(part.path).toLowerCase()}': part.path,
    };
    try {
      for (final incoming in incomingPaths) {
        if (p.extension(incoming).toLowerCase() != '.mp3') {
          failures.add(l10n.errNotMp3(p.basename(incoming)));
          continue;
        }
        try {
          final source = _pathFromUri(incoming);
          final mapped = sources[_sourceKey(source)] ?? sources[incoming];
          final metadataPath = mapped != null && await File(mapped).exists()
              ? mapped
              : source;
          final selectedTrack = await _readTrack(metadataPath);
          final folder = Directory(p.dirname(source));
          final siblings = <File>[];
          try {
            await for (final entity in folder.list(followLinks: false)) {
              if (entity is File &&
                  p.extension(entity.path).toLowerCase() == '.mp3') {
                siblings.add(entity);
              }
            }
          } on FileSystemException catch (error) {
            failures.add(l10n.errListFolder(p.basename(source), '$error'));
          }

          // Folders that may hold the images/ subfolder and JSON sidecars.
          final companionFolders = <String>{};
          final selectedKey = _sourceKey(source);
          final candidates = <String, ImportedTrack>{
            selectedKey: selectedTrack,
          };
          var foundMatchingSibling = false;
          for (final sibling in siblings) {
            final siblingKey = _sourceKey(sibling.path);
            if (siblingKey == selectedKey) continue;
            try {
              final track = await _readTrack(sibling.path);
              if (sameBookTracks(selectedTrack, track)) {
                candidates[siblingKey] = track;
                foundMatchingSibling = true;
              }
            } catch (error) {
              failures.add(
                l10n.errReadTags(p.basename(sibling.path), '$error'),
              );
            }
          }

          if (!foundMatchingSibling && _needsFolderAccess(source)) {
            try {
              final folderUri = await FilePicker.pickDirectory(
                dialogTitle: l10n.pickFolderTitle,
              );
              if (folderUri == null) {
                folderAccessNote = l10n.noteOnlySelected;
              } else {
                final folderFiles = await _listFolderMp3s(folderUri);
                companionFolders.addAll(folderFiles.map(p.dirname));
                if (Platform.isAndroid) {
                  temporaryFolders.addAll(folderFiles.map(p.dirname));
                }
                for (final folderFile in folderFiles) {
                  if (p.basename(folderFile).toLowerCase() ==
                      p.basename(source).toLowerCase()) {
                    continue;
                  }
                  try {
                    final track = await _readTrack(folderFile);
                    if (sameBookTracks(selectedTrack, track)) {
                      candidates[_sourceKey(folderFile)] = track;
                      foundMatchingSibling = true;
                    }
                  } catch (error) {
                    failures.add(
                      l10n.errReadTags(p.basename(folderFile), '$error'),
                    );
                  }
                }
                if (!foundMatchingSibling) {
                  folderAccessNote = l10n.noteNoMatches;
                }
              }
            } catch (error) {
              folderAccessNote = l10n.noteScanFailed('$error');
            }
          }

          final placedFrom = imported.length;
          for (final entry in candidates.entries) {
            final candidatePath = entry.value.path;
            final sourceKey = entry.key;
            final existing = sources[sourceKey];
            if (existing != null && await File(existing).exists()) {
              if (pathSet.add(existing)) paths.add(existing);
              imported.add(existing);
              continue;
            }
            final libraryCopy = entry.value.hasBookTags
                ? libraryParts['${_bookId(entry.value.title, entry.value.author)}|${p.basename(candidatePath).toLowerCase()}']
                : null;
            if (libraryCopy != null && await File(libraryCopy).exists()) {
              if (pathSet.add(libraryCopy)) paths.add(libraryCopy);
              imported.add(libraryCopy);
              continue;
            }
            if (_isInsideLibrary(candidatePath)) {
              if (pathSet.add(candidatePath)) paths.add(candidatePath);
              imported.add(candidatePath);
              continue;
            }
            try {
              final file = File(candidatePath);
              if (!await file.exists()) {
                failures.add(l10n.errNotFound(p.basename(candidatePath)));
                continue;
              }
              final bookId =
                  '${_bookId(selectedTrack.title, selectedTrack.author)}|${p.dirname(candidatePath)}';
              final importDirectory = importDirectories.putIfAbsent(
                bookId,
                () => Directory(
                  p.join(
                    _libraryDirectory!.path,
                    '${DateTime.now().microsecondsSinceEpoch}_${_safeDirectoryName(selectedTrack.title)}',
                  ),
                ),
              );
              await importDirectory.create(recursive: true);
              final destination = p.join(
                importDirectory.path,
                p.basename(candidatePath),
              );
              await file.copy(destination);
              if (pathSet.add(destination)) paths.add(destination);
              sources[sourceKey] = destination;
              imported.add(destination);
            } catch (error) {
              failures.add(l10n.errFile(p.basename(candidatePath), '$error'));
            }
          }
          companionFolders.addAll(
            candidates.values.map((track) => p.dirname(track.path)),
          );
          await copyCompanionFiles(
            companionFolders,
            imported.sublist(placedFrom),
            failures,
            copyError: l10n.errCopyImages,
          );
        } catch (error) {
          failures.add(l10n.errFile(p.basename(incoming), '$error'));
        }
      }
      for (final folder in temporaryFolders) {
        try {
          await Directory(folder).delete(recursive: true);
        } catch (_) {
          // Temporary chapter copies live in the cache; Android can clear them.
        }
      }
      await preferences.setStringList('library.paths', paths);
      await preferences.setString('sourceMap', jsonEncode(sources));
      await _rebuildLibrary(paths);
      if (autoplay && imported.isNotEmpty) {
        final book = books
            .where(
              (item) => item.parts.any((part) => imported.contains(part.path)),
            )
            .firstOrNull;
        if (book != null) await playBook(book);
      }
      if (failures.isNotEmpty) {
        _setMessage(
          [
            ?folderAccessNote,
            l10n.importFailures(failures.join('\n')),
          ].join('\n'),
        );
      } else if (folderAccessNote != null) {
        _setMessage(folderAccessNote);
      } else if (imported.isNotEmpty) {
        _setMessage(l10n.importedFiles(imported.length));
      }
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<void> _openSharedFiles(List<SharedMediaFile> files) async {
    final audioPaths = files
        .where((file) => p.extension(file.path).toLowerCase() == '.mp3')
        .map((file) => file.path)
        .toList();
    if (audioPaths.isEmpty) {
      _setMessage(l10n.errSelectedNotMp3);
      return;
    }
    await importFiles(audioPaths, autoplay: true);
    await ReceiveSharingIntent.instance.reset();
  }

  bool _isInsideLibrary(String path) {
    final library = _libraryDirectory?.path;
    if (library == null) return false;
    return p.isWithin(p.absolute(library), p.absolute(path));
  }

  bool _needsFolderAccess(String path) {
    final normalized = p.normalize(p.absolute(path));
    if (Platform.isAndroid) {
      return normalized.contains('/cache/file_picker/') ||
          normalized.contains('/cache/receive_sharing_intent/');
    }
    if (Platform.isIOS) {
      return p.isWithin(
        p.normalize(p.absolute(Directory.systemTemp.path)),
        normalized,
      );
    }
    return false;
  }

  Future<List<String>> _listFolderMp3s(Uri folderUri) async {
    if (Platform.isAndroid) {
      final files = await const MethodChannel('storyshelf/audio_folder')
          .invokeListMethod<String>('copyMp3Files', {
            'treeUri': folderUri.toString(),
          });
      return files ?? const [];
    }
    if (folderUri.scheme != 'file') {
      throw FileSystemException(l10n.errNotLocalFolder);
    }
    final directory = Directory(folderUri.toFilePath());
    final files = <String>[];
    await for (final entity in directory.list(followLinks: false)) {
      if (entity is File && p.extension(entity.path).toLowerCase() == '.mp3') {
        files.add(entity.path);
      }
    }
    return files;
  }

  /// Removes [book] from the library: stops it if it is playing, forgets its
  /// paths, resume position and recent entry, and deletes its copies in the
  /// app's library folder. Files outside app storage are never deleted.
  Future<void> removeBook(AudioBook book) async {
    if (currentBook?.id == book.id) await stop();
    final preferences = _preferences;
    final library = _libraryDirectory?.path;
    final partPaths = book.parts.map((part) => part.path).toSet();
    final paths = (preferences?.getStringList('library.paths') ?? [])
        .where((path) => !partPaths.contains(path))
        .toList();
    final sources = _readSourceMap(preferences?.getString('sourceMap'))
      ..removeWhere((_, value) => partPaths.contains(value));
    if (library != null) {
      await deleteImportedBookFiles(
        book: book,
        libraryPath: library,
        keptPaths: paths.toSet(),
      );
    }
    _progressMs.remove(book.id);
    _recentIds.remove(book.id);
    await preferences?.remove('progress.${book.id}');
    await preferences?.setStringList('recentBooks', _recentIds);
    await preferences?.setStringList('library.paths', paths);
    await preferences?.setString('sourceMap', jsonEncode(sources));
    books = books.where((item) => item.id != book.id).toList();
    if (preferences != null) await _rebuildLibrary(paths);
    _setMessage(l10n.bookRemoved(book.title));
  }

  Future<void> playBook(AudioBook book) async {
    if (book.parts.isEmpty) return;
    busy = true;
    _loadingBook = true;
    _completed = false;
    _saveProgress();
    currentBook = book;
    _actualDurations.clear();
    final saved = Duration(milliseconds: _progressMs[book.id] ?? 0);
    final resumeAt = saved > const Duration(seconds: 5)
        ? saved - const Duration(seconds: 5)
        : Duration.zero;
    final target = _partAndOffset(book, resumeAt);
    currentPartIndex = target.$1;
    position = target.$2 + _startOffsetForPart(book, target.$1);
    duration = _durationForBook(book);
    selectedTab = 3;
    _recentIds.remove(book.id);
    _recentIds.insert(0, book.id);
    if (_recentIds.length > 30) _recentIds = _recentIds.take(30).toList();
    await _preferences?.setStringList('recentBooks', _recentIds);
    _resetImage(target.$2);
    _notify();
    try {
      await _player.loadBook(
        book,
        initialIndex: target.$1,
        initialPosition: target.$2,
        speed: speed,
        unknownAuthorLabel: l10n.unknownAuthor,
      );
      _loadingBook = false;
      _applySnapshot(_player.currentSnapshot);
    } catch (error) {
      _setMessage(l10n.errPlay(book.title, '$error'));
    } finally {
      _loadingBook = false;
      busy = false;
      _notify();
    }
  }

  Future<void> togglePlayPause() async {
    if (currentBook == null || busy) return;
    try {
      if (playing) {
        await _player.pause();
        _saveProgress();
      } else {
        if (_completed) {
          _completed = false;
          await _player.seek(Duration.zero, partIndex: 0);
        }
        await _player.play();
      }
    } catch (error) {
      _setMessage(l10n.errPlaybackChange('$error'));
    }
  }

  Future<void> stop() async {
    if (currentBook == null) return;
    _saveProgress();
    try {
      await _player.stop();
    } catch (error) {
      _setMessage(l10n.errPlaybackStop('$error'));
    }
    currentBook = null;
    currentPartIndex = 0;
    _completed = false;
    _imageSync.reset(0);
    position = Duration.zero;
    duration = Duration.zero;
    playing = false;
    _progressSaveTimer?.cancel();
    _notify();
  }

  Future<void> seek(Duration target) async {
    final book = currentBook;
    if (book == null) return;
    final total = _durationForBook(book);
    final clamped = target < Duration.zero
        ? Duration.zero
        : total > Duration.zero && target > total
        ? total
        : target;
    final location = _partAndOffset(book, clamped);
    _seeking = true;
    try {
      await _player.seek(location.$2, partIndex: location.$1);
      _completed = false;
      currentPartIndex = location.$1;
      position = clamped;
      _resetImage(location.$2);
      _saveProgress();
      _notify();
    } catch (error) {
      _setMessage(l10n.errSeek('$error'));
    } finally {
      _seeking = false;
    }
  }

  Future<void> seekBy(Duration amount) => seek(position + amount);

  Future<void> seekChapter(BookChapter chapter) async {
    final book = currentBook;
    if (book == null) return;
    _seeking = true;
    try {
      await _player.seek(chapter.offset, partIndex: chapter.partIndex);
      _completed = false;
      currentPartIndex = chapter.partIndex;
      position = chapter.absoluteOffset;
      _resetImage(chapter.offset);
      if (!playing) {
        await _player.play();
      }
      _saveProgress();
      _notify();
    } catch (error) {
      _setMessage(l10n.errOpenChapter(chapter.title, '$error'));
    } finally {
      _seeking = false;
    }
  }

  Future<void> previousChapter() async {
    final book = currentBook;
    if (book == null || book.parts.length < 2) return;
    if (currentPartIndex == 0) {
      await seek(Duration.zero);
      return;
    }
    final targetIndex = currentPartIndex - 1;
    _seeking = true;
    try {
      await _player.seek(Duration.zero, partIndex: targetIndex);
      _completed = false;
      currentPartIndex = targetIndex;
      position = _startOffsetForPart(book, targetIndex);
      _resetImage(Duration.zero);
      if (!playing) {
        await _player.play();
      }
      _saveProgress();
      _notify();
    } catch (error) {
      _setMessage(l10n.errPreviousFile('$error'));
    } finally {
      _seeking = false;
    }
  }

  Future<void> nextChapter() async {
    final book = currentBook;
    if (book == null || currentPartIndex + 1 >= book.parts.length) return;
    final targetIndex = currentPartIndex + 1;
    _seeking = true;
    try {
      await _player.seek(Duration.zero, partIndex: targetIndex);
      _completed = false;
      currentPartIndex = targetIndex;
      position = _startOffsetForPart(book, targetIndex);
      _resetImage(Duration.zero);
      if (!playing) {
        await _player.play();
      }
      _saveProgress();
      _notify();
    } catch (error) {
      _setMessage(l10n.errNextFile('$error'));
    } finally {
      _seeking = false;
    }
  }

  static const double minSpeed = 0.5;
  static const double maxSpeed = 2.0;
  static const double speedStep = 0.25;

  /// Snaps [value] to the 0.25 grid between 0.5× and 2×.
  static double snapSpeed(double value) {
    final steps = ((value - minSpeed) / speedStep).round();
    return (minSpeed + steps * speedStep).clamp(minSpeed, maxSpeed).toDouble();
  }

  Future<void> setSpeed(double value) async {
    final next = snapSpeed(value);
    if (next == speed) return;
    speed = next;
    _notify();
    try {
      await _player.setSpeed(speed);
    } catch (error) {
      _setMessage(l10n.errSpeed('$error'));
    }
    await _preferences?.setDouble('playback.speed', speed);
  }

  /// Refreshes UI state from the underlying background player (for example
  /// after unlocking the phone and returning to the app).
  Future<void> syncPlaybackState() async {
    if (_disposed || currentBook == null || _loadingBook || _seeking) return;
    _applySnapshot(_player.currentSnapshot);
  }

  void openTab(int tab) {
    selectedTab = tab;
    if (tab != 2) selectedAuthor = null;
    _notify();
  }

  void openAuthor(String author) {
    selectedAuthor = author;
    selectedTab = 2;
    _notify();
  }

  void clearAuthor() {
    selectedAuthor = null;
    _notify();
  }

  List<AudioBook> booksByAuthor(String author) {
    final result = books.where((book) => book.author == author).toList();
    result.sort((a, b) => _compareText(a.title, b.title));
    return result;
  }

  String? takeMessage() {
    final value = _message;
    _message = null;
    return value;
  }

  String? _message;

  Future<void> _rebuildLibrary(List<String> paths) async {
    final tracks = <ImportedTrack>[];
    for (final path in paths) {
      if (!await File(path).exists()) continue;
      try {
        tracks.add(await _readTrack(path));
      } catch (error) {
        tracks.add(
          ImportedTrack(
            path: path,
            title: bookTitleFromFilename(path),
            author: unknownAuthorKey,
            chapterTitle: chapterTitleFromFilename(path),
            trackNumber: chapterNumberFromFilename(path),
            duration: Duration.zero,
            coverBytes: null,
            chapters: const [],
            hasBookTags: false,
          ),
        );
        _setMessage(l10n.errTagsFallback(p.basename(path)));
      }
    }
    books = groupTracksIntoBooks(tracks);
    books.sort((a, b) => _compareText(a.title, b.title));
    _notify();
  }

  Future<ImportedTrack> _readTrack(String path) async {
    final tag = await Haudiotagger.read(path);
    Duration trackDuration = Duration.zero;
    try {
      trackDuration =
          (await Haudiotagger.readProperties(path)).duration ?? Duration.zero;
    } catch (error) {
      trackDuration = Duration.zero;
      _setMessage(l10n.errDuration(p.basename(path), '$error'));
    }
    final cover = tag?.pictures
        .where((picture) => picture.bytes.isNotEmpty)
        .map((picture) => picture.bytes)
        .firstOrNull;
    var lyrics = tag?.lyrics;
    if (lyrics == null || lyrics.trim().isEmpty) {
      try {
        final customTags = await Haudiotagger.getCustomTags(path);
        lyrics = customTags.entries
            .where((entry) => entry.key.toUpperCase() == 'LYRICS')
            .map((entry) => entry.value)
            .firstOrNull;
      } catch (error) {
        _setMessage(l10n.errLyrics(p.basename(path), '$error'));
      }
    }
    final images = await readPartImages(path, lyrics: lyrics);
    return trackFromTags(
      path: path,
      images: images,
      title: tag?.title,
      album: tag?.album,
      albumArtist: tag?.albumArtist,
      trackArtist: tag?.trackArtist,
      trackNumber: tag?.trackNumber,
      duration: trackDuration,
      coverBytes: cover,
      lyrics: lyrics,
    );
  }

  void _onSnapshot(PlaybackSnapshot snapshot) {
    if (_disposed || _loadingBook || _seeking) return;
    _applySnapshot(snapshot);
  }

  void _applySnapshot(PlaybackSnapshot snapshot) {
    final book = currentBook;
    if (book == null || book.parts.isEmpty) return;

    if (snapshot.completed) {
      final wasCompleted = _completed;
      _completed = true;
      currentPartIndex = book.parts.length - 1;
      final total = _durationForBook(book);
      duration = total;
      position = total;
      playing = false;
      _progressMs[book.id] = position.inMilliseconds;
      _progressSaveTimer?.cancel();
      unawaited(_persistProgress(book.id));
      if (!wasCompleted) {
        unawaited(_player.pause());
      }
      _notify();
      return;
    }

    _completed = false;
    final previousPart = currentPartIndex;
    final partIndex =
        snapshot.partIndex.clamp(0, book.parts.length - 1).toInt();
    final partChanged = partIndex != previousPart;
    currentPartIndex = partIndex;

    final reportedDuration = snapshot.partDuration;
    if (reportedDuration != null && reportedDuration > Duration.zero) {
      _actualDurations[partIndex] = reportedDuration;
    }
    duration = _durationForBook(book);

    var localPosition = snapshot.localPosition < Duration.zero
        ? Duration.zero
        : snapshot.localPosition;
    final partDur = _partDuration(book, partIndex);
    if (partDur > Duration.zero && localPosition > partDur) {
      localPosition = partDur;
    }

    position = _startOffsetForPart(book, partIndex) + localPosition;
    final wasPlaying = playing;
    playing = snapshot.playing;

    if (partChanged) {
      _resetImage(localPosition);
      _progressMs[book.id] = position.inMilliseconds;
      _progressSaveTimer?.cancel();
      unawaited(_persistProgress(book.id));
    } else {
      _imageSync.update(
        autoImageIndex(book.imagesByPart, partIndex, localPosition),
      );
      _progressMs[book.id] = position.inMilliseconds;
      if (wasPlaying && !playing) {
        _progressSaveTimer?.cancel();
        unawaited(_persistProgress(book.id));
      } else {
        _progressSaveTimer?.cancel();
        _progressSaveTimer = Timer(const Duration(seconds: 2), () {
          unawaited(_persistProgress(book.id));
        });
      }
    }
    _notify();
  }

  (int, Duration) _partAndOffset(AudioBook book, Duration absolute) {
    var remaining = absolute;
    for (var i = 0; i < book.parts.length; i++) {
      final partDuration = _partDuration(book, i);
      if (partDuration <= Duration.zero ||
          remaining <= partDuration ||
          i == book.parts.length - 1) {
        return (i, remaining);
      }
      remaining -= partDuration;
    }
    return (book.parts.length - 1, Duration.zero);
  }

  Duration _partDuration(AudioBook book, int index) =>
      book.parts[index].duration > Duration.zero
      ? book.parts[index].duration
      : _actualDurations[index] ?? Duration.zero;

  Duration _startOffsetForPart(AudioBook book, int index) {
    var result = Duration.zero;
    for (var i = 0; i < index; i++) {
      result += _partDuration(book, i);
    }
    return result;
  }

  Duration _durationForBook(AudioBook book) {
    var result = Duration.zero;
    for (var i = 0; i < book.parts.length; i++) {
      result += _partDuration(book, i);
    }
    return result;
  }

  void _saveProgress() {
    final book = currentBook;
    if (book == null) return;
    _progressMs[book.id] = position.inMilliseconds;
    _progressSaveTimer?.cancel();
    unawaited(_persistProgress(book.id));
  }

  Future<void> _persistProgress(String bookId) async {
    await _preferences?.setInt('progress.$bookId', _progressMs[bookId] ?? 0);
  }

  void _setMessage(String message) {
    _message = message;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _progressSaveTimer?.cancel();
    _sharingSubscription?.cancel();
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    unawaited(_player.dispose());
    super.dispose();
  }
}

/// Copies the epub-to-audio extras that sit next to the chapter MP3s (the
/// `images/` folder and `NN - Title.json` sidecars) beside the library
/// copies. Existing files are kept; missing ones are simply skipped.
Future<void> copyCompanionFiles(
  Set<String> sourceFolders,
  List<String> placedMp3s,
  List<String> failures, {
  String Function(String error)? copyError,
}) async {
  final targets = placedMp3s.map(p.dirname).toSet();
  for (final target in targets) {
    for (final folder in sourceFolders) {
      if (p.equals(folder, target)) continue;
      try {
        for (final mp3 in placedMp3s.where(
          (m) => p.equals(p.dirname(m), target),
        )) {
          final sidecar = File(p.join(folder, p.basename(sidecarPathFor(mp3))));
          final destination = File(sidecarPathFor(mp3));
          if (await sidecar.exists() && !await destination.exists()) {
            await sidecar.copy(destination.path);
          }
        }
        final images = Directory(p.join(folder, 'images'));
        if (!await images.exists()) continue;
        final imageTarget = Directory(p.join(target, 'images'));
        await imageTarget.create(recursive: true);
        await for (final entity in images.list(followLinks: false)) {
          if (entity is! File || !looksLikeImagePath(entity.path)) continue;
          final destination = p.join(imageTarget.path, p.basename(entity.path));
          if (!await File(destination).exists()) {
            await entity.copy(destination);
          }
        }
      } catch (error) {
        failures.add(
          (copyError ?? (e) => 'Could not copy the book images: $e')('$error'),
        );
      }
    }
  }
}

/// Deletes the library copies of [book]: each MP3 inside [libraryPath], its
/// JSON sidecar and its images, then the book's folder when nothing in
/// [keptPaths] still lives there. Paths outside [libraryPath] are skipped.
Future<void> deleteImportedBookFiles({
  required AudioBook book,
  required String libraryPath,
  required Set<String> keptPaths,
}) async {
  final library = p.normalize(p.absolute(libraryPath));
  bool inside(String path) =>
      p.isWithin(library, p.normalize(p.absolute(path)));
  Future<void> deleteFile(String path) async {
    if (!inside(path)) return;
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  final folders = <String>{};
  for (final part in book.parts) {
    if (!inside(part.path)) continue;
    folders.add(p.normalize(p.absolute(p.dirname(part.path))));
    await deleteFile(part.path);
    await deleteFile(sidecarPathFor(part.path));
    for (final image in part.images) {
      await deleteFile(image.path);
    }
  }
  for (final folder in folders) {
    if (p.equals(folder, library) || !inside(folder)) continue;
    final stillUsed = keptPaths.any(
      (path) => p.isWithin(folder, p.normalize(p.absolute(path))),
    );
    if (stillUsed) continue;
    try {
      await Directory(folder).delete(recursive: true);
    } catch (_) {}
  }
}

/// Author stored for MP3s without author tags; the UI shows it localized.
const unknownAuthorKey = 'Unknown Author';

/// Builds a track from its ID3 tags, falling back to the file name.
///
/// Books made by epub-to-audio tag every chapter with album = book title,
/// artist/album artist = author, title = chapter title and track = n/N.
/// Older books may only carry the book title in the title tag, or no tags at
/// all ("Book 01.mp3", "Book 02.mp3"); those still group and order correctly.
ImportedTrack trackFromTags({
  required String path,
  String? title,
  String? album,
  String? albumArtist,
  String? trackArtist,
  int? trackNumber,
  Duration duration = Duration.zero,
  Uint8List? coverBytes,
  String? lyrics,
  List<PartImage> images = const [],
}) {
  final cleanAlbum = _clean(album);
  final cleanTitle = _clean(title);
  final bookTitle = cleanAlbum ?? cleanTitle;
  final chapterTitle =
      cleanAlbum != null &&
          cleanTitle != null &&
          cleanTitle.toLowerCase() != cleanAlbum.toLowerCase()
      ? cleanTitle
      : chapterTitleFromFilename(path);
  return ImportedTrack(
    path: path,
    title: bookTitle ?? bookTitleFromFilename(path),
    author: _clean(albumArtist) ?? _clean(trackArtist) ?? unknownAuthorKey,
    chapterTitle: chapterTitle,
    trackNumber: trackNumber != null && trackNumber > 0
        ? trackNumber
        : chapterNumberFromFilename(path),
    duration: duration,
    coverBytes: coverBytes,
    chapters: parseChapters(lyrics),
    hasBookTags: bookTitle != null,
    images: images,
  );
}

/// Tracks with book tags group by album + author; untagged tracks group by
/// the folder they live in.
String bookKeyForTrack(ImportedTrack track) => track.hasBookTags
    ? _bookId(track.title, track.author)
    : 'folder|${p.normalize(p.dirname(track.path))}';

bool sameBookTracks(ImportedTrack first, ImportedTrack second) =>
    bookKeyForTrack(first) == bookKeyForTrack(second);

List<AudioBook> groupTracksIntoBooks(Iterable<ImportedTrack> tracks) {
  final groups = <String, List<ImportedTrack>>{};
  for (final track in tracks) {
    groups.putIfAbsent(bookKeyForTrack(track), () => []).add(track);
  }
  final result = groups.entries.map((entry) {
    final seenNames = <String>{};
    final group = orderBookTracks(entry.value)
        .where((track) => seenNames.add(p.basename(track.path).toLowerCase()))
        .toList();
    final first = group.first;
    return AudioBook(
      id: entry.key,
      title: first.hasBookTags ? first.title : _untaggedBookTitle(group),
      author: first.author,
      parts: group
          .map(
            (track) => AudioPart(
              path: track.path,
              chapterTitle: track.chapterTitle,
              trackNumber: track.trackNumber,
              duration: track.duration,
              chapters: track.chapters,
              images: track.images,
            ),
          )
          .toList(),
      coverBytes: group
          .map((track) => track.coverBytes)
          .whereType<Uint8List>()
          .firstOrNull,
    );
  }).toList();
  result.sort((a, b) => _compareText(a.title, b.title));
  return result;
}

String _untaggedBookTitle(List<ImportedTrack> group) {
  final stems = group.map((track) => track.title.toLowerCase()).toSet();
  if (stems.length == 1) return group.first.title;
  return _folderTitle(group.first.path) ?? group.first.title;
}

String? _folderTitle(String path) {
  final name = p
      .basename(p.dirname(path))
      .replaceFirst(RegExp(r'^\d{10,}_'), '')
      .replaceAll('_', ' ')
      .trim();
  return name.isEmpty || name == '.' ? null : name;
}

/// "Book 01.mp3" -> "Book"; "03.mp3" -> the folder name.
String bookTitleFromFilename(String path) {
  final stem = p
      .basenameWithoutExtension(path)
      .replaceAll(RegExp(r'\d+'), ' ')
      .replaceAll(RegExp(r'[\s._\-()\[\]]+'), ' ')
      .trim();
  if (stem.isNotEmpty) return stem;
  return _folderTitle(path) ?? p.basenameWithoutExtension(path);
}

List<ImportedTrack> orderBookTracks(Iterable<ImportedTrack> tracks) {
  final ordered = tracks.toList();
  ordered.sort((first, second) {
    final firstNumber =
        first.trackNumber ?? chapterNumberFromFilename(first.path) ?? 1 << 30;
    final secondNumber =
        second.trackNumber ?? chapterNumberFromFilename(second.path) ?? 1 << 30;
    final byNumber = firstNumber.compareTo(secondNumber);
    if (byNumber != 0) return byNumber;
    return _compareText(p.basename(first.path), p.basename(second.path));
  });
  return ordered;
}

/// Leading number ("03 - Title.mp3"), else the last number in the name
/// ("Book 3.mp3", "Book - Part 03.mp3").
int? chapterNumberFromFilename(String path) {
  final name = p.basenameWithoutExtension(path);
  final match =
      RegExp(r'^\s*(\d+)(?:[\s._)-]|$)').firstMatch(name) ??
      RegExp(r'(\d+)\D*$').firstMatch(name);
  return match == null ? null : int.tryParse(match.group(1)!);
}

String chapterTitleFromFilename(String path) {
  final basename = p.basenameWithoutExtension(path);
  final match = RegExp(r'^\s*\d+\s*[-_.\s)]*\s*(.+?)\s*$').firstMatch(basename);
  final title = match?.group(1)?.trim();
  return title == null || title.isEmpty ? basename : title;
}

List<PartChapter> parseChapters(String? lyrics) {
  if (lyrics == null || lyrics.trim().isEmpty) return const [];
  final result = <PartChapter>[];
  final pattern = RegExp(
    r'^\s*\[?(\d{1,3}):(\d{2})(?:[.:](\d{1,3}))?\]?\s*[-–:]?\s*(.*?)\s*$',
  );
  for (final line in const LineSplitter().convert(lyrics)) {
    final match = pattern.firstMatch(line);
    if (match == null) continue;
    final minutes = int.tryParse(match.group(1)!) ?? 0;
    final seconds = int.tryParse(match.group(2)!) ?? 0;
    final fraction = match.group(3) ?? '';
    final milliseconds = fraction.isEmpty
        ? 0
        : int.parse(fraction.padRight(3, '0').substring(0, 3));
    final title = match.group(4)?.trim() ?? '';
    if (title.isEmpty || _imageReference.hasMatch(title)) continue;
    result.add(
      PartChapter(
        title: title,
        offset: Duration(
          minutes: minutes,
          seconds: seconds,
          milliseconds: milliseconds,
        ),
      ),
    );
  }
  result.sort((a, b) => a.offset.compareTo(b.offset));
  return result;
}

/// epub-to-audio stores timed image paths ("images/01-02.jpg") in the
/// lyrics; they are not chapters.
final _imageReference = RegExp(
  r'\.(jpe?g|png|gif|webp|bmp|svg)$',
  caseSensitive: false,
);

String _bookId(String title, String author) =>
    '${author.trim().toLowerCase()}|${title.trim().toLowerCase()}';

String _sourceKey(String path) => p.normalize(p.absolute(path));

String _safeDirectoryName(String value) {
  final cleaned = value.replaceAll(RegExp(r'[^\w.-]+'), '_');
  return cleaned.isEmpty ? 'book' : cleaned;
}

String? _clean(String? value) {
  final cleaned = value?.trim();
  return cleaned == null || cleaned.isEmpty ? null : cleaned;
}

int _compareText(String a, String b) =>
    a.toLowerCase().compareTo(b.toLowerCase());

String _pathFromUri(String value) {
  final uri = Uri.tryParse(value);
  return uri != null && uri.scheme == 'file' ? uri.toFilePath() : value;
}

Map<String, String> _readSourceMap(String? encoded) {
  if (encoded == null) return {};
  try {
    return (jsonDecode(encoded) as Map<String, dynamic>).map(
      (key, value) => MapEntry(key, value as String),
    );
  } on FormatException {
    return {};
  } on TypeError {
    return {};
  }
}
