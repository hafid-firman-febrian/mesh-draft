import 'package:mesh_draft/features/note/application/services/note_service.dart';
import 'package:mesh_draft/features/note/domain/models/note_model.dart';
import 'package:mesh_draft/features/note/presentation/controllers/note_list_controller.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'note_detail_controller.g.dart';

@riverpod
class NoteDetailController extends _$NoteDetailController {
  @override
  Future<Note?> build(String id) async {
    // Turunkan satu note dari stream daftar yang sudah di-watch —
    // bukan query ulang. Edit/hapus otomatis terpancar ke sini.
    final notes = await ref.watch(noteListControllerProvider.future);
    final matches = notes.where((note) => note.id == id);
    return matches.isEmpty ? null : matches.first;
  }

  Future<void> updateNote({
    required String title,
    required String content,
  }) async {
    final current = state.value;
    if (current == null) return;
    await ref.read(noteServiceProvider).updateNote(
          current.copyWith(title: title, content: content),
        );
  }

  Future<void> deleteNote() async {
    final current = state.value;
    if (current == null) return;
    await ref.read(noteServiceProvider).deleteNote(current.id);
  }
}
