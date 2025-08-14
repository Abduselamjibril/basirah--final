// lib/pages/about_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme_provider.dart'; // Adjust import path as needed
// Optional: For getting app version automatically
// import 'package:package_info_plus/package_info_plus.dart';

class AboutPage extends StatelessWidget {
  // Can be StatelessWidget if version is static
  const AboutPage({Key? key}) : super(key: key);

  // --- Content ---
  // Replace with your actual 'About Us' text
  final String missionStatement =
      "Basirah Institute for Quranic Studies is committed to fostering a deeper understanding and connection with the Quran through authentic, accessible, and engaging educational resources. We aim to empower individuals with knowledge that illuminates the heart and guides daily life.";
  final String whatWeOffer =
      "We offer a variety of programs including insightful lectures, structured courses, interactive sessions, and a supportive community environment, all centered around the teachings of the Quran and Sunnah. Our app provides convenient access to these resources anytime, anywhere.";

  // Example: Static version, replace with dynamic if needed
  final String appVersion = "1.0.0";

  // --- Dynamic Version Fetching (Optional) ---
  // Future<String> _getAppVersion() async {
  //   try {
  //     PackageInfo packageInfo = await PackageInfo.fromPlatform();
  //     return packageInfo.version;
  //   } catch (e) {
  //     print("Error getting package info: $e");
  //     return "N/A"; // Fallback version
  //   }
  // }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isNightMode = themeProvider.isDarkMode;

    final Color textColor = isNightMode ? Colors.white : Colors.black87;
    final Color headingColor =
        isNightMode ? Colors.white : Color(0xFF005A4A); // Darker Green/White
    final Color subTextColor = isNightMode ? Colors.grey[400]! : Colors.black54;
    final Color appBarColor =
        isNightMode ? Color(0xFF002147) : Color(0xFF009B77);

    return Scaffold(
      appBar: AppBar(
        title: const Text('About Basirah'),
        backgroundColor: appBarColor,
        foregroundColor: Colors.white, // Title and back button color
        elevation: 1,
      ),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Logo
            Image.asset(
              'assets/images/logo.png', // Ensure this path is correct
              height: 130,
              width: 130,
            ),
            const SizedBox(height: 16),

            // Institute Name
            Text(
              'Basirah Institute',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: headingColor,
              ),
              textAlign: TextAlign.center,
            ),
            Text(
              'for Quranic Studies',
              style: TextStyle(
                fontSize: 18,
                color: subTextColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),

            // Divider
            Divider(
              color: isNightMode ? Colors.grey[700] : Colors.grey[300],
              thickness: 1,
              indent: 20,
              endIndent: 20,
            ),
            const SizedBox(height: 30),

            // Mission Section
            _buildSectionTitle('Our Mission', headingColor),
            const SizedBox(height: 10),
            Text(
              missionStatement,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: textColor,
                height: 1.5, // Line spacing
              ),
            ),
            const SizedBox(height: 30),

            // What We Offer Section
            _buildSectionTitle('What We Offer', headingColor),
            const SizedBox(height: 10),
            Text(
              whatWeOffer,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: textColor,
                height: 1.5, // Line spacing
              ),
            ),
            const SizedBox(height: 40),

            // App Version (Optional)
            Text(
              'App Version: $appVersion',
              style: TextStyle(
                fontSize: 14,
                color: subTextColor,
              ),
            ),
            // --- OR Use FutureBuilder for dynamic version ---
            // FutureBuilder<String>(
            //   future: _getAppVersion(),
            //   builder: (context, snapshot) {
            //     final version = snapshot.hasData ? snapshot.data : 'Loading...';
            //     return Text(
            //       'App Version: $version',
            //       style: TextStyle(
            //         fontSize: 14,
            //         color: subTextColor,
            //       ),
            //     );
            //   },
            // ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // Helper widget for section titles
  Widget _buildSectionTitle(String title, Color color) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: color,
      ),
      textAlign: TextAlign.center,
    );
  }
}
