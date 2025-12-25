import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../models/medicine.dart';
import '../models/report.dart';

class PharmacyProvider extends ChangeNotifier {
  late Box<Medicine> _medicineBox;
  late Box<Report> _reportBox;

  List<Medicine> _medicines = [];
  List<Report> _reports = [];
  bool _initialized = false;

  List<Medicine> get medicines => _medicines;
  List<Report> get reports => _reports;

  Future<void> initBoxes() async {
    _medicineBox = await Hive.openBox<Medicine>('medicines');
    _reportBox = await Hive.openBox<Report>('reports');
    await loadData();
    _initialized = true;
  }

  Future<void> loadData() async {
    _medicines = _medicineBox.values.toList();
    _reports = _reportBox.values.toList();
    notifyListeners();
  }

  Future<void> addMedicine(Medicine medicine) async {
    await _medicineBox.put(medicine.id, medicine);
    await loadData();
  }

  Future<void> updateMedicine(Medicine medicine) async {
    final oldMedicine = _medicines.firstWhere((m) => m.id == medicine.id);
    if (oldMedicine.name != medicine.name) {
      // Update medicine name in all reports
      for (final report in _reports) {
        if (report.medicineName == oldMedicine.name) {
          report.medicineName = medicine.name;
          await report.save();
        }
      }
    }
    await medicine.save();
    await loadData();
  }

  Future<void> deleteMedicine(Medicine medicine) async {
    // Delete all reports for this medicine
    final reportsToDelete = _reports
        .where((report) => report.medicineName == medicine.name)
        .toList();
    for (final report in reportsToDelete) {
      await report.delete();
    }

    await medicine.delete();
    await loadData();
  }

  Future<void> addReport(Report report) async {
    if (!_initialized) {
      await initBoxes();
    }
    await _reportBox.add(report);
    await loadData();
  }

  Future<void> clearNewReportsNotification() async {
    for (final report in _reports) {
      if (!(report.isRead ?? false)) {
        report.isRead = true;
        await report.save();
      }
    }
    await loadData();
  }

  Future<void> removeReport(Report report) async {
    await report.delete();
    await loadData();
  }

  List<Medicine> getOutOfStockMedicines() {
    return _medicines.where((medicine) => medicine.remainingQty == 0).toList();
  }

  int get outOfStockCount =>
      _medicines.where((medicine) => medicine.remainingQty == 0).length;

  int get newReportsCount => _reports.where((r) => !(r.isRead ?? false)).length;

  List<Medicine> searchMedicines(String query) {
    if (query.isEmpty) return _medicines;
    return _medicines
        .where(
          (medicine) =>
              medicine.name.toLowerCase().contains(query.toLowerCase()),
        )
        .toList();
  }

  Medicine? findMedicineByBarcode(String barcode) {
    try {
      return _medicines.firstWhere((medicine) => medicine.barcode == barcode);
    } catch (e) {
      return null;
    }
  }
}
