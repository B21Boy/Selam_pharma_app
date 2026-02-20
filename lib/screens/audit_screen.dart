import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../providers/pharmacy_provider.dart';
import '../models/report.dart';
import '../models/medicine.dart';
import '../widgets/custom_bottom_nav_bar.dart';
import 'register_medicine_dialog.dart';
import 'chat_screen.dart';
import 'report_screen.dart';
import 'home_screen.dart';
import '../utils/ui_helpers.dart';

class AuditScreen extends StatefulWidget {
  const AuditScreen({super.key});

  @override
  State<AuditScreen> createState() => _AuditScreenState();
}

class _AuditScreenState extends State<AuditScreen> {
  int _selectedPeriodIndex = 0;
  int _selectedNavIndex = 3;
  final List<String> _timePeriods = [
    'Today',
    'This Week',
    'This Month',
    'This Year',
  ];

  List<Report> _filterReportsByPeriod(List<Report> reports, String period) {
    final now = DateTime.now();
    DateTime startDate;

    switch (period) {
      case 'Today':
        startDate = DateTime(now.year, now.month, now.day);
        break;
      case 'This Week':
        startDate = now.subtract(Duration(days: now.weekday % 7));
        startDate = DateTime(startDate.year, startDate.month, startDate.day);
        break;
      case 'This Month':
        startDate = DateTime(now.year, now.month, 1);
        break;
      case 'This Year':
        startDate = DateTime(now.year, 1, 1);
        break;
      default:
        startDate = DateTime(now.year, now.month, now.day);
    }

    return reports
        .where(
          (report) => report.dateTime.isAfter(
            startDate.subtract(const Duration(seconds: 1)),
          ),
        )
        .toList();
  }

  Map<String, dynamic> _calculateSummary(
    List<Report> reports,
    List<Medicine> medicines,
  ) {
    double totalRevenue = 0;
    int totalItems = 0;
    Map<String, int> medicineCount = {};

    for (final report in reports) {
      totalRevenue += report.totalGain;
      totalItems += report.soldQty;
      medicineCount[report.medicineName] =
          (medicineCount[report.medicineName] ?? 0) + report.soldQty;
    }

    final topMedicine = medicineCount.entries.isNotEmpty
        ? medicineCount.entries.reduce((a, b) => a.value > b.value ? a : b).key
        : 'None';

    // Calculate total profit as sum of real profits from each medicine
    double totalProfit = 0;
    for (final medicine in medicines) {
      final medicineReports = reports
          .where((r) => r.medicineName == medicine.name)
          .toList();
      final soldQty = medicineReports.fold<int>(0, (sum, r) => sum + r.soldQty);
      final revenue = medicineReports.fold<double>(
        0,
        (sum, r) => sum + r.totalGain,
      );
      final cost = soldQty * medicine.buyPrice;
      final realProfit = revenue - cost;
      totalProfit += realProfit;
    }

    return {
      'totalRevenue': totalRevenue,
      'totalItems': totalItems,
      'uniqueMedicines': medicineCount.length,
      'topMedicine': topMedicine,
      'medicineCount': medicineCount,
      'totalProfit': totalProfit,
    };
  }

  Future<void> _exportData(List<Report> reports, String period) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final fileName =
          'audit_${period.replaceAll(' ', '_').toLowerCase()}_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv';
      final file = File('${directory.path}/$fileName');

      final csvData = StringBuffer();
      csvData.writeln('Date,Medicine,Quantity,Total Gain');

      for (final report in reports) {
        csvData.writeln(
          '${DateFormat('yyyy-MM-dd HH:mm').format(report.dateTime)},${report.medicineName},${report.soldQty},${report.totalGain}',
        );
      }

      await file.writeAsString(csvData.toString());

