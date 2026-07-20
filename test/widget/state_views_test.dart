import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mesh_draft/core/theme/app_theme.dart';
import 'package:mesh_draft/core/widgets/state_views.dart';

void main() {
  Widget wrap(Widget child) =>
      MaterialApp(theme: AppTheme.dark, home: Scaffold(body: child));

  testWidgets('ErrorStateView memakai pesan bawaan', (tester) async {
    await tester.pumpWidget(wrap(const ErrorStateView(error: 'boom')));

    expect(find.text('Gagal memuat catatan: boom'), findsOneWidget);
  });

  testWidgets('ErrorStateView memakai pesan kustom', (tester) async {
    await tester.pumpWidget(
      wrap(const ErrorStateView(error: 'boom', message: 'Gagal memuat graph')),
    );

    expect(find.text('Gagal memuat graph: boom'), findsOneWidget);
  });

  testWidgets('EmptyStateView menampilkan tombol saat aksi diisi', (
    tester,
  ) async {
    var tapped = 0;
    await tester.pumpWidget(
      wrap(
        EmptyStateView(
          icon: Icons.note_alt_outlined,
          message: 'Belum ada apa-apa',
          actionLabel: 'Buat catatan',
          onAction: () => tapped++,
        ),
      ),
    );

    expect(find.text('Belum ada apa-apa'), findsOneWidget);
    expect(find.byIcon(Icons.note_alt_outlined), findsOneWidget);

    await tester.tap(find.text('Buat catatan'));
    await tester.pump();
    expect(tapped, 1);
  });

  testWidgets('EmptyStateView menyembunyikan tombol tanpa aksi', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        const EmptyStateView(
          icon: Icons.note_alt_outlined,
          message: 'Belum ada apa-apa',
        ),
      ),
    );

    expect(find.text('Belum ada apa-apa'), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);
  });
}
