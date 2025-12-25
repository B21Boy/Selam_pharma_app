import 'package:hive/hive.dart';

part 'report.g.dart';

@HiveType(typeId: 1)
class Report extends HiveObject {
  @HiveField(0)
  String medicineName;

  @HiveField(1)
  int soldQty;

  @HiveField(2)
  int sellPrice;

  @HiveField(3)
  int totalGain;

  @HiveField(4)
  DateTime dateTime;

  @HiveField(5)
  bool? isRead;

  Report({
    required this.medicineName,
    required this.soldQty,
    required this.sellPrice,
    required this.totalGain,
    required this.dateTime,
    this.isRead = false,
  });
}
