import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme_provider.dart'; // Import your theme provider

class AccountPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isNightMode = themeProvider.isDarkMode;

    // Define Theme-Specific Colors
    final Color primaryColor = const Color(0xFF009B77);
    final Color scaffoldBgColor = isNightMode
        ? const Color(0xFF1E1E1E)
        : Colors.grey[100]!; // Consistent dark/light background
    final Color appBarColor = isNightMode
        ? const Color(0xFF1F1F1F)
        : primaryColor; // Darker grey / Primary
    final Color iconColor = isNightMode
        ? primaryColor
        : Colors.black87; // Primary green in night, dark in day
    final Color titleTextColor = isNightMode ? Colors.white : Colors.black87;
    final Color buttonBgColor = primaryColor;
    final Color buttonFgColor = Colors.white;
    final Color textButtonColor = primaryColor;

    return Scaffold(
      backgroundColor: scaffoldBgColor, // Applied
      appBar: AppBar(
        title: Text('Account',
            style: TextStyle(color: Colors.white)), // Standard white title
        backgroundColor: appBarColor, // Applied
        elevation: 1, // Subtle elevation
        // Removed explicit background color for body container, Scaffold handles it
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.account_circle_outlined, // Use outlined version
              size: 100,
              color: iconColor, // Applied
            ),
            const SizedBox(height: 20),
            Text(
              'Welcome to your account!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w500, // Slightly less bold
                color: titleTextColor, // Applied
              ),
            ),
            const SizedBox(height: 32.0), // Increased spacing
            ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, '/login');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: buttonBgColor, // Applied
                foregroundColor: buttonFgColor, // Applied
                padding: const EdgeInsets.symmetric(
                    vertical: 14, horizontal: 32), // Adjusted padding
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30), // Keep rounded
                ),
                elevation: 2,
              ),
              child: const Text(
                'Login',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 12.0), // Increased spacing
            TextButton(
              onPressed: () {
                Navigator.pushNamed(context, '/signup');
              },
              child: Text(
                'Sign Up',
                style: TextStyle(
                  color: textButtonColor, // Applied
                  fontSize: 16, // Slightly larger text button
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
