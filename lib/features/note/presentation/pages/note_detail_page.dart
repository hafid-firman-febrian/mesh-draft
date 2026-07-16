import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mesh_draft/core/theme/color_tokens.dart';
import 'package:mesh_draft/core/utils/date_extensions.dart';
import 'package:mesh_draft/features/note/domain/models/note_model.dart';
import 'package:mesh_draft/features/note/presentation/controllers/note_detail_controller.dart';
import 'package:mesh_draft/features/note/presentation/widgets/linked_notes_section.dart';

class NoteDetailPage extends ConsumerWidget {
  const NoteDetailPage({super.key, required this.noteId});

  final String noteId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final noteAsync = ref.watch(noteDetailControllerProvider(noteId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Catatan'),
        actions: [
          if (noteAsync.value != null) ...[
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit',
              onPressed: () => context.push('/note/$noteId/edit'),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Hapus',
              onPressed: () => _confirmDelete(context, ref),
            ),
          ],
        ],
      ),
      body: switch (noteAsync) {
        AsyncData(:final value) =>
          value == null ? const _NotFound() : _DetailBody(note: value),
        AsyncError(:final error) => Center(
            child: Padding(
              padding: const EdgeInsets.all(MeshSpacing.lg),
              child: Text('Gagal memuat catatan: $error'),
            ),
          ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
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
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await ref
        .read(noteDetailControllerProvider(noteId).notifier)
        .deleteNote();
    if (context.mounted) context.pop();
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({required this.note});

  final Note note;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final metaStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return ListView(
      padding: const EdgeInsets.all(MeshSpacing.lg),
      children: [
        Text(note.title, style: theme.textTheme.headlineSmall),
        const SizedBox(height: MeshSpacing.md),
        if (note.content.trim().isNotEmpty)
          Text(note.content, style: theme.textTheme.bodyLarge)
        else
          Text(
            'Tanpa isi',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            ),
          ),
        const SizedBox(height: MeshSpacing.xl),
        Text('Dibuat: ${note.createdAt.formattedDateTime}', style: metaStyle),
        Text(
          'Diperbarui: ${note.updatedAt.formattedDateTime}',
          style: metaStyle,
        ),
        const SizedBox(height: MeshSpacing.lg),
        const Divider(),
        const SizedBox(height: MeshSpacing.sm),
        LinkedNotesSection(noteId: note.id),
      ],
    );
  }
}

class _NotFound extends StatelessWidget {
  const _NotFound();

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Catatan tidak ditemukan.'));
  }
}
