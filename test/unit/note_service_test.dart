import 'package:flutter_test/flutter_test.dart';
import 'package:mesh_draft/core/exceptions/validation_exception.dart';
import 'package:mesh_draft/features/note/application/services/note_service.dart';
import 'package:mesh_draft/features/note/data/repositories/note_repository.dart';
import 'package:mesh_draft/features/note/domain/models/note_model.dart';
import 'package:uuid/uuid.dart';

void main() {
  late _FakeNoteRepository repository;
  late NoteService service;

  setUp(() {
    repository = _FakeNoteRepository();
    service = NoteService(repository, const Uuid());
  });

  group('createNote — validasi judul', () {
    test('judul kosong ditolak', () {
      expect(
        () => service.createNote(title: ''),
        throwsA(isA<ValidationException>()),
      );
    });

    test('judul hanya spasi ditolak', () {
      expect(
        () => service.createNote(title: '   '),
        throwsA(isA<ValidationException>()),
      );
    });

    test('judul lebih dari 200 karakter ditolak', () {
      expect(
        () => service.createNote(title: 'a' * 201),
        throwsA(isA<ValidationException>()),
      );
    });

    test('judul tepat 200 karakter diterima', () async {
      final note = await service.createNote(title: 'a' * 200);
      expect(note.title.length, 200);
    });

    test('judul di-trim sebelum disimpan', () async {
      final note = await service.createNote(title: '  Judul  ');
      expect(note.title, 'Judul');
    });
  });

  group('updateNotePosition', () {
    test('meneruskan id dan koordinat ke repository', () async {
      await service.updateNotePosition('n1', x: 12.5, y: -7.0);
      expect(repository.lastPositionUpdate, (id: 'n1', x: 12.5, y: -7.0));
    });

    test('tidak memvalidasi apa pun — hanya persist posisi', () async {
      await service.updateNotePosition('', x: 0, y: 0);
      expect(repository.lastPositionUpdate, (id: '', x: 0.0, y: 0.0));
    });
  });

  group('createNote — perilaku', () {
    test('menghasilkan id non-kosong dan meneruskan note ke repository',
        () async {
      final note = await service.createNote(title: 'Judul');
      expect(note.id, isNotEmpty);
      expect(repository.lastCreated, note);
    });

    test('content default kosong bila tidak diisi', () async {
      final note = await service.createNote(title: 'Judul');
      expect(note.content, '');
    });

    test('createdAt dan updatedAt di-set ke instant yang sama', () async {
      final note = await service.createNote(title: 'Judul');
      expect(note.createdAt, note.updatedAt);
    });
  });
}

class _FakeNoteRepository implements NoteRepository {
  Note? lastCreated;
  ({String id, double x, double y})? lastPositionUpdate;

  @override
  Future<Note> createNote(Note note) async {
    lastCreated = note;
    return note;
  }

  @override
  Future<void> updateNotePosition(String id, double x, double y) async {
    lastPositionUpdate = (id: id, x: x, y: y);
  }

  @override
  Future<List<Note>> getAllNotes() => throw UnimplementedError();

  @override
  Future<Note?> getNoteById(String id) => throw UnimplementedError();

  @override
  Future<Note> updateNote(Note note) => throw UnimplementedError();

  @override
  Future<void> deleteNote(String id) => throw UnimplementedError();

  @override
  Stream<List<Note>> watchAllNotes() => throw UnimplementedError();
}
