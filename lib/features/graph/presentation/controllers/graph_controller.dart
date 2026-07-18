import 'package:mesh_draft/features/link/application/services/link_service.dart';
import 'package:mesh_draft/features/link/domain/models/note_link_model.dart';
import 'package:mesh_draft/features/note/application/services/note_service.dart';
import 'package:mesh_draft/features/note/domain/models/note_model.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'graph_controller.g.dart';

typedef GraphData = ({List<Note> notes, List<NoteLink> links});

@riverpod
Stream<List<Note>> graphNotes(Ref ref) =>
    ref.watch(noteServiceProvider).watchAllNotes();

@riverpod
Stream<List<NoteLink>> graphLinks(Ref ref) =>
    ref.watch(linkServiceProvider).watchAllLinks();

@riverpod
class GraphController extends _$GraphController {
  @override
  GraphData? build() {
    final notes = ref.watch(graphNotesProvider);
    final links = ref.watch(graphLinksProvider);
    // Tunggu KEDUA stream punya data sebelum render. Kalau tidak, notes bisa
    // sampai duluan (links masih kosong) → graf tampil tanpa edge lalu node
    // "dihisap" ke tengah begitu links menyusul (dan simulasi reheat dua kali).
    if (!notes.hasValue || !links.hasValue) return null;
    return (notes: notes.requireValue, links: links.requireValue);
  }
}
