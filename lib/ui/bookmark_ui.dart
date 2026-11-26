import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../l10n/app_localizations.dart';
import '../state/app_state.dart';
import '../state/bookmarks.dart';

const _accent = Color(0xFFD8A15D);
const _sheetColor = Color(0xFF1B1D21);

/// Small round icon button for the row above the progress bar. [onLongPress]
/// is optional; a button without [onPressed] is shown dimmed.
class JumpIconButton extends StatelessWidget {
  const JumpIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.onLongPress,
    super.key,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Tooltip(
      message: tooltip,
      // A long press opens the history instead of showing the tooltip.
      triggerMode: onLongPress == null
          ? TooltipTriggerMode.longPress
          : TooltipTriggerMode.manual,
      child: SizedBox(
        width: 36,
        height: 36,
        child: InkResponse(
          radius: 20,
          onTap: onPressed,
          onLongPress: onLongPress,
          child: Icon(
            icon,
            size: 22,
            color: enabled ? Colors.white70 : Colors.white24,
          ),
        ),
      ),
    );
  }
}

/// Asks for a bookmark name and note. Returns null when cancelled.
Future<({String label, String note})?> showBookmarkDialog(
  BuildContext context, {
  required String title,
  required String label,
  String note = '',
}) {
  return showDialog<({String label, String note})>(
    context: context,
    builder: (_) => _BookmarkDialog(title: title, label: label, note: note),
  );
}

class _BookmarkDialog extends StatefulWidget {
  const _BookmarkDialog({
    required this.title,
    required this.label,
    required this.note,
  });

  final String title;
  final String label;
  final String note;

  @override
  State<_BookmarkDialog> createState() => _BookmarkDialogState();
}

class _BookmarkDialogState extends State<_BookmarkDialog> {
  late final TextEditingController _label = TextEditingController(
    text: widget.label,
  );
  late final TextEditingController _note = TextEditingController(
    text: widget.note,
  );

  @override
  void dispose() {
    _label.dispose();
    _note.dispose();
    super.dispose();
  }

  void _submit() =>
      Navigator.pop(context, (label: _label.text, note: _note.text));

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const ValueKey('bookmark-name'),
              controller: _label,
              maxLines: 1,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(labelText: l10n.bookmarkNameLabel),
            ),
            const SizedBox(height: 8),
            TextField(
              key: const ValueKey('bookmark-note'),
              controller: _note,
              minLines: 1,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: l10n.bookmarkNoteLabel),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          key: const ValueKey('bookmark-save'),
          onPressed: _submit,
          child: Text(l10n.save),
        ),
      ],
    );
  }
}

/// "Save the current spot" button handler of the player.
Future<void> addBookmarkFlow(BuildContext context, AudiobookAppState app) async {
  final l10n = AppLocalizations.of(context);
  final result = await showBookmarkDialog(
    context,
    title: l10n.bookmarkNewTitle,
    label: app.defaultBookmarkLabel(),
  );
  if (result == null) return;
  await app.addBookmark(label: result.label, note: result.note);
}

Future<void> showBookmarksSheet(BuildContext context, AudiobookAppState app) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: _sheetColor,
    builder: (_) => SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.72,
        child: BookmarksSheet(app: app),
      ),
    ),
  );
}

class BookmarksSheet extends StatelessWidget {
  const BookmarksSheet({required this.app, super.key});

