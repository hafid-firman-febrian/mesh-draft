import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mesh_draft/core/storage/database.dart';
import 'package:mesh_draft/core/storage/database_provider.dart';
import 'package:mesh_draft/core/theme/app_theme.dart';
import 'package:mesh_draft/features/link/data/data_sources/link_local_data_source.dart';
import 'package:mesh_draft/features/note/data/data_sources/note_local_data_source.dart';
import 'package:mesh_draft/features/note/presentation/pages/note_list_page.dart';

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

  Widget buildApp() {
    return ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: MaterialApp(theme: AppTheme.dark, home: const NoteListPage()),
    );
  }

  Future<void> disposeApp(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 1));
    }
  }

  Future<void> seed() async {
    final now = DateTime(2026, 7, 18, 10);
    await notes.createNote(
      NotesCompanion.insert(
        id: 'a',
        title: 'Punya link',
        createdAt: now,
        updatedAt: now,
      ),
    );
    await notes.createNote(
      NotesCompanion.insert(
        id: 'b',
        title: 'Lawan link',
        createdAt: now,
        updatedAt: now,
      ),
    );
    await notes.createNote(
      NotesCompanion.insert(
        id: 'c',
        title: 'Tanpa link',
        createdAt: now,
        updatedAt: now,
      ),
    );
    await links.createLink(
      NoteLinksCompanion.insert(
        id: 'l1',
        sourceId: 'a',
        targetId: 'b',
        createdAt: now,
      ),
    );
  }

  testWidgets('dialog hapus dari list menyebutkan jumlah link', (tester) async {
    await seed();
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    await tester.longPress(find.text('Punya link'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Hapus'));
    await tester.pumpAndSettle();

    expect(
      find.text('Tindakan ini permanen. 1 link ikut terhapus.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();

    await disposeApp(tester);
  });

  testWidgets('dialog hapus orphan tidak menyebut link', (tester) async {
    await seed();
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    await tester.longPress(find.text('Tanpa link'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Hapus'));
    await tester.pumpAndSettle();

    expect(find.text('Tindakan ini permanen.'), findsOneWidget);

    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();

    await disposeApp(tester);
  });
}
