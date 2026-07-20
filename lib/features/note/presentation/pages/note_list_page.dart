import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:go_router/go_router.dart';
import 'package:mesh_draft/core/theme/color_tokens.dart';
import 'package:mesh_draft/core/widgets/page_header.dart';
import 'package:mesh_draft/core/widgets/folders_action.dart';
import 'package:mesh_draft/features/link/domain/models/note_link_model.dart';
import 'package:mesh_draft/features/note/application/services/note_service.dart';
import 'package:mesh_draft/features/note/domain/models/note_model.dart';
import 'package:mesh_draft/features/note/presentation/controllers/note_list_controller.dart';
import 'package:mesh_draft/features/note/presentation/controllers/note_search_controller.dart';
import 'package:mesh_draft/features/note/presentation/widgets/note_card.dart';
import 'package:mesh_draft/features/note/presentation/widgets/note_filter_chips.dart';
import 'package:mesh_draft/features/note/presentation/widgets/note_search_bar.dart';

enum _NoteMenuAction { edit, viewLinks, copy, delete }

class NoteListPage extends ConsumerWidget {
  const NoteListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notesAsync = ref.watch(noteListControllerProvider);
    final linksAsync = ref.watch(allNoteLinksProvider);
    final query = ref.watch(noteSearchQueryProvider);
    final searchedAsync = ref.watch(searchedNotesProvider(query));
    final activeFilter = ref.watch(noteFilterSelectionProvider);

    final notes = notesAsync.value;
    final links = linksAsync.value;

    Widget content;
    if (notesAsync.hasError) {
      content = _ErrorState(error: notesAsync.error!);
    } else if (linksAsync.hasError) {
      content = _ErrorState(error: linksAsync.error!);
    } else if (notes == null || links == null) {
      content = const Center(child: CircularProgressIndicator());
    } else if (notes.isEmpty) {
      content = const _EmptyState();
    } else {
      // Toolbar dibangun sekali di sini dan tetap mounted selama notes ada,
      // terlepas dari status loading searchedNotesProvider — provider itu
      // family per query, jadi tiap ketikan bikin instance baru yang mulai
      // dari AsyncLoading. Kalau toolbar ikut hilang saat loading, NoteSearchBar
      // (dan TextEditingController-nya) di-unmount lalu dibangun ulang kosong.
      final linkCounts = _linkCountsByNoteId(links);
      final toolbar = Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, MeshSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const NoteSearchBar(),
            const SizedBox(height: MeshSpacing.sm),
            NoteFilterChips(notes: notes, linkCounts: linkCounts),
          ],
        ),
      );

      final searched = searchedAsync.value;
      Widget gridArea;
      if (searchedAsync.hasError) {
        gridArea = _ErrorState(error: searchedAsync.error!);
      } else if (searched == null) {
        gridArea = const Center(child: CircularProgressIndicator());
      } else {
        final filtered = searched
            .where((note) => _matchesFilter(note, activeFilter, linkCounts))
            .toList();

        if (filtered.isEmpty) {
          gridArea = query.isNotEmpty
              ? _SearchEmptyState(query: query)
              : activeFilter == NoteFilterType.orphan
              ? const _OrphanEmptyState()
              : const _NoResultsState();
        } else {
          gridArea = _NotesGrid(
            notes: filtered,
            linkCounts: linkCounts,
            onLongPressNote: (note, position) =>
                _showContextMenu(context, ref, note, position),
          );
        }
      }

      content = Column(
        children: [
          toolbar,
          Expanded(child: gridArea),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(actions: const [FoldersAction()]),
      body: Column(
        children: [
          const PageHeader(title: 'Notes'),
          Expanded(child: content),
        ],
      ),
    );
  }

  Future<void> _showContextMenu(
    BuildContext context,
    WidgetRef ref,
    Note note,
    Offset position,
  ) async {
    final selected = await showMenu<_NoteMenuAction>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx,
        position.dy,
      ),
      items: const [
        PopupMenuItem(value: _NoteMenuAction.edit, child: Text('Edit')),
        PopupMenuItem(
          value: _NoteMenuAction.viewLinks,
          child: Text('Lihat Tautan'),
        ),
        PopupMenuItem(value: _NoteMenuAction.copy, child: Text('Salin')),
        PopupMenuItem(value: _NoteMenuAction.delete, child: Text('Hapus')),
      ],
    );
    if (selected == null || !context.mounted) return;

    switch (selected) {
      case _NoteMenuAction.edit:
        context.push('/note/${note.id}?focus=title');
      case _NoteMenuAction.viewLinks:
        context.push('/note/${note.id}');
      case _NoteMenuAction.copy:
        await _copyTitle(context, note);
      case _NoteMenuAction.delete:
        await _confirmDelete(context, ref, note);
    }
  }

  Future<void> _copyTitle(BuildContext context, Note note) async {
    await Clipboard.setData(ClipboardData(text: note.title));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Judul disalin'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Note note,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hapus catatan?'),
        content: const Text('Tindakan ini tidak dapat dibatalkan.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: MeshColors.danger,
              // Tanpa ini label memakai colorScheme.onPrimary turunan seed,
              // yang tidak dijamin kontras terhadap danger.
              foregroundColor: MeshColors.textPrimary,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(noteServiceProvider).deleteNote(note.id);
  }
}

