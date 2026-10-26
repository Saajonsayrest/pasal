import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pasal_mobile/core/l10n/tr.dart';
import 'package:pasal_mobile/core/models/models.dart';
import 'package:pasal_mobile/core/session/session.dart';
import 'package:pasal_mobile/core/theme/app_theme.dart';
import 'package:pasal_mobile/core/utils/bs.dart';
import 'package:pasal_mobile/core/widgets/inputs.dart';
import 'package:pasal_mobile/core/widgets/page.dart';
import 'package:pasal_mobile/core/widgets/pasal_widgets.dart';
import 'package:pasal_mobile/core/widgets/toast.dart';
import 'package:pasal_mobile/features/home/data/home_prefs.dart';
import 'package:pasal_mobile/features/home/data/home_repository.dart';
import 'package:pasal_mobile/features/home/data/vat_period.dart';
import 'package:pasal_mobile/features/home/presentation/home_widgets.dart';

/// Which notification kinds a filter chip shows. `all` shows every kind.
bool noticeMatchesFilter(String filter, String kind) => switch (filter) {
      'stock' => kind == 'low_stock',
      'money' => kind == 'credit_overdue',
      'vat' => kind == 'vat_unfiled' || kind == 'vat_due',
      _ => true,
    };

class _Notice {
  const _Notice({
    required this.kind,
    required this.title,
    required this.body,
    required this.href,
    required this.icon,
    required this.tone,
    required this.at,
    required this.day,
    required this.time,
  });

  final String kind;
  final String title;
  final String body;
  final String href;
  final IconData icon;
  final Tone tone;

  /// Full date-time (or the start of the day for the VAT row).
  final String at;

  /// The Nepal calendar day, used to group rows into Today and Earlier.
  final String day;
  final String time;
}

/// Bell page. The server list, plus a VAT row the app works out (owner, 10 days before the due date).
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  String _filter = 'all';

  Future<void> _markAllRead() async {
    await ref.read(notificationSeenProvider.notifier).markAllRead();
    if (!mounted) return;
    showToast(context, 'All marked as read', 'सबै पढिएको चिन्ह लगाइयो');
  }

  String _hrefFor(String kind, bool owner) => switch (kind) {
        'low_stock' => '/low-stock',
        'credit_overdue' => owner ? '/reports/credit-age' : '/customers',
        'vat_unfiled' => '/vat/filings',
        _ => '/settings/staff',
      };

  IconData _iconFor(String kind) => switch (kind) {
        'low_stock' => Icons.production_quantity_limits_rounded,
        'credit_overdue' => Icons.schedule_rounded,
        'vat_unfiled' || 'vat_due' => Icons.receipt_long_rounded,
        _ => Icons.badge_rounded,
      };

  Tone _toneFor(String kind) => switch (kind) {
        'low_stock' => Tone.warn,
        'credit_overdue' => Tone.bad,
        'vat_unfiled' || 'vat_due' => Tone.info,
        _ => Tone.neutral,
      };

  bool _isUnread(String at, DateTime? seen) => seen == null || DateTime.parse(at).isAfter(seen);

  @override
  Widget build(BuildContext context) {
    final owner = ref.watch(sessionProvider).isOwner;
    final period = nextVatPeriod();
    final today = todayAd();
    final dueSoon = owner && period.daysLeft <= 10;
    final preview = dueSoon ? ref.watch(vatPreviewProvider).value : null;
    final seen = ref.watch(notificationSeenProvider);
    final notes = ref.watch(notificationsProvider);

    List<_Notice> rowsFrom(List<AppNotification> list) {
      final out = <_Notice>[];
      if (dueSoon) {
        final rs = preview == null ? null : context.rs(preview.payable);
        out.add(
          _Notice(
            kind: 'vat_due',
            title: '${monthTitle(period.year, period.month)} ${context.tr('VAT', 'भ्याट')} ${dueLabel(context, period.daysLeft)}',
            body: rs == null ? formatDate(period.due) : context.tr('About $rs to pay', 'अनुमानित $rs तिर्नुपर्ने'),
            href: '/vat',
            icon: _iconFor('vat_due'),
            tone: _toneFor('vat_due'),
            at: '${today}T00:00:00+05:45',
            day: today,
            time: '',
          ),
        );
      }
      for (final n in list) {
        final day = adOfStamp(n.at);
        out.add(
          _Notice(
            kind: n.type,
            title: n.title,
            body: n.body,
            href: _hrefFor(n.type, owner),
            icon: _iconFor(n.type),
            tone: _toneFor(n.type),
            at: n.at,
            day: day,
            time: day == today ? formatTime(n.at) : formatDate(n.at),
          ),
        );
      }
      return out;
    }

    return PageScaffold(
      title: context.tr('Notifications', 'सूचनाहरू'),
      actions: [
        TextButton.icon(
          onPressed: _markAllRead,
          icon: const Icon(Icons.done_all_rounded, size: 18),
          label: Text(context.tr('Mark all as read', 'सबै पढिएको चिन्ह')),
        ),
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ChipsRow<String>(
            value: _filter,
            onChanged: (v) => setState(() => _filter = v),
            options: {
              'all': context.tr('All', 'सबै'),
              'stock': context.tr('Stock', 'स्टक'),
              'money': context.tr('Money', 'पैसा'),
              'vat': context.tr('VAT', 'भ्याट'),
            },
          ),
          const SizedBox(height: 12),
          AsyncBody<List<AppNotification>>(
            value: notes,
            onRetry: () => ref.invalidate(notificationsProvider),
            data: (list) {
              final shown = rowsFrom(list).where((r) => noticeMatchesFilter(_filter, r.kind)).toList();
              if (shown.isEmpty) {
                return EmptyState(
                  icon: Icons.notifications_none_rounded,
                  title: context.tr('No notifications', 'कुनै सूचना छैन'),
                  text: context.tr('Nothing needs your attention right now.', 'अहिले ध्यान दिनुपर्ने केही छैन।'),
                );
              }
              final todayRows = shown.where((r) => r.day == today).toList();
              final earlierRows = shown.where((r) => r.day != today).toList();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (todayRows.isNotEmpty) ...[
                    SectionTitle(context.tr('Today', 'आज')),
                    ListCard(children: [for (final r in todayRows) _NoticeRow(notice: r, unread: _isUnread(r.at, seen))]),
                  ],
                  if (earlierRows.isNotEmpty) ...[
                    SectionTitle(context.tr('Earlier', 'अघिल्ला')),
                    ListCard(children: [for (final r in earlierRows) _NoticeRow(notice: r, unread: _isUnread(r.at, seen))]),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _NoticeRow extends StatelessWidget {
  const _NoticeRow({required this.notice, required this.unread});

  final _Notice notice;
  final bool unread;

  @override
  Widget build(BuildContext context) {
    return ListRow(
      leading: IconTile(notice.icon, tone: notice.tone, size: 44),
      title: notice.title,
      subtitle: notice.body,
      trailing: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (unread)
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(bottom: 4),
              decoration: BoxDecoration(color: context.colors.good, shape: BoxShape.circle),
            ),
          Text(notice.time, style: context.text.labelSmall?.copyWith(color: context.scheme.onSurfaceVariant)),
        ],
      ),
      onTap: () => context.push(notice.href),
    );
  }
}
