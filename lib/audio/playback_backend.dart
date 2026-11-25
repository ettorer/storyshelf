import 'dart:async';
import 'dart:io';

import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/audiobook.dart';

class PlaybackSnapshot {
  const PlaybackSnapshot({
    required this.partIndex,
    required this.localPosition,
    required this.partDuration,
    required this.playing,
    required this.completed,
  });

  static const empty = PlaybackSnapshot(
    partIndex: 0,
    localPosition: Duration.zero,
    partDuration: null,
    playing: false,
    completed: false,
  );

  final int partIndex;
  final Duration localPosition;
  final Duration? partDuration;
  final bool playing;
  final bool completed;
}

abstract class AudioPlaybackBackend {
  Stream<PlaybackSnapshot> get snapshots;
  Stream<String> get errors;
  PlaybackSnapshot get currentSnapshot;

  Future<void> loadBook(
    AudioBook book, {
    required int initialIndex,
    required Duration initialPosition,
    required double speed,
    required String unknownAuthorLabel,
  });

  Future<void> play();
  Future<void> pause();
  Future<void> stop();
  Future<void> seek(Duration localPosition, {int? partIndex});
  Future<void> setSpeed(double speed);
  Future<void> dispose();
}

class JustAudioPlaybackBackend implements AudioPlaybackBackend {
  final StreamController<PlaybackSnapshot> _snapshotController =
      StreamController<PlaybackSnapshot>.broadcast();
  final StreamController<String> _errorController =
      StreamController<String>.broadcast();
  final List<StreamSubscription<dynamic>> _subscriptions = [];

  AudioPlayer? _player;
  bool _disposed = false;
  PlaybackSnapshot _latest = PlaybackSnapshot.empty;

  @override
  Stream<PlaybackSnapshot> get snapshots => _snapshotController.stream;

  @override
  Stream<String> get errors => _errorController.stream;

  @override
  PlaybackSnapshot get currentSnapshot => _readSnapshot();

  AudioPlayer _ensurePlayer() {
    final existing = _player;
    if (existing != null) return existing;
    final player = AudioPlayer();
    _player = player;
    _subscriptions.addAll([
      player.positionStream.listen((_) => _emitSnapshot()),
      player.playerStateStream.listen((_) => _emitSnapshot()),
      player.currentIndexStream.listen((_) => _emitSnapshot()),
      player.durationStream.listen((_) => _emitSnapshot()),
      player.errorStream.listen((error) {
        if (!_disposed && !_errorController.isClosed) {
          _errorController.add(error.message ?? '$error');
        }
      }),
    ]);
    return player;
  }

  PlaybackSnapshot _readSnapshot() {
    final player = _player;
    if (player == null) return _latest;
    final processingState = player.processingState;
    final completed = processingState == ProcessingState.completed;
    final activePlaying =
        player.playing &&
        !completed &&
        processingState != ProcessingState.idle;
    _latest = PlaybackSnapshot(
      partIndex: player.currentIndex ?? 0,
      localPosition: player.position,
      partDuration: player.duration,
      playing: activePlaying,
      completed: completed,
    );
    return _latest;
  }

  void _emitSnapshot() {
    if (_disposed || _snapshotController.isClosed) return;
    _snapshotController.add(_readSnapshot());
  }

  Future<Uri?> _coverUriForBook(AudioBook book) async {
    final bytes = book.coverBytes;
    if (bytes == null || bytes.isEmpty) return null;
    try {
      final tempDir = await getTemporaryDirectory();
      final coverDir = Directory(p.join(tempDir.path, 'storyshelf_covers'));
      await coverDir.create(recursive: true);
      final safeName = book.id.replaceAll(RegExp(r'[^\w.-]+'), '_');
      final file = File(p.join(coverDir.path, '$safeName.img'));
      if (!await file.exists() || await file.length() != bytes.length) {
        await file.writeAsBytes(bytes, flush: true);
      }
      return Uri.file(file.path);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> loadBook(
    AudioBook book, {
    required int initialIndex,
    required Duration initialPosition,
    required double speed,
    required String unknownAuthorLabel,
  }) async {
    final player = _ensurePlayer();
    if (player.playing) {
      await player.pause();
    }
    final coverUri = await _coverUriForBook(book);
    final author =
        book.author == 'Unknown Author' ? unknownAuthorLabel : book.author;
    final sources = <AudioSource>[
      for (var i = 0; i < book.parts.length; i++)
        AudioSource.file(
          book.parts[i].path,
          tag: MediaItem(
            id: '${book.id}#$i',
            album: book.title,
            title: book.parts[i].chapterTitle,
            artist: author,
            duration: book.parts[i].duration > Duration.zero
                ? book.parts[i].duration
                : null,
            artUri: coverUri,
          ),
        ),
    ];
    await player.setAudioSources(
      sources,
      initialIndex: initialIndex,
      initialPosition: initialPosition,
    );
    await player.setSpeed(speed);
    await play();
  }

  @override
  Future<void> play() async {
    final player = _ensurePlayer();
    // AudioPlayer.play() completes only when playback pauses or finishes, so do
    // not await it here; emit state immediately and forward async errors.
    unawaited(
      player.play().catchError((Object error) {
        if (!_disposed && !_errorController.isClosed) {
          _errorController.add('$error');
        }
      }),
    );
    _emitSnapshot();
  }

  @override
  Future<void> pause() async {
    final player = _player;
    if (player == null) return;
    await player.pause();
    _emitSnapshot();
  }

  @override
  Future<void> stop() async {
    final player = _player;
    if (player == null) return;
    await player.stop();
    _latest = PlaybackSnapshot.empty;
    _emitSnapshot();
  }

  @override
  Future<void> seek(Duration localPosition, {int? partIndex}) async {
    final player = _player;
    if (player == null) return;
    await player.seek(localPosition, index: partIndex);
    _emitSnapshot();
  }

  @override
  Future<void> setSpeed(double speed) async {
    final player = _player;
    if (player == null) return;
    await player.setSpeed(speed);
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    await _player?.dispose();
    _player = null;
    await _snapshotController.close();
    await _errorController.close();
  }
}
