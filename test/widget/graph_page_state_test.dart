import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mesh_draft/core/theme/app_theme.dart';
import 'package:mesh_draft/features/graph/presentation/controllers/graph_controller.dart';
import 'package:mesh_draft/features/graph/presentation/pages/graph_page.dart';
import 'package:mesh_draft/features/graph/presentation/widgets/graph_view.dart';
import 'package:mesh_draft/features/link/domain/models/note_link_model.dart';
import 'package:mesh_draft/features/note/domain/models/note_model.dart';

void main() {
  Widget buildApp({
    required Stream<List<Note>> notes,
    required Stream<List<NoteLink>> links,
  }) {
    return ProviderScope(
      overrides: [
        graphNotesProvider.overrideWith((ref) => notes),
        graphLinksProvider.overrideWith((ref) => links),
      ],
      child: MaterialApp(theme: AppTheme.dark, home: const GraphPage()),
    );
  }

  // GraphView memanggil _ticker.repeat() sehingga animasinya TIDAK PERNAH
  // selesai — pumpAndSettle akan timeout. Bongkar tree secara eksplisit lalu
  // pump beberapa kali supaya ticker dan Timer stream sempat dibersihkan.
  Future<void> disposeApp(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 1));
    }
  }

  testWidgets('menampilkan spinner selama stream belum memancarkan data', (
    tester,
  ) async {
    final notesController = StreamController<List<Note>>();
    final linksController = StreamController<List<NoteLink>>();
    addTearDown(notesController.close);
    addTearDown(linksController.close);

    await tester.pumpWidget(
      buildApp(notes: notesController.stream, links: linksController.stream),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(GraphView), findsNothing);
    expect(find.text('Graph'), findsOneWidget);

    await disposeApp(tester);
  });

  testWidgets('menampilkan pesan error saat stream notes gagal', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildApp(
        notes: Stream<List<Note>>.error(Exception('boom')),
        links: Stream.value(const <NoteLink>[]),
      ),
    );
    await tester.pump();

    expect(find.textContaining('Gagal memuat graph'), findsOneWidget);
    expect(find.byType(GraphView), findsNothing);

    await disposeApp(tester);
  });

  testWidgets('menampilkan empty state saat belum ada catatan', (tester) async {
    await tester.pumpWidget(
      buildApp(
        notes: Stream.value(const <Note>[]),
        links: Stream.value(const <NoteLink>[]),
      ),
    );
    await tester.pump();

    expect(
      find.text(
        'Belum ada catatan.\nGraph terbentuk setelah catatan pertama dibuat.',
      ),
      findsOneWidget,
    );
    expect(find.text('Buat catatan'), findsOneWidget);
    expect(find.byType(GraphView), findsNothing);

    await disposeApp(tester);
  });

  testWidgets('merender GraphView saat data ada', (tester) async {
    final now = DateTime(2026, 7, 18, 10);
    await tester.pumpWidget(
      buildApp(
        notes: Stream.value([
          Note(
            id: 'a',
            title: 'A',
            content: '',
            createdAt: now,
            updatedAt: now,
          ),
        ]),
        links: Stream.value(const <NoteLink>[]),
      ),
    );
    // pump(), BUKAN pumpAndSettle() — ticker GraphView tidak pernah settle.
    await tester.pump();

    expect(find.byType(GraphView), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    await disposeApp(tester);
  });
}
