import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:recall/core/widgets/adaptive_shell.dart';
import 'package:recall/features/decks/presentation/card_editor_page.dart';
import 'package:recall/features/decks/presentation/deck_editor_page.dart';
import 'package:recall/features/decks/presentation/decks_screen.dart';
import 'package:recall/features/import_export/presentation/import_page.dart';
import 'package:recall/features/settings/settings_page.dart';
import 'package:recall/features/stats/presentation/stats_page.dart';
import 'package:recall/features/study/presentation/study_page.dart';

part 'router.g.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');
final shellNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'shell');

// Full-screen routes first: '/decks/new' must win over '/decks/:deckId'.

@TypedGoRoute<DeckNewRoute>(path: '/decks/new')
class DeckNewRoute extends GoRouteData with $DeckNewRoute {
  const DeckNewRoute();
  static final GlobalKey<NavigatorState> $parentNavigatorKey = rootNavigatorKey;

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const DeckEditorPage();
}

@TypedGoRoute<DeckEditRoute>(path: '/decks/:deckId/edit')
class DeckEditRoute extends GoRouteData with $DeckEditRoute {
  const DeckEditRoute({required this.deckId});
  final int deckId;
  static final GlobalKey<NavigatorState> $parentNavigatorKey = rootNavigatorKey;

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      DeckEditorPage(deckId: deckId);
}

@TypedGoRoute<StudyRoute>(path: '/decks/:deckId/study')
class StudyRoute extends GoRouteData with $StudyRoute {
  const StudyRoute({required this.deckId});
  final int deckId;
  static final GlobalKey<NavigatorState> $parentNavigatorKey = rootNavigatorKey;

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      StudyPage(deckId: deckId);
}

@TypedGoRoute<CardNewRoute>(path: '/decks/:deckId/cards/new')
class CardNewRoute extends GoRouteData with $CardNewRoute {
  const CardNewRoute({required this.deckId});
  final int deckId;
  static final GlobalKey<NavigatorState> $parentNavigatorKey = rootNavigatorKey;

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      CardEditorPage(deckId: deckId);
}

@TypedGoRoute<CardEditRoute>(path: '/decks/:deckId/cards/:cardId')
class CardEditRoute extends GoRouteData with $CardEditRoute {
  const CardEditRoute({required this.deckId, required this.cardId});
  final int deckId;
  final int cardId;
  static final GlobalKey<NavigatorState> $parentNavigatorKey = rootNavigatorKey;

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      CardEditorPage(deckId: deckId, cardId: cardId);
}

@TypedGoRoute<ImportRoute>(path: '/import')
class ImportRoute extends GoRouteData with $ImportRoute {
  const ImportRoute();
  static final GlobalKey<NavigatorState> $parentNavigatorKey = rootNavigatorKey;

  @override
  Widget build(BuildContext context, GoRouterState state) => const ImportPage();
}

@TypedShellRoute<AppShellRoute>(
  routes: [
    TypedGoRoute<DecksRoute>(path: '/'),
    TypedGoRoute<DeckRoute>(path: '/decks/:deckId'),
    TypedGoRoute<StatsRoute>(path: '/stats'),
    TypedGoRoute<SettingsRoute>(path: '/settings'),
  ],
)
class AppShellRoute extends ShellRouteData {
  const AppShellRoute();
  static final GlobalKey<NavigatorState> $navigatorKey = shellNavigatorKey;

  @override
  Widget builder(BuildContext context, GoRouterState state, Widget navigator) =>
      AdaptiveShell(location: state.uri.path, child: navigator);
}

class DecksRoute extends GoRouteData with $DecksRoute {
  const DecksRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const DecksScreen();
}

class DeckRoute extends GoRouteData with $DeckRoute {
  const DeckRoute({required this.deckId});
  final int deckId;

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      DecksScreen(deckId: deckId);
}

class StatsRoute extends GoRouteData with $StatsRoute {
  const StatsRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) => const StatsPage();
}

class SettingsRoute extends GoRouteData with $SettingsRoute {
  const SettingsRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const SettingsPage();
}

GoRouter buildRouter({String initialLocation = '/'}) => GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: initialLocation,
  routes: $appRoutes,
);
