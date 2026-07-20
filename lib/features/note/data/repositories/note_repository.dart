import 'package:drift/drift.dart' show Value;
import 'package:mesh_draft/core/storage/database.dart' as db;
import 'package:mesh_draft/features/note/data/data_sources/note_local_data_source.dart';
import 'package:mesh_draft/features/note/domain/models/note_model.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'note_repository.g.dart';

abstract class NoteRepository {
  Future<List<Note>> getAllNotes();
  Future<Note?> getNoteById(String id);
  Future<Note> createNote(Note note);
  Future<Note> updateNote(Note note);
  Future<void> updateNotePosition(String id, double x, double y);
  Future<void> deleteNote(String id);
  Stream<List<Note>> watchAllNotes();
  Stream<List<Note>> watchNotesSearch(String query);
}

class NoteRepositoryImpl implements NoteRepository {
  NoteRepositoryImpl({required NoteLocalDataSource localDataSource})
    : _local = localDataSource;

  final NoteLocalDataSource _local;

  @override
  Future<List<Note>> getAllNotes() async {
    final rows = await _local.getAllNotes();
    return rows.map(_toDomain).toList();
  }

  @override
  Stream<List<Note>> watchAllNotes() {
    return _local.watchAllNotes().map((rows) => rows.map(_toDomain).toList());
  }

  @override
  Stream<List<Note>> watchNotesSearch(String query) {
    return _local
        .watchNotesSearch(query)
        .map((rows) => rows.map(_toDomain).toList());
  }

  @override
  Future<Note?> getNoteById(String id) async {
    final row = await _local.getNoteById(id);
    return row == null ? null : _toDomain(row);
  }

  @override
  Future<Note> createNote(Note note) async {
    final row = await _local.createNote(_toCompanion(note));
    return _toDomain(row);
  }

  @override
  Future<Note> updateNote(Note note) async {
    final row = await _local.updateNote(_toCompanion(note));
    return _toDomain(row);
  }

  @override
  Future<void> updateNotePosition(String id, double x, double y) =>
      _local.updatePosition(id, x, y);

  @override
  Future<void> deleteNote(String id) => _local.deleteNote(id);

  Note _toDomain(db.Note row) => Note(
    id: row.id,
    title: row.title,
    content: row.content,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
    posX: row.posX,
    posY: row.posY,
  );

  // posX/posY ikut disertakan: updateNote memakai replace (mengganti seluruh
  // baris), jadi tanpa ini mengedit judul akan menghapus posisi hasil drag.
  db.NotesCompanion _toCompanion(Note note) => db.NotesCompanion(
    id: Value(note.id),
    title: Value(note.title),
    content: Value(note.content),
    createdAt: Value(note.createdAt),
    updatedAt: Value(note.updatedAt),
    posX: Value(note.posX),
    posY: Value(note.posY),
  );
}

@riverpod
NoteRepository noteRepository(Ref ref) {
  return NoteRepositoryImpl(
    localDataSource: ref.watch(noteLocalDataSourceProvider),
  );
}
