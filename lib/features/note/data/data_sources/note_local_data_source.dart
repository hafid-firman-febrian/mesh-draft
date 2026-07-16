import 'package:drift/drift.dart';
import 'package:mesh_draft/core/storage/database.dart';
import 'package:mesh_draft/core/storage/database_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'note_local_data_source.g.dart';

class NoteLocalDataSource {
  NoteLocalDataSource(this._db);

  final AppDatabase _db;

  Future<List<Note>> getAllNotes() {
    return (_db.select(_db.notes)
          ..orderBy([(tbl) => OrderingTerm.desc(tbl.updatedAt)]))
        .get();
  }

  Stream<List<Note>> watchAllNotes() {
    return (_db.select(_db.notes)
          ..orderBy([(tbl) => OrderingTerm.desc(tbl.updatedAt)]))
        .watch();
  }

  Future<Note?> getNoteById(String id) {
    return (_db.select(_db.notes)..where((tbl) => tbl.id.equals(id)))
        .getSingleOrNull();
  }

  Future<Note> createNote(NotesCompanion note) {
    return _db.into(_db.notes).insertReturning(note);
  }

  Future<Note> updateNote(NotesCompanion note) async {
    await _db.update(_db.notes).replace(note);
    // replace hanya mengembalikan status, bukan barisnya — baca ulang
    // supaya pemanggil menerima row final hasil DB.
    return (await getNoteById(note.id.value))!;
  }

  Future<void> deleteNote(String id) async {
    await (_db.delete(_db.notes)..where((tbl) => tbl.id.equals(id))).go();
  }
}

@riverpod
NoteLocalDataSource noteLocalDataSource(Ref ref) {
  return NoteLocalDataSource(ref.watch(databaseProvider));
}
