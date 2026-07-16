import 'package:go_router/go_router.dart';
import 'package:mesh_draft/features/link/presentation/pages/link_modal_page.dart';
import 'package:mesh_draft/features/note/presentation/pages/note_detail_page.dart';
import 'package:mesh_draft/features/note/presentation/pages/note_form_page.dart';
import 'package:mesh_draft/features/note/presentation/pages/note_list_page.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const NoteListPage(),
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
