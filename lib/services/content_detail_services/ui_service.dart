import 'package:flutter/material.dart';

// REFINED SOLUTION: STEP 2A
// Import main.dart to get access to our global keys and providers
import '../../main.dart';

class UIService {
  void showSuccessSnackbar(String message) {
    // REFINED SOLUTION: STEP 2B
    // Now we can safely check the theme from the global instance
    final isNightMode = themeProvider.isDarkMode;

    rootScaffoldMessengerKey.currentState?.removeCurrentSnackBar();
    rootScaffoldMessengerKey.currentState?.showSnackBar(SnackBar(
      content: Text(message),
      // The theme-based color now works correctly
      backgroundColor: isNightMode ? Colors.grey[700] : const Color(0xFF009B77),
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.only(left: 24.0, right: 24.0, bottom: 20.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      duration: const Duration(seconds: 2),
    ));
  }

  void showErrorSnackbar(String message) {
    rootScaffoldMessengerKey.currentState?.removeCurrentSnackBar();
    rootScaffoldMessengerKey.currentState?.showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: Colors.redAccent.shade700,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.only(left: 24.0, right: 24.0, bottom: 20.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      duration: const Duration(seconds: 3),
    ));
  }
}