bool _matchesFilter(
  Note note,
  NoteFilterType filter,
  Map<String, int> linkCounts,
) {
  final hasLink = (linkCounts[note.id] ?? 0) > 0;
  return switch (filter) {
    NoteFilterType.all => true,
    NoteFilterType.linked => hasLink,
    NoteFilterType.orphan => !hasLink,
  };
}

Map<String, int> _linkCountsByNoteId(List<NoteLink> links) {
  final counts = <String, int>{};
  for (final link in links) {
    counts[link.sourceId] = (counts[link.sourceId] ?? 0) + 1;
    counts[link.targetId] = (counts[link.targetId] ?? 0) + 1;
  }
  return counts;
}

class _NotesGrid extends StatelessWidget {
  const _NotesGrid({
    required this.notes,
    required this.linkCounts,
    required this.onLongPressNote,
  });

  final List<Note> notes;
  final Map<String, int> linkCounts;
  final void Function(Note note, Offset position) onLongPressNote;

  @override
  Widget build(BuildContext context) {
    return MasonryGridView.count(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, MeshSpacing.lg),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      itemCount: notes.length,
      itemBuilder: (context, index) {
        final note = notes[index];
        return NoteCard(
          note: note,
          linkCount: linkCounts[note.id] ?? 0,
          onTap: () => context.push('/note/${note.id}'),
          onLongPressStart: (position) => onLongPressNote(note, position),
        );
      },
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(MeshSpacing.lg),
        child: Text('Gagal memuat catatan: $error'),
      ),
    );
  }
}

class _SearchEmptyState extends StatelessWidget {
  const _SearchEmptyState({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(MeshSpacing.xl),
        child: Text(
          'Tidak ada catatan cocok dengan "$query"',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16, color: MeshColors.textSecondary),
        ),
      ),
    );
  }
}

class _OrphanEmptyState extends StatelessWidget {
  const _OrphanEmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(MeshSpacing.xl),
        child: Text(
          'Semua catatan sudah ter-link 🎉',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, color: MeshColors.textSecondary),
        ),
      ),
    );
  }
}

class _NoResultsState extends StatelessWidget {
  const _NoResultsState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(MeshSpacing.xl),
        child: Text(
          'Tidak ada catatan yang cocok.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, color: MeshColors.textSecondary),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(MeshSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.note_alt_outlined,
              size: 72,
              color: MeshColors.textMuted,
            ),
            const SizedBox(height: MeshSpacing.lg),
            const Text(
              'Belum ada catatan.\nBuat yang pertama →',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: MeshColors.textSecondary),
            ),
            const SizedBox(height: MeshSpacing.lg),
            FilledButton.icon(
              onPressed: () => context.push('/create'),
              icon: const Icon(Icons.add),
              label: const Text('Buat catatan'),
            ),
          ],
        ),
      ),
    );
  }
}
