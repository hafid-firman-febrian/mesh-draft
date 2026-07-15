import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const Scaffold(
        body: Center(child: Text('Graph View')),
      ),
      routes: [
        GoRoute(
          path: 'note/:id',
          builder: (context, state) => Scaffold(
            body: Center(child: Text('Note ${state.pathParameters['id']}')),
          ),
        ),
        GoRoute(
          path: 'notes',
          builder: (context, state) => const Scaffold(
            body: Center(child: Text('Notes List')),
          ),
        ),
      ],
    ),
  ],
);
