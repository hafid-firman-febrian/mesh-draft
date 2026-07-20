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

  testWidgets('0 catatan menampilkan empty state dengan CTA', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    expect(find.text('Belum ada catatan.\nBuat yang pertama →'), findsOneWidget);
    expect(find.text('Buat catatan'), findsOneWidget);

    await disposeApp(tester);
  });

  testWidgets('search tanpa hasil menampilkan pesan khusus', (tester) async {
    final now = DateTime(2026, 7, 18, 10);
    await notes.createNote(
      NotesCompanion.insert(
        id: 'a',
        title: 'Riverpod pattern',
        createdAt: now,
        updatedAt: now,
      ),
    );

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'zzzz');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(
      find.text('Tidak ada catatan cocok dengan "zzzz"'),
      findsOneWidget,
    );

    await disposeApp(tester);
  });

  testWidgets('chip Orphan kosong menampilkan pesan semua ter-link', (
    tester,
  ) async {
    final now = DateTime(2026, 7, 18, 10);
    await notes.createNote(
      NotesCompanion.insert(
        id: 'a',
        title: 'A',
        createdAt: now,
        updatedAt: now,
      ),
    );
    await notes.createNote(
      NotesCompanion.insert(
        id: 'b',
        title: 'B',
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

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Orphan'));
    await tester.pumpAndSettle();

    expect(find.text('Semua catatan sudah ter-link 🎉'), findsOneWidget);

    await disposeApp(tester);
  });
}
