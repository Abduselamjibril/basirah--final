import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme_provider.dart';

class ContactInfoPage extends StatelessWidget {
  const ContactInfoPage({Key? key}) : super(key: key);

  // Helper to launch URLs for phone calls or emails
  Future<void> _launchUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      // You can add a snackbar here to show an error if launch fails
      print('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    // This primaryColor is for the AppBar and the top icon.
    final Color appBarColor =
        isDark ? const Color(0xFF1E1E1E) : const Color(0xFF009B77);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Contact For Help',
            style: TextStyle(color: Colors.white)),
        backgroundColor: appBarColor,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Icon(
                Icons.support_agent_rounded,
                size: 80,
                // Using the specific green color here as well for consistency
                color: const Color(0xFF009B77),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Password Reset Assistance',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'If you are unable to reset your password using your email, please contact our support team. We will help you reset your account password manually.',
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            _buildContactTile(
              context,
              icon: Icons.phone_rounded,
              title: 'Call Support',
              subtitle:
                  '+1 (234) 567-8901', // <-- REPLACE WITH YOUR PHONE NUMBER
              onTap: () => _launchUrl('tel:+12345678901'), // <-- REPLACE
            ),
            const SizedBox(height: 16),
            _buildContactTile(
              context,
              icon: Icons.email_rounded,
              title: 'Email Support',
              subtitle: 'support@basirah.com', // <-- REPLACE WITH YOUR EMAIL
              onTap: () =>
                  _launchUrl('mailto:support@basirah.com'), // <-- REPLACE
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactTile(BuildContext context,
      {required IconData icon,
      required String title,
      required String subtitle,
      required VoidCallback onTap}) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        onTap: onTap,
        // --- THIS IS THE CHANGE ---
        // The leading icon now uses your specific green color directly.
        leading: Icon(
          icon,
          color: const Color(0xFF009B77), // Set the icon color to your green
          size: 30,
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 16)),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
      ),
    );
  }
}
