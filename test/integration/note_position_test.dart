import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mesh_draft/core/storage/database.dart' show AppDatabase;
import 'package:mesh_draft/features/note/data/data_sources/note_local_data_source.dart';
import 'package:mesh_draft/features/note/data/repositories/note_repository.dart';
import 'package:mesh_draft/features/note/domain/models/note_model.dart';

void main() {
  late AppDatabase db;
  late NoteRepository repository;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = NoteRepositoryImpl(localDataSource: NoteLocalDataSource(db));
  });

  tearDown(() => db.close());

  Future<Note> seed() {
    final now = DateTime(2026, 7, 18, 10);
    return repository.createNote(Note(
      id: 'n1',
      title: 'Catatan',
      content: '',
      createdAt: now,
      updatedAt: now,
    ));
  }

  test('posX/posY null saat catatan baru dibuat', () async {
    final note = await seed();
    expect(note.posX, isNull);
    expect(note.posY, isNull);
  });

  test('updateNotePosition menyimpan posX/posY dan tidak mengubah updatedAt',
      () async {
    final created = await seed();

    await repository.updateNotePosition('n1', 120.5, -80.25);

    final reloaded = await repository.getNoteById('n1');
    expect(reloaded!.posX, 120.5);
    expect(reloaded.posY, -80.25);
    expect(reloaded.updatedAt, created.updatedAt);
  });

  test('mengedit catatan mempertahankan posX/posY hasil drag', () async {
    await seed();
    await repository.updateNotePosition('n1', 300, 400);

    final positioned = (await repository.getNoteById('n1'))!;
    await repository.updateNote(positioned.copyWith(title: 'Judul baru'));

    final reloaded = (await repository.getNoteById('n1'))!;
    expect(reloaded.title, 'Judul baru');
    expect(reloaded.posX, 300);
    expect(reloaded.posY, 400);
  });
}
