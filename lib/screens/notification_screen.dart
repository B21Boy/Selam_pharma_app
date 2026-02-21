import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/pharmacy_provider.dart';
import '../models/report.dart';
import 'medicine_detail_screen.dart';

class NotificationScreen extends StatelessWidget {
  const NotificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<PharmacyProvider>();
    final newReports = prov.reports.where((r) => !(r.isRead ?? false)).toList();
    final outOfStock = prov.getOutOfStockMedicines();
    final medicines = prov.medicines;

    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'New reports',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${newReports.length}',
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Out of stock',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${outOfStock.length}',
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),
              Card(
                child: ExpansionTile(
                  initiallyExpanded: true,
                  title: Text('New Reports (${newReports.length})'),
                  children: newReports.isEmpty
                      ? [const ListTile(title: Text('No new reports'))]
                      : newReports.map((Report r) {
                          final dt = DateFormat.yMMMd().add_jm().format(
                            r.dateTime,
                          );
                          return ListTile(
                            title: Text(r.medicineName),
                            subtitle: Text(
                              'Sold: ${r.soldQty} • Gain: ${r.totalGain} • $dt',
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.visibility_outlined),
                              onPressed: () async {
                                // open detail if medicine exists
                                dynamic med;
                                try {
                                  med = prov.medicines.firstWhere(
                                    (m) => m.name == r.medicineName,
                                  );
                                } catch (_) {
                                  med = null;
                                }

                                if (med == null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Medicine not found'),
                                    ),
                                  );
                                  return;
                                }

                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => MedicineDetailScreen(medicine: med),
                                  ),
                                );
                              },
                            ),
                          );
                        }).toList(),
                ),
              ),

              const SizedBox(height: 12),
              Card(
                child: ExpansionTile(
                  title: Text('Out of stock (${outOfStock.length})'),
                  children: outOfStock.isEmpty
                      ? [const ListTile(title: Text('No out-of-stock items'))]
                      : outOfStock.map((m) {
                          return ListTile(
                            title: Text(m.name),
                            subtitle: Text(
                              'Category: ${m.category ?? '—'} • Qty: ${m.totalQty}',
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.restore_outlined),
                              onPressed: () async {
                                // navigate to detail
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => MedicineDetailScreen(medicine: m),
                                  ),
                                );
                              },
                            ),
                          );
                        }).toList(),
                ),
              ),

              const SizedBox(height: 12),
              Card(
                child: ExpansionTile(
                  title: Text('All medicines (${medicines.length})'),
                  children: medicines.map((m) {
                    return ListTile(
                      title: Text(m.name),
                      subtitle: Text(
                        'Qty: ${m.totalQty} • Remaining: ${m.remainingQty}',
                      ),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => MedicineDetailScreen(medicine: m),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
