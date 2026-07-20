import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mesh_draft/core/theme/app_theme.dart';
import 'package:mesh_draft/features/note/domain/models/note_model.dart';
import 'package:mesh_draft/features/note/presentation/widgets/note_card.dart';

void main() {
  final now = DateTime(2026, 7, 18, 10);

  Note noteWith({String content = ''}) => Note(
    id: 'a',
    title: 'Judul kartu',
    content: content,
    createdAt: now,
    updatedAt: now,
  );

  Widget wrap(Widget child) => MaterialApp(
    theme: AppTheme.dark,
    home: Scaffold(body: child),
  );

  testWidgets('menampilkan badge jumlah link saat note punya link', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        NoteCard(
          note: noteWith(),
          linkCount: 3,
          onTap: () {},
          onLongPressStart: (_) {},
        ),
      ),
    );

    expect(find.text('3'), findsOneWidget);
    expect(find.byIcon(Icons.link), findsOneWidget);
    expect(find.text('tanpa link'), findsNothing);
  });

  testWidgets('menampilkan "tanpa link" untuk orphan', (tester) async {
    await tester.pumpWidget(
      wrap(
        NoteCard(
          note: noteWith(),
          linkCount: 0,
          onTap: () {},
          onLongPressStart: (_) {},
        ),
      ),
    );

    expect(find.text('tanpa link'), findsOneWidget);
    expect(find.byIcon(Icons.link), findsNothing);
  });

  testWidgets('menyembunyikan preview saat isi kosong', (tester) async {
    await tester.pumpWidget(
      wrap(
        NoteCard(
          note: noteWith(),
          linkCount: 0,
          onTap: () {},
          onLongPressStart: (_) {},
        ),
      ),
    );

    expect(find.text('Judul kartu'), findsOneWidget);
    // Kalau preview tetap dirender saat isi kosong, ia jadi Text bertulisan
    // kosong. Menyatakan ketiadaannya langsung lebih tahan banting daripada
    // menghitung jumlah Text, yang pecah tiap kali struktur kartu bergeser.
    expect(find.text(''), findsNothing);
  });

  testWidgets('menampilkan preview saat isi terisi', (tester) async {
    await tester.pumpWidget(
      wrap(
        NoteCard(
          note: noteWith(content: 'Isi catatan'),
          linkCount: 0,
          onTap: () {},
          onLongPressStart: (_) {},
        ),
      ),
    );

    expect(find.text('Isi catatan'), findsOneWidget);
  });
}
