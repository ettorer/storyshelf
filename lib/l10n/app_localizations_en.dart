// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'StoryShelf';

  @override
  String get appBarTitle => 'STORYSHELF';

  @override
  String get addMp3Tooltip => 'Add audiobook';

  @override
  String get navHome => 'Home';

  @override
  String get navBooks => 'Books';

  @override
  String get navAuthors => 'Authors';

  @override
  String get navPlaying => 'Playing';

  @override
  String get emptyLibraryTitle => 'Your library is empty';

  @override
  String get emptyLibraryHint =>
      'Tap + at the top right and pick one MP3 from an audiobook folder: StoryShelf imports all of its chapters.';

  @override
  String get addAudiobookButton => 'Add audiobook';

  @override
  String get shelfRecent => 'Recent';

  @override
  String get shelfBooks => 'Books';

  @override
  String get shelfAuthors => 'Authors';

  @override
  String bookCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count books',
      one: '1 book',
    );
    return '$_temp0';
  }

  @override
  String get allBooksTooltip => 'All books';

  @override
  String get booksByThisAuthor => 'Books by this author';

  @override
  String get noBooksTitle => 'No books yet';

  @override
  String get noBooksDetail => 'Add MP3 files to start building your library.';

  @override
  String get addBooksButton => 'Add books';

  @override
  String get allAuthorsTooltip => 'All authors';

  @override
  String get noAuthorsTitle => 'No authors yet';

  @override
  String get noAuthorsDetail => 'Authors from your MP3 tags will appear here.';

  @override
  String get nothingPlayingTitle => 'Nothing playing';

  @override
  String get nothingPlayingDetail =>
      'Choose a book from your library to start listening.';

  @override
  String get showChaptersTooltip => 'Show chapters';

  @override
  String chapterOfTotal(int current, int total) {
    return 'Chapter $current of $total';
  }

  @override
  String get back30Tooltip => 'Back 30 seconds';

  @override
  String get back10Tooltip => 'Back 10 seconds';

  @override
  String get forward30Tooltip => 'Forward 30 seconds';

  @override
  String get previousChapterTooltip => 'Previous chapter';

  @override
  String get nextChapterTooltip => 'Next chapter';

  @override
  String get speedTooltip => 'Playback speed';

  @override
  String get chaptersTitle => 'Chapters';

  @override
  String get playTooltip => 'Play';

  @override
  String get pauseTooltip => 'Pause';

  @override
  String get stopTooltip => 'Stop';

  @override
  String audioFileCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count audio files',
      one: '1 audio file',
    );
    return '$_temp0';
  }

  @override
  String get removeFromLibrary => 'Remove from library';

  @override
  String get removeConfirmTitle => 'Remove from library?';

  @override
  String get removeConfirmBody =>
      'The book, its imported files and its listening position are removed from StoryShelf. Your original files are not touched.';

  @override
  String get cancel => 'Cancel';

  @override
  String get remove => 'Remove';

  @override
  String seekReadout(String position, String total) {
    return '$position / $total';
  }

  @override
  String imageCounter(int index, int count) {
    return '$index/$count';
  }

  @override
  String get unknownAuthor => 'Unknown author';

  @override
  String errReceiveFile(String error) {
    return 'Could not receive the selected file: $error';
  }

  @override
  String errOpenFile(String error) {
    return 'Could not open the selected audio file: $error';
  }

  @override
  String errSelectFiles(String error) {
    return 'Could not select audio files: $error';
  }

  @override
  String errNotMp3(String name) {
    return '$name is not an MP3 file';
  }

  @override
  String errListFolder(String name, String error) {
    return 'Could not list the MP3 files next to \"$name\": $error';
  }

  @override
  String errReadTags(String name, String error) {
    return 'Could not read the tags of \"$name\": $error';
  }

  @override
  String get pickFolderTitle => 'Select the folder containing this audiobook';

  @override
  String get noteOnlySelected =>
      'Only the selected MP3 was added. Select its folder to import the other chapters.';

  @override
  String get noteNoMatches =>
      'No other MP3 files in the selected folder have matching book title and author tags.';

  @override
  String noteScanFailed(String error) {
    return 'Could not scan the audiobook folder. Only the selected MP3 was added: $error';
  }

  @override
  String get errNotLocalFolder =>
      'The selected folder is not a local directory.';

  @override
  String errNotFound(String name) {
    return '$name could not be found';
  }

  @override
  String errFile(String name, String error) {
    return '$name: $error';
  }

  @override
  String errCopyImages(String error) {
    return 'Could not copy the book images: $error';
  }

  @override
  String importFailures(String details) {
    return 'Some files could not be imported:\n$details';
  }

  @override
  String importedFiles(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Added $count audio files to your library.',
      one: 'Added 1 audio file to your library.',
    );
    return '$_temp0';
  }

  @override
  String get errSelectedNotMp3 => 'The selected item is not an MP3 file.';

  @override
  String bookRemoved(String title) {
    return 'Removed \"$title\" from your library.';
  }

  @override
  String errPlay(String title, String error) {
    return 'Could not play \"$title\": $error';
  }

  @override
  String errPlaybackChange(String error) {
    return 'Playback could not be changed: $error';
  }

  @override
  String errPlaybackStop(String error) {
    return 'Playback could not be stopped: $error';
  }

  @override
  String errSeek(String error) {
    return 'Could not seek to that position: $error';
  }

  @override
  String errOpenChapter(String title, String error) {
    return 'Could not open chapter \"$title\": $error';
  }

  @override
  String errPreviousFile(String error) {
    return 'Could not open the previous audio file: $error';
  }

  @override
  String errNextFile(String error) {
    return 'Could not open the next audio file: $error';
  }

  @override
  String errContinueNext(String error) {
    return 'Could not continue to the next audio file: $error';
  }

  @override
  String errSpeed(String error) {
    return 'Playback speed could not be changed: $error';
  }

  @override
  String errTagsFallback(String name) {
    return 'Some MP3 tags could not be read. Added \"$name\" using its file name.';
  }

  @override
  String errDuration(String name, String error) {
    return 'Could not read the duration of \"$name\": $error';
  }

  @override
  String errLyrics(String name, String error) {
    return 'Could not read the LYRICS tag in \"$name\": $error';
  }

  @override
  String get addBookmarkTooltip => 'Add bookmark';

  @override
  String get bookmarksTooltip => 'Bookmarks';

  @override
  String get bookmarksTitle => 'Bookmarks';

  @override
  String get bookmarksEmpty =>
      'No bookmarks yet. Tap the bookmark button on the player to save your spot.';

  @override
  String get bookmarkNewTitle => 'New bookmark';

  @override
  String get bookmarkEditTitle => 'Edit bookmark';

  @override
  String get bookmarkNameLabel => 'Name';

  @override
  String get bookmarkNoteLabel => 'Note (optional)';

  @override
  String get save => 'Save';

  @override
  String get edit => 'Edit';

  @override
  String get delete => 'Delete';

  @override
  String get undo => 'Undo';

  @override
  String bookmarkSaved(String label) {
    return 'Bookmark saved: $label';
  }

  @override
  String get bookmarkDeleted => 'Bookmark deleted';

  @override
  String get undoJumpTooltip => 'Back to the previous spot (hold for history)';

  @override
  String get redoJumpTooltip => 'Forward to the next spot';

  @override
  String get historyTitle => 'Jump history';

  @override
  String get historyHint =>
      'Spots you jumped away from, newest first. Tap one to go back there.';

  @override
  String get historyEmpty =>
      'No jumps yet. Spots are saved when you change chapter, drag the progress bar or use a bookmark.';
}
