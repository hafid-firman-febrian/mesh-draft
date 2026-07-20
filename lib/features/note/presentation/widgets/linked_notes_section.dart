import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mesh_draft/core/theme/color_tokens.dart';
import 'package:mesh_draft/features/link/application/services/link_service.dart';
import 'package:mesh_draft/features/link/domain/models/note_link_model.dart';
import 'package:mesh_draft/features/note/domain/models/note_model.dart';
import 'package:mesh_draft/features/note/presentation/controllers/note_list_controller.dart';

class LinkedNotesSection extends ConsumerStatefulWidget {
  const LinkedNotesSection({super.key, required this.noteId});

  final String noteId;

  @override
  ConsumerState<LinkedNotesSection> createState() => _LinkedNotesSectionState();
}

class _LinkedNotesSectionState extends ConsumerState<LinkedNotesSection> {
  static const _initialVisible = 3;
  bool _showAll = false;

  @override
  Widget build(BuildContext context) {
    final linksAsync = ref.watch(noteLinksProvider(widget.noteId));
    final notesAsync = ref.watch(noteListControllerProvider);

    final links = linksAsync.value;
    final notes = notesAsync.value;
    final hasMore = links != null && links.length > _initialVisible;
    final visibleLinks = (hasMore && !_showAll)
        ? links.sublist(0, _initialVisible)
        : links;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          links == null ? 'LINKED NOTES' : 'LINKED NOTES · ${links.length}',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.0,
            color: MeshColors.textSecondary,
          ),
        ),
        const SizedBox(height: MeshSpacing.sm),
        if (visibleLinks == null || notes == null)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: MeshSpacing.sm),
            child: LinearProgressIndicator(color: MeshColors.node),
          )
        else if (visibleLinks.isEmpty)
          const Padding(
            padding: EdgeInsets.only(bottom: MeshSpacing.sm),
            child: Text(
              'Belum ada tautan. Tautkan catatan ini untuk melihat keterkaitannya.',
              style: TextStyle(color: MeshColors.textSecondary),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.only(bottom: MeshSpacing.sm),
            child: Wrap(
              spacing: MeshSpacing.sm,
              runSpacing: MeshSpacing.sm,
              children: [
                ..._chips(context, ref, visibleLinks, notes),
                if (hasMore)
                  _ToggleChip(
                    label: _showAll ? 'Show less' : 'Show more',
                    onTap: () => setState(() => _showAll = !_showAll),
                  ),
              ],
            ),
          ),
        AddLinkButton(onTap: () => context.push('/note/${widget.noteId}/link')),
      ],
    );
  }

  List<Widget> _chips(
    BuildContext context,
    WidgetRef ref,
    List<NoteLink> links,
    List<Note> notes,
  ) {
    final byId = {for (final note in notes) note.id: note};
    return [
      for (final link in links)
        if (byId[link.sourceId == widget.noteId ? link.targetId : link.sourceId]
            case final other?)
          _LinkChip(
            title: other.title,
            onTap: () => context.push('/note/${other.id}'),
            onRemove: () => _confirmUnlink(context, ref, link, other),
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

class _ToggleChip extends StatelessWidget {
  const _ToggleChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(MeshRadius.pill),
      onTap: onTap,
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: MeshSpacing.md),
        decoration: BoxDecoration(
          color: MeshColors.surface,
          borderRadius: BorderRadius.circular(MeshRadius.pill),
        ),
        child: Center(
          widthFactor: 1,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: MeshColors.inkPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

class _LinkChip extends StatelessWidget {
  const _LinkChip({
    required this.title,
    required this.onTap,
    required this.onRemove,
  });

  final String title;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(MeshRadius.pill),
        onTap: onTap,
        child: Container(
          height: 32,
          padding: const EdgeInsets.only(left: MeshSpacing.sm, right: 6),
          decoration: BoxDecoration(
            color: MeshColors.surface,
            border: Border.all(color: MeshColors.surfaceBorder),
            borderRadius: BorderRadius.circular(MeshRadius.pill),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: MeshColors.inkPrimary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: MeshSpacing.xs),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 160),
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    color: MeshColors.inkPrimary,
                  ),
                ),
              ),
              InkWell(
                borderRadius: BorderRadius.circular(MeshRadius.pill),
                onTap: onRemove,
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(
                    Icons.close,
                    size: 14,
                    color: MeshColors.inkMuted,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AddLinkButton extends StatelessWidget {
  const AddLinkButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(MeshRadius.sm),
      onTap: onTap,
      child: CustomPaint(
        painter: _DashedBorderPainter(),
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: MeshSpacing.md),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add, size: 18, color: MeshColors.node),
                SizedBox(width: MeshSpacing.xs),
                Text(
                  'Link to Note',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: MeshColors.node,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = MeshColors.canvasBorder
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(MeshRadius.sm),
    );
    final dashed = _dashPath(
      Path()..addRRect(rrect),
      dashLength: 5,
      gapLength: 4,
    );
    canvas.drawPath(dashed, paint);
  }

  Path _dashPath(
    Path source, {
    required double dashLength,
    required double gapLength,
  }) {
    final dest = Path();
    for (final metric in source.computeMetrics()) {
      var distance = 0.0;
      var draw = true;
      while (distance < metric.length) {
        final length = draw ? dashLength : gapLength;
        if (draw) {
          dest.addPath(
            metric.extractPath(distance, distance + length),
            Offset.zero,
          );
        }
        distance += length;
        draw = !draw;
      }
    }
    return dest;
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
