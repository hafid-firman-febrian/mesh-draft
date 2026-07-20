import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mesh_draft/core/storage/database.dart';
import 'package:mesh_draft/core/storage/database_provider.dart';
import 'package:mesh_draft/core/theme/app_theme.dart';
import 'package:mesh_draft/features/link/data/data_sources/link_local_data_source.dart';
import 'package:mesh_draft/features/note/data/data_sources/note_local_data_source.dart';
import 'package:mesh_draft/features/note/presentation/pages/note_detail_page.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

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

  Widget buildApp(String? noteId, {bool autoFocusTitle = false}) {
    return ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: MaterialApp(
        theme: AppTheme.dark,
        home: NoteDetailPage(noteId: noteId, autoFocusTitle: autoFocusTitle),
      ),
    );
  }

  // Sama seperti note_list_search_filter_test.dart: dispose provider stream
  // Drift menjadwalkan Timer durasi-nol yang butuh beberapa pump untuk
  // benar-benar menyala sebelum flutter_test menganggapnya "masih pending".
  Future<void> disposeApp(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 1));
    }
  }

  testWidgets('mengetik isi lalu tunggu debounce menyimpan otomatis', (
    tester,
  ) async {
    final now = DateTime(2026, 7, 18, 10);
    await notes.createNote(
      NotesCompanion.insert(
        id: 'a',
        title: 'Judul awal',
        createdAt: now,
        updatedAt: now,
      ),
    );

    await tester.pumpWidget(buildApp('a'));
    await tester.pumpAndSettle();

    final contentField = find.byType(TextField).at(1);
    await tester.tap(contentField); // fokus di content, seperti saat mengetik
    await tester.pumpAndSettle();
    await tester.enterText(contentField, 'Isi baru ditulis');
    // Timer debounce dibuat di dalam zona FakeAsync milik testWidgets —
    // majukan fake clock secara eksplisit, bukan tunggu waktu nyata.
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pumpAndSettle();

    final reloaded = await notes.getNoteById('a');
    expect(reloaded!.content, 'Isi baru ditulis');

    // Regresi: noteDetailControllerProvider re-derive dari stream notes
    // global, jadi auto-save di atas memicu provider ini reload sendiri.
    // Editor (dan fokus field yang sedang diketik) tidak boleh hilang
    // akibat reload itu.
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(TextField), findsNWidgets(2));
    final contentWidget = tester.widget<TextField>(contentField);
    expect(contentWidget.focusNode!.hasFocus, isTrue);

    await disposeApp(tester);
  });

  testWidgets('blur menyimpan segera tanpa menunggu debounce penuh', (
    tester,
  ) async {
    final now = DateTime(2026, 7, 18, 10);
    await notes.createNote(
      NotesCompanion.insert(
        id: 'a',
        title: 'Judul awal',
        createdAt: now,
        updatedAt: now,
      ),
    );

    await tester.pumpWidget(buildApp('a'));
    await tester.pumpAndSettle();

    final titleField = find.byType(TextField).first;
    final contentField = find.byType(TextField).at(1);

    await tester.enterText(contentField, 'Simpan saat blur');
    await tester.tap(titleField); // pindah fokus → content blur → auto-save
    await tester.pumpAndSettle();

    final reloaded = await notes.getNoteById('a');
    expect(reloaded!.content, 'Simpan saat blur');

    await disposeApp(tester);
  });

  // Jalur "⋮ → Edit" sudah dibuang. Perilaku yang masih hidup adalah
  // autoFocusTitle, dipakai /create dan ?focus=title dari context menu list.
  testWidgets('autoFocusTitle memfokuskan field judul saat dibuka', (
    tester,
  ) async {
    final now = DateTime(2026, 7, 18, 10);
    await notes.createNote(
      NotesCompanion.insert(
        id: 'a',
        title: 'Judul awal',
        createdAt: now,
        updatedAt: now,
      ),
    );

    await tester.pumpWidget(buildApp('a', autoFocusTitle: true));
    await tester.pumpAndSettle();

    final titleWidget = tester.widget<TextField>(find.byType(TextField).first);
    expect(titleWidget.focusNode!.hasFocus, isTrue);

    await disposeApp(tester);
  });

  testWidgets('dialog hapus menyebutkan jumlah link', (tester) async {
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

    await tester.pumpWidget(buildApp('a'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(PhosphorIconsRegular.trash));
    await tester.pumpAndSettle();

    expect(
      find.text('Tindakan ini permanen. 1 link ikut terhapus.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();

    await disposeApp(tester);
  });

  testWidgets(
    'halaman create: UI lengkap sejak awal, judul membuat catatan tanpa kedip',
    (tester) async {
      await tester.pumpWidget(buildApp(null));
      await tester.pumpAndSettle();

      // "UI sudah siap" — meta & shell Linked Notes tampil sejak awal,
      // walau catatan belum pernah tersimpan. Cuma ikon hapus yang menunggu
      // catatan benar-benar ada (butuh id nyata).
      expect(find.byIcon(PhosphorIconsRegular.trash), findsNothing);
      expect(find.text('0 karakter · 0 link'), findsOneWidget);
      expect(find.text('LINKED NOTES · 0'), findsOneWidget);
      expect(find.byType(TextField), findsNWidgets(2));
      expect(await notes.getAllNotes(), isEmpty);

      final titleField = find.byType(TextField).first;
      await tester.tap(titleField);
      await tester.pumpAndSettle();
      await tester.enterText(titleField, 'Catatan baru');
      // Debounce men-trigger createNote, yang membuat noteDetailController-
      // Provider(id-baru) di-watch untuk PERTAMA KALInya — cold start tanpa
      // value sebelumnya, beda dari kasus reload note yang sudah ada.
      // Editor tidak boleh diganti spinner selama transisi create→edit ini.
      await tester.pump(const Duration(milliseconds: 900));
      await tester.pumpAndSettle();

      final all = await notes.getAllNotes();
      expect(all, hasLength(1));
      expect(all.single.title, 'Catatan baru');

      // Begitu tersimpan, halaman bertransisi ke mode edit — ikon hapus
      // muncul, TextField tidak berkurang, dan fokus judul tidak hilang.
      expect(find.byIcon(PhosphorIconsRegular.trash), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(TextField), findsNWidgets(2));
      final titleWidget = tester.widget<TextField>(titleField);
      expect(titleWidget.focusNode!.hasFocus, isTrue);

      await disposeApp(tester);
    },
  );

  testWidgets(
    'halaman create: mengetik isi saja tanpa judul tidak membuat catatan',
    (tester) async {
      await tester.pumpWidget(buildApp(null));
      await tester.pumpAndSettle();

      final contentField = find.byType(TextField).at(1);
      await tester.enterText(contentField, 'Isi tanpa judul');
      await tester.pump(const Duration(milliseconds: 900));
      await tester.pumpAndSettle();

      expect(await notes.getAllNotes(), isEmpty);

      await disposeApp(tester);
    },
  );

  testWidgets('linked notes: tampil 3 dulu, chip Show more/Show less toggle', (
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
    for (var i = 0; i < 5; i++) {
      final id = 'other$i';
      await notes.createNote(
        NotesCompanion.insert(
          id: id,
          title: 'Linked $i',
          createdAt: now,
          updatedAt: now,
        ),
      );
      await links.createLink(
        NoteLinksCompanion.insert(
          id: 'link$i',
          sourceId: 'a',
          targetId: id,
          createdAt: now,
        ),
      );
    }

    await tester.pumpWidget(buildApp('a'));
    await tester.pumpAndSettle();

    for (var i = 0; i < 3; i++) {
      expect(find.text('Linked $i'), findsOneWidget);
    }
    expect(find.text('Linked 3'), findsNothing);
    expect(find.text('Linked 4'), findsNothing);
    expect(find.text('Show more'), findsOneWidget);

    // Regresi: Container(alignment: ...) tanpa width eksplisit melebar
    // memenuhi seluruh constraint yang tersedia di dalam Wrap — chip harus
    // shrink-wrap ke lebar tulisannya, bukan selebar layar.
    final chipSize = tester.getSize(
      find
          .ancestor(
            of: find.text('Show more'),
            matching: find.byType(Container),
          )
          .first,
    );
    expect(chipSize.width, lessThan(200));

    await tester.tap(find.text('Show more'));
    await tester.pumpAndSettle();

    for (var i = 0; i < 5; i++) {
      expect(find.text('Linked $i'), findsOneWidget);
    }
    expect(find.text('Show more'), findsNothing);
    expect(find.text('Show less'), findsOneWidget);

    await tester.tap(find.text('Show less'));
    await tester.pumpAndSettle();

    for (var i = 0; i < 3; i++) {
      expect(find.text('Linked $i'), findsOneWidget);
    }
    expect(find.text('Linked 3'), findsNothing);
    expect(find.text('Linked 4'), findsNothing);
    expect(find.text('Show more'), findsOneWidget);
    expect(find.text('Show less'), findsNothing);

    await disposeApp(tester);
  });
}
