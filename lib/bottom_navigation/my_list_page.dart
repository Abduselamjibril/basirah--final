import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme_provider.dart';
import '../playlists_tab.dart';
import '../bookmarks_tab.dart';

// Import Notification Service
import '../services/notification_service.dart'; // <<--- ADDED

class MyListPage extends StatefulWidget {
  final NotificationService? notificationService; // <<--- ADDED

  // Updated constructor
  const MyListPage({super.key, this.notificationService}); // <<--- MODIFIED

  @override
  _MyListPageState createState() => _MyListPageState();

  // This method on the StatefulWidget is often unused for state refresh triggered by parents.
  Future<void> refreshData() async {
    print("MyListPage widget's refreshData called.");
    // If needed, use a GlobalKey to call the State's method or child tab methods.
  }
}

class _MyListPageState extends State<MyListPage> {
  @override
  void initState() {
    super.initState();
    // Access service via: widget.notificationService
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isNightMode = themeProvider.isDarkMode;
    final primaryColor = Color(0xFF009B77);
    final backgroundColor = themeProvider.currentTheme.scaffoldBackgroundColor;
    final appBarColor = isNightMode ? Color(0xFF1F1F1F) : primaryColor;
    final unselectedTextColor =
        isNightMode ? Colors.white70 : Colors.white.withOpacity(0.7);

    // --- Build Method Content (Remains the same UI structure) ---
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: backgroundColor,
        appBar: AppBar(
          /* ... AppBar UI ... */
          title: Text(
            'My Lists',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          centerTitle: true,
          backgroundColor: appBarColor,
          elevation: 1,
          bottom: TabBar(
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            indicatorSize: TabBarIndicatorSize.label,
            labelColor: Colors.white,
            unselectedLabelColor: unselectedTextColor,
            labelStyle: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
            unselectedLabelStyle:
                TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
            tabs: [
              Tab(child: Text('Playlists', textAlign: TextAlign.center)),
              Tab(child: Text('Bookmarks', textAlign: TextAlign.center)),
            ],
          ),
        ),
        body: Container(
          // decoration: BoxDecoration( /* Gradient decoration removed for clarity with RefreshIndicator */),
          child: TabBarView(
            children: [
              RefreshIndicator(
                color: primaryColor,
                backgroundColor: isNightMode ? Colors.grey[800] : Colors.white,
                onRefresh: () async {
                  // Add actual refresh logic for PlaylistsTab if needed
                  await Future.delayed(Duration(seconds: 1));
                  if (mounted) setState(() {});
                },
                // Pass service to child tab if it needs it
                child: PlaylistsTab(), // <<--- Pass service if needed
              ),
              RefreshIndicator(
                color: primaryColor,
                backgroundColor: isNightMode ? Colors.grey[800] : Colors.white,
                onRefresh: () async {
                  // Add actual refresh logic for BookmarksTab if needed
                  await Future.delayed(Duration(seconds: 1));
                  if (mounted) setState(() {});
                },
                // Pass service to child tab if it needs it
                child: BookmarksTab(), // <<--- Pass service if needed
              ),
            ],
          ),
        ),
      ),
    );
  }
}
