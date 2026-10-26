import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pasal_mobile/core/l10n/tr.dart';
import 'package:pasal_mobile/core/providers.dart';
import 'package:pasal_mobile/core/session/session.dart';
import 'package:pasal_mobile/core/theme/app_theme.dart';
import 'package:pasal_mobile/core/widgets/page.dart';
import 'package:pasal_mobile/core/widgets/pasal_widgets.dart';
import 'package:pasal_mobile/features/auth/data/account_repository.dart';

/// A3. Four setup steps for the owner. Each step opens its screen. Done steps are ticked from the data.
class FirstRunScreen extends ConsumerWidget {
  const FirstRunScreen({super.key});

  static const skipKey = 'pasal_welcome_done';

  Future<void> _skip(BuildContext context, WidgetRef ref) async {
    await ref.read(sharedPrefsProvider).setBool(skipKey, true);
    if (context.mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final setup = ref.watch(setupChecklistProvider);
    final first = (ref.watch(sessionProvider).user?.name ?? '').split(' ').first;

    return PageScaffold(
      title: context.tr('First-run guide', 'सुरुको गाइड'),
      bottom: SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          onPressed: () => _skip(context, ref),
          child: Text(context.tr('Skip for now', 'अहिले छोड्ने')),
        ),
      ),
      body: AsyncBody<SetupChecklist>(
        value: setup,
        onRetry: () => ref.invalidate(setupChecklistProvider),
        data: (c) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            HeroCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  StatBlock(
                    label: context.tr('Welcome, $first', 'स्वागत छ, $first'),
                    value: context.tr("Let's set up your shop", 'पसल सेटअप गरौँ'),
                    sub: context.tr('Four quick steps. You can do them later too.', 'चार सजिला काम। पछि पनि गर्न सकिन्छ।'),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          context.tr(
                            '${context.num(c.doneCount)} of ${context.num(4)} steps done',
                            '${context.num(4)} मध्ये ${context.num(c.doneCount)} काम पूरा भयो',
                          ),
                          style: context.text.bodySmall?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      Text('${context.num(c.doneCount * 25)}%', style: context.text.bodySmall?.copyWith(fontWeight: FontWeight.w700)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(value: c.doneCount / 4),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SectionTitle(context.tr('Setup steps', 'सेटअपका काम')),
            const SizedBox(height: 8),
            ListCard(
              children: [
                _SetupStep(
                  done: c.shopDone,
                  icon: Icons.storefront_rounded,
                  title: context.tr('Shop details', 'पसलको विवरण'),
                  subtitle: context.tr('Phone, address and PAN', 'फोन, ठेगाना र PAN'),
                  path: '/settings/shop',
                ),
                _SetupStep(
                  done: c.itemDone,
                  icon: Icons.add_rounded,
                  title: context.tr('Add your first item', 'पहिलो सामान थप्ने'),
                  subtitle: context.tr('Name, price and stock', 'नाम, भाउ र स्टक'),
                  path: '/items/new',
                ),
                _SetupStep(
                  done: c.customerDone,
                  icon: Icons.person_add_rounded,
                  title: context.tr('Add your first customer', 'पहिलो ग्राहक थप्ने'),
                  subtitle: context.tr('Name, phone and credit limit', 'नाम, फोन र उधारो सीमा'),
                  path: '/customers/new',
                ),
                _SetupStep(
                  done: c.staffDone,
                  icon: Icons.badge_rounded,
                  title: context.tr('Invite staff', 'कर्मचारी थप्ने'),
                  subtitle: context.tr('Give staff a login. They cannot see buying prices.', 'कर्मचारीलाई लग इन दिनुहोस्। उनीहरूले खरिद भाउ देख्दैनन्।'),
                  path: '/settings/staff',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SetupStep extends StatelessWidget {
  const _SetupStep({required this.done, required this.icon, required this.title, required this.subtitle, required this.path});

  final bool done;
  final IconData icon;
  final String title;
  final String subtitle;
  final String path;

  @override
  Widget build(BuildContext context) {
    return ListRow(
      leading: IconTile(done ? Icons.check_rounded : icon, tone: done ? Tone.good : Tone.primary, size: 44),
      title: title,
      subtitle: subtitle,
      trailing: PBadge(
        done ? context.tr('Done', 'भयो') : context.tr('To do', 'बाँकी'),
        tone: done ? Tone.good : Tone.neutral,
      ),
      onTap: () => context.push(path),
    );
  }
}
