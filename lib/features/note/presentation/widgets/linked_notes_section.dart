import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mesh_draft/core/theme/color_tokens.dart';
import 'package:mesh_draft/features/link/application/services/link_service.dart';
import 'package:mesh_draft/features/link/domain/models/note_link_model.dart';
import 'package:mesh_draft/features/note/domain/models/note_model.dart';
import 'package:mesh_draft/features/note/presentation/controllers/note_list_controller.dart';

class LinkedNotesSection extends ConsumerWidget {
  const LinkedNotesSection({super.key, required this.noteId});

  final String noteId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final linksAsync = ref.watch(noteLinksProvider(noteId));
    final notesAsync = ref.watch(noteListControllerProvider);

    final links = linksAsync.value;
    final notes = notesAsync.value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Tautan', style: theme.textTheme.titleMedium),
            ),
            TextButton.icon(
              onPressed: () => context.push('/note/$noteId/link'),
              icon: const Icon(Icons.add_link),
              label: const Text('Tambah'),
            ),
          ],
        ),
        const SizedBox(height: MeshSpacing.xs),
        if (links == null || notes == null)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: MeshSpacing.sm),
            child: LinearProgressIndicator(),
          )
        else if (links.isEmpty)
          Text(
            'Belum ada tautan. Tautkan catatan ini untuk melihat keterkaitannya.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          )
        else
          ..._tiles(context, ref, links, notes),
      ],
    );
  }

  List<Widget> _tiles(
    BuildContext context,
    WidgetRef ref,
    List<NoteLink> links,
    List<Note> notes,
  ) {
    final byId = {for (final note in notes) note.id: note};
    return [
      for (final link in links)
        if (byId[link.sourceId == noteId ? link.targetId : link.sourceId]
            case final other?)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.link),
            title: Text(
              other.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: IconButton(
              icon: const Icon(Icons.link_off),
              tooltip: 'Lepas tautan',
              onPressed: () => _confirmUnlink(context, ref, link, other),
            ),
            onTap: () => context.push('/note/${other.id}'),
          ),
    ];
  }

  Future<void> _confirmUnlink(
    BuildContext context,
    WidgetRef ref,
    NoteLink link,
    Note other,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Lepas tautan?'),
        content: Text('Lepas tautan ke "${other.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Lepas'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(linkServiceProvider).deleteLink(link.id);
  }
}
