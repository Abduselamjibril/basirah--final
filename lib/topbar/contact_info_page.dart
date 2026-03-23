// lib/topbar/contact_info_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../theme_provider.dart';

// Data Model
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
          SnackBar(
            content: Text('Could not open link: $url'),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.fromLTRB(24.0, 0.0, 24.0, 20.0),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final topPadding = MediaQuery.of(context).padding.top;

    // ── Unified colour palette (synced with Login / Signup / Forgot) ──
    const Color accentGreen = Color(0xFF009B77);
    final Color scaffoldBg =
        isDark ? const Color(0xFF0D1B2A) : const Color(0xFFF7F8FA);
    final Color cardBg = isDark ? const Color(0xFF1B2838) : Colors.white;
    final Color headingColor = isDark ? Colors.white : const Color(0xFF1A1A2E);
    final Color subtitleColor =
        isDark ? Colors.grey.shade400 : Colors.grey.shade600;
    final Color linkColor = isDark ? const Color(0xFF4DD0B5) : accentGreen;
    final Color backBtnBg = isDark
        ? Colors.white.withOpacity(0.1)
        : Colors.black.withOpacity(0.05);
    final Color backBtnIcon = isDark ? Colors.white : const Color(0xFF1A1A2E);

    return Scaffold(
      backgroundColor: scaffoldBg,
      body: Stack(
        children: [
          // ── Main content ──
          FutureBuilder<ContactInfo>(
            future: _futureContactInfo,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(
                  child: CircularProgressIndicator(
                    color: linkColor,
                  ),
                );
              } else if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: EdgeInsets.only(
                      left: 28.0,
                      right: 28.0,
                      top: topPadding + 56,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.error_outline_rounded,
                            size: 48, color: Colors.redAccent.shade200),
                        const SizedBox(height: 16),
                        Text(
                          'Unable to load contact info.\nPlease try again later.',
                          textAlign: TextAlign.center,
                          style:
                              TextStyle(fontSize: 15, color: subtitleColor),
                        ),
                      ],
                    ),
                  ),
                );
              } else if (snapshot.hasData) {
                final contactInfo = snapshot.data!;
                return SingleChildScrollView(
                  padding: EdgeInsets.only(
                    left: 28.0,
                    right: 28.0,
                    top: topPadding + 56,
                    bottom: 32,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 12),

                      // ── Logo (synced: 160x160) ──
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: accentGreen
                                  .withOpacity(isDark ? 0.15 : 0.12),
                              blurRadius: 40,
                              spreadRadius: 12,
                            ),
                          ],
                        ),
                        child: Image.asset(
                          isDark
                              ? 'assets/images/logo3.png'
                              : 'assets/images/logo.png',
                          width: 160,
                          height: 160,
                        ),
                      ),
                      const SizedBox(height: 32),

                      // ── Heading ──
                      Text('Password Reset Assistance',
                          style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: headingColor,
                              letterSpacing: -0.5),
                          textAlign: TextAlign.center),
                      const SizedBox(height: 10),
                      Text(
                        'If you are unable to reset your password using email, please contact our support team. We will help you reset your account.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 14,
                            color: subtitleColor,
                            height: 1.5),
                      ),
                      const SizedBox(height: 32),

                      // ── Contact Cards ──
                      _buildContactCard(
                        icon: Icons.phone_rounded,
                        title: 'Call Support',
                        subtitle: contactInfo.phone,
                        onTap: () => _launchUrl(
                            'tel:${contactInfo.phone.replaceAll(RegExp(r'[^0-9+]'), '')}'),
                        cardBg: cardBg,
                        isDark: isDark,
                        accentColor: linkColor,
                        headingColor: headingColor,
                        subtitleColor: subtitleColor,
                      ),
                      const SizedBox(height: 14),
                      _buildContactCard(
                        icon: Icons.email_rounded,
                        title: 'Email Support',
                        subtitle: contactInfo.email,
                        onTap: () =>
                            _launchUrl('mailto:${contactInfo.email}'),
                        cardBg: cardBg,
                        isDark: isDark,
                        accentColor: linkColor,
                        headingColor: headingColor,
                        subtitleColor: subtitleColor,
                      ),
                    ],
                  ),
                );
              } else {
                return Center(
                  child: Text("Contact information not found.",
                      style: TextStyle(color: subtitleColor)),
                );
              }
            },
          ),

          // ── Floating back button (synced) ──
          Positioned(
            top: topPadding + 10,
            left: 16,
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: backBtnBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.arrow_back_ios_new_rounded,
                    size: 18, color: backBtnIcon),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required Color cardBg,
    required bool isDark,
    required Color accentColor,
    required Color headingColor,
    required Color subtitleColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.25 : 0.06),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: accentColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: headingColor)),
                  const SizedBox(height: 4),
                  Text(subtitle,
                      style: TextStyle(
                          fontSize: 14, color: subtitleColor)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded,
                size: 16, color: subtitleColor),
          ],
        ),
      ),
    );
  }
}
