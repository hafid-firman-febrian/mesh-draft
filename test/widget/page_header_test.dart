import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mesh_draft/core/theme/app_theme.dart';
import 'package:mesh_draft/core/theme/color_tokens.dart';
import 'package:mesh_draft/core/widgets/page_header.dart';

void main() {
  Future<void> pump(WidgetTester tester, String title) {
    return tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(body: PageHeader(title: title)),
      ),
    );
  }

  testWidgets('menampilkan judul yang diberikan', (tester) async {
    await pump(tester, 'Notes');

    expect(find.text('Notes'), findsOneWidget);
  });

  testWidgets('gaya judul sama untuk tiap halaman', (tester) async {
    await pump(tester, 'Graph');

    final style = tester.widget<Text>(find.text('Graph')).style!;
    expect(style.fontSize, 32);
    expect(style.fontWeight, FontWeight.w700);
    expect(style.color, MeshColors.textPrimary);
  });

  testWidgets('padding memakai token spacing', (tester) async {
    await pump(tester, 'Notes');

    final padding = tester.widget<Padding>(
      find
          .ancestor(of: find.text('Notes'), matching: find.byType(Padding))
          .first,
    );
    expect(
      padding.padding,
      const EdgeInsets.fromLTRB(20, MeshSpacing.sm, 20, MeshSpacing.md),
    );
  });
}