      if (mounted) {
        showAppSnackBar(context, 'Data exported to ${file.path}');
      }
    } catch (e) {
      if (mounted) {
        showAppSnackBar(context, 'Failed to export data', error: true);
      }
    }
  }

  Widget _buildPeriodContent(String period) {
    final pharmacyProvider = Provider.of<PharmacyProvider>(context);
    final allReports = pharmacyProvider.reports;
    final filteredReports = _filterReportsByPeriod(allReports, period);
    final summary = _calculateSummary(
      filteredReports,
      pharmacyProvider.medicines,
    );

    return filteredReports.isEmpty
        ? Center(
            child: Text(
              'No reports available for $period.',
              style: GoogleFonts.montserrat(fontSize: 16),
            ),
          )
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Summary Cards
                Row(
                  children: [
                    Expanded(
                      child: _buildSummaryCard(
                        'Total Revenue',
                        '${summary['totalRevenue'].toStringAsFixed(2)} Birr',
                        Icons.attach_money,
                        Colors.green,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildSummaryCard(
                        'Items Sold',
                        '${summary['totalItems']}',
                        Icons.inventory,
                        Colors.blue,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildSummaryCard(
                        'Unique Medicines',
                        '${summary['uniqueMedicines']}',
                        Icons.medical_services,
                        Colors.orange,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildSummaryCard(
                        'Top Medicine',
                        summary['topMedicine'],
                        Icons.star,
                        Colors.purple,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildSummaryCard(
                        'Total Profit',
                        '${summary['totalProfit'].toStringAsFixed(2)} Birr',
                        Icons.account_balance_wallet,
                        Colors.teal,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Export Button
                ElevatedButton.icon(
                  onPressed: () => _exportData(filteredReports, period),
                  icon: const Icon(Icons.download),
                  label: Text(
                    'Export $period Data',
                    style: GoogleFonts.montserrat(),
                  ),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                  ),
                ),
                const SizedBox(height: 16),

                // Chart Section
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.bar_chart,
                              color: const Color(0xFF007BFF),
                              size: 24,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Sales by Medicine',
                              style: GoogleFonts.montserrat(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF007BFF),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 250,
                          child: BarChart(
                            BarChartData(
                              alignment: BarChartAlignment.spaceAround,
                              maxY:
                                  (summary['medicineCount'] as Map<String, int>)
                                      .values
                                      .isNotEmpty
                                  ? (summary['medicineCount']
                                                as Map<String, int>)
                                            .values
                                            .cast<int>()
                                            .reduce((a, b) => a > b ? a : b)
                                            .toDouble() *
                                        1.2
                                  : 10,
                              barGroups:
                                  (summary['medicineCount'] as Map<String, int>)
                                      .entries
                                      .map((entry) {
                                        final index =
                                            (summary['medicineCount']
                                                    as Map<String, int>)
                                                .keys
                                                .toList()
                                                .indexOf(entry.key);
                                        return BarChartGroupData(
                                          x: index,
                                          barRods: [
                                            BarChartRodData(
                                              toY: entry.value.toDouble(),
                                              color: const Color(0xFF007BFF),
                                              width: 20,
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                              backDrawRodData:
                                                  BackgroundBarChartRodData(
                                                    show: true,
                                                    toY:
                                                        (summary['medicineCount']
                                                                as Map<
                                                                  String,
                                                                  int
                                                                >)
                                                            .values
                                                            .cast<int>()
                                                            .reduce(
                                                              (a, b) =>
                                                                  a > b ? a : b,
                                                            )
                                                            .toDouble() *
                                                        1.2,
                                                    color: Colors.grey[200],
                                                  ),
                                            ),
                                          ],
                                        );
                                      })
                                      .toList(),
                              titlesData: FlTitlesData(
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    getTitlesWidget: (value, meta) {
                                      final index = value.toInt();
                                      if (index >= 0 &&
                                          index <
                                              (summary['medicineCount']
                                                      as Map<String, int>)
                                                  .keys
                                                  .length) {
                                        final medicine =
                                            (summary['medicineCount']
                                                    as Map<String, int>)
                                                .keys
                                                .elementAt(index);
                                        return Padding(
                                          padding: const EdgeInsets.only(
                                            top: 8.0,
                                          ),
                                          child: Text(
                                            medicine.length > 8
                                                ? '${medicine.substring(0, 8)}...'
                                                : medicine,
                                            style: GoogleFonts.montserrat(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w500,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        );
                                      }
                                      return const Text('');
                                    },
                                    reservedSize: 40,
                                  ),
                                ),
                                leftTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    getTitlesWidget: (value, meta) {
                                      return Text(
                                        value.toInt().toString(),
                                        style: GoogleFonts.montserrat(
                                          fontSize: 10,
                                          color: Colors.grey[600],
                                        ),
                                      );
                                    },
                                    reservedSize: 30,
                                  ),
                                ),
                                topTitles: AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                                rightTitles: AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                              ),
                              gridData: FlGridData(
                                show: true,
                                drawVerticalLine: false,
                                horizontalInterval: 5,
                                getDrawingHorizontalLine: (value) {
                                  return FlLine(
                                    color: Colors.grey[300],
                                    strokeWidth: 1,
                                    dashArray: [5, 5],
                                  );
                                },
                              ),
                              borderData: FlBorderData(show: false),
                              barTouchData: BarTouchData(
                                enabled: true,
                                touchTooltipData: BarTouchTooltipData(
                                  getTooltipItem:
                                      (group, groupIndex, rod, rodIndex) {
                                        final medicine =
                                            (summary['medicineCount']
                                                    as Map<String, int>)
                                                .keys
                                                .elementAt(group.x.toInt());
                                        return BarTooltipItem(
                                          '$medicine\n${rod.toY.toInt()} units',
                                          GoogleFonts.montserrat(
                                            color: Colors.black,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        );
                                      },
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Collapsible Details Section
                ExpansionTile(
                  title: Row(
                    children: [
                      Icon(Icons.expand_more, color: const Color(0xFF007BFF)),
                      const SizedBox(width: 8),
                      Text(
                        'Detailed Reports',
                        style: GoogleFonts.montserrat(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF007BFF),
                        ),
                      ),
                    ],
                  ),
                  children: [
                    // Group reports by date
                    ..._groupReportsByDate(filteredReports).entries.map((
                      entry,
                    ) {
                      final date = entry.key;
                      final dayReports = entry.value;
                      final medicines = pharmacyProvider.medicines;
                      final daySummary = _calculateSummary(
                        dayReports,
                        medicines,
                      );

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8.0),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    DateFormat(
                                      'EEEE, yyyy-MM-dd',
                                    ).format(DateTime.parse(date)),
                                    style: GoogleFonts.montserrat(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(
                                        0xFF007BFF,
                                      ).withAlpha(25),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '${daySummary['totalItems']} items',
                                      style: GoogleFonts.montserrat(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF007BFF),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              LinearProgressIndicator(
                                value: summary['totalRevenue'] > 0
                                    ? daySummary['totalRevenue'] /
                                          summary['totalRevenue']
                                    : 0,
                                backgroundColor: Colors.grey[300],
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.green,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${daySummary['totalRevenue'].toStringAsFixed(2)} Birr',
                                style: GoogleFonts.montserrat(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.green,
                                ),
                              ),
                              const SizedBox(height: 12),
                              ...(daySummary['medicineCount']
                                      as Map<String, int>)
                                  .entries
                                  .map((medicineEntry) {
                                    return Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 4.0,
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              medicineEntry.key,
                                              style: GoogleFonts.montserrat(
                                                fontSize: 14,
                                              ),
                                            ),
                                          ),
                                          Text(
                                            '${medicineEntry.value} units',
                                            style: GoogleFonts.montserrat(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ],
            ),
          );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          'Audit',
          style: GoogleFonts.montserrat(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).appBarTheme.titleTextStyle?.color,
          ),
        ),
      ),
      body: Column(
        children: [
          // Time Period buttons (styled like home screen categories)
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
          // Content area
          Expanded(
            child: _buildPeriodContent(_timePeriods[_selectedPeriodIndex]),
          ),
        ],
      ),
      // register button is rendered inline inside CustomBottomNavBar
      bottomNavigationBar: CustomBottomNavBar(
        pharmacyProvider: context.watch<PharmacyProvider>(),
        selectedIndex: _selectedNavIndex,
        onSelect: (i) => setState(() => _selectedNavIndex = i),
        onHome: () {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const HomeScreen()),
          );
        },
        onRegister: () {
          showModalBottomSheet<String>(
            context: context,
            isScrollControlled: true,
            builder: (context) => RegisterMedicineDialog(),
          );
        },
        onChat: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ChatScreen()),
          );
        },
        onReports: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ReportScreen()),
          );
        },
        onAudit: () {},
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
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              title,
              style: GoogleFonts.montserrat(
                fontSize: 12,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: GoogleFonts.montserrat(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: color,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Map<String, List<Report>> _groupReportsByDate(List<Report> reports) {
    final groupedReports = <String, List<Report>>{};
    for (final report in reports) {
      final dateKey = DateFormat('yyyy-MM-dd').format(report.dateTime);
      groupedReports.putIfAbsent(dateKey, () => []).add(report);
    }
    return groupedReports;
  }
}
