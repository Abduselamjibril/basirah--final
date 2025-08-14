import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../course/quranic_course.dart';
import '../surah/surah_page.dart';
import '../story/beyond_story.dart';
import '../commentary/commentary_page.dart';
import '../deeper_look/deeper_look_page.dart';
import '../theme_provider.dart';

// Import Notification Service
import '../services/notification_service.dart'; // <<--- ADDED

class LibraryPage extends StatefulWidget {
  final NotificationService? notificationService; // <<--- ADDED

  // Updated constructor
  const LibraryPage({super.key, this.notificationService}); // <<--- MODIFIED

  @override
  _LibraryPageState createState() => _LibraryPageState();

  // This method on the StatefulWidget is often unused for state refresh triggered by parents.
  Future<void> refreshData() async {
    print("LibraryPage widget's refreshData called.");
    // If needed, use a GlobalKey to call the State's method.
  }
}

class _LibraryPageState extends State<LibraryPage> {
  String _selectedCategory = 'Quranic Course';
  Widget _selectedCategoryContent = CoursesPage(); // Default content

  @override
  void initState() {
    super.initState();
    _loadSelectedCategory();
    // Access service via: widget.notificationService
  }

  Future<void> _loadSelectedCategory() async {
    final prefs = await SharedPreferences.getInstance();
    String? cachedCategory = prefs.getString('selectedCategory');
    if (cachedCategory != null && mounted) {
      _selectCategory(cachedCategory, _getCategoryContent(cachedCategory));
    }
  }

  Future<void> _saveSelectedCategory(String category) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selectedCategory', category);
  }

  Widget _getCategoryContent(String category) {
    // You might need to update constructors of these pages too if they need the service
    switch (category) {
      case 'Quranic Course':
        return CoursesPage(/*notificationService: widget.notificationService*/);
      case 'Objective of Surah':
        return SurahPage(/*notificationService: widget.notificationService*/);
      case 'Beyond Story':
        return StoryNightPage(
            /*notificationService: widget.notificationService*/);
      case 'Concise Commentary':
        return CommentaryPage(
            /*notificationService: widget.notificationService*/);
      case 'Deeper Look':
        return DeeperLookPage(
            /*notificationService: widget.notificationService*/);
      default:
        return CoursesPage(/*notificationService: widget.notificationService*/);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isNightMode = themeProvider.isDarkMode;

    // --- Build Method Content (Remains the same UI structure) ---
    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            /* ... Category Bar UI ... */
            padding: EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: isNightMode ? Colors.grey[900] : Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  spreadRadius: 2,
                  blurRadius: 4,
                ),
              ],
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: 8.0),
              child: Row(
                children: [
                  _buildCategoryTitle(
                      'Quranic Course',
                      () => _selectCategory('Quranic Course',
                          _getCategoryContent('Quranic Course')),
                      _selectedCategory == 'Quranic Course',
                      isNightMode),
                  _buildCategoryTitle(
                      'Surah',
                      () => _selectCategory(
                          'Surah', _getCategoryContent('Objective of Surah')),
                      _selectedCategory == 'Surah' ||
                          _selectedCategory == 'Objective of Surah',
                      isNightMode),
                  _buildCategoryTitle(
                      'Beyond Story',
                      () => _selectCategory(
                          'Beyond Story', _getCategoryContent('Beyond Story')),
                      _selectedCategory == 'Beyond Story',
                      isNightMode),
                  _buildCategoryTitle(
                      'Concise Commentary',
                      () => _selectCategory('Concise Commentary',
                          _getCategoryContent('Concise Commentary')),
                      _selectedCategory == 'Concise Commentary',
                      isNightMode),
                  _buildCategoryTitle(
                      'Deeper Look',
                      () => _selectCategory(
                          'Deeper Look', _getCategoryContent('Deeper Look')),
                      _selectedCategory == 'Deeper Look',
                      isNightMode),
                ],
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: _selectedCategoryContent,
            ),
          ),
        ],
      ),
    );
  }

  // --- _buildCategoryTitle (Remains the same) ---
  Widget _buildCategoryTitle(
      String title, VoidCallback onTap, bool isSelected, bool isNightMode) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        /* ... Category Title UI ... */
        padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          border: isSelected
              ? Border(
                  bottom: BorderSide(
                      color: isNightMode ? Colors.white : Color(0xFF009B77),
                      width: 2.0))
              : null,
        ),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 15,
            color: isSelected
                ? (isNightMode ? Colors.white : Color(0xFF009B77))
                : (isNightMode ? Colors.white54 : Colors.black54),
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  void _selectCategory(String category, Widget content) {
    if (!mounted) return;
    setState(() {
      _selectedCategory = category;
      _selectedCategoryContent = content;
      _saveSelectedCategory(category);
    });
  }
}
