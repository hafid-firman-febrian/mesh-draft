import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mesh_draft/core/theme/color_tokens.dart';
import 'package:mesh_draft/features/note/domain/models/note_model.dart';
import 'package:mesh_draft/features/note/presentation/controllers/note_search_controller.dart';

class NoteFilterChips extends ConsumerWidget {
  const NoteFilterChips({
    super.key,
    required this.notes,
    required this.linkCounts,
  });

  final List<Note> notes;
  final Map<String, int> linkCounts;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(noteFilterSelectionProvider);
    final linkedCount = notes
        .where((note) => (linkCounts[note.id] ?? 0) > 0)
        .length;
    final orphanCount = notes.length - linkedCount;

    void select(NoteFilterType type) =>
        ref.read(noteFilterSelectionProvider.notifier).select(type);

    return Row(
      children: [
        _FilterChip(
          label: 'All',
          count: notes.length,
          selected: active == NoteFilterType.all,
          onTap: () => select(NoteFilterType.all),
        ),
        const SizedBox(width: MeshSpacing.sm),
        _FilterChip(
          label: 'Linked',
          count: linkedCount,
          selected: active == NoteFilterType.linked,
          onTap: () => select(NoteFilterType.linked),
        ),
        const SizedBox(width: MeshSpacing.sm),
        _FilterChip(
          label: 'Orphan',
          count: orphanCount,
          selected: active == NoteFilterType.orphan,
          onTap: () => select(NoteFilterType.orphan),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Chip duduk di atas canvas gelap. Terpilih = isi krem dengan tinta gelap,
    // tidak terpilih = transparan dengan garis — aturan yang sama dengan tab
    // aktif di MeshNavBar. Dua-duanya krem seperti sebelumnya membuat status
    // terpilih tak terbedakan.
    final textColor = selected
        ? MeshColors.inkPrimary
        : MeshColors.textSecondary;

    return InkWell(
      borderRadius: BorderRadius.circular(MeshRadius.pill),
      onTap: onTap,
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? MeshColors.surface : Colors.transparent,
          border: selected ? null : Border.all(color: MeshColors.canvasBorder),
          borderRadius: BorderRadius.circular(MeshRadius.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '$count',
              style: TextStyle(
                fontSize: 13,
                color: textColor.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
