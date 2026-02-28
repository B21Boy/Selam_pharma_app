import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AuthHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final double height;
  final double titleFontSize;
  final double subtitleFontSize;

  const AuthHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.height = 220,
    this.titleFontSize = 32,
    this.subtitleFontSize = 14,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primaryLight, AppTheme.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(48),
          bottomRight: Radius.circular(48),
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: TextStyle(
                color: Colors.white,
                fontSize: titleFontSize,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: subtitleFontSize,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
