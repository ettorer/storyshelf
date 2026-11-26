// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Italian (`it`).
class AppLocalizationsIt extends AppLocalizations {
  AppLocalizationsIt([String locale = 'it']) : super(locale);

  @override
  String get appTitle => 'StoryShelf';

  @override
  String get appBarTitle => 'STORYSHELF';

  @override
  String get addMp3Tooltip => 'Aggiungi audiolibro';

  @override
  String get navHome => 'Home';

  @override
  String get navBooks => 'Libri';

  @override
  String get navAuthors => 'Autori';

  @override
  String get navPlaying => 'In ascolto';

  @override
  String get emptyLibraryTitle => 'La tua libreria è vuota';

  @override
  String get emptyLibraryHint =>
      'Tocca + in alto a destra e scegli un MP3 dalla cartella di un audiolibro: StoryShelf ne importa tutti i capitoli.';

  @override
  String get addAudiobookButton => 'Aggiungi audiolibro';

  @override
  String get shelfRecent => 'Recenti';

  @override
  String get shelfBooks => 'Libri';

  @override
  String get shelfAuthors => 'Autori';

  @override
  String bookCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count libri',
      one: '1 libro',
    );
    return '$_temp0';
  }

  @override
  String get allBooksTooltip => 'Tutti i libri';

  @override
  String get booksByThisAuthor => 'Libri di questo autore';

  @override
  String get noBooksTitle => 'Ancora nessun libro';

  @override
  String get noBooksDetail =>
      'Aggiungi dei file MP3 per iniziare la tua libreria.';

  @override
  String get addBooksButton => 'Aggiungi libri';

  @override
  String get allAuthorsTooltip => 'Tutti gli autori';

  @override
  String get noAuthorsTitle => 'Ancora nessun autore';

  @override
  String get noAuthorsDetail =>
      'Qui compariranno gli autori letti dai tag dei tuoi MP3.';

  @override
  String get nothingPlayingTitle => 'Niente in riproduzione';

  @override
  String get nothingPlayingDetail =>
      'Scegli un libro dalla libreria per iniziare ad ascoltare.';

  @override
  String get showChaptersTooltip => 'Mostra capitoli';

  @override
  String chapterOfTotal(int current, int total) {
    return 'Capitolo $current di $total';
  }

  @override
  String get back30Tooltip => 'Indietro di 30 secondi';

  @override
  String get back10Tooltip => 'Indietro di 10 secondi';

  @override
  String get forward30Tooltip => 'Avanti di 30 secondi';

  @override
  String get previousChapterTooltip => 'Capitolo precedente';

  @override
  String get nextChapterTooltip => 'Capitolo successivo';

  @override
  String get speedTooltip => 'Velocità di riproduzione';

  @override
  String get chaptersTitle => 'Capitoli';

  @override
  String get playTooltip => 'Riproduci';

  @override
  String get pauseTooltip => 'Pausa';

  @override
  String get stopTooltip => 'Ferma';

  @override
  String audioFileCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count file audio',
      one: '1 file audio',
    );
    return '$_temp0';
  }

  @override
  String get removeFromLibrary => 'Rimuovi dalla libreria';

  @override
  String get removeConfirmTitle => 'Rimuovere dalla libreria?';

  @override
  String get removeConfirmBody =>
      'Il libro, i file importati e la posizione di ascolto verranno rimossi da StoryShelf. I tuoi file originali non verranno toccati.';

  @override
  String get cancel => 'Annulla';

  @override
  String get remove => 'Rimuovi';

  @override
  String seekReadout(String position, String total) {
    return '$position / $total';
  }

  @override
  String imageCounter(int index, int count) {
    return '$index/$count';
  }

  @override
  String get unknownAuthor => 'Autore sconosciuto';

  @override
  String errReceiveFile(String error) {
    return 'Impossibile ricevere il file selezionato: $error';
  }

  @override
  String errOpenFile(String error) {
    return 'Impossibile aprire il file audio selezionato: $error';
  }

  @override
  String errSelectFiles(String error) {
    return 'Impossibile selezionare i file audio: $error';
  }

  @override
  String errNotMp3(String name) {
    return '$name non è un file MP3';
  }

  @override
  String errListFolder(String name, String error) {
    return 'Impossibile elencare i file MP3 accanto a \"$name\": $error';
  }

  @override
  String errReadTags(String name, String error) {
    return 'Impossibile leggere i tag di \"$name\": $error';
  }

  @override
  String get pickFolderTitle =>
      'Seleziona la cartella che contiene questo audiolibro';

  @override
  String get noteOnlySelected =>
      'È stato aggiunto solo l\'MP3 selezionato. Seleziona la sua cartella per importare gli altri capitoli.';

  @override
  String get noteNoMatches =>
      'Nessun altro MP3 nella cartella selezionata ha gli stessi tag di titolo e autore.';

  @override
  String noteScanFailed(String error) {
    return 'Impossibile esaminare la cartella dell\'audiolibro. È stato aggiunto solo l\'MP3 selezionato: $error';
  }

  @override
  String get errNotLocalFolder =>
      'La cartella selezionata non è una cartella locale.';

  @override
  String errNotFound(String name) {
    return '$name non è stato trovato';
  }

  @override
  String errFile(String name, String error) {
    return '$name: $error';
  }

  @override
  String errCopyImages(String error) {
    return 'Impossibile copiare le immagini del libro: $error';
  }

  @override
  String importFailures(String details) {
    return 'Alcuni file non sono stati importati:\n$details';
  }

  @override
  String importedFiles(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Aggiunti $count file audio alla libreria.',
      one: 'Aggiunto 1 file audio alla libreria.',
    );
    return '$_temp0';
  }

  @override
  String get errSelectedNotMp3 => 'L\'elemento selezionato non è un file MP3.';

  @override
  String bookRemoved(String title) {
    return '\"$title\" è stato rimosso dalla libreria.';
  }

  @override
  String errPlay(String title, String error) {
    return 'Impossibile riprodurre \"$title\": $error';
  }

  @override
  String errPlaybackChange(String error) {
    return 'Impossibile cambiare la riproduzione: $error';
  }

  @override
  String errPlaybackStop(String error) {
    return 'Impossibile fermare la riproduzione: $error';
  }

  @override
  String errSeek(String error) {
    return 'Impossibile spostarsi in quel punto: $error';
  }

  @override
  String errOpenChapter(String title, String error) {
    return 'Impossibile aprire il capitolo \"$title\": $error';
  }

  @override
  String errPreviousFile(String error) {
    return 'Impossibile aprire il file audio precedente: $error';
  }

  @override
  String errNextFile(String error) {
    return 'Impossibile aprire il file audio successivo: $error';
  }

  @override
  String errContinueNext(String error) {
    return 'Impossibile passare al file audio successivo: $error';
  }

  @override
  String errSpeed(String error) {
    return 'Impossibile cambiare la velocità di riproduzione: $error';
  }

  @override
  String errTagsFallback(String name) {
    return 'Alcuni tag MP3 non sono leggibili: \"$name\" è stato aggiunto usando il nome del file.';
  }

  @override
  String errDuration(String name, String error) {
    return 'Impossibile leggere la durata di \"$name\": $error';
  }

  @override
  String errLyrics(String name, String error) {
    return 'Impossibile leggere il tag LYRICS di \"$name\": $error';
  }

  @override
  String get addBookmarkTooltip => 'Aggiungi segnalibro';

  @override
  String get bookmarksTooltip => 'Segnalibri';

  @override
  String get bookmarksTitle => 'Segnalibri';

  @override
  String get bookmarksEmpty =>
      'Nessun segnalibro. Tocca il pulsante del segnalibro nel player per salvare il punto.';

  @override
  String get bookmarkNewTitle => 'Nuovo segnalibro';

  @override
  String get bookmarkEditTitle => 'Modifica segnalibro';

  @override
  String get bookmarkNameLabel => 'Nome';

  @override
  String get bookmarkNoteLabel => 'Nota (facoltativa)';

  @override
  String get save => 'Salva';

  @override
  String get edit => 'Modifica';

  @override
  String get delete => 'Elimina';

  @override
  String get undo => 'Annulla';

  @override
  String bookmarkSaved(String label) {
    return 'Segnalibro salvato: $label';
  }

  @override
  String get bookmarkDeleted => 'Segnalibro eliminato';

  @override
  String get undoJumpTooltip =>
      'Torna al punto precedente (tieni premuto per la cronologia)';

  @override
  String get redoJumpTooltip => 'Vai al punto successivo';

  @override
  String get historyTitle => 'Cronologia dei salti';

  @override
  String get historyHint =>
      'I punti da cui ti sei spostato, dal più recente. Tocca un punto per tornarci.';

  @override
  String get historyEmpty =>
      'Nessun salto. I punti vengono salvati quando cambi capitolo, trascini la barra di avanzamento o usi un segnalibro.';
}
