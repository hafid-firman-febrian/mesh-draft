import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mesh_draft/core/dev/graph_dev_tools.dart';
import 'package:mesh_draft/features/graph/presentation/widgets/graph_view.dart';

class GraphPage extends ConsumerWidget {
  const GraphPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Graf'),
        actions: [
          // Tombol dev-only — tampil di debug & profile (untuk mengukur target
          // 100 node di profile mode), hilang di rilis. Hapus bersama
          // core/dev/graph_dev_tools.dart sebelum rilis.
          if (!kReleaseMode) ...[
            IconButton(
              icon: const Icon(Icons.auto_awesome_outlined),
              tooltip: 'Seed 100 dummy (dev)',
              onPressed: () => seedDummyGraph(ref),
            ),
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: 'Hapus semua (dev)',
              onPressed: () => clearAllNotes(ref),
            ),
          ],
        ],
      ),
      body: GraphView(
        onNodeTap: (noteId) => context.push('/note/$noteId'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/create'),
        child: const Icon(Icons.add),
      ),
    );
  }
}
