import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// App bar with optional back button that navigates to home.
AppBar appBarWithBack(
  BuildContext context, {
  required String title,
  List<Widget>? actions,
  bool showBackButton = true,
}) {
  return AppBar(
    leading: showBackButton
        ? IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => context.go('/'),
            tooltip: 'Back',
          )
        : null,
    title: Text(title),
    actions: actions,
  );
}
