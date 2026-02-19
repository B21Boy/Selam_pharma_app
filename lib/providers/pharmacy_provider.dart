import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/medicine.dart';
import '../models/report.dart';
import '../services/ai_service.dart';

class PharmacyProvider extends ChangeNotifier {
  Box<Medicine>? _medicineBox;
  Box<Report>? _reportBox;
  StreamSubscription<User?>? _authSub;

  List<Medicine> _medicines = [];
  List<Report> _reports = [];
  bool _initialized = false;

  List<Medicine> get medicines => _medicines;
  List<Report> get reports => _reports;

  /// Initialize boxes and listen for auth changes to open per-user boxes.
  Future<void> initBoxes() async {
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) async {
      // Handle auth changes; run async but don't block the listener caller.
      _openBoxesForUid(user?.uid).catchError((e) {
        debugPrint('PharmacyProvider: open boxes on auth change failed: $e');
      });
    });

    // Open boxes for current user in background to avoid blocking UI creation.
    _openBoxesForUid(FirebaseAuth.instance.currentUser?.uid)
        .then((_) {
          _initialized = true;
          notifyListeners();
        })
        .catchError((e) {
          debugPrint('PharmacyProvider: open boxes failed: $e');
        });
  }

  Future<void> loadData() async {
    _medicines = _medicineBox?.values.toList() ?? [];
    _reports = _reportBox?.values.toList() ?? [];
    notifyListeners();
  }

  Future<void> addMedicine(Medicine medicine) async {
    await _medicineBox?.put(medicine.id, medicine);
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
    await _reportBox?.add(report);
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

  Future<void> _openBoxesForUid(String? uid) async {
    final medsName = uid == null ? 'medicines_guest' : 'medicines_$uid';
    final reportsName = uid == null ? 'reports_guest' : 'reports_$uid';

    try {
      // close existing boxes if different
      if (_medicineBox != null && _medicineBox!.isOpen) {
        await _medicineBox!.close();
      }
      if (_reportBox != null && _reportBox!.isOpen) {
        await _reportBox!.close();
      }
    } catch (e) {
      debugPrint('PharmacyProvider: error closing boxes: $e');
    }

    _medicineBox = await Hive.openBox<Medicine>(medsName);
    _reportBox = await Hive.openBox<Report>(reportsName);
    await loadData();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    try {
      _medicineBox?.close();
      _reportBox?.close();
    } catch (_) {}
    super.dispose();
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

  /// Build a safe prompt and get AI recommendation, validating results.
  Future<String> recommendFromSymptoms(String symptoms) async {
    if (!_initialized) await initBoxes();

    // Build a constrained prompt listing available medicines and safety rules.
    final medicineList = _medicines.map((m) => m.name).toList();
    final buffer = StringBuffer();
    buffer.writeln('You are a pharmacy assistant.');
    buffer.writeln('Available medicines: ${medicineList.join(", ")}');
    buffer.writeln('Rules:');
    buffer.writeln('- Recommend only from the Available medicines list.');
    buffer.writeln('- Do not diagnose conditions.');
    buffer.writeln('- Do not give child dosages.');
    buffer.writeln(
      '- If symptoms are severe (chest pain, difficulty breathing, fainting), advise to seek emergency care.',
    );
    buffer.writeln('User symptoms: $symptoms');

    final ai = AIService();
    final resp = await ai.getAIRecommendation(buffer.toString());

    final lower = resp.toLowerCase();
    // If AI advises seeing a doctor / emergency, allow that through.
    if (lower.contains('doctor') ||
        lower.contains('emergency') ||
        lower.contains('seek medical') ||
        lower.contains('call 911') ||
        lower.contains('urgent')) {
      return resp;
    }

    // Validate that at least one recommended medicine exists in Hive.
    final knownNames = _medicines.map((m) => m.name.toLowerCase()).toList();
    final mentionedKnown = knownNames
        .where((name) => lower.contains(name))
        .toList();

    if (mentionedKnown.isEmpty) {
      return 'I’m not confident recommending a medicine. Please consult a pharmacist or doctor.';
    }

    return resp;
  }
}
