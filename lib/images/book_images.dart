import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

/// One image shown while a chapter plays, as written by epub-to-audio.
class PartImage {
  const PartImage({required this.path, required this.time, this.caption});

  /// Absolute path of the image file.
  final String path;

  /// Offset inside the chapter MP3 where the image becomes current.
  final Duration time;
  final String? caption;
}

/// A timed image reference before it is resolved against the MP3 folder.
class TimedImageRef {
  const TimedImageRef({required this.file, required this.time, this.caption});

  /// Path relative to the MP3, e.g. `images/01-02.jpg`.
  final String file;
  final Duration time;
  final String? caption;
}

final _imageExtension = RegExp(
  r'\.(jpe?g|png|gif|webp|bmp)$',
  caseSensitive: false,
);

bool looksLikeImagePath(String value) => _imageExtension.hasMatch(value.trim());

// ---------------------------------------------------------------------------
// SYLT (ID3v2.3 / v2.4 synchronised lyrics)
// ---------------------------------------------------------------------------

/// Reads the ID3v2 tag at the start of [file] and returns the image entries
/// of its SYLT frames (content descriptor "images" preferred).
Future<List<TimedImageRef>> readSyltImagesFromFile(String file) async {
  final raf = await File(file).open();
  try {
    final header = await raf.read(10);
    final size = id3TagSize(header);
    if (size == null) return const [];
    final body = await raf.read(size);
    return parseSyltImages(Uint8List.fromList([...header, ...body]));
  } finally {
    await raf.close();
  }
}

/// Total size of the tag body (without the 10-byte header), or null when
/// [header] is not an ID3v2 header.
int? id3TagSize(List<int> header) {
  if (header.length < 10 ||
      header[0] != 0x49 ||
      header[1] != 0x44 ||
      header[2] != 0x33) {
    return null;
  }
  return _synchsafe(header, 6);
}

int _synchsafe(List<int> b, int o) =>
    (b[o] & 0x7f) << 21 |
    (b[o + 1] & 0x7f) << 14 |
    (b[o + 2] & 0x7f) << 7 |
    (b[o + 3] & 0x7f);

int _bigEndian(List<int> b, int o) =>
    b[o] << 24 | b[o + 1] << 16 | b[o + 2] << 8 | b[o + 3];

/// Parses a complete ID3v2 tag (header included) and returns the timed image
/// paths stored in SYLT frames with millisecond timestamps.
List<TimedImageRef> parseSyltImages(Uint8List tag) {
  final size = id3TagSize(tag);
  if (size == null) return const [];
  final version = tag[3];
  final flags = tag[5];
  if (version < 3 || version > 4) return const [];
  if (flags & 0x80 != 0) return const []; // unsynchronised tags: not ours
  final end = (10 + size).clamp(0, tag.length);
  var offset = 10;
  if (flags & 0x40 != 0 && offset + 4 <= end) {
    // Extended header: v2.3 size excludes itself, v2.4 is synchsafe total.
    offset += version == 3
        ? 4 + _bigEndian(tag, offset)
        : _synchsafe(tag, offset);
  }
  final frames = <(String, List<TimedImageRef>)>[];
  while (offset + 10 <= end) {
    final id = String.fromCharCodes(tag.sublist(offset, offset + 4));
    if (tag[offset] == 0) break; // padding
    final frameSize = version == 4
        ? _synchsafe(tag, offset + 4)
        : _bigEndian(tag, offset + 4);
    final start = offset + 10;
    final stop = start + frameSize;
    if (frameSize <= 0 || stop > end) break;
    if (id == 'SYLT') {
      final parsed = _parseSyltFrame(tag.sublist(start, stop));
      if (parsed != null) frames.add(parsed);
    }
    offset = stop;
  }
  if (frames.isEmpty) return const [];
  final preferred = frames.where((f) => f.$1.toLowerCase() == 'images');
  final chosen = preferred.isNotEmpty ? preferred.first.$2 : frames.first.$2;
  final result = chosen.where((r) => looksLikeImagePath(r.file)).toList()
    ..sort((a, b) => a.time.compareTo(b.time));
  return result;
}

(String, List<TimedImageRef>)? _parseSyltFrame(Uint8List data) {
  if (data.length < 6) return null;
  final encoding = data[0];
  final timestampFormat = data[4];
  if (timestampFormat != 2) return null; // only milliseconds
  var offset = 6;
  final descriptor = _readString(data, offset, encoding);
  offset = descriptor.$2;
  final refs = <TimedImageRef>[];
  while (offset < data.length) {
    final text = _readString(data, offset, encoding);
    offset = text.$2;
    if (offset + 4 > data.length) break;
    final ms = _bigEndian(data, offset);
    offset += 4;
    final file = text.$1.trim();
    if (file.isNotEmpty) {
      refs.add(
        TimedImageRef(
          file: file,
          time: Duration(milliseconds: ms),
        ),
      );
    }
  }
  return (descriptor.$1, refs);
}

