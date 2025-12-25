import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/pharmacy_provider.dart';

class AnnouncementScreen extends StatelessWidget {
  const AnnouncementScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final pharmacyProvider = context.watch<PharmacyProvider>();
    final outOfStockMedicines = pharmacyProvider.getOutOfStockMedicines();

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.announcement, color: Colors.white),
            SizedBox(width: 8),
            Text('Out of Stock Alerts'),
          ],
        ),
        backgroundColor: Color(0xFFDC3545), // Red color for alerts
      ),
      body: outOfStockMedicines.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.check_circle,
                    size: 80,
                    color: Color(0xFF28A745), // Green for good status
                  ),
                  SizedBox(height: 16),
                  Text(
                    'All medicines are in stock!',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'No out-of-stock alerts at this time',
                    style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: EdgeInsets.all(16),
              itemCount: outOfStockMedicines.length,
              itemBuilder: (context, index) {
                final medicine = outOfStockMedicines[index];
                return Card(
                  margin: EdgeInsets.only(bottom: 12),
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Color(0xFFDC3545).withAlpha(77),
                        width: 2,
                      ),
                    ),
                    child: Row(
                      children: [
                        // Warning icon
                        Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Color(0xFFDC3545).withAlpha(25),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.warning,
                            color: Color(0xFFDC3545),
                            size: 24,
                          ),
                        ),
                        SizedBox(width: 16),
                        // Medicine details
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                medicine.name,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Out of Stock',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFFDC3545),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Buy Price: ${medicine.buyPrice} Birr | Sell Price: ${medicine.sellPrice} Birr',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Action button
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Color(0xFF007BFF),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            'Restock',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
