// lib/topbar/about_page.dart

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

class AboutPage extends StatefulWidget {
  const AboutPage({Key? key}) : super(key: key);

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  late Future<AppContent> _futureContent;

  @override
  void initState() {
    super.initState();
    _futureContent = _fetchContent();
  }

  Future<AppContent> _fetchContent() async {
    // IMPORTANT: Replace with your actual API URL
    const String apiUrl = 'https://admin.basirahtv.com/api/about-us';

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
    final Color appBarColor =
        isDark ? const Color(0xFF1E1E1E) : const Color(0xFF009B77);
    final Color textColor = isDark ? Colors.white70 : Colors.black87;
    final Color headingColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      appBar: AppBar(
        title:
            const Text('About Basirah', style: TextStyle(color: Colors.white)),
        backgroundColor: appBarColor,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: FutureBuilder<AppContent>(
        future: _futureContent,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(
                child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text('Error: ${snapshot.error}',
                        textAlign: TextAlign.center)));
          } else if (snapshot.hasData) {
            final content = snapshot.data!;
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: RichText(
                textAlign: TextAlign.justify,
                text: TextSpan(
                  style:
                      TextStyle(color: textColor, fontSize: 16.0, height: 1.5),
                  children: [
                    TextSpan(
                      text: '${content.title}\n\n',
                      style: TextStyle(
                          fontSize: 22.0,
                          fontWeight: FontWeight.bold,
                          color: headingColor),
                    ),
                    TextSpan(text: content.content),
                  ],
                ),
              ),
            );
          } else {
            return const Center(child: Text('No content found.'));
          }
        },
      ),
    );
  }
}
