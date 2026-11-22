# StoryShelf

StoryShelf is a Flutter audiobook player for Android, iOS, Linux, macOS, and
Windows. When you select an MP3, it scans its folder for other MP3s with the
same book title and author tags, then imports those chapters together. Parts
are ordered by track number, with a leading filename number as a fallback.

## Features

- Browse an alphabetized book and author library, or scroll the home page's
  recent, book, and author shelves.
- Resume each audiobook five seconds before its last saved position.
- Play multi-file books in track order; previous/next chapter moves between
  MP3 files, playback continues into the next chapter automatically, and the
  player shows "Chapter X of N" with the chapter title (title tag, or the file
  name without its leading number). The chapter list also uses embedded
  LYRICS timestamps when available; timed image paths such as
  `images/01-02.jpg` written by epub-to-audio are ignored for now.
- Book images (epub-to-audio): the playing page shows the cover; swipe left
  or right to browse the cover followed by every image of the book (chapter
  order, then time order), with an `n/N` counter and the caption. During
  playback the page follows the audio: it shows the latest image of the
  current chapter whose time has been reached, and the cover before the
  chapter's first image. Changing chapter (buttons, chapter list,
  auto-advance) or seeking returns to the automatic image. A manual swipe is
  kept until the next image time in the chapter is reached (or until you
  change chapter or seek); then automatic sync takes over again.
  Image times come from the SYLT frame (content descriptor `images`), else
  the LRC lines in the lyrics (`[mm:ss.xx]images/NN-ii.jpg`), else the
  `NN - Title.json` sidecar, which also supplies captions. Images are read
  from the `images/` folder next to the MP3s; missing files are skipped. On
  import the `images/` folder and the JSON sidecars are copied together with
  the MP3s (on Android, from the folder you pick).
- Progress bar: dragging shows the target time in a bubble above the thumb
  (kept inside the screen edges) and in a large readout above the bar, so
  your finger never hides it. Playback jumps only when you release.
- Long-press a book cover on the Home or Books page to remove the book from
  the library (after confirming). This deletes StoryShelf's imported copies
  (MP3s, images, JSON) and the saved listening position, and stops the book
  if it is playing; your original files are never touched.
- MP3s without book tags are grouped by folder, so older books named
  `Book 01.mp3`, `Book 02.mp3`… still open as one book.
- Use a generated title-and-author cover when an MP3 has no embedded artwork.
- Open MP3 files from the system file picker; Android and iOS also register
  StoryShelf as an app that can open MP3 files.

- When the library is empty, Home shows how to import (tap + and pick one MP3
  of a book).
- English and Italian UI (see Languages).

Imported audio and playback progress are stored on the device.

## Languages

The UI follows the phone language: Italian when the device language is
Italian, English for every other language. There is no in-app picker.

Strings live in ARB files in `lib/l10n/` (`app_en.arb` is the template,
`app_it.arb` the Italian translation) and are compiled by Flutter's gen-l10n
(`l10n.yaml`, `generate: true`) into `lib/l10n/app_localizations*.dart` on
`flutter pub get`/build (or run `flutter gen-l10n`). To add a language, add
`lib/l10n/app_<code>.arb` with the same keys and extend `resolveAppLocale` in
`lib/main.dart`.

## Build

Install Flutter, Java 17, and Android SDK Platform 37 for Android builds. Then:

```sh
flutter pub get
flutter run
```

Run `flutter build linux`, `flutter build macos`, or `flutter build windows` to
build desktop versions on their supported host platforms. iOS builds require
macOS and Xcode.
