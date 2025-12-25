import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/pharmacy_provider.dart';
import '../models/report.dart';
import '../models/medicine.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  ReportScreenState createState() => ReportScreenState();
}

class ReportScreenState extends State<ReportScreen> {
  final TextEditingController _searchController = TextEditingController();
  int _selectedPeriodIndex = 0;
  final List<String> _timePeriods = [
    'Today',
    'This Week',
    'This Month',
    'This Year',
  ];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
  }

  List<Report> _filterReportsByPeriod(List<Report> reports, String period) {
    final now = DateTime.now();
    DateTime startDate;
    DateTime endDate;

    switch (period) {
      case 'Today':
        startDate = DateTime(now.year, now.month, now.day);
        endDate = startDate;
        break;
      case 'This Week':
        startDate = now.subtract(Duration(days: now.weekday - 1));
        startDate = DateTime(startDate.year, startDate.month, startDate.day);
        endDate = startDate.add(Duration(days: 6));
        break;
      case 'This Month':
        startDate = DateTime(now.year, now.month, 1);
        endDate = DateTime(
          now.year,
          now.month + 1,
          1,
        ).subtract(Duration(days: 1));
        break;
      case 'This Year':
        startDate = DateTime(now.year, 1, 1);
        endDate = DateTime(now.year + 1, 1, 1).subtract(Duration(days: 1));
        break;
      default:
        startDate = DateTime(now.year, now.month, now.day);
        endDate = startDate;
    }

    return reports.where((report) {
      final reportDate = DateTime(
        report.dateTime.year,
        report.dateTime.month,
        report.dateTime.day,
      );
      return reportDate.isAfter(startDate.subtract(Duration(days: 1))) &&
          reportDate.isBefore(endDate.add(Duration(days: 1)));
    }).toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reports = context.watch<PharmacyProvider>().reports;
    final query = _searchController.text.toLowerCase();
    final periodFilteredReports = _filterReportsByPeriod(
      reports,
      _timePeriods[_selectedPeriodIndex],
    );
    final filteredReports = periodFilteredReports.where((report) {
      final matchesSearch =
          query.isEmpty || report.medicineName.toLowerCase().contains(query);
      return matchesSearch;
    }).toList();

    // Group reports by date
    Map<String, List<Report>> groupedReports = {};
    for (var report in filteredReports) {
      String dateKey = DateFormat('yyyy-MM-dd').format(report.dateTime);
      groupedReports.putIfAbsent(dateKey, () => []).add(report);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Reports',
          style: GoogleFonts.montserrat(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).appBarTheme.titleTextStyle?.color,
          ),
        ),
      ),
      body: Column(
        children: [
          // Period Selection Buttons
          Container(
            margin: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: _timePeriods.map((period) {
                final isSelected = _timePeriods[_selectedPeriodIndex] == period;
                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedPeriodIndex = _timePeriods.indexOf(period);
                        _searchController.clear();
                      });
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4.0),
                      padding: const EdgeInsets.symmetric(vertical: 12.0),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF007BFF)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(8.0),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF007BFF)
                              : Colors.grey[300]!,
                          width: 1.0,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: const Color(0xFF007BFF).withAlpha(77),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Text(
                        period,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.montserrat(
                          color: isSelected ? Colors.white : Colors.grey[700],
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          // Summary Cards
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: _buildSummaryCard(
                    _timePeriods[_selectedPeriodIndex],
                    '${filteredReports.length} Reports',
                    Icons.calendar_today,
                    Colors.orange,
                  ),
                ),
              ],
            ),
          ),
          // Search and Filter Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search medicines...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          // Reports List
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final crossAxisCount = constraints.maxWidth > 600 ? 2 : 1;
                final sortedEntries = groupedReports.entries.toList()
                  ..sort((a, b) => b.key.compareTo(a.key));
                return ListView(
                  padding: const EdgeInsets.all(16.0),
                  children: sortedEntries.map((entry) {
                    final date = entry.key;
                    final dayReports = entry.value;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 16.0),
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ExpansionTile(
                        title: Row(
                          children: [
                            Icon(Icons.calendar_today, color: Colors.blue),
                            SizedBox(width: 8),
                            Text(
                              DateFormat(
                                'EEEE, MMMM dd, yyyy',
                              ).format(DateTime.parse(date)),
                              style: GoogleFonts.montserrat(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        children: [
                          GridView.builder(
                            shrinkWrap: true,
                            physics: NeverScrollableScrollPhysics(),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: crossAxisCount,
                                  crossAxisSpacing: 8,
                                  mainAxisSpacing: 8,
                                  childAspectRatio: 1.5,
                                ),
                            itemCount: dayReports.length,
                            itemBuilder: (context, index) {
                              final report = dayReports[index];
                              final isProfitable =
                                  report.totalGain > 10; // Simple threshold
                              return Card(
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                color: isProfitable
                                    ? Colors.green[50]
                                    : Colors.orange[50],
                                child: Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.medication,
                                            color: isProfitable
                                                ? Colors.green
                                                : Colors.orange,
                                          ),
                                          SizedBox(width: 8),
                                          Expanded(
                                            child: GestureDetector(
                                              onTap: () => _showRenameDialog(
                                                context,
                                                report,
                                              ),
                                              child: Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      report.medicineName,
                                                      style:
                                                          GoogleFonts.montserrat(
                                                            fontSize: 16,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            color:
                                                                Theme.of(
                                                                      context,
                                                                    )
                                                                    .textTheme
                                                                    .bodyLarge
                                                                    ?.color,
                                                          ),
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  Icon(
                                                    Icons.edit,
                                                    size: 16,
                                                    color: Colors.blue,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.inventory_2,
                                            size: 16,
                                            color: Colors.grey[700],
                                          ),
                                          SizedBox(width: 4),
                                          Text(
                                            'Qty: ${report.soldQty}',
                                            style: GoogleFonts.montserrat(
                                              fontSize: 14,
                                              color: Theme.of(
                                                context,
                                              ).textTheme.bodyMedium?.color,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.attach_money,
                                            size: 16,
                                            color: Colors.grey[700],
                                          ),
                                          SizedBox(width: 4),
                                          Text(
                                            'Sold: ${report.sellPrice} Birr',
                                            style: GoogleFonts.montserrat(
                                              fontSize: 14,
                                              color: Theme.of(
                                                context,
                                              ).textTheme.bodyMedium?.color,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.trending_up,
                                            size: 16,
                                            color: isProfitable
                                                ? Colors.green
                                                : Colors.orange,
                                          ),
                                          SizedBox(width: 4),
                                          Text(
                                            'Gain: ${report.totalGain.toStringAsFixed(2)} Birr',
                                            style: GoogleFonts.montserrat(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: isProfitable
                                                  ? Colors.green
                                                  : Colors.orange,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Spacer(),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            SizedBox(height: 8),
            Text(
              title,
              style: GoogleFonts.montserrat(
                fontSize: 12,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 4),
            Text(
              value,
              style: GoogleFonts.montserrat(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _showRenameDialog(BuildContext context, Report report) {
    final controller = TextEditingController(text: report.medicineName);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Rename Medicine',
          style: GoogleFonts.montserrat(fontWeight: FontWeight.w600),
        ),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: 'New Medicine Name',
            labelStyle: GoogleFonts.montserrat(),
            hintText: 'Enter new medicine name',
          ),
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel', style: GoogleFonts.montserrat()),
          ),
          TextButton(
            onPressed: () =>
                _renameMedicineFromReport(context, report, controller.text),
            child: Text(
              'Rename',
              style: GoogleFonts.montserrat(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _renameMedicineFromReport(
    BuildContext context,
    Report report,
    String newName,
  ) async {
    if (newName.trim().isEmpty) {
      Navigator.of(context).pop();
      return;
    }

    final provider = context.read<PharmacyProvider>();
    final medicines = provider.medicines;

    // Find the medicine with the current report's medicine name
    final medicineToUpdate = medicines.firstWhere(
      (medicine) => medicine.name == report.medicineName,
      orElse: () => Medicine(
        id: '',
        name: '',
        totalQty: 0,
        soldQty: 0,
        buyPrice: 0,
        sellPrice: 0,
      ),
    );

    if (medicineToUpdate.id.isNotEmpty) {
      // Update the medicine name
      medicineToUpdate.name = newName.trim();

      // Update the medicine (this will also update all reports with the new name)
      await provider.updateMedicine(medicineToUpdate);

      Navigator.of(context).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Medicine renamed successfully')));
    } else {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Medicine not found')));
    }
  }
}
