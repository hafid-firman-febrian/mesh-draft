import 'package:mesh_draft/core/exceptions/validation_exception.dart';
import 'package:mesh_draft/features/note/data/repositories/note_repository.dart';
import 'package:mesh_draft/features/note/domain/models/note_model.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

part 'note_service.g.dart';

class NoteService {
  NoteService(this._repository, this._uuid);

  final NoteRepository _repository;
  final Uuid _uuid;

  Stream<List<Note>> watchAllNotes() => _repository.watchAllNotes();

  Future<Note?> getNoteById(String id) => _repository.getNoteById(id);

  Future<Note> createNote({required String title, String content = ''}) {
    final trimmed = _validateTitle(title);
    final now = DateTime.now();
    return _repository.createNote(Note(
      id: _uuid.v4(),
      title: trimmed,
      content: content,
      createdAt: now,
      updatedAt: now,
    ));
  }

  Future<Note> updateNote(Note note) {
    final trimmed = _validateTitle(note.title);
    return _repository.updateNote(note.copyWith(
      title: trimmed,
      updatedAt: DateTime.now(),
    ));
  }

  // Menyimpan posisi node hasil drag. Tanpa validasi judul dan tanpa bump
  // updatedAt — memindahkan node bukan mengedit isi catatan.
  Future<void> updateNotePosition(
    String id, {
    required double x,
    required double y,
  }) =>
      _repository.updateNotePosition(id, x, y);

  Future<void> deleteNote(String id) => _repository.deleteNote(id);

  String _validateTitle(String title) {
    final trimmed = title.trim();
    if (trimmed.isEmpty) {
      throw const ValidationException('Judul wajib diisi');
    }
    if (trimmed.length > 200) {
      throw const ValidationException('Judul maksimal 200 karakter');
    }
    return trimmed;
  }
}

@riverpod
NoteService noteService(Ref ref) {
  return NoteService(ref.watch(noteRepositoryProvider), const Uuid());
}
