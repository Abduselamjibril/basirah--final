import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../course/quranic_course.dart';
import '../surah/surah_page.dart';
import '../story/beyond_story.dart';
import '../commentary/commentary_page.dart';
import '../deeper_look/deeper_look_page.dart';
import '../theme_provider.dart';
import '../providers/navigation_provider.dart';

// Import Notification Service
import '../services/notification_service.dart';

class LibraryPage extends StatefulWidget {
  final NotificationService? notificationService;

  const LibraryPage({super.key, this.notificationService});

  @override
  _LibraryPageState createState() => _LibraryPageState();

  Future<void> refreshData() async {
    print("LibraryPage widget's refreshData called.");
  }
}

class _LibraryPageState extends State<LibraryPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    final navProvider = Provider.of<NavigationProvider>(context, listen: false);
    _tabController = TabController(
      length: 5,
      vsync: this,
      initialIndex: navProvider.libraryTabIndex,
    );
    // Listen to changes in the controller to update the provider if the user swipes
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      if (navProvider.libraryTabIndex != _tabController.index) {
        navProvider.setLibraryTab(_tabController.index);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isNightMode = themeProvider.isDarkMode;
    const Color primaryColor = Color(0xFF009B77);
    final Color backgroundColor = themeProvider.currentTheme.scaffoldBackgroundColor;
    final Color appBarColor =
        isNightMode ? const Color(0xFF1F1F1F) : primaryColor;
    final Color unselectedTextColor =
        isNightMode ? Colors.white70 : Colors.white.withOpacity(0.7);

    // Sync tab controller with provider if changed externally
    final navProvider = Provider.of<NavigationProvider>(context);
    if (_tabController.index != navProvider.libraryTabIndex) {
      _tabController.animateTo(navProvider.libraryTabIndex);
    }

    return Scaffold(
        backgroundColor: backgroundColor,
        appBar: AppBar(
          title: const Text(
            'Library',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          centerTitle: true,
          backgroundColor: appBarColor,
          foregroundColor: Colors.white,
          elevation: 1,
          bottom: TabBar(
            controller: _tabController,
            isScrollable: true,
            indicatorColor: Colors.white,
            indicatorWeight: 3.5,
            indicatorSize: TabBarIndicatorSize.tab,
            indicator: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.white, width: 3.5),
              ),
            ),
            labelColor: Colors.white,
            unselectedLabelColor: unselectedTextColor,
            labelStyle: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              letterSpacing: 0.2,
            ),
            unselectedLabelStyle:
                const TextStyle(fontWeight: FontWeight.w400, fontSize: 14),
            labelPadding:
                const EdgeInsets.symmetric(horizontal: 16),
            tabAlignment: TabAlignment.start,
            tabs: const [
              Tab(text: 'Quranic Course'),
              Tab(text: 'Surah'),
              Tab(text: 'Beyond Story'),
              Tab(text: 'Commentary'),
              Tab(text: 'Deeper Look'),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            CoursesPage(),
            SurahPage(),
            StoryNightPage(),
            CommentaryPage(),
            DeeperLookPage(),
          ],
        ),
      );
    }
}
