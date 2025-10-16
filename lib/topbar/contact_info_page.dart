// lib/topbar/contact_info_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../theme_provider.dart'; // Adjust this import path if needed

// Data Model included directly in the file
class ContactInfo {
  final String phone;
  final String email;

  ContactInfo({required this.phone, required this.email});

  factory ContactInfo.fromJson(Map<String, dynamic> json) {
    return ContactInfo(
      phone: json['phone_number'] as String? ?? 'Not Available',
      email: json['email'] as String? ?? 'Not Available',
    );
  }
}

class ContactInfoPage extends StatefulWidget {
  const ContactInfoPage({Key? key}) : super(key: key);

  @override
  State<ContactInfoPage> createState() => _ContactInfoPageState();
}

class _ContactInfoPageState extends State<ContactInfoPage> {
  late Future<ContactInfo> _futureContactInfo;

  @override
  void initState() {
    super.initState();
    _futureContactInfo = _fetchContactInfo();
  }

  Future<ContactInfo> _fetchContactInfo() async {
    // IMPORTANT: Replace with your actual API URL
    const String apiUrl = 'https://admin.basirahtv.com/api/contact-information';

    try {
      final response = await http.get(Uri.parse(apiUrl));
      if (response.statusCode == 200) {
        return ContactInfo.fromJson(jsonDecode(response.body));
      } else {
        throw Exception(
            'Failed to load contact info (Status code: ${response.statusCode})');
      }
    } catch (e) {
      throw Exception('Failed to connect to the server: $e');
    }
  }

  Future<void> _launchUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open link: $url')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final Color appBarColor =
        isDark ? const Color(0xFF1E1E1E) : const Color(0xFF009B77);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Contact For Help',
            style: TextStyle(color: Colors.white)),
        backgroundColor: appBarColor,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: FutureBuilder<ContactInfo>(
        future: _futureContactInfo,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text('Error: ${snapshot.error}',
                    textAlign: TextAlign.center),
              ),
            );
          } else if (snapshot.hasData) {
            final contactInfo = snapshot.data!;
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(
                    child: Icon(
                      Icons.support_agent_rounded,
                      size: 80,
                      color: Color(0xFF009B77),
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
                    subtitle: contactInfo.phone,
                    onTap: () => _launchUrl(
                        'tel:${contactInfo.phone.replaceAll(RegExp(r'[^0-9+]'), '')}'),
                  ),
                  const SizedBox(height: 16),
                  _buildContactTile(
                    context,
                    icon: Icons.email_rounded,
                    title: 'Email Support',
                    subtitle: contactInfo.email,
                    onTap: () => _launchUrl('mailto:${contactInfo.email}'),
                  ),
                ],
              ),
            );
          } else {
            return const Center(child: Text("Contact information not found."));
          }
        },
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
        leading: Icon(
          icon,
          color: const Color(0xFF009B77),
          size: 30,
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 16)),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
      ),
    );
  }
}
