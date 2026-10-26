import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pasal_mobile/core/session/session.dart';
import 'package:pasal_mobile/features/home/presentation/owner_home.dart';
import 'package:pasal_mobile/features/home/presentation/staff_home.dart';

/// Tab 1. Owner home or staff home, by role.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOwner = ref.watch(sessionProvider).isOwner;
    return isOwner ? const OwnerHome() : const StaffHome();
  }
}
