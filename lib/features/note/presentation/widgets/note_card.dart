import 'package:flutter/material.dart';
import 'package:mesh_draft/core/theme/color_tokens.dart';
import 'package:mesh_draft/core/utils/date_extensions.dart';
import 'package:mesh_draft/features/note/domain/models/note_model.dart';

class NoteCard extends StatelessWidget {
  const NoteCard({
    super.key,
    required this.note,
    required this.linkCount,
    required this.onTap,
    required this.onLongPressStart,
  });

  final Note note;
  final int linkCount;
  final VoidCallback onTap;
  final ValueChanged<Offset> onLongPressStart;

  @override
  Widget build(BuildContext context) {
    final hasContent = note.content.trim().isNotEmpty;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(MeshRadius.md),
        onTap: onTap,
        onLongPress: () {
          final renderBox = context.findRenderObject()! as RenderBox;
          final center = renderBox.localToGlobal(
            renderBox.size.center(Offset.zero),
          );
          onLongPressStart(center);
        },
        child: Container(
          padding: const EdgeInsets.all(MeshSpacing.md),
          decoration: BoxDecoration(
            color: MeshColors.surface,
            borderRadius: BorderRadius.circular(MeshRadius.md),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                note.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: MeshColors.inkPrimary,
                ),
              ),
              if (hasContent) ...[
                const SizedBox(height: MeshSpacing.xs),
                Text(
                  note.content,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    color: MeshColors.inkSecondary,
                  ),
                ),
              ],
              const SizedBox(height: MeshSpacing.sm),
              Row(
                children: [
                  Text(
                    note.updatedAt.formattedDate,
                    style: const TextStyle(
                      fontSize: 11,
                      color: MeshColors.inkMuted,
                    ),
                  ),
                  const Spacer(),
                  if (linkCount > 0)
                    _LinkBadge(count: linkCount)
                  else
                    const Text(
                      'tanpa link',
                      style: TextStyle(
                        fontSize: 11,
                        color: MeshColors.inkMuted,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LinkBadge extends StatelessWidget {
  const _LinkBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: MeshSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: MeshColors.badgeSurface,
        borderRadius: BorderRadius.circular(MeshRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.link, size: 12, color: MeshColors.inkPrimary),
          const SizedBox(width: 2),
          Text(
            '$count',
            style: const TextStyle(fontSize: 11, color: MeshColors.inkPrimary),
          ),
        ],
      ),
    );
  }
}
