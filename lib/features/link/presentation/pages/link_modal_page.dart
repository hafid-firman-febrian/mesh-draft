import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mesh_draft/core/exceptions/validation_exception.dart';
import 'package:mesh_draft/core/theme/color_tokens.dart';
import 'package:mesh_draft/features/link/application/services/link_service.dart';
import 'package:mesh_draft/features/link/domain/models/note_link_model.dart';
import 'package:mesh_draft/features/note/application/services/note_service.dart';
import 'package:mesh_draft/features/note/domain/models/note_model.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'link_modal_page.g.dart';

@riverpod
Stream<List<Note>> linkableNotes(Ref ref) {
  return ref.watch(noteServiceProvider).watchAllNotes();
}

class LinkModalPage extends ConsumerWidget {
  const LinkModalPage({super.key, required this.noteId});

  final String noteId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notesAsync = ref.watch(linkableNotesProvider);
    final linksAsync = ref.watch(noteLinksProvider(noteId));

    return Scaffold(
      appBar: AppBar(title: const Text('Tautkan Catatan')),
      body: _body(context, ref, notesAsync, linksAsync),
    );
  }

  Widget _body(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<Note>> notesAsync,
    AsyncValue<List<NoteLink>> linksAsync,
  ) {
    if (notesAsync.hasError || linksAsync.hasError) {
      final error = notesAsync.error ?? linksAsync.error;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(MeshSpacing.lg),
          child: Text('Gagal memuat: $error'),
        ),
      );
    }

    final notes = notesAsync.value;
    final links = linksAsync.value;
    if (notes == null || links == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final others = notes.where((note) => note.id != noteId).toList();
    if (others.isEmpty) {
      return const _EmptyOthers();
    }

    final linkedIds = <String>{
      for (final link in links)
        link.sourceId == noteId ? link.targetId : link.sourceId,
    };

    return ListView.builder(
      itemCount: others.length,
      itemBuilder: (context, index) {
        final note = others[index];
        final alreadyLinked = linkedIds.contains(note.id);
        return ListTile(
          title: Text(
            note.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Icon(
            alreadyLinked ? Icons.check_circle : Icons.add_circle_outline,
            color: alreadyLinked
                ? Theme.of(context).colorScheme.primary
                : null,
          ),
          enabled: !alreadyLinked,
          onTap: alreadyLinked ? null : () => _link(context, ref, note),
        );
      },
    );
  }

  Future<void> _link(BuildContext context, WidgetRef ref, Note note) async {
    try {
      await ref.read(linkServiceProvider).createLink(noteId, note.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ditautkan ke "${note.title}"')),
        );
      }
    } on ValidationException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    }
  }
}

class _EmptyOthers extends StatelessWidget {
  const _EmptyOthers();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(MeshSpacing.lg),
        child: Text(
          'Belum ada catatan lain untuk ditautkan.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
