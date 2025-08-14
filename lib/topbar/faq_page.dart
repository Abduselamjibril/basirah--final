import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'dart:convert';
import '../theme_provider.dart'; // Import your theme provider
import 'dart:async'; // Import for TimeoutException

class FaqPage extends StatefulWidget {
  FaqPage({Key? key}) : super(key: key);

  @override
  _FaqPageState createState() => _FaqPageState();

  refreshData() {}

  // This method doesn't seem used externally, consider removing if not needed
  // refreshData() {}
}

class _FaqPageState extends State<FaqPage> {
  List faqs = [];
  bool isLoading = true;
  String? errorLoading; // To store error message

  // Ensure this URL is correct and accessible
  final String _apiBaseUrl = "https://admin.basirahtv.com";

  @override
  void initState() {
    super.initState();
    fetchFAQs(); // Initial fetch
  }

  // Fetch FAQs from the backend
  Future<void> fetchFAQs() async {
    if (mounted) {
      setState(() {
        isLoading = true;
        errorLoading = null; // Clear previous error on refresh
      });
    }

    try {
      final response = await http
          .get(Uri.parse('$_apiBaseUrl/api/faqs'))
          .timeout(const Duration(seconds: 15)); // Add timeout

      if (!mounted) return; // Check after await

      if (response.statusCode == 200) {
        setState(() {
          faqs = json.decode(response.body);
          isLoading = false;
        });
      } else {
        print("Error fetching FAQs: ${response.statusCode}");
        setState(() {
          errorLoading = "Failed to load FAQs (Code: ${response.statusCode}).";
          isLoading = false;
          faqs = []; // Clear data on error
        });
      }
    } on TimeoutException catch (_) {
      print("Error fetching FAQs: Timeout");
      if (mounted) {
        setState(() {
          errorLoading = "Request timed out. Please try again.";
          isLoading = false;
          faqs = [];
        });
      }
    } on http.ClientException catch (e) {
      print("Error fetching FAQs: ClientException $e");
      if (mounted) {
        setState(() {
          errorLoading = "Network error. Please check connection.";
          isLoading = false;
          faqs = [];
        });
      }
    } catch (e) {
      print("Network error fetching FAQs: $e");
      if (mounted) {
        setState(() {
          errorLoading = "An unexpected error occurred.";
          isLoading = false;
          faqs = [];
        });
      }
    }
  }

  // Renamed for clarity to match RefreshIndicator's onRefresh
  Future<void> _handleRefresh() async {
    await fetchFAQs();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isNightMode = themeProvider.isDarkMode;

    // Define Theme-Specific Colors
    final Color primaryColor = const Color(0xFF009B77);
    final Color scaffoldBgColor =
        isNightMode ? const Color(0xFF002147) : Colors.grey[100]!;
    final Color cardBgColor =
        isNightMode ? const Color(0xFF1E1E1E) : Colors.white;
    final Color questionColor = isNightMode
        ? Colors.white
        : const Color(0xFF002147); // White / Oxford Blue
    final Color answerColor = isNightMode ? Colors.white70 : Colors.black54;
    final Color loadingIndicatorColor = primaryColor;
    final Color errorTextColor =
        isNightMode ? Colors.white70 : Colors.grey[700]!;
    final Color errorIconColor = Colors.redAccent;
    final Color retryButtonBgColor = primaryColor;
    final Color retryButtonFgColor = Colors.white;
    final Color refreshIndicatorBg = cardBgColor; // Match card

    return Scaffold(
      backgroundColor: scaffoldBgColor, // Applied
      appBar: AppBar(
        // Added AppBar for context
        title: const Text('FAQs', style: TextStyle(color: Colors.white)),
        backgroundColor: isNightMode ? const Color(0xFF1F1F1F) : primaryColor,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: RefreshIndicator(
        onRefresh: _handleRefresh, // Use the renamed refresh handler
        color: loadingIndicatorColor, // Applied
        backgroundColor: refreshIndicatorBg, // Applied
        child: isLoading
            ? Center(
                child: CircularProgressIndicator(
                    color: loadingIndicatorColor)) // Applied
            : errorLoading != null
                ? _buildErrorState(
                    errorLoading!,
                    isNightMode,
                    errorTextColor,
                    errorIconColor,
                    retryButtonBgColor,
                    retryButtonFgColor) // Show error view
                : faqs.isEmpty
                    ? _buildEmptyState(isNightMode, questionColor,
                        answerColor) // Show empty state
                    : ListView.builder(
                        padding:
                            const EdgeInsets.all(16.0), // Padding for the list
                        itemCount: faqs.length,
                        itemBuilder: (context, index) {
                          return _buildFAQItem(
                              faqs[index]['question'] ??
                                  'No Question', // Handle null safety
                              faqs[index]['answer'] ??
                                  'No Answer Provided', // Handle null safety
                              isNightMode,
                              cardBgColor,
                              questionColor,
                              answerColor,
                              primaryColor // Pass primary for icon color
                              );
                        },
                      ),
      ),
    );
  }

  Widget _buildFAQItem(
      String question,
      String answer,
      bool isNightMode,
      Color cardBgColor,
      Color questionColor,
      Color answerColor,
      Color iconColor) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      color: cardBgColor, // Applied
      elevation: isNightMode ? 1 : 2, // Subtle elevation difference
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12)), // More rounded
      clipBehavior: Clip.antiAlias, // Clip ripple effect
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(
            horizontal: 20, vertical: 8), // Adjust padding
        iconColor: iconColor, // Applied themed icon color
        collapsedIconColor: isNightMode
            ? Colors.grey[400]
            : Colors.grey[600], // Color when collapsed
        title: Text(
          question,
          style: TextStyle(
            color: questionColor, // Applied
            fontSize: 16,
            fontWeight: FontWeight.w600, // Slightly bolder
          ),
        ),
        children: [
          Container(
            // Container for padding and potential background subtle difference
            color: isNightMode
                ? cardBgColor.withAlpha(150)
                : Colors.grey.shade50, // Slightly different bg for answer
            padding: const EdgeInsets.only(
                left: 20.0,
                right: 20.0,
                bottom: 20.0,
                top: 5.0), // Adjust padding
            child: Text(
              answer,
              style: TextStyle(
                color: answerColor, // Applied
                fontSize: 14.5, // Slightly larger answer text
                height: 1.4, // Better line spacing
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String errorMsg, bool isNightMode, Color textColor,
      Color iconColor, Color buttonBgColor, Color buttonFgColor) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded,
                size: 60, color: iconColor), // Applied
            const SizedBox(height: 16),
            Text('Failed to Load FAQs',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: isNightMode ? Colors.white : Colors.black87)),
            const SizedBox(height: 8),
            Text(errorMsg,
                textAlign: TextAlign.center,
                style: TextStyle(color: textColor)), // Applied
            const SizedBox(height: 24),
            ElevatedButton.icon(
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Retry'),
                onPressed: _handleRefresh,
                style: ElevatedButton.styleFrom(
                    backgroundColor: buttonBgColor,
                    foregroundColor: buttonFgColor) // Applied
                )
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isNightMode, Color titleColor, Color textColor) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.question_answer_outlined,
                size: 70,
                color: isNightMode ? Colors.grey[600] : Colors.grey[400]),
            const SizedBox(height: 16),
            Text('No FAQs Available',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: titleColor)), // Applied
            const SizedBox(height: 8),
            Text('Check back later for frequently asked questions.',
                textAlign: TextAlign.center,
                style: TextStyle(color: textColor)), // Applied
          ],
        ),
      ),
    );
  }
}
