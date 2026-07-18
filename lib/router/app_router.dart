import 'package:go_router/go_router.dart';
import 'package:mesh_draft/features/graph/presentation/pages/graph_page.dart';
import 'package:mesh_draft/features/link/presentation/pages/link_modal_page.dart';
import 'package:mesh_draft/features/note/presentation/pages/note_detail_page.dart';
import 'package:mesh_draft/features/note/presentation/pages/note_form_page.dart';
import 'package:mesh_draft/features/note/presentation/pages/note_list_page.dart';
import 'package:mesh_draft/router/app_shell.dart';

final appRouter = GoRouter(
  initialLocation: '/notes',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          AppShell(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/notes',
              builder: (context, state) => const NoteListPage(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/graph',
              builder: (context, state) => const GraphPage(),
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: '/create',
      builder: (context, state) => const NoteFormPage(),
    ),
    GoRoute(
      path: '/note/:id',
      builder: (context, state) =>
          NoteDetailPage(noteId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/note/:id/edit',
      builder: (context, state) =>
          NoteFormPage(noteId: state.pathParameters['id']),
    ),
    GoRoute(
      path: '/note/:id/link',
      builder: (context, state) =>
          LinkModalPage(noteId: state.pathParameters['id']!),
    ),
  ],
);
