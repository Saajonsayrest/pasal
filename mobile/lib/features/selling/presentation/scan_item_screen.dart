import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:pasal_mobile/core/l10n/tr.dart';
import 'package:pasal_mobile/core/theme/app_theme.dart';
import 'package:pasal_mobile/core/widgets/page.dart';
import 'package:pasal_mobile/core/widgets/pasal_widgets.dart';

/// Full-screen camera. The first code it reads is sent back to the sell screen with `pop`.
class ScanItemScreen extends StatefulWidget {
  const ScanItemScreen({super.key});

  @override
  State<ScanItemScreen> createState() => _ScanItemScreenState();
}

class _ScanItemScreenState extends State<ScanItemScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _done = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_done) return;
    String? code;
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue;
      if (value != null && value.trim().isNotEmpty) {
        code = value.trim();
        break;
      }
    }
    if (code == null) return;
    _done = true;
    HapticFeedback.mediumImpact();
    unawaited(_controller.stop());
    context.pop<String>(code);
  }

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      title: context.tr('Scan a barcode', 'बारकोड स्क्यान'),
      scroll: false,
      maxWidth: 900,
      padding: EdgeInsets.zero,
      body: Column(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(Radii.lg),
              child: MobileScanner(
                controller: _controller,
                onDetect: _onDetect,
                errorBuilder: (context, error) => EmptyState(
                  icon: Icons.no_photography_rounded,
                  title: context.tr('The camera is not available', 'क्यामेरा खुलेन'),
                  text: context.tr('Allow camera access in the phone settings, then try again.', 'फोनको सेटिङमा क्यामेरा खोल्न दिनुहोस्, त्यसपछि फेरि प्रयास गर्नुहोस्।'),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Text(
              context.tr('Hold the code in front of the camera.', 'कोड क्यामेराको अगाडि राख्नुहोस्।'),
              textAlign: TextAlign.center,
              style: context.text.bodyMedium?.copyWith(color: context.scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}
