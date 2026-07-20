import 'package:mesh_draft/features/link/application/services/link_service.dart';
import 'package:mesh_draft/features/link/domain/models/note_link_model.dart';
import 'package:mesh_draft/features/note/application/services/note_service.dart';
import 'package:mesh_draft/features/note/domain/models/note_model.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'note_list_controller.g.dart';

@riverpod
class NoteListController extends _$NoteListController {
  @override
  Stream<List<Note>> build() {
    return ref.watch(noteServiceProvider).watchAllNotes();
  }
}

@riverpod
Stream<List<NoteLink>> allNoteLinks(Ref ref) {
  return ref.watch(linkServiceProvider).watchAllLinks();
}
