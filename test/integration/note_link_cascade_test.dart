import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mesh_draft/core/storage/database.dart';
import 'package:mesh_draft/features/link/data/data_sources/link_local_data_source.dart';
import 'package:mesh_draft/features/note/data/data_sources/note_local_data_source.dart';

void main() {
  late AppDatabase db;
  late NoteLocalDataSource notes;
  late LinkLocalDataSource links;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    notes = NoteLocalDataSource(db);
    links = LinkLocalDataSource(db);
  });

  tearDown(() => db.close());

  test('hapus catatan → link yang melibatkannya ikut terhapus (cascade)',
      () async {
    final now = DateTime.now();
    await notes.createNote(
      NotesCompanion.insert(id: 'a', title: 'A', createdAt: now, updatedAt: now),
    );
    await notes.createNote(
      NotesCompanion.insert(id: 'b', title: 'B', createdAt: now, updatedAt: now),
    );
    await links.createLink(
      NoteLinksCompanion.insert(
        id: 'l1',
        sourceId: 'a',
        targetId: 'b',
        createdAt: now,
      ),
    );

    expect(await links.linkExists('a', 'b'), isTrue);

    await notes.deleteNote('a');

    expect(await links.linkExists('a', 'b'), isFalse);
  });
}
