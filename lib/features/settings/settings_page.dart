import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:recall/app/settings.dart';
import 'package:recall/app/theme/app_theme.dart';
import 'package:recall/l10n/gen/app_localizations.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final s = ref.watch(settingsProvider).value ?? const AppSettings();
    final ctl = ref.read(settingsProvider.notifier);
    return Scaffold(
      appBar: AppBar(
        title: Text(l.settingsTitle, style: context.text.headlineMedium),
        toolbarHeight: 72,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _Section(
                title: l.languageSetting,
                child: SegmentedButton<String>(
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(value: '', label: Text(l.languageSystem)),
                    ButtonSegment(value: 'en', label: Text(l.languageEnglish)),
                    ButtonSegment(value: 'ar', label: Text(l.languageArabic)),
                  ],
                  selected: {s.localeCode ?? ''},
                  onSelectionChanged: (v) =>
                      ctl.setLocale(v.first.isEmpty ? null : v.first),
                ),
              ),
              _Section(
                title: l.themeSetting,
                child: SegmentedButton<ThemeMode>(
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(
                      value: ThemeMode.system,
                      label: Text(l.themeSystem),
                    ),
                    ButtonSegment(
                      value: ThemeMode.light,
                      label: Text(l.themeLight),
                    ),
                    ButtonSegment(
                      value: ThemeMode.dark,
                      label: Text(l.themeDark),
                    ),
                  ],
                  selected: {s.themeMode},
                  onSelectionChanged: (v) => ctl.setThemeMode(v.first),
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l.reduceMotion),
                subtitle: Text(l.reduceMotionDesc),
                value: s.reduceMotion,
                onChanged: (v) => ctl.setReduceMotion(value: v),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 28),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: context.text.titleSmall),
        const SizedBox(height: 12),
        SizedBox(width: double.infinity, child: child),
      ],
    ),
  );
}
