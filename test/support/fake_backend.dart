import 'dart:async';

import 'package:audiobook_player/audio/playback_backend.dart';
import 'package:audiobook_player/models/audiobook.dart';

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
