import 'package:flutter/material.dart';
import 'package:flutter_driver/driver_extension.dart';
import 'package:hive_flutter/hive_flutter.dart';
//
import 'package:shmed/main.dart' as app;
import 'package:shmed/models/medicine.dart';
import 'package:shmed/models/report.dart';

void main() async {
  enableFlutterDriverExtension();
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  Hive.registerAdapter(MedicineAdapter());
  Hive.registerAdapter(ReportAdapter());

  final settingsBox = await Hive.openBox('settings');

  runApp(app.MyApp(settingsBox: settingsBox));
}
