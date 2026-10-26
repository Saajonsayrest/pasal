import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pasal_mobile/core/l10n/tr.dart';
import 'package:pasal_mobile/core/settings/settings.dart';
import 'package:pasal_mobile/core/theme/app_theme.dart';
import 'package:pasal_mobile/core/utils/bs.dart';
import 'package:pasal_mobile/core/widgets/inputs.dart';
import 'package:pasal_mobile/core/widgets/page.dart';
import 'package:pasal_mobile/core/widgets/pasal_widgets.dart';

/// Main colour, theme, language and date style. Saved on this phone and shown at once.
class AppLookScreen extends ConsumerWidget {
  const AppLookScreen({super.key});

  /// Same order and names as the website colours (seedColors in core settings).
  static const _colourNames = <(String, String)>[
    ('Green', 'हरियो'),
    ('Blue', 'नीलो'),
    ('Purple', 'बैजनी'),
    ('Red', 'रातो'),
    ('Orange', 'सुन्तला'),
    ('Teal', 'हरियो-नीलो'),
    ('Grey', 'खरानी'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return PageScaffold(
      title: context.tr('App look', 'एपको रूप'),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _heading(context, context.tr('Main colour', 'मुख्य रङ'), context.tr('Used on buttons and charts', 'बटन र चार्टमा देखिन्छ')),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (var i = 0; i < seedColors.length; i++)
                      _ColourDot(
                        key: ValueKey('seed-${seedColors[i].toARGB32()}'),
                        color: seedColors[i],
                        picked: settings.seed == seedColors[i].toARGB32(),
                        label: context.tr(_colourNames[i].$1, _colourNames[i].$2),
                        onTap: () => notifier.setSeed(seedColors[i]),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          PCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _heading(context, context.tr('Theme', 'थिम')),
                const SizedBox(height: 12),
                Seg<ThemeChoice>(
                  value: settings.theme,
                  onChanged: notifier.setTheme,
                  options: {
                    ThemeChoice.light: context.tr('Light', 'हल्का'),
                    ThemeChoice.dark: context.tr('Dark', 'गाढा'),
                    ThemeChoice.black: context.tr('Black', 'कालो'),
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          PCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _heading(context, context.tr('Language', 'भाषा')),
                const SizedBox(height: 12),
                Seg<bool>(
                  value: settings.ne,
                  onChanged: notifier.setNepali,
                  options: const {false: 'English', true: 'नेपाली'},
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          PCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _heading(context, context.tr('Date style', 'मितिको ढाँचा'), context.tr('BS date first, AD small', 'BS मिति पहिले, AD सानो अक्षरमा')),
                const SizedBox(height: 12),
                Seg<bool>(
                  value: settings.bsDates,
                  onChanged: notifier.setBsDates,
                  options: const {true: 'BS', false: 'AD'},
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 6),
            child: Text(
              context.tr('Preview', 'नमुना'),
              style: context.text.labelLarge?.copyWith(color: context.scheme.onSurfaceVariant, fontWeight: FontWeight.w700),
            ),
          ),
          HeroCard(
            child: Row(
              children: [
                Expanded(
                  child: StatBlock(
                    label: context.tr('We owe', 'हामीले तिर्न बाँकी'),
                    value: context.rs(12400000),
                  ),
                ),
                const SizedBox(width: 12),
                PBadge(formatDate(todayAd()), tone: Tone.primary),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget _heading(BuildContext context, String title, [String? sub]) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
          if (sub != null) Text(sub, style: context.text.bodySmall?.copyWith(color: context.scheme.onSurfaceVariant)),
        ],
      );
}

class _ColourDot extends StatelessWidget {
  const _ColourDot({required this.color, required this.picked, required this.label, required this.onTap, super.key});

  final Color color;
  final bool picked;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: picked,
      label: label,
      child: Material(
        color: color,
        shape: CircleBorder(
          side: picked ? BorderSide(width: 3, color: context.scheme.onSurface) : BorderSide.none,
        ),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 46,
            height: 46,
            child: picked ? const Icon(Icons.check_rounded, color: Colors.white) : null,
          ),
        ),
      ),
    );
  }
}
