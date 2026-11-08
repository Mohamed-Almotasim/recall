import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:recall/app/providers.dart';
import 'package:recall/features/decks/application/seed_service.dart';
import 'package:recall/features/stats/data/demo_history.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'settings.freezed.dart';
part 'settings.g.dart';

@freezed
abstract class AppSettings with _$AppSettings {
  const factory AppSettings({
    /// null = follow the system.
    String? localeCode,
    @Default(ThemeMode.system) ThemeMode themeMode,
    @Default(false) bool reduceMotion,
  }) = _AppSettings;
}

/// Loads persisted settings, seeding the demo decks on the very first run.
@Riverpod(keepAlive: true)
class Settings extends _$Settings {
  @override
  Future<AppSettings> build() async {
    final repo = ref.watch(settingsRepositoryProvider);
    final seeded = await seedIfFirstRun(
      decks: ref.watch(deckRepositoryProvider),
      settings: repo,
      loadAsset: rootBundle.loadString,
    );
    if (seeded && const bool.fromEnvironment('DEMO_HISTORY')) {
      await seedDemoHistory(
        ref.watch(appDatabaseProvider),
        ref.watch(clockProvider).now(),
      );
    }
    final m = await repo.readAll();
    return AppSettings(
      localeCode: (m['locale'] ?? '').isEmpty ? null : m['locale'],
      themeMode: ThemeMode.values.asNameMap()[m['theme']] ?? ThemeMode.system,
      reduceMotion: m['reduceMotion'] == '1',
    );
  }

  AppSettings get _current => state.value ?? const AppSettings();

  Future<void> setLocale(String? code) async {
    state = AsyncData(_current.copyWith(localeCode: code));
    await ref.read(settingsRepositoryProvider).write('locale', code ?? '');
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = AsyncData(_current.copyWith(themeMode: mode));
    await ref.read(settingsRepositoryProvider).write('theme', mode.name);
  }

  Future<void> setReduceMotion({required bool value}) async {
    state = AsyncData(_current.copyWith(reduceMotion: value));
    await ref
        .read(settingsRepositoryProvider)
        .write('reduceMotion', value ? '1' : '0');
  }
}
