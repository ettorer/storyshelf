import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_it.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('it'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'StoryShelf'**
  String get appTitle;

  /// No description provided for @appBarTitle.
  ///
  /// In en, this message translates to:
  /// **'STORYSHELF'**
  String get appBarTitle;

  /// No description provided for @addMp3Tooltip.
  ///
  /// In en, this message translates to:
  /// **'Add audiobook'**
  String get addMp3Tooltip;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navBooks.
  ///
  /// In en, this message translates to:
  /// **'Books'**
  String get navBooks;

  /// No description provided for @navAuthors.
  ///
  /// In en, this message translates to:
  /// **'Authors'**
  String get navAuthors;

  /// No description provided for @navPlaying.
  ///
  /// In en, this message translates to:
  /// **'Playing'**
  String get navPlaying;

  /// No description provided for @emptyLibraryTitle.
  ///
  /// In en, this message translates to:
  /// **'Your library is empty'**
  String get emptyLibraryTitle;

  /// No description provided for @emptyLibraryHint.
  ///
  /// In en, this message translates to:
  /// **'Tap + at the top right and pick one MP3 from an audiobook folder: StoryShelf imports all of its chapters.'**
  String get emptyLibraryHint;

  /// No description provided for @addAudiobookButton.
  ///
  /// In en, this message translates to:
  /// **'Add audiobook'**
  String get addAudiobookButton;

  /// No description provided for @shelfRecent.
  ///
  /// In en, this message translates to:
  /// **'Recent'**
  String get shelfRecent;

  /// No description provided for @shelfBooks.
  ///
  /// In en, this message translates to:
  /// **'Books'**
  String get shelfBooks;

  /// No description provided for @shelfAuthors.
  ///
  /// In en, this message translates to:
  /// **'Authors'**
  String get shelfAuthors;

  /// No description provided for @bookCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 book} other{{count} books}}'**
  String bookCount(int count);

  /// No description provided for @allBooksTooltip.
  ///
  /// In en, this message translates to:
  /// **'All books'**
  String get allBooksTooltip;

  /// No description provided for @booksByThisAuthor.
  ///
  /// In en, this message translates to:
  /// **'Books by this author'**
  String get booksByThisAuthor;

  /// No description provided for @noBooksTitle.
  ///
  /// In en, this message translates to:
  /// **'No books yet'**
  String get noBooksTitle;

  /// No description provided for @noBooksDetail.
  ///
  /// In en, this message translates to:
  /// **'Add MP3 files to start building your library.'**
  String get noBooksDetail;

  /// No description provided for @addBooksButton.
  ///
  /// In en, this message translates to:
  /// **'Add books'**
  String get addBooksButton;

  /// No description provided for @allAuthorsTooltip.
  ///
  /// In en, this message translates to:
  /// **'All authors'**
  String get allAuthorsTooltip;

  /// No description provided for @noAuthorsTitle.
  ///
  /// In en, this message translates to:
  /// **'No authors yet'**
  String get noAuthorsTitle;

  /// No description provided for @noAuthorsDetail.
  ///
  /// In en, this message translates to:
  /// **'Authors from your MP3 tags will appear here.'**
  String get noAuthorsDetail;

  /// No description provided for @nothingPlayingTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing playing'**
  String get nothingPlayingTitle;

  /// No description provided for @nothingPlayingDetail.
  ///
  /// In en, this message translates to:
  /// **'Choose a book from your library to start listening.'**
  String get nothingPlayingDetail;

  /// No description provided for @showChaptersTooltip.
  ///
  /// In en, this message translates to:
  /// **'Show chapters'**
  String get showChaptersTooltip;

  /// No description provided for @chapterOfTotal.
  ///
  /// In en, this message translates to:
  /// **'Chapter {current} of {total}'**
  String chapterOfTotal(int current, int total);

  /// No description provided for @back30Tooltip.
  ///
  /// In en, this message translates to:
  /// **'Back 30 seconds'**
  String get back30Tooltip;

  /// No description provided for @back10Tooltip.
  ///
  /// In en, this message translates to:
  /// **'Back 10 seconds'**
  String get back10Tooltip;

  /// No description provided for @forward30Tooltip.
  ///
  /// In en, this message translates to:
  /// **'Forward 30 seconds'**
  String get forward30Tooltip;

  /// No description provided for @previousChapterTooltip.
  ///
  /// In en, this message translates to:
  /// **'Previous chapter'**
  String get previousChapterTooltip;

  /// No description provided for @nextChapterTooltip.
  ///
  /// In en, this message translates to:
  /// **'Next chapter'**
  String get nextChapterTooltip;

  /// No description provided for @speedTooltip.
  ///
  /// In en, this message translates to:
  /// **'Playback speed'**
  String get speedTooltip;

  /// No description provided for @chaptersTitle.
  ///
  /// In en, this message translates to:
  /// **'Chapters'**
  String get chaptersTitle;

  /// No description provided for @playTooltip.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get playTooltip;

  /// No description provided for @pauseTooltip.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get pauseTooltip;

  /// No description provided for @stopTooltip.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get stopTooltip;

  /// No description provided for @audioFileCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 audio file} other{{count} audio files}}'**
  String audioFileCount(int count);

  /// No description provided for @removeFromLibrary.
  ///
  /// In en, this message translates to:
  /// **'Remove from library'**
  String get removeFromLibrary;

  /// No description provided for @removeConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove from library?'**
  String get removeConfirmTitle;

  /// No description provided for @removeConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'The book, its imported files and its listening position are removed from StoryShelf. Your original files are not touched.'**
  String get removeConfirmBody;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @seekReadout.
  ///
  /// In en, this message translates to:
  /// **'{position} / {total}'**
  String seekReadout(String position, String total);

  /// No description provided for @imageCounter.
  ///
  /// In en, this message translates to:
  /// **'{index}/{count}'**
  String imageCounter(int index, int count);

  /// No description provided for @unknownAuthor.
  ///
  /// In en, this message translates to:
  /// **'Unknown author'**
  String get unknownAuthor;

  /// No description provided for @errReceiveFile.
  ///
  /// In en, this message translates to:
  /// **'Could not receive the selected file: {error}'**
  String errReceiveFile(String error);

  /// No description provided for @errOpenFile.
  ///
  /// In en, this message translates to:
  /// **'Could not open the selected audio file: {error}'**
  String errOpenFile(String error);

  /// No description provided for @errSelectFiles.
  ///
  /// In en, this message translates to:
  /// **'Could not select audio files: {error}'**
  String errSelectFiles(String error);

  /// No description provided for @errNotMp3.
  ///
  /// In en, this message translates to:
  /// **'{name} is not an MP3 file'**
  String errNotMp3(String name);

  /// No description provided for @errListFolder.
  ///
  /// In en, this message translates to:
  /// **'Could not list the MP3 files next to \"{name}\": {error}'**
  String errListFolder(String name, String error);

  /// No description provided for @errReadTags.
  ///
  /// In en, this message translates to:
  /// **'Could not read the tags of \"{name}\": {error}'**
  String errReadTags(String name, String error);

  /// No description provided for @pickFolderTitle.
  ///
  /// In en, this message translates to:
  /// **'Select the folder containing this audiobook'**
  String get pickFolderTitle;

  /// No description provided for @noteOnlySelected.
  ///
  /// In en, this message translates to:
  /// **'Only the selected MP3 was added. Select its folder to import the other chapters.'**
  String get noteOnlySelected;

  /// No description provided for @noteNoMatches.
  ///
  /// In en, this message translates to:
  /// **'No other MP3 files in the selected folder have matching book title and author tags.'**
  String get noteNoMatches;

  /// No description provided for @noteScanFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not scan the audiobook folder. Only the selected MP3 was added: {error}'**
  String noteScanFailed(String error);

  /// No description provided for @errNotLocalFolder.
  ///
  /// In en, this message translates to:
  /// **'The selected folder is not a local directory.'**
  String get errNotLocalFolder;

  /// No description provided for @errNotFound.
  ///
  /// In en, this message translates to:
  /// **'{name} could not be found'**
  String errNotFound(String name);

  /// No description provided for @errFile.
  ///
  /// In en, this message translates to:
  /// **'{name}: {error}'**
  String errFile(String name, String error);

  /// No description provided for @errCopyImages.
  ///
  /// In en, this message translates to:
  /// **'Could not copy the book images: {error}'**
  String errCopyImages(String error);

  /// No description provided for @importFailures.
  ///
  /// In en, this message translates to:
  /// **'Some files could not be imported:\n{details}'**
  String importFailures(String details);

  /// No description provided for @importedFiles.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Added 1 audio file to your library.} other{Added {count} audio files to your library.}}'**
  String importedFiles(int count);

  /// No description provided for @errSelectedNotMp3.
  ///
  /// In en, this message translates to:
  /// **'The selected item is not an MP3 file.'**
  String get errSelectedNotMp3;

  /// No description provided for @bookRemoved.
  ///
  /// In en, this message translates to:
  /// **'Removed \"{title}\" from your library.'**
  String bookRemoved(String title);

  /// No description provided for @errPlay.
  ///
  /// In en, this message translates to:
  /// **'Could not play \"{title}\": {error}'**
  String errPlay(String title, String error);

  /// No description provided for @errPlaybackChange.
  ///
  /// In en, this message translates to:
  /// **'Playback could not be changed: {error}'**
  String errPlaybackChange(String error);

  /// No description provided for @errPlaybackStop.
  ///
  /// In en, this message translates to:
  /// **'Playback could not be stopped: {error}'**
  String errPlaybackStop(String error);

  /// No description provided for @errSeek.
  ///
  /// In en, this message translates to:
  /// **'Could not seek to that position: {error}'**
  String errSeek(String error);

  /// No description provided for @errOpenChapter.
  ///
  /// In en, this message translates to:
  /// **'Could not open chapter \"{title}\": {error}'**
  String errOpenChapter(String title, String error);

  /// No description provided for @errPreviousFile.
  ///
  /// In en, this message translates to:
  /// **'Could not open the previous audio file: {error}'**
  String errPreviousFile(String error);

  /// No description provided for @errNextFile.
  ///
  /// In en, this message translates to:
  /// **'Could not open the next audio file: {error}'**
  String errNextFile(String error);

  /// No description provided for @errContinueNext.
  ///
  /// In en, this message translates to:
  /// **'Could not continue to the next audio file: {error}'**
  String errContinueNext(String error);

  /// No description provided for @errSpeed.
  ///
  /// In en, this message translates to:
  /// **'Playback speed could not be changed: {error}'**
  String errSpeed(String error);

  /// No description provided for @errTagsFallback.
  ///
  /// In en, this message translates to:
  /// **'Some MP3 tags could not be read. Added \"{name}\" using its file name.'**
  String errTagsFallback(String name);

  /// No description provided for @errDuration.
  ///
  /// In en, this message translates to:
  /// **'Could not read the duration of \"{name}\": {error}'**
  String errDuration(String name, String error);

  /// No description provided for @errLyrics.
  ///
  /// In en, this message translates to:
  /// **'Could not read the LYRICS tag in \"{name}\": {error}'**
  String errLyrics(String name, String error);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'it'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'it':
      return AppLocalizationsIt();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
