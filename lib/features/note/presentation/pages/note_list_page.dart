import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mesh_draft/core/theme/color_tokens.dart';
import 'package:mesh_draft/features/note/presentation/controllers/note_list_controller.dart';
import 'package:mesh_draft/features/note/presentation/widgets/note_card.dart';

class NoteListPage extends ConsumerWidget {
  const NoteListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notesAsync = ref.watch(noteListControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('MeshDraft')),
      body: switch (notesAsync) {
        AsyncData(:final value) => value.isEmpty
            ? const _EmptyState()
            : ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: MeshSpacing.sm),
                itemCount: value.length,
                itemBuilder: (context, index) {
                  final note = value[index];
                  return NoteCard(
                    note: note,
                    onTap: () => context.push('/note/${note.id}'),
                  );
                },
              ),
        AsyncError(:final error) => Center(
            child: Padding(
              padding: const EdgeInsets.all(MeshSpacing.lg),
              child: Text('Gagal memuat catatan: $error'),
            ),
          ),
        _ => const Center(child: CircularProgressIndicator()),
      },
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/create'),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(MeshSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.hub_outlined,
              size: 72,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: MeshSpacing.lg),
            Text(
              'Belum ada catatan',
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: MeshSpacing.sm),
            Text(
              'Buat catatan pertamamu untuk memulai.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
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
