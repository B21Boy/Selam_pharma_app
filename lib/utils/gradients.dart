import 'package:flutter/material.dart';

class AppGradients {
  static const LinearGradient blueGreenGradient = LinearGradient(
    colors: [
      Color(0xFF007BFF), // Blue
      Color(0xFF28A745), // Green
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkBlueGreenGradient = LinearGradient(
    colors: [
      Color(0xFF0056CC), // Darker blue
      Color(0xFF1E7E34), // Darker green
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
