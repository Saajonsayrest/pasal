import 'package:flutter/widgets.dart';

/// Screens that open over the bottom menu (details, forms, checkout) use `parentNavigatorKey: rootNavigatorKey`.
final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');
