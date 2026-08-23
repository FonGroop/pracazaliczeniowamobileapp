import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../data/models/city_note.dart';
import '../data/models/map_focus_target.dart';
import '../data/models/tour_place.dart';
import '../l10n/app_localizations.dart';
import '../ui/screens/detail_screen.dart';
import '../ui/screens/home_screen.dart';
import '../ui/screens/map_screen.dart';
import '../ui/screens/notes_screen.dart';
import '../ui/screens/plan_detail_screen.dart';
import '../ui/screens/planner_screen.dart';
import '../ui/screens/saved_screen.dart';
import '../ui/screens/settings_screen.dart';
import '../ui/shared/app_shell.dart';

final appRouter = GoRouter(
  initialLocation: '/discover',
  routes: [
    ShellRoute(
      builder: (context, state, child) => AppShell(child: child),
      routes: [
        GoRoute(
          path: '/discover',
          name: 'discover',
          builder: (context, state) => const HomeScreen(),
          routes: [
            GoRoute(
              path: 'details/:id',
              name: 'details',
              builder: (context, state) {
                final place = state.extra as TourPlace?;
                return DetailScreen(
                  id: int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
                  place: place,
                );
              },
            ),
          ],
        ),
        GoRoute(
          path: '/map',
          name: 'map',
          builder: (context, state) {
            final extra = state.extra;
            return MapScreen(
              focusTarget: extra is MapFocusTarget ? extra : null,
              initialCenter: extra is LatLng ? extra : null,
            );
          },
        ),
        GoRoute(
          path: '/saved',
          name: 'saved',
          builder: (context, state) => const SavedScreen(),
        ),
        GoRoute(
          path: '/ideas',
          name: 'ideas',
          builder: (context, state) => const NotesScreen(),
          routes: [
            GoRoute(
              path: 'new',
              name: 'ideaCreate',
              builder: (context, state) =>
                  NoteEditorScreen(initialLocation: state.extra as LatLng?),
            ),
            GoRoute(
              path: 'edit',
              name: 'ideaEdit',
              builder: (context, state) =>
                  NoteEditorScreen(existingNote: state.extra as CityNote?),
            ),
          ],
        ),
        GoRoute(
          path: '/settings',
          name: 'settings',
          builder: (context, state) => const SettingsScreen(),
        ),
        GoRoute(
          path: '/planner',
          name: 'planner',
          builder: (context, state) => const PlannerScreen(),
          routes: [
            GoRoute(
              path: 'new',
              name: 'planCreate',
              builder: (context, state) => const PlanEditorScreen(),
            ),
            GoRoute(
              path: ':id',
              name: 'planDetails',
              builder: (context, state) =>
                  PlanDetailScreen(planId: state.pathParameters['id'] ?? ''),
            ),
          ],
        ),
      ],
    ),
  ],
  errorBuilder: (context, state) => Scaffold(
    appBar: AppBar(title: Text(AppLocalizations.of(context).routeError)),
    body: Center(child: Text(state.error.toString())),
  ),
);