  final AudiobookAppState app;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // Own messenger so the delete-undo snackbar shows inside the sheet.
    return ScaffoldMessenger(
      child: Builder(
        builder: (context) => Scaffold(
          backgroundColor: Colors.transparent,
          body: ListenableBuilder(
            listenable: app,
            builder: (context, _) {
              final items = app.bookmarks;
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 8, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            l10n.bookmarksTitle,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        IconButton(
                          tooltip: l10n.addBookmarkTooltip,
                          onPressed: () => addBookmarkFlow(context, app),
                          icon: const Icon(Icons.bookmark_add_outlined),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: items.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32),
                              child: Text(
                                l10n.bookmarksEmpty,
                                key: const ValueKey('bookmarks-empty'),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white60,
                                  height: 1.45,
                                ),
                              ),
                            ),
                          )
                        : ListView.builder(
                            itemCount: items.length,
                            itemBuilder: (context, index) =>
                                _bookmarkTile(context, items[index]),
                          ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _bookmarkTile(BuildContext context, Bookmark bookmark) {
    final l10n = AppLocalizations.of(context);
    final time = formatClock(app.spotTime(bookmark.partIndex, bookmark.offsetMs));
    return Dismissible(
      key: ValueKey('bookmark-${bookmark.id}'),
      background: _swipeBackground(Alignment.centerLeft),
      secondaryBackground: _swipeBackground(Alignment.centerRight),
      onDismissed: (_) => _delete(context, bookmark),
      child: ListTile(
        leading: const Icon(Icons.bookmark_rounded, color: _accent),
        title: Text(bookmark.label, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: bookmark.note.isEmpty
            ? null
            : Text(bookmark.note, maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(time, style: const TextStyle(color: Colors.white54)),
            PopupMenuButton<String>(
              key: ValueKey('bookmark-menu-${bookmark.id}'),
              icon: const Icon(Icons.more_vert_rounded, color: Colors.white54),
              onSelected: (choice) async {
                if (choice == 'edit') {
                  final result = await showBookmarkDialog(
                    context,
                    title: l10n.bookmarkEditTitle,
                    label: bookmark.label,
                    note: bookmark.note,
                  );
                  if (result != null) {
                    await app.updateBookmark(
                      bookmark.id,
                      label: result.label,
                      note: result.note,
                    );
                  }
                } else if (choice == 'delete') {
                  await _delete(context, bookmark);
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(value: 'edit', child: Text(l10n.edit)),
                PopupMenuItem(value: 'delete', child: Text(l10n.delete)),
              ],
            ),
          ],
        ),
        onTap: () {
          Navigator.pop(context);
          app.jumpToBookmark(bookmark);
        },
      ),
    );
  }

  Widget _swipeBackground(Alignment alignment) => Container(
    color: const Color(0x33E57373),
    alignment: alignment,
    padding: const EdgeInsets.symmetric(horizontal: 20),
    child: const Icon(Icons.delete_outline_rounded, color: Colors.white70),
  );

  Future<void> _delete(BuildContext context, Bookmark bookmark) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    await app.deleteBookmark(bookmark.id);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(l10n.bookmarkDeleted),
          action: SnackBarAction(
            label: l10n.undo,
            onPressed: () => app.restoreBookmark(bookmark),
          ),
        ),
      );
  }
}

Future<void> showHistorySheet(BuildContext context, AudiobookAppState app) {
  HapticFeedback.selectionClick();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: _sheetColor,
    builder: (_) => SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.55,
        child: HistorySheet(app: app),
      ),
    ),
  );
}

class HistorySheet extends StatelessWidget {
  const HistorySheet({required this.app, super.key});

  final AudiobookAppState app;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final spots = app.history.undoSpots;
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.historyTitle,
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
              child: spots.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(
                          l10n.historyEmpty,
                          key: const ValueKey('history-empty'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white60,
                            height: 1.45,
                          ),
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: spots.length + 1,
                      itemBuilder: (context, row) {
                        if (row == 0) {
                          return Padding(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                            child: Text(
                              l10n.historyHint,
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 12,
                              ),
                            ),
                          );
                        }
                        // Newest first; entries are stored oldest first.
                        final index = spots.length - row;
                        final spot = spots[index];
                        final chapter = app.spotChapter(
                          spot.partIndex,
                          spot.offsetMs,
                        );
                        final time = formatClock(
                          app.spotTime(spot.partIndex, spot.offsetMs),
                        );
                        return ListTile(
                          key: ValueKey('history-$index'),
                          leading: const Icon(
                            Icons.history_rounded,
                            color: _accent,
                          ),
                          title: Text(
                            chapter,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Text(
                            time,
                            style: const TextStyle(color: Colors.white54),
                          ),
                          onTap: () {
                            Navigator.pop(context);
                            app.jumpToHistory(index);
                          },
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}
