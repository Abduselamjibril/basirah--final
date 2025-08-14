import 'package:flutter/material.dart';

class ThemeProvider with ChangeNotifier {
  bool _isDarkMode = false; // Set default to day mode

  bool get isDarkMode => _isDarkMode;

  ThemeData get currentTheme {
    return _isDarkMode ? darkTheme : lightTheme;
  }

  ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: Color(0xFF1E1E2C), // Main color
      scaffoldBackgroundColor: Color(0xFF002147), // Oxford blue
      colorScheme: ColorScheme.dark(
        primary: Color(0xFF1E1E2C), // Main color
        secondary: Colors.white.withOpacity(0.15), // 15% white
      ),
    );
  }

  ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      primaryColor: Colors.white.withOpacity(0.85), // 85% white
      scaffoldBackgroundColor:
          Colors.white.withOpacity(0.85), // Background color
      colorScheme: ColorScheme.light(
        primary: Color(0xFF009B77).withOpacity(0.15), // 15% Caribbean green
        secondary: Color(0xFF009B77)
            .withOpacity(0.15), // Buttons or parts in 15% Caribbean green
      ),
    );
  }

  void toggleTheme() {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
  }
}
