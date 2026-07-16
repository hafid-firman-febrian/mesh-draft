import 'package:flutter/material.dart';
import 'package:mesh_draft/core/theme/color_tokens.dart';
import 'package:mesh_draft/core/utils/date_extensions.dart';
import 'package:mesh_draft/features/note/domain/models/note_model.dart';

class NoteCard extends StatelessWidget {
  const NoteCard({super.key, required this.note, required this.onTap});

  final Note note;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasContent = note.content.trim().isNotEmpty;

    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: MeshSpacing.md,
        vertical: MeshSpacing.sm,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(MeshSpacing.md),
        title: Text(
          note.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleMedium,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hasContent) ...[
              const SizedBox(height: MeshSpacing.xs),
              Text(
                note.content,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium,
              ),
            ],
            const SizedBox(height: MeshSpacing.sm),
            Text(
              note.updatedAt.formattedDateTime,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        isThreeLine: hasContent,
        onTap: onTap,
      ),
    );
  }
}
