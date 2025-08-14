// lib/widgets/header_navigation_bar.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme_provider.dart';
import '../services/notification_service.dart';
import 'package:badges/badges.dart' as badges;
import 'package:basirah/screens/gift_page.dart'; // NEW: Import the new gift page

class HeaderNavigationBar extends StatelessWidget implements PreferredSizeWidget {
  final VoidCallback onNotificationTapped;
  final VoidCallback onProfileTapped;
  final VoidCallback onThemeToggle;
  // REMOVED: onFaqTapped is no longer needed.
  // NEW: Added onGiftTapped callback.
  final VoidCallback onGiftTapped;

  const HeaderNavigationBar({
    super.key,
    required this.onNotificationTapped,
    required this.onProfileTapped,
    required this.onThemeToggle,
    required this.onGiftTapped, // NEW
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 1);

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final notificationService = Provider.of<NotificationService>(context);
    final unreadNotificationCount =
        notificationService.unreadApiNotificationCount;

    bool isNightMode = themeProvider.isDarkMode;
    final iconColor = isNightMode ? Colors.white : const Color(0xFF009B77);
    final badgeColor = Colors.red;
    final badgeTextColor = Colors.white;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppBar(
          elevation: 0,
          backgroundColor: isNightMode
              ? const Color(0xFF002147)
              : Colors.white.withOpacity(0.85),
          title: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Image.asset(
              'assets/images/logo.png',
              height: 32.0,
            ),
          ),
          actions: [
            IconButton(
              tooltip:
                  isNightMode ? 'Switch to Light Mode' : 'Switch to Dark Mode',
              onPressed: onThemeToggle,
              icon: Icon(isNightMode ? Icons.light_mode : Icons.dark_mode),
              color: iconColor,
            ),
            
            // --- NEW: Gift Icon Button ---
            IconButton(
              tooltip: 'Gift a Subscription',
              onPressed: onGiftTapped,
              icon: const Icon(Icons.card_giftcard),
              color: iconColor,
            ),
            // --- END NEW ---

            // REMOVED: The FAQ IconButton has been replaced by the Gift Icon.
            // IconButton(
            //   tooltip: 'FAQ',
            //   onPressed: onFaqTapped,
            //   icon: const Icon(Icons.help_outline),
            //   color: iconColor,
            // ),
            
            badges.Badge(
              position: badges.BadgePosition.topEnd(top: 4, end: 4),
              badgeContent: Text(
                unreadNotificationCount > 99
                    ? '99+'
                    : unreadNotificationCount.toString(),
                style: TextStyle(color: badgeTextColor, fontSize: 10),
              ),
              showBadge: unreadNotificationCount > 0,
              badgeStyle: badges.BadgeStyle(
                badgeColor: badgeColor,
                padding: EdgeInsets.all(unreadNotificationCount > 9 ? 4 : 5),
              ),
              child: IconButton(
                tooltip: 'Notifications',
                onPressed: onNotificationTapped,
                icon: const Icon(Icons.notifications),
                color: iconColor,
              ),
            ),
            IconButton(
              tooltip: 'Profile',
              onPressed: onProfileTapped,
              icon: const Icon(Icons.person_outline),
              color: iconColor,
            ),
          ],
        ),
        Divider(
          height: 1,
          thickness: 1,
          color: isNightMode
              ? Colors.white.withOpacity(0.5)
              : const Color(0xFF009B77).withOpacity(0.5),
        ),
      ],
    );
  }
}