import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mesh_draft/core/widgets/page_header.dart';
import 'package:mesh_draft/features/graph/presentation/widgets/graph_view.dart';

class GraphPage extends StatelessWidget {
  const GraphPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Tanpa AppBar, body mulai dari y=0 — SafeArea yang menahan header dari
      // status bar. Scaffold hanya menyisipkan inset itu lewat AppBar.
      body: SafeArea(
        child: Column(
          children: [
            const PageHeader(title: 'Graph'),
            Expanded(
              child: GraphView(
                onNodeTap: (noteId) => context.push('/note/$noteId'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
