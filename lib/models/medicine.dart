import 'dart:typed_data';
import 'package:hive/hive.dart';

part 'medicine.g.dart';

@HiveType(typeId: 0)
class Medicine extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  int totalQty;

  @HiveField(3)
  int buyPrice;

  @HiveField(4)
  int sellPrice;

  @HiveField(5)
  Uint8List? imageBytes;

  @HiveField(6)
  int soldQty;

  @HiveField(7)
  String? category;

  @HiveField(8)
  String? barcode;
  @HiveField(9)
  String? imageUrl;

  @HiveField(10)
  String? cloudinaryPublicId;

  @HiveField(11)
  int? lastModifiedMillis;

  Medicine({
    required this.id,
    required this.name,
    required this.totalQty,
    required this.buyPrice,
    required this.sellPrice,
    this.imageBytes,
    this.soldQty = 0,
    this.category = 'Others',
    this.barcode,
  });

  int get remainingQty => totalQty - soldQty;
}
