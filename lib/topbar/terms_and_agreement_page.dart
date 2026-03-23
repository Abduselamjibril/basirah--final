// lib/topbar/terms_and_agreement_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../theme_provider.dart'; // Adjust this import path if needed

// Data Model included directly in the file
class AppContent {
  final String title;
  final String content;

  AppContent({required this.title, required this.content});

  factory AppContent.fromJson(Map<String, dynamic> json) {
    return AppContent(
      title: json['title'] as String? ?? 'Loading...',
      content: json['content'] as String? ?? 'Content not available.',
    );
  }
}

class TermsAndAgreementPage extends StatefulWidget {
  const TermsAndAgreementPage({super.key});

  @override
  State<TermsAndAgreementPage> createState() => _TermsAndAgreementPageState();
}

class _TermsAndAgreementPageState extends State<TermsAndAgreementPage> {
  late Future<AppContent> _futureContent;

  @override
  void initState() {
    super.initState();
    _futureContent = _fetchContent();
  }

  Future<AppContent> _fetchContent() async {
    // IMPORTANT: Replace with your actual API URL
    const String apiUrl = 'https://admin.basirahtv.com/api/terms-and-agreement';

    try {
      final response = await http.get(Uri.parse(apiUrl));
      if (response.statusCode == 200) {
        return AppContent.fromJson(jsonDecode(response.body));
      } else {
        throw Exception(
            'Failed to load content (Status code: ${response.statusCode})');
      }
    } catch (e) {
      throw Exception('Failed to connect to the server: $e');
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
          FutureBuilder<AppContent>(
            future: _futureContent,
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
                      left: 28.0, right: 28.0, top: topPadding + 56,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.error_outline_rounded,
                            size: 48, color: Colors.redAccent.shade200),
                        const SizedBox(height: 16),
                        Text(
                          'Unable to load content.\nPlease try again later.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 15, color: subtitleColor),
                        ),
                      ],
                    ),
                  ),
                );
              } else if (snapshot.hasData) {
                final content = snapshot.data!;
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
                              color: accentGreen.withOpacity(isDark ? 0.15 : 0.12),
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
                      Align(
                        alignment: Alignment.center,
                        child: Text(content.title,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: headingColor,
                                letterSpacing: -0.5)),
                      ),
                      const SizedBox(height: 28),

                      // ── Content Card ──
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
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
                        child: RichText(
                          textAlign: TextAlign.justify,
                          text: TextSpan(
                            style: TextStyle(
                                color: subtitleColor,
                                fontSize: 16.0,
                                height: 1.6),
                            children: [
                              TextSpan(text: content.content),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              } else {
                return Center(
                  child: Text('No content found.',
                      style: TextStyle(color: subtitleColor)),
                );
              }
            },
          ),

          // ── Floating back button ──
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
}
