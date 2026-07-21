import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mesh_draft/core/widgets/page_header.dart';
import 'package:mesh_draft/core/widgets/state_views.dart';
import 'package:mesh_draft/features/graph/presentation/controllers/graph_controller.dart';
import 'package:mesh_draft/features/graph/presentation/widgets/graph_view.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

class GraphPage extends ConsumerWidget {
  const GraphPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notesAsync = ref.watch(graphNotesProvider);
    final linksAsync = ref.watch(graphLinksProvider);

    final notes = notesAsync.value;
    final links = linksAsync.value;

    Widget content;
    if (notesAsync.hasError) {
      content = ErrorStateView(
        error: notesAsync.error!,
        message: 'Gagal memuat graph',
      );
    } else if (linksAsync.hasError) {
      content = ErrorStateView(
        error: linksAsync.error!,
        message: 'Gagal memuat graph',
      );
    } else if (notes == null || links == null) {
      // Tunggu KEDUA stream sebelum mount GraphView. Kalau notes sampai
      // duluan (links masih kosong), GraphView render tanpa edge lalu simulasi
      // reheat dua kali saat links menyusul — node "dihisap" ke tengah.
      // Invarian yang sama dijaga di graph_controller.dart.
      content = const Center(child: CircularProgressIndicator());
    } else if (notes.isEmpty) {
      content = EmptyStateView(
        icon: PhosphorIconsRegular.graph,
        message:
            'Belum ada catatan.\nGraph terbentuk setelah catatan pertama dibuat.',
        actionLabel: 'Buat catatan',
        onAction: () => context.push('/create'),
      );
    } else {
      content = GraphView(onNodeTap: (noteId) => context.push('/note/$noteId'));
    }

    return Scaffold(
      // Tanpa AppBar, body mulai dari y=0 — SafeArea yang menahan header dari
      // status bar. Scaffold hanya menyisipkan inset itu lewat AppBar.
      body: SafeArea(
        child: Column(
          children: [
            const PageHeader(title: 'Graph'),
            Expanded(child: content),
          ],
        ),
      ),
    );
  }
}
