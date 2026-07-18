import 'package:drift/drift.dart';
import 'package:mesh_draft/core/storage/database.dart';
import 'package:mesh_draft/core/storage/database_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'link_local_data_source.g.dart';

class LinkLocalDataSource {
  LinkLocalDataSource(this._db);

  final AppDatabase _db;

  Stream<List<NoteLink>> watchAllLinks() {
    return _db.select(_db.noteLinks).watch();
  }

  Stream<List<NoteLink>> watchLinksForNote(String noteId) {
    return (_db.select(_db.noteLinks)
          ..where((tbl) => tbl.sourceId.equals(noteId) | tbl.targetId.equals(noteId)))
        .watch();
  }

  Future<bool> linkExists(String sourceId, String targetId) async {
    final row = await (_db.select(_db.noteLinks)
          ..where((tbl) =>
              tbl.sourceId.equals(sourceId) & tbl.targetId.equals(targetId)))
        .getSingleOrNull();
    return row != null;
  }

  Future<NoteLink> createLink(NoteLinksCompanion link) {
    return _db.into(_db.noteLinks).insertReturning(link);
  }

  Future<void> deleteLink(String id) async {
    await (_db.delete(_db.noteLinks)..where((tbl) => tbl.id.equals(id))).go();
  }
}

@riverpod
LinkLocalDataSource linkLocalDataSource(Ref ref) {
  return LinkLocalDataSource(ref.watch(databaseProvider));
}
