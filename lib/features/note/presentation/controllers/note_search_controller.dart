import 'package:mesh_draft/features/note/data/repositories/note_repository.dart';
import 'package:mesh_draft/features/note/domain/models/note_model.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'note_search_controller.g.dart';

enum NoteFilterType { all, linked, orphan }

@riverpod
class NoteSearchQuery extends _$NoteSearchQuery {
  @override
  String build() => '';

  void setQuery(String query) => state = query;
}

@riverpod
class NoteFilterSelection extends _$NoteFilterSelection {
  @override
  NoteFilterType build() => NoteFilterType.all;

  void select(NoteFilterType type) => state = type;
}

@riverpod
Stream<List<Note>> searchedNotes(Ref ref, String query) {
  return ref.watch(noteRepositoryProvider).watchNotesSearch(query);
}
