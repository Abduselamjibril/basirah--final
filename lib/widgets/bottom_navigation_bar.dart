import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme_provider.dart'; // Import the ThemeProvider

class BottomNavigationBarWidget extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  BottomNavigationBarWidget({
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Divider(
          color: themeProvider.isDarkMode
              ? Colors.white
              : Color(
                  0xFF009B77), // White in dark mode, Caribbean green in light mode
          thickness: 1, // Thickness of the divider
        ),
        BottomNavigationBar(
          currentIndex: currentIndex,
          backgroundColor: themeProvider.isDarkMode
              ? Color(0xFF002147) // Oxford blue for dark mode
              : Colors.white.withOpacity(0.85), // 85% white for light mode
          selectedItemColor: themeProvider.isDarkMode
              ? Colors.white // White for selected in dark mode
              : Color(0xFF009B77), // Caribbean green for selected in light mode
          unselectedItemColor: themeProvider.isDarkMode
              ? Colors.white
                  .withOpacity(0.7) // Light white for unselected in dark mode
              : Color(0xFF002147), // Black for unselected in light mode
          onTap: onTap,
          items: [
            BottomNavigationBarItem(
              icon: Icon(Icons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.library_books),
              label: 'Library',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.school),
              label: 'My Learning',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.list),
              label: 'My List',
            ),
          ],
        ),
      ],
    );
  }
}
