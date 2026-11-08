import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:recall/app/router.dart';
import 'package:recall/app/settings.dart';
import 'package:recall/app/theme/app_theme.dart';
import 'package:recall/l10n/gen/app_localizations.dart';
import 'package:recall/splash/recall_splash.dart';

class RecallApp extends ConsumerStatefulWidget {
  const RecallApp({
    super.key,
    this.showSplash = true,
    this.initialLocation = '/',
  });

  final bool showSplash;
  final String initialLocation;

  @override
  ConsumerState<RecallApp> createState() => _RecallAppState();
}

class _RecallAppState extends ConsumerState<RecallApp>
    with WidgetsBindingObserver {
  late final GoRouter _router = buildRouter(
    initialLocation: widget.initialLocation,
  );
  late bool _splashDone = !widget.showSplash;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeLocales(List<Locale>? locales) => setState(() {});

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(settingsProvider);
    final s = async.value ?? const AppSettings();
    final locale = s.localeCode == null ? null : Locale(s.localeCode!);
    final effective = locale ?? ui.PlatformDispatcher.instance.locale;

    return MaterialApp.router(
      routerConfig: _router,
      debugShowCheckedModeBanner: false,
      onGenerateTitle: (c) => AppLocalizations.of(c).appName,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      themeMode: s.themeMode,
      theme: AppTheme.light(effective),
      darkTheme: AppTheme.dark(effective),
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        final content = MediaQuery(
          data: mq.copyWith(
            disableAnimations: mq.disableAnimations || s.reduceMotion,
          ),
          child: child!,
        );
        final ready = async.hasValue && _splashDone;
        final scheme = Theme.of(context).colorScheme;
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          child: ready
              ? KeyedSubtree(key: const ValueKey('app'), child: content)
              : MediaQuery(
                  key: const ValueKey('splash'),
                  data: mq.copyWith(
                    disableAnimations: mq.disableAnimations || s.reduceMotion,
                  ),
                  child: RecallSplash(
                    paper: scheme.surface,
                    ink: scheme.onSurface,
                    accent: scheme.primary,
                    cardColor: context.paper.card,
                    fontFamily: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.fontFamily,
                    onFinished: () => setState(() => _splashDone = true),
                  ),
                ),
        );
      },
    );
  }
}