/// Reads a terminated string; returns the text and the offset after the
/// terminator.
(String, int) _readString(Uint8List data, int offset, int encoding) {
  final wide = encoding == 1 || encoding == 2;
  var end = offset;
  if (wide) {
    while (end + 1 < data.length && !(data[end] == 0 && data[end + 1] == 0)) {
      end += 2;
    }
    final bytes = data.sublist(offset, end.clamp(offset, data.length));
    final next = (end + 2).clamp(0, data.length);
    return (_decodeUtf16(bytes, bigEndianDefault: encoding == 2), next);
  }
  while (end < data.length && data[end] != 0) {
    end++;
  }
  final bytes = data.sublist(offset, end);
  final text = encoding == 3
      ? utf8.decode(bytes, allowMalformed: true)
      : latin1.decode(bytes);
  return (text, (end + 1).clamp(0, data.length));
}

String _decodeUtf16(List<int> bytes, {required bool bigEndianDefault}) {
  var bigEndian = bigEndianDefault;
  var start = 0;
  if (bytes.length >= 2) {
    if (bytes[0] == 0xFF && bytes[1] == 0xFE) {
      bigEndian = false;
      start = 2;
    } else if (bytes[0] == 0xFE && bytes[1] == 0xFF) {
      bigEndian = true;
      start = 2;
    }
  }
  final units = <int>[];
  for (var i = start; i + 1 < bytes.length; i += 2) {
    units.add(
      bigEndian ? bytes[i] << 8 | bytes[i + 1] : bytes[i + 1] << 8 | bytes[i],
    );
  }
  return String.fromCharCodes(units);
}

// ---------------------------------------------------------------------------
// USLT / LRC fallback and JSON sidecar
// ---------------------------------------------------------------------------

final _lrcLine = RegExp(
  r'^\s*\[(\d+):(\d{1,2})(?:[.:](\d{1,3}))?\]\s*(.*?)\s*$',
);

/// Image lines such as `[14:32.52]images/01-02.jpg` (minutes may exceed 59).
List<TimedImageRef> parseLrcImages(String? lyrics) {
  if (lyrics == null || lyrics.trim().isEmpty) return const [];
  final result = <TimedImageRef>[];
  for (final line in const LineSplitter().convert(lyrics)) {
    final match = _lrcLine.firstMatch(line);
    if (match == null) continue;
    final file = match.group(4)!;
    if (!looksLikeImagePath(file)) continue;
    final fraction = match.group(3) ?? '';
    final ms = fraction.isEmpty
        ? 0
        : int.parse(fraction.padRight(3, '0').substring(0, 3));
    result.add(
      TimedImageRef(
        file: file,
        time: Duration(
          minutes: int.parse(match.group(1)!),
          seconds: int.parse(match.group(2)!),
          milliseconds: ms,
        ),
      ),
    );
  }
  result.sort((a, b) => a.time.compareTo(b.time));
  return result;
}

/// Parses an epub-to-audio sidecar: `{"images": [{"file", "time_ms",
/// "caption"}, ...]}`. Invalid JSON yields an empty list.
List<TimedImageRef> parseSidecarImages(String? json) {
  if (json == null || json.trim().isEmpty) return const [];
  try {
    final decoded = jsonDecode(json);
    if (decoded is! Map || decoded['images'] is! List) return const [];
    final result = <TimedImageRef>[];
    for (final item in decoded['images'] as List) {
      if (item is! Map) continue;
      final file = item['file'];
      final time = item['time_ms'];
      if (file is! String || time is! num || !looksLikeImagePath(file)) {
        continue;
      }
      final caption = item['caption'];
      result.add(
        TimedImageRef(
          file: file,
          time: Duration(milliseconds: time.round()),
          caption: caption is String && caption.trim().isNotEmpty
              ? caption.trim()
              : null,
        ),
      );
    }
    result.sort((a, b) => a.time.compareTo(b.time));
    return result;
  } on FormatException {
    return const [];
  }
}

String _normalizeRef(String file) =>
    p.posix.normalize(file.replaceAll('\\', '/')).toLowerCase();

