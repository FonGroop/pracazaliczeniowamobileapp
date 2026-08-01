import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../l10n/app_localizations.dart';
import '../shared/section_card.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);
    final useGps = ref.watch(useGpsProvider);

    Future<void> persist(String message) async {
      final prefs = await ref.read(preferencesProvider.future);
      await prefs.setDarkMode(ref.read(themeModeProvider) == ThemeMode.dark);
      await prefs.setLanguageCode(ref.read(localeProvider).languageCode);
      await prefs.setUseGps(ref.read(useGpsProvider));
      if (context.mounted) showAppNotice(ref, message);
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SectionCard(
                title: l10n.settings,
                icon: Icons.tune,
                child: Column(
                  children: [
                    SwitchListTile(
                      value: themeMode == ThemeMode.dark,
                      onChanged: (value) async {
                        ref.read(themeModeProvider.notifier).state = value
                            ? ThemeMode.dark
                            : ThemeMode.light;
                        await persist(l10n.preferencesUpdated);
                      },
                      title: Text(l10n.darkMode),
                      secondary: const Icon(Icons.dark_mode_outlined),
                    ),
                    SwitchListTile(
                      value: useGps,
                      onChanged: (value) async {
                        ref.read(useGpsProvider.notifier).state = value;
                        ref.read(discoveryAreaProvider.notifier).state = null;
                        ref.invalidate(locationProvider);
                        await persist(l10n.preferencesUpdated);
                      },
                      title: Text(l10n.useGps),
                      secondary: const Icon(Icons.gps_fixed),
                    ),
                    SegmentedButton<String>(
                      segments: [
                        ButtonSegment(
                          value: 'en',
                          label: Text(l10n.english),
                          icon: const Icon(Icons.language),
                        ),
                        ButtonSegment(
                          value: 'pl',
                          label: Text(l10n.polish),
                          icon: const Icon(Icons.translate),
                        ),
                      ],
                      selected: {locale.languageCode},
                      onSelectionChanged: (selection) async {
                        ref.read(localeProvider.notifier).state = Locale(
                          selection.first,
                        );
                        await persist(l10n.preferencesUpdated);
                      },
                    ),
                    const SizedBox(height: 12),
                    Text(
                      l10n.preferencesStoredLocally,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
