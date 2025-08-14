// lib/topbar/notifications_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme_provider.dart';
import '../services/notification_service.dart';
import '../providers/auth_provider.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  _NotificationsPageState createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Mark as read when the page is opened
      Provider.of<NotificationService>(context, listen: false)
          .markApiNotificationsAsRead();
    });
  }

  void _showNotificationPopup(String title, String remark) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(child: Text(remark)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final notificationService = Provider.of<NotificationService>(context);
    // --- FIX: Get the AuthProvider to access the token for the refresh action ---
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final isNightMode = themeProvider.isDarkMode;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Notifications"),
        backgroundColor:
            isNightMode ? const Color(0xFF1E1E1E) : const Color(0xFF009B77),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        color: isNightMode ? const Color(0xFF002147) : Colors.white,
        child: RefreshIndicator(
          // --- FIX: Pass the token to the onRefresh callback ---
          onRefresh: () => notificationService.fetchApiNotifications(
              token: authProvider.token),
          child: notificationService.isLoadingApiNotifications &&
                  notificationService.apiNotifications.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : notificationService.apiNotifications.isEmpty
                  ? Center(
                      child: Text(
                        'No active notifications.',
                        style: TextStyle(
                          color: isNightMode ? Colors.white : Colors.black,
                          fontSize: 16,
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: notificationService.apiNotifications.length,
                      itemBuilder: (context, index) {
                        final notification =
                            notificationService.apiNotifications[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 12.0, vertical: 6.0),
                          color: isNightMode
                              ? const Color(0xFF1E1E1E)
                              : Colors.white,
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: ListTile(
                            title: Text(
                              notification['title'] ?? 'No Title',
                              style: TextStyle(
                                color:
                                    isNightMode ? Colors.white : Colors.black,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              notification['remark'] ?? 'No Remarks',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                color: isNightMode
                                    ? Colors.grey[400]
                                    : Colors.grey[700],
                              ),
                            ),
                            onTap: () => _showNotificationPopup(
                              notification['title'] ?? 'No Title',
                              notification['remark'] ?? 'No Remarks',
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ),
    );
  }
}
