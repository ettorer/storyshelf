import 'dart:async';

import 'package:audiobook_player/audio/playback_backend.dart';
import 'package:audiobook_player/models/audiobook.dart';
import 'package:audiobook_player/state/app_state.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeAudioPlaybackBackend implements AudioPlaybackBackend {
  final StreamController<PlaybackSnapshot> _snapshots =
      StreamController<PlaybackSnapshot>.broadcast();
  final StreamController<String> _errors =
      StreamController<String>.broadcast();

  PlaybackSnapshot _snapshot = PlaybackSnapshot.empty;
  AudioBook? loadedBook;
  int? loadedInitialIndex;
  Duration? loadedInitialPosition;
  double? loadedSpeed;
  final List<(int?, Duration)> seeks = [];
  int playCalls = 0;
  int pauseCalls = 0;
  int stopCalls = 0;

  @override
  Stream<PlaybackSnapshot> get snapshots => _snapshots.stream;

  @override
  Stream<String> get errors => _errors.stream;

  @override
  PlaybackSnapshot get currentSnapshot => _snapshot;

  void emit(PlaybackSnapshot snapshot) {
    _snapshot = snapshot;
    _snapshots.add(snapshot);
  }

  void setSnapshotSilently(PlaybackSnapshot snapshot) {
    _snapshot = snapshot;
  }

  @override
  Future<void> loadBook(
    AudioBook book, {
    required int initialIndex,
    required Duration initialPosition,
    required double speed,
    required String unknownAuthorLabel,
  }) async {
    loadedBook = book;
    loadedInitialIndex = initialIndex;
    loadedInitialPosition = initialPosition;
    loadedSpeed = speed;
    _snapshot = PlaybackSnapshot(
      partIndex: initialIndex,
      localPosition: initialPosition,
      partDuration: book.parts[initialIndex].duration,
      playing: true,
      completed: false,
    );
  }

  @override
  Future<void> play() async {
    playCalls++;
    _snapshot = PlaybackSnapshot(
      partIndex: _snapshot.partIndex,
      localPosition: _snapshot.localPosition,
      partDuration: _snapshot.partDuration,
      playing: true,
      completed: false,
    );
    _snapshots.add(_snapshot);
  }

  @override
  Future<void> pause() async {
    pauseCalls++;
    _snapshot = PlaybackSnapshot(
      partIndex: _snapshot.partIndex,
      localPosition: _snapshot.localPosition,
      partDuration: _snapshot.partDuration,
      playing: false,
      completed: _snapshot.completed,
    );
    _snapshots.add(_snapshot);
  }

  @override
  Future<void> stop() async {
    stopCalls++;
    _snapshot = PlaybackSnapshot.empty;
    _snapshots.add(_snapshot);
  }

  @override
  Future<void> seek(Duration localPosition, {int? partIndex}) async {
    seeks.add((partIndex, localPosition));
    _snapshot = PlaybackSnapshot(
      partIndex: partIndex ?? _snapshot.partIndex,
      localPosition: localPosition,
      partDuration: _snapshot.partDuration,
      playing: _snapshot.playing,
      completed: false,
    );
    _snapshots.add(_snapshot);
  }

  @override
  Future<void> setSpeed(double speed) async {
    loadedSpeed = speed;
  }

  @override
  Future<void> dispose() async {
    await _snapshots.close();
    await _errors.close();
  }
}

AudioBook _threePartBook() => AudioBook(
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
        chapters: const [],
      ),
  ],
);

void main() {
  test('loads whole book playlist and advances across parts seamlessly', () async {
    final fake = FakeAudioPlaybackBackend();
    final app = AudiobookAppState(player: fake);
    final book = _threePartBook();
    await app.setSpeed(1.25);

    await app.playBook(book);

    expect(fake.loadedBook, book);
    expect(fake.loadedInitialIndex, 0);
    expect(fake.loadedInitialPosition, Duration.zero);
    expect(fake.loadedSpeed, 1.25);
    expect(app.playing, isTrue);
    expect(app.currentPartIndex, 0);
    expect(app.duration, const Duration(minutes: 30));

    // Native background player advances to part 1 (at 0:15 into part 1).
    fake.emit(
      const PlaybackSnapshot(
        partIndex: 1,
        localPosition: Duration(seconds: 15),
        partDuration: Duration(minutes: 10),
        playing: true,
        completed: false,
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(app.currentPartIndex, 1);
    expect(app.position, const Duration(minutes: 10, seconds: 15));
    expect(app.playing, isTrue);

    app.dispose();
  });

  test('syncPlaybackState refreshes position after background advancement while locked', () async {
    final fake = FakeAudioPlaybackBackend();
    final app = AudiobookAppState(player: fake);
    final book = _threePartBook();

    await app.playBook(book);

    // Simulate native service advancing to part 2 without Dart receiving stream
    // ticks while suspended, then resuming when the user unlocks the phone.
    fake.setSnapshotSilently(
      const PlaybackSnapshot(
        partIndex: 2,
        localPosition: Duration(minutes: 3, seconds: 20),
        partDuration: Duration(minutes: 10),
        playing: true,
        completed: false,
      ),
    );

    await app.syncPlaybackState();

    expect(app.currentPartIndex, 2);
    expect(app.position, const Duration(minutes: 23, seconds: 20));
    expect(app.playing, isTrue);

    app.dispose();
  });

  test('completion stops at book end and togglePlayPause restarts from part 0', () async {
    final fake = FakeAudioPlaybackBackend();
    final app = AudiobookAppState(player: fake);
    final book = _threePartBook();

    await app.playBook(book);

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

    expect(app.playing, isFalse);
    expect(app.position, const Duration(minutes: 30));
    expect(app.currentPartIndex, 2);

    await app.togglePlayPause();
    expect(fake.seeks.last, (0, Duration.zero));
    expect(fake.playCalls, 1);
    expect(app.playing, isTrue);

    app.dispose();
  });

  test('seek, nextChapter, and previousChapter map to correct part index and offset', () async {
    final fake = FakeAudioPlaybackBackend();
    final app = AudiobookAppState(player: fake);
    final book = _threePartBook();

    await app.playBook(book);

    await app.seek(const Duration(minutes: 14, seconds: 30));
    expect(fake.seeks.last, (1, const Duration(minutes: 4, seconds: 30)));
    expect(app.currentPartIndex, 1);
    expect(app.position, const Duration(minutes: 14, seconds: 30));

    await app.nextChapter();
    expect(fake.seeks.last, (2, Duration.zero));
    expect(app.currentPartIndex, 2);
    expect(app.position, const Duration(minutes: 20));

    await app.previousChapter();
    expect(fake.seeks.last, (1, Duration.zero));
    expect(app.currentPartIndex, 1);
    expect(app.position, const Duration(minutes: 10));

    app.dispose();
  });
}
