import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/pharmacy_provider.dart';
import '../models/medicine.dart';

class TrashScreen extends StatefulWidget {
  const TrashScreen({super.key});

  @override
  State<TrashScreen> createState() => _TrashScreenState();
}

class _TrashScreenState extends State<TrashScreen> {
  bool _loading = false;
  bool _selectionMode = false;
  final Set<String> _selected = {};

  Future<void> _confirmRestore(PharmacyProvider prov, Medicine med) async {
    final ok =
        await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Restore'),
            content: Text('Restore "${med.name}" back to inventory?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Restore'),
              ),
            ],
          ),
        ) ??
        false;
    if (!ok) return;
    setState(() => _loading = true);
    final restoredReports = await prov.restoreMedicineFromTrash(med.id);
    setState(() => _loading = false);
    if (mounted) {
      if (restoredReports > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Restored ${med.name} and $restoredReports report(s)')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Restored ${med.name}')),
        );
      }
    }
  }

  Future<void> _confirmPermanentDelete(
    PharmacyProvider prov,
    Medicine med,
  ) async {
    final ok =
        await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Delete permanently'),
            content: Text(
              'Permanently delete "${med.name}"? This cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;
    if (!ok) return;
    setState(() => _loading = true);
    await prov.permanentlyDeleteFromTrash(med.id);
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<PharmacyProvider>();
    final trashed = prov.trashedMedicines;
    return Scaffold(
      appBar: AppBar(
        title: _selectionMode
            ? Text('${_selected.length} selected')
            : const Text('Trash'),
        actions: _selectionMode
            ? [
                IconButton(
                  tooltip: 'Restore selected',
                  icon: const Icon(Icons.restore),
                  onPressed: _selected.isEmpty
                      ? null
                      : () async {
                          setState(() => _loading = true);
                          final selectionCount = _selected.length;
                          var totalRestoredReports = 0;
                          for (final id in _selected.toList()) {
                            final cnt = await prov.restoreMedicineFromTrash(id);
                            totalRestoredReports += cnt;
                          }
                          _selected.clear();
                          setState(() {
                            _selectionMode = false;
                            _loading = false;
                          });
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Restored $selectionCount item(s) and $totalRestoredReports report(s)')),
                            );
                          }
                        },
                ),
                IconButton(
                  tooltip: 'Delete selected',
                  icon: const Icon(Icons.delete_forever),
                  onPressed: _selected.isEmpty
                      ? null
                      : () async {
                          final ok =
                              await showDialog<bool>(
                                context: context,
                                builder: (_) => AlertDialog(
                                  title: const Text('Delete permanently'),
                                  content: Text(
                                    'Permanently delete ${_selected.length} items? This cannot be undone.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: const Text('Cancel'),
                                    ),
                                    ElevatedButton(
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      child: const Text('Delete'),
                                    ),
                                  ],
                                ),
                              ) ??
                              false;
                          if (!ok) return;
                          setState(() => _loading = true);
                          for (final id in _selected.toList()) {
                            await prov.permanentlyDeleteFromTrash(id);
                          }
                          _selected.clear();
                          setState(() {
                            _selectionMode = false;
                            _loading = false;
                          });
                        },
                ),
                IconButton(
                  tooltip: 'Cancel',
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(() {
                    _selectionMode = false;
                    _selected.clear();
                  }),
                ),
              ]
            : null,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : trashed.isEmpty
          ? const Center(child: Text('Trash is empty'))
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: trashed.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (ctx, i) {
                final med = trashed[i];
                final daysLeft = prov.daysLeftInTrash(med);
                String expiryText = 'Expires: —';
                if (med.deletedAtMillis != null) {
                  final deletedAt = DateTime.fromMillisecondsSinceEpoch(
                    med.deletedAtMillis!,
                  );
                  final expireAt = deletedAt.add(
                    Duration(days: prov.trashRetentionDays),
                  );
                  expiryText =
                      'Expires: ${DateFormat.yMMMd().add_jm().format(expireAt)}';
                }
                final selected = _selected.contains(med.id);
                return ListTile(
                  leading: _selectionMode
                      ? Checkbox(
                          value: selected,
                          onChanged: (v) => setState(() {
                            if (v == true) {
                              _selected.add(med.id);
                            } else {
                              _selected.remove(med.id);
                            }
                          }),
                        )
                      : null,
                  tileColor: Theme.of(context).cardColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  title: Text(med.name),
                  subtitle: Text(
                    'Qty: ${med.totalQty} • ${med.category ?? '—'} • $expiryText • $daysLeft day(s) left',
                  ),
                  onLongPress: () => setState(() {
                    _selectionMode = true;
                    _selected.add(med.id);
                  }),
                  onTap: _selectionMode
                      ? () => setState(() {
                          if (selected) {
                            _selected.remove(med.id);
                          } else {
                            _selected.add(med.id);
                          }
                        })
                      : null,
                  trailing: _selectionMode
                      ? null
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Restore',
                              icon: const Icon(Icons.restore_outlined),
                              onPressed: () => _confirmRestore(prov, med),
                            ),
                            IconButton(
                              tooltip: 'Delete permanently',
                              icon: const Icon(Icons.delete_forever_outlined),
                              onPressed: () =>
                                  _confirmPermanentDelete(prov, med),
                            ),
                          ],
                        ),
                );
              },
            ),
    );
  }
}
