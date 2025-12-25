import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'models/medicine.dart';
import 'models/report.dart';
import 'providers/pharmacy_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  Hive.registerAdapter(MedicineAdapter());
  Hive.registerAdapter(ReportAdapter());

  final settingsBox = await Hive.openBox('settings');

  runApp(MyApp(settingsBox: settingsBox));
}

class MyApp extends StatelessWidget {
  final Box settingsBox;

  const MyApp({super.key, required this.settingsBox});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => ThemeProvider(settingsBox)),
        ChangeNotifierProvider(
          create: (context) => PharmacyProvider()..initBoxes(),
        ),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'Pharmacy Manager',
            theme: ThemeData(
              primaryColor: Color(0xFF007BFF), // Medical blue
              colorScheme: ColorScheme.light(
                primary: Color(0xFF007BFF),
                secondary: Color(0xFF28A745), // Pharmacy green
                surface: Colors.white,
                onPrimary: Colors.white,
                onSecondary: Colors.white,
                onSurface: Colors.black87,
              ),
              scaffoldBackgroundColor: Color(0xFFF8F9FA),
              appBarTheme: AppBarThemeData(
                backgroundColor: Color(0xFF007BFF),
                foregroundColor: Colors.white,
                elevation: 4,
                centerTitle: true,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                ),
              ),
              cardTheme: CardThemeData(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                shadowColor: Colors.black12,
              ),
              inputDecorationTheme: InputDecorationTheme(
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Color(0xFFDEE2E6)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Color(0xFFDEE2E6)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Color(0xFF007BFF), width: 2),
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
              ),
              elevatedButtonTheme: ElevatedButtonThemeData(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF007BFF),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  elevation: 2,
                ),
              ),
              bottomNavigationBarTheme: BottomNavigationBarThemeData(
                backgroundColor: Colors.white,
                selectedItemColor: Color(0xFF007BFF),
                unselectedItemColor: Colors.grey,
                elevation: 8,
                type: BottomNavigationBarType.fixed,
              ),
            ),
            darkTheme: ThemeData.dark().copyWith(
              primaryColor: Color(0xFF007BFF),
              colorScheme: ColorScheme.dark(
                primary: Color(0xFF007BFF),
                secondary: Color(0xFF28A745),
                surface: Color(0xFF1E1E1E),
                onPrimary: Colors.white,
                onSecondary: Colors.white,
                onSurface: Colors.white70,
              ),
              scaffoldBackgroundColor: Color(0xFF121212),
              appBarTheme: AppBarThemeData(
                backgroundColor: Color(0xFF007BFF),
                foregroundColor: Colors.white,
                elevation: 4,
                centerTitle: true,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                ),
              ),
              cardTheme: CardThemeData(
                color: Color(0xFF2D2D2D),
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                shadowColor: Colors.black38,
              ),
              inputDecorationTheme: InputDecorationTheme(
                filled: true,
                fillColor: Color(0xFF2D2D2D),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Color(0xFF007BFF), width: 2),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[600]!, width: 1),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Color(0xFF007BFF), width: 2),
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
              ),
              elevatedButtonTheme: ElevatedButtonThemeData(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF007BFF),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  elevation: 2,
                ),
              ),
              bottomNavigationBarTheme: BottomNavigationBarThemeData(
                backgroundColor: Color(0xFF1E1E1E),
                selectedItemColor: Color(0xFF007BFF),
                unselectedItemColor: Colors.grey[400],
                elevation: 8,
                type: BottomNavigationBarType.fixed,
              ),
            ),
            themeMode: themeProvider.themeMode,
            home: HomeScreen(),
          );
        },
      ),
    );
  }
}
