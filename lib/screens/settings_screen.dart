// Temporary: ignore new RadioGroup deprecations and context sync lint here.
// TODO: migrate RadioListTile usage to RadioGroup when updating Flutter SDK.
// ignore_for_file: deprecated_member_use, use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../providers/pharmacy_provider.dart';
import '../utils/ui_helpers.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Local state for toggles (no persistence in this minimal scaffold)
  String _themeMode = 'system'; // 'system' | 'light' | 'dark'
  bool _notificationsEnabled = true;
  bool _badgeEnabled = true;
  bool _biometricEnabled = false;
  bool _trashNotificationsEnabled = true;

  Box? _settingsBox;

  @override
  void initState() {
    super.initState();
    try {
      _settingsBox = Hive.box('settings');
      _trashNotificationsEnabled =
          _settingsBox?.get(
            'trash_notifications_enabled',
            defaultValue: true,
          ) ??
          true;
    } catch (_) {
      _trashNotificationsEnabled = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        automaticallyImplyLeading: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          children: [
            const SizedBox(height: 8),

            // Appearance
            Text('Appearance', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  RadioListTile<String>(
                    value: 'system',
                    groupValue: _themeMode,
                    title: const Text('System'),
                    onChanged: (v) =>
                        setState(() => _themeMode = v ?? 'system'),
                  ),
                  RadioListTile<String>(
                    value: 'light',
                    groupValue: _themeMode,
                    title: const Text('Light'),
                    onChanged: (v) =>
                        setState(() => _themeMode = v ?? 'system'),
                  ),
                  RadioListTile<String>(
                    value: 'dark',
                    groupValue: _themeMode,
                    title: const Text('Dark'),
                    onChanged: (v) =>
                        setState(() => _themeMode = v ?? 'system'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Notifications
            Text('Notifications', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  SwitchListTile(
                    value: _notificationsEnabled,
                    onChanged: (v) => setState(() => _notificationsEnabled = v),
                    title: const Text('Enable notifications'),
                    subtitle: const Text('Show notifications and badges'),
                  ),
                  SwitchListTile(
                    value: _badgeEnabled,
                    onChanged: (v) => setState(() => _badgeEnabled = v),
                    title: const Text('Show badges'),
                  ),
                  SwitchListTile(
                    value: _trashNotificationsEnabled,
                    onChanged: (v) async {
                      setState(() => _trashNotificationsEnabled = v);
                      // persist
                      try {
                        _settingsBox?.put('trash_notifications_enabled', v);
                      } catch (_) {}
                      // if disabling, cancel scheduled notifications for trashed items
                      final prov = Provider.of<PharmacyProvider>(
                        context,
                        listen: false,
                      );
                      if (!v) {
                        for (final med in prov.trashedMedicines) {
                          await NotificationService.instance.cancelFor(med.id);
                        }
                      } else {
                        // schedule notifications for existing trashed items
                        for (final med in prov.trashedMedicines) {
                          final deletedAt = med.deletedAtMillis != null
                              ? DateTime.fromMillisecondsSinceEpoch(
                                  med.deletedAtMillis!,
                                )
                              : DateTime.now();
                          final expireAt = deletedAt.add(
                            Duration(days: prov.trashRetentionDays),
                          );
                          final twoDays = expireAt.subtract(
                            const Duration(days: 2),
                          );
                          final oneDay = expireAt.subtract(
                            const Duration(days: 1),
                          );
                          try {
                            await NotificationService.instance.schedule(
                              notifId: med.id,
                              offset: 0,
                              title: 'Expiring soon',
                              body:
                                  '${med.name} will be permanently deleted in 2 days.',
                              at: twoDays,
                            );
                            await NotificationService.instance.schedule(
                              notifId: med.id,
                              offset: 1,
                              title: 'Expiring soon',
                              body:
                                  '${med.name} will be permanently deleted in 1 day.',
                              at: oneDay,
                            );
                            await NotificationService.instance.schedule(
                              notifId: med.id,
                              offset: 2,
                              title: 'Deleted',
                              body:
                                  '${med.name} has been permanently deleted from Trash.',
                              at: expireAt,
                            );
                          } catch (_) {}
                        }
                      }
                    },
                    title: const Text('Trash expiry notifications'),
                    subtitle: const Text(
                      'Notify when trashed items are about to be permanently deleted',
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Account / Security
            Text('Privacy & Security', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  SwitchListTile(
                    value: _biometricEnabled,
                    onChanged: (v) => setState(() => _biometricEnabled = v),
                    title: const Text('Use biometric unlock'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Data & Storage
            Text('Data & Storage', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.file_download_outlined),
                    title: const Text('Export data'),
                    subtitle: const Text('Export CSV / JSON'),
                    onTap: () {
                      // TODO: implement export
                      showAppSnackBar(context, 'Export started');
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.delete_outline),
                    title: const Text('Clear cache'),
                    onTap: () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Clear cache?'),
                          content: const Text(
                            'This will remove temporary data. Continue?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(false),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(true),
                              child: const Text('Clear'),
                            ),
                          ],
                        ),
                      );
                      if (!mounted) return;
                      if (ok == true) {
                        showAppSnackBar(context, 'Cache cleared');
                      }
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Account actions
            Text('Account', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.logout_outlined),
                    title: const Text('Logout'),
                    subtitle: const Text('Sign out of this account'),
                    onTap: () async {
                      try {
                        await AuthService().signOut();
                        if (!mounted) return;
                        Navigator.of(
                          context,
                        ).pushNamedAndRemoveUntil('/login', (route) => false);
                      } catch (e) {
                        if (!mounted) return;
                        showAppSnackBar(
                          context,
                          'Sign out failed: $e',
                          error: true,
                        );
                      }
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.person_remove_outlined),
                    title: const Text('Delete account'),
                    subtitle: const Text('Permanently delete account and data'),
                    onTap: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Delete account?'),
                          content: const Text(
                            'This will permanently delete your account and associated cloud data. This cannot be undone. Continue?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(false),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(true),
                              child: const Text('Delete'),
                            ),
                          ],
                        ),
                      );
                      if (confirm != true) return;

                      // show progress
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (context) =>
                            const Center(child: CircularProgressIndicator()),
                      );

                      try {
                        await AuthService().deleteAccount();
                        if (!mounted) return;
                        Navigator.of(context).pop(); // pop progress
                        Navigator.of(
                          context,
                        ).pushNamedAndRemoveUntil('/login', (route) => false);
                      } on Exception catch (e) {
                        if (!mounted) return;
                        Navigator.of(context).pop(); // pop progress
                        final msg = e.toString();
                        showAppSnackBar(
                          context,
                          'Delete failed: $msg',
                          error: true,
                        );
                      }
                    },
                  ),
                ],
              ),
            ),

            // About
            Text('About', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: const [
                  ListTile(
                    leading: Icon(Icons.info_outline),
                    title: Text('About this app'),
                    subtitle: Text('Version 1.0.0'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
