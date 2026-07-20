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

  Future<void> seed() async {
    final now = DateTime(2026, 7, 18, 10);
    await notes.createNote(
      NotesCompanion.insert(
        id: 'a',
        title: 'Riverpod pattern',
        createdAt: now,
        updatedAt: now,
      ),
    );
    await notes.createNote(
      NotesCompanion.insert(
        id: 'b',
        title: 'Color tokens',
        createdAt: now,
        updatedAt: now,
      ),
    );
    await notes.createNote(
      NotesCompanion.insert(
        id: 'c',
        title: 'Orphan note',
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

  Widget buildApp() {
    return ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: MaterialApp(theme: AppTheme.dark, home: const NoteListPage()),
    );
  }

  // Drift menjadwalkan Timer durasi-nol saat query stream di-cancel (dipicu
  // saat ProviderScope dispose). flutter_test menganggap Timer tersisa
  // sebagai error kalau widget tree sudah dibongkar tanpa pump lagi —
  // bongkar tree secara eksplisit lalu pump sekali supaya Timer itu sempat
  // menyala sebelum test berakhir.
  Future<void> disposeApp(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    // 3 provider stream (notes, links, searched) masing-masing menjadwalkan
    // Timer durasi-nol miliknya sendiri saat dibongkar — durasi non-zero
    // dan beberapa iterasi supaya fake clock benar-benar maju dan menguras
    // timer yang muncul berantai.
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 1));
    }
  }

  testWidgets('mengetik judul menyaring grid setelah debounce', (tester) async {
    await seed();
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    expect(find.text('Riverpod pattern'), findsOneWidget);
    expect(find.text('Color tokens'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Riverpod');
    // Timer debounce dibuat di dalam zona FakeAsync milik testWidgets —
    // majukan fake clock secara eksplisit, bukan tunggu waktu nyata.
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(find.text('Riverpod pattern'), findsOneWidget);
    expect(find.text('Color tokens'), findsNothing);

    await disposeApp(tester);
  });

  testWidgets('chip Orphan hanya menampilkan catatan tanpa link', (
    tester,
  ) async {
    await seed();
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Orphan'));
    await tester.pumpAndSettle();

    expect(find.text('Orphan note'), findsOneWidget);
    expect(find.text('Riverpod pattern'), findsNothing);
    expect(find.text('Color tokens'), findsNothing);

    await disposeApp(tester);
  });

  testWidgets('search dan chip filter berlaku bersamaan', (tester) async {
    await seed();
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Linked'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Color');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(find.text('Color tokens'), findsOneWidget);
    expect(find.text('Riverpod pattern'), findsNothing);
    expect(find.text('Orphan note'), findsNothing);

    await disposeApp(tester);
  });
}