/// Combines the sources: SYLT first, then USLT/LRC, then the JSON sidecar for
/// timing; captions always come from the sidecar when it has the file.
List<TimedImageRef> mergeImageSources({
  List<TimedImageRef> sylt = const [],
  List<TimedImageRef> lrc = const [],
  List<TimedImageRef> sidecar = const [],
}) {
  final timing = sylt.isNotEmpty
      ? sylt
      : lrc.isNotEmpty
      ? lrc
      : sidecar;
  final captions = {
    for (final ref in sidecar)
      if (ref.caption != null) _normalizeRef(ref.file): ref.caption,
  };
  return [
    for (final ref in timing)
      TimedImageRef(
        file: ref.file,
        time: ref.time,
        caption: ref.caption ?? captions[_normalizeRef(ref.file)],
      ),
  ];
}

/// Resolves references against the MP3's folder, dropping missing files.
List<PartImage> resolveImages(
  String mp3Path,
  List<TimedImageRef> refs, {
  bool Function(String path)? exists,
}) {
  final check = exists ?? (path) => File(path).existsSync();
  final folder = p.dirname(mp3Path);
  final result = <PartImage>[];
  for (final ref in refs) {
    final relative = ref.file.replaceAll('\\', '/');
    if (p.posix.isAbsolute(relative) || relative.split('/').contains('..')) {
      continue;
    }
    final path = p.joinAll([folder, ...relative.split('/')]);
    if (!check(path)) continue;
    result.add(PartImage(path: path, time: ref.time, caption: ref.caption));
  }
  return result;
}

/// Path of the sidecar JSON for an MP3 (`NN - Title.json`).
String sidecarPathFor(String mp3Path) => p.setExtension(mp3Path, '.json');

/// Reads every image source for one chapter MP3. Never throws.
Future<List<PartImage>> readPartImages(String mp3Path, {String? lyrics}) async {
  var sylt = const <TimedImageRef>[];
  try {
    sylt = await readSyltImagesFromFile(mp3Path);
  } catch (_) {}
  var sidecar = const <TimedImageRef>[];
  try {
    final json = File(sidecarPathFor(mp3Path));
    if (await json.exists()) {
      sidecar = parseSidecarImages(await json.readAsString());
    }
  } catch (_) {}
  final refs = mergeImageSources(
    sylt: sylt,
    lrc: parseLrcImages(lyrics),
    sidecar: sidecar,
  );
  return resolveImages(mp3Path, refs);
}

// ---------------------------------------------------------------------------
// Which image to show
// ---------------------------------------------------------------------------

/// Index in the book's image sequence (0 = cover, then every chapter's images
/// in chapter order) of the first image of [partIndex].
int firstImageIndexOfPart(List<List<PartImage>> imagesByPart, int partIndex) {
  var index = 1;
  for (var i = 0; i < partIndex && i < imagesByPart.length; i++) {
    index += imagesByPart[i].length;
  }
  return index;
}

/// The image that should be visible at [localPosition] in [partIndex]: the
/// latest image of that chapter whose time has been reached, else the cover.
int autoImageIndex(
  List<List<PartImage>> imagesByPart,
  int partIndex,
  Duration localPosition,
) {
  if (partIndex < 0 || partIndex >= imagesByPart.length) return 0;
  final images = imagesByPart[partIndex];
  var latest = -1;
  for (var i = 0; i < images.length; i++) {
    if (images[i].time <= localPosition) latest = i;
  }
  return latest < 0
      ? 0
      : firstImageIndexOfPart(imagesByPart, partIndex) + latest;
}

/// Combines automatic sync with manual swipes.
///
/// A swipe pins the chosen image until the automatic image would change
/// (the next image timestamp is reached), or until the chapter changes or
/// the user seeks; then automatic sync takes over again.
class ImageSync {
  int? _manualIndex;
  int _autoWhenPinned = 0;
  int _auto = 0;

  int get displayed => _manualIndex ?? _auto;
  bool get isPinned => _manualIndex != null;

  /// Feed the current automatic index; returns the index to display.
  int update(int autoIndex) {
    if (_manualIndex != null && autoIndex != _autoWhenPinned) {
      _manualIndex = null;
    }
    _auto = autoIndex;
    return displayed;
  }

  void swipeTo(int index) {
    if (index == _auto) {
      _manualIndex = null;
      return;
    }
    _manualIndex = index;
    _autoWhenPinned = _auto;
  }

  /// Chapter change or seek: drop the manual pin and show [autoIndex].
  void reset(int autoIndex) {
    _manualIndex = null;
    _auto = autoIndex;
  }
}
