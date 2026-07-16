import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mesh_draft/core/exceptions/validation_exception.dart';
import 'package:mesh_draft/features/note/presentation/controllers/note_detail_controller.dart';
import 'package:mesh_draft/features/note/presentation/controllers/note_list_controller.dart';
import 'package:mesh_draft/features/note/presentation/widgets/note_form.dart';

class NoteFormPage extends ConsumerWidget {
  const NoteFormPage({super.key, this.noteId});

  final String? noteId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (noteId == null) {
      return _FormScaffold(
        title: 'Catatan Baru',
        child: NoteForm(
          submitLabel: 'Simpan',
          onSubmit: (title, content) => _create(context, ref, title, content),
        ),
      );
    }

    final noteAsync = ref.watch(noteDetailControllerProvider(noteId!));
    return switch (noteAsync) {
      AsyncData(:final value) => value == null
          ? const _FormScaffold(
              title: 'Edit Catatan',
              child: Center(child: Text('Catatan tidak ditemukan.')),
            )
          : _FormScaffold(
              title: 'Edit Catatan',
              child: NoteForm(
                initialTitle: value.title,
                initialContent: value.content,
                submitLabel: 'Simpan',
                onSubmit: (title, content) =>
                    _update(context, ref, title, content),
              ),
            ),
      AsyncError(:final error) => _FormScaffold(
          title: 'Edit Catatan',
          child: Center(child: Text('Gagal memuat catatan: $error')),
        ),
      _ => const _FormScaffold(
          title: 'Edit Catatan',
          child: Center(child: CircularProgressIndicator()),
        ),
    };
  }

  Future<void> _create(
    BuildContext context,
    WidgetRef ref,
    String title,
    String content,
  ) async {
    try {
      await ref
          .read(noteListControllerProvider.notifier)
          .createNote(title: title, content: content);
      if (context.mounted) context.pop();
    } on ValidationException catch (e) {
      if (context.mounted) _showError(context, e.message);
    }
  }

  Future<void> _update(
    BuildContext context,
    WidgetRef ref,
    String title,
    String content,
  ) async {
    try {
      await ref
          .read(noteDetailControllerProvider(noteId!).notifier)
          .updateNote(title: title, content: content);
      if (context.mounted) context.pop();
    } on ValidationException catch (e) {
      if (context.mounted) _showError(context, e.message);
    }
  }

  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

class _FormScaffold extends StatelessWidget {
  const _FormScaffold({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(child: child),
    );
  }
}
