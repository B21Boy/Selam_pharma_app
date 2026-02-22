import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:hive/hive.dart';
import '../providers/pharmacy_provider.dart';
import '../screens/contact_screen.dart';
import '../screens/trash_screen.dart';
import '../screens/notification_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/help_screen.dart';

class AppDrawer extends StatefulWidget {
  final void Function()? onRegister;
  final void Function()? onContact;
  final void Function()? onTrash;
  final void Function()? onHelp;

  const AppDrawer({
    super.key,
    this.onRegister,
    this.onContact,
    this.onTrash,
    this.onHelp,
  });

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0.02, 0.04),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    WidgetsBinding.instance.addPostFrameCallback((_) => _ctrl.forward());
    // load persisted avatar path if available
    try {
      _settingsBox = Hive.box('settings');
    } catch (_) {
      _settingsBox = null;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Box? _settingsBox;

  Future<void> _pickAvatar() async {
    try {
      final picker = ImagePicker();
      final xfile = await picker.pickImage(source: ImageSource.gallery);
      if (xfile == null) return;
      final path = xfile.path;
      // persist
      try {
        _settingsBox?.put('drawerAvatarPath', path);
      } catch (_) {}
      setState(() {});
    } catch (e) {
      // ignore errors silently
    }
  }

  Widget _buildItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: theme.primaryColor.withAlpha((0.06 * 255).round()),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: theme.primaryColor),
      ),
      title: Text(
        title,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: subtitle != null
          ? Text(subtitle, style: theme.textTheme.bodySmall)
          : null,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16.0,
        vertical: 12.0,
      ),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      horizontalTitleGap: 12,
      tileColor: Colors.transparent,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pharmacy = context.watch<PharmacyProvider?>();
    final screenW = MediaQuery.of(context).size.width;
    final drawerWidth = math.min(screenW * 0.92, 420.0);

    return Drawer(
      width: drawerWidth,
      child: SafeArea(
        child: FadeTransition(
          opacity: _fade,
          child: SlideTransition(
            position: _slide,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  height: 120,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        theme.primaryColor,
                        theme.primaryColor.withAlpha((0.9 * 255).round()),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 56,
                        height: 56,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Positioned.fill(
                              child: Builder(
                                builder: (ctx) {
                                  String? avatarPath;
                                  try {
                                    avatarPath = Hive.box(
                                      'settings',
                                    ).get('drawerAvatarPath');
                                  } catch (_) {
                                    avatarPath = null;
                                  }
                                  if (avatarPath != null &&
                                      File(avatarPath).existsSync()) {
                                    return CircleAvatar(
                                      radius: 28,
                                      backgroundColor: Colors.white,
                                      backgroundImage: FileImage(
                                        File(avatarPath),
                                      ),
                                    );
                                  }
                                  return CircleAvatar(
                                    radius: 28,
                                    backgroundColor: Colors.white,
                                    child: Icon(
                                      Icons.local_pharmacy,
                                      color: theme.primaryColor,
                                      size: 30,
                                    ),
                                  );
                                },
                              ),
                            ),
                            Positioned(
                              bottom: -2,
                              right: -2,
                              child: GestureDetector(
                                onTap: _pickAvatar,
                                child: Container(
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    color: theme.primaryColor,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 2,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.add,
                                    size: 12,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Pharmacy Manager',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Manage medicines & reports',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close, color: Colors.white70),
                        tooltip: 'Close',
                        splashRadius: 20,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      _buildItem(
                        context,
                        icon: Icons.add_circle_outline,
                        title: 'Register',
                        subtitle: 'Add new medicine',
                        onTap:
                            widget.onRegister ??
                            () => Navigator.of(context).pop(),
                      ),

                      ListTile(
                        leading: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: theme.primaryColor.withAlpha(
                              (0.06 * 255).round(),
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.notifications_outlined,
                            color: theme.primaryColor,
                          ),
                        ),
                        title: Text(
                          'Notifications',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          '${pharmacy?.newReportsCount ?? 0} new reports • ${pharmacy?.outOfStockCount ?? 0} out of stock',
                          style: theme.textTheme.bodySmall,
                        ),
                        trailing: (pharmacy?.newReportsCount ?? 0) > 0
                            ? Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.primaryColor,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${pharmacy?.newReportsCount ?? 0}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              )
                            : null,
                        onTap: () {
                          final nav = Navigator.of(context);
                          nav.pop();
                          nav.push(
                            MaterialPageRoute(
                              builder: (_) => const NotificationScreen(),
                            ),
                          );
                        },
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16.0,
                          vertical: 12.0,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),

                      _buildItem(
                        context,
                        icon: Icons.contact_page_outlined,
                        title: 'Contact',
                        subtitle: 'Support & feedback',
                        onTap:
                            widget.onContact ??
                            () {
                              final nav = Navigator.of(context);
                              nav.pop();
                              nav.push(
                                MaterialPageRoute(
                                  builder: (_) => const ContactScreen(),
                                ),
                              );
                            },
                      ),

                      Builder(
                        builder: (ctx) {
                          final prov = ctx.watch<PharmacyProvider?>();
                          final expiring =
                              prov?.trashedExpiringWithin(days: 2) ?? 0;
                          return ListTile(
                            leading: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: theme.primaryColor.withAlpha(
                                  (0.06 * 255).round(),
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.delete_outline,
                                color: theme.primaryColor,
                              ),
                            ),
                            title: Text(
                              'Trash',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              'Recently deleted items',
                              style: theme.textTheme.bodySmall,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16.0,
                              vertical: 12.0,
                            ),
                            onTap:
                                widget.onTrash ??
                                () {
                                  final nav = Navigator.of(context);
                                  nav.pop();
                                  nav.push(
                                    MaterialPageRoute(
                                      builder: (_) => const TrashScreen(),
                                    ),
                                  );
                                },
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            trailing: expiring > 0
                                ? Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.orange,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '$expiring',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  )
                                : null,
                          );
                        },
                      ),

                      _buildItem(
                        context,
                        icon: Icons.help_outline,
                        title: 'Help',
                        subtitle: 'App help & docs',
                        onTap:
                            widget.onHelp ??
                            () {
                              final nav = Navigator.of(context);
                              nav.pop();
                              nav.push(
                                MaterialPageRoute(
                                  builder: (_) => const HelpScreen(),
                                ),
                              );
                            },
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 12.0,
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      final nav = Navigator.of(context);
                      nav.pop();
                      nav.push(
                        MaterialPageRoute(
                          builder: (_) => const SettingsScreen(),
                        ),
                      );
                    },
                    child: Row(
                      children: [
                        Icon(
                          Icons.settings_outlined,
                          size: 18,
                          color: theme.hintColor,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Settings',
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                        Icon(
                          Icons.chevron_right,
                          size: 20,
                          color: theme.hintColor,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
