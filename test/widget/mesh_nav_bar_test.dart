import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mesh_draft/core/theme/app_theme.dart';
import 'package:mesh_draft/core/theme/color_tokens.dart';
import 'package:mesh_draft/core/widgets/mesh_nav_bar.dart';

void main() {
  late List<int> selectedIndexes;
  late int createTaps;

  setUp(() {
    selectedIndexes = [];
    createTaps = 0;
  });

  Future<void> pump(WidgetTester tester, int currentIndex) {
    return tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          bottomNavigationBar: MeshNavBar(
            currentIndex: currentIndex,
            onDestinationSelected: selectedIndexes.add,
            onCreatePressed: () => createTaps++,
          ),
        ),
      ),
    );
  }

  Color? circleColorAt(WidgetTester tester, int index) {
    final container = tester.widget<AnimatedContainer>(
      find.byType(AnimatedContainer).at(index),
    );
    return (container.decoration as BoxDecoration).color;
  }

  testWidgets('lingkaran menandai tab Notes saat aktif', (tester) async {
    await pump(tester, 0);
    await tester.pumpAndSettle();

    expect(circleColorAt(tester, 0), MeshColors.surface);
    expect(circleColorAt(tester, 1), Colors.transparent);
  });

  testWidgets('lingkaran berpindah ke Graph saat aktif', (tester) async {
    await pump(tester, 1);
    await tester.pumpAndSettle();

    expect(circleColorAt(tester, 0), Colors.transparent);
    expect(circleColorAt(tester, 1), MeshColors.surface);
  });

  testWidgets('tap tab meneruskan indeksnya', (tester) async {
    await pump(tester, 0);

    await tester.tap(find.byType(AnimatedContainer).at(1));

    expect(selectedIndexes, [1]);
  });

  testWidgets('tab non-aktif tetap punya target sentuh penuh', (tester) async {
    await pump(tester, 0);

    expect(
      tester.getSize(find.byType(AnimatedContainer).at(1)),
      const Size(48, 48),
    );
  });

  testWidgets('tombol tengah membuat catatan tanpa memindahkan tab', (
    tester,
  ) async {
    await pump(tester, 0);

    await tester.tap(find.byIcon(Icons.add));

    expect(createTaps, 1);
    expect(selectedIndexes, isEmpty);
  });
}
