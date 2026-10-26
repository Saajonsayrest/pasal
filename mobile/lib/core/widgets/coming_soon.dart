import 'package:flutter/material.dart';
import 'package:pasal_mobile/core/l10n/tr.dart';
import 'package:pasal_mobile/core/widgets/page.dart';
import 'package:pasal_mobile/core/widgets/pasal_widgets.dart';

/// Placeholder for a screen that is not written yet.
class ComingSoon extends StatelessWidget {
  const ComingSoon(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      title: title,
      scroll: false,
      body: EmptyState(icon: Icons.construction_rounded, title: context.tr('Not built yet', 'अझै बनेको छैन'), text: title),
    );
  }
}
