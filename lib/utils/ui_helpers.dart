import 'package:flutter/material.dart';

void showAppSnackBar(
  BuildContext context,
  String message, {
  bool error = false,
  Duration? duration,
}) {
  final theme = Theme.of(context);
  final snack = SnackBar(
    content: Text(
      message,
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
    ),
    backgroundColor: error
        ? theme.colorScheme.error
        : theme.colorScheme.secondary,
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    duration: duration ?? (error ? const Duration(seconds: 5) : const Duration(seconds: 3)),
  );
  ScaffoldMessenger.of(context).showSnackBar(snack);
}
