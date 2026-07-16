import 'package:mesh_draft/core/exceptions/validation_exception.dart';
import 'package:mesh_draft/features/note/data/repositories/note_repository.dart';
import 'package:mesh_draft/features/note/domain/models/note_model.dart';
import 'package:uuid/uuid.dart';

class NoteService {
  NoteService(this._repository, this._uuid);

  final NoteRepository _repository;
  final Uuid _uuid;

  Stream<List<Note>> watchAllNotes() => _repository.watchAllNotes();

  Future<Note> createNote({required String title, String content = ''}) {
    final trimmed = title.trim();
    if (trimmed.isEmpty) {
      throw const ValidationException('Judul wajib diisi');
    }
    if (trimmed.length > 200) {
      throw const ValidationException('Judul maksimal 200 karakter');
    }

    final now = DateTime.now();
    return _repository.createNote(Note(
      id: _uuid.v4(),
      title: trimmed,
      content: content,
      createdAt: now,
      updatedAt: now,
    ));
  }
}
