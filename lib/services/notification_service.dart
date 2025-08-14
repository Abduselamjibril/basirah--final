// lib/services/notification_service.dart

import 'dart:convert';
import 'package:basirah/topbar/notifications_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:http/http.dart' as http;

// Make NotificationService a ChangeNotifier to manage state and notify listeners.
class NotificationService with ChangeNotifier {
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  GlobalKey<NavigatorState>? _navigatorKey;

  // --- START: State Management for In-App API Notifications ---

  List<dynamic> _apiNotifications = [];
  bool _isLoadingApiNotifications =
      false; // Start with false, set to true on call
  int _unreadApiNotificationCount = 0;

  List<dynamic> get apiNotifications => _apiNotifications;
  bool get isLoadingApiNotifications => _isLoadingApiNotifications;
  int get unreadApiNotificationCount => _unreadApiNotificationCount;

  // --- MODIFIED: The method now requires an auth token to work ---
  /// Fetches notifications from the server and updates the unread count.
  /// Requires the user's auth token to access the protected endpoint.
  Future<void> fetchApiNotifications({required String? token}) async {
    // --- FIX: Add a guard clause to prevent calls without a token ---
    if (token == null || token.isEmpty) {
      debugPrint('Cannot fetch API notifications: No auth token provided.');
      // Clear any old data if the user logged out
      _apiNotifications = [];
      _unreadApiNotificationCount = 0;
      _isLoadingApiNotifications = false;
      notifyListeners();
      return;
    }

    // Set loading to true only when the fetch operation starts
    _isLoadingApiNotifications = true;
    notifyListeners();

    try {
      // --- FIX: Use http.get and add the Authorization header ---
      final response = await http.get(
        Uri.parse('https://admin.basirahtv.com/api/notifications'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json', // Good practice for Laravel APIs
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _apiNotifications = List<dynamic>.from(data);
        // This logic remains the same for now, but could be enhanced later
        _unreadApiNotificationCount = _apiNotifications.length;
      } else {
        // Log the error for better debugging
        debugPrint(
            'Failed to load notifications: Status Code ${response.statusCode}, Body: ${response.body}');
        throw Exception('Failed to load notifications: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching API notifications: $e');
      _apiNotifications = []; // Clear notifications on error
      _unreadApiNotificationCount = 0;
    } finally {
      _isLoadingApiNotifications = false;
      // Notify listeners (like the UI) that the data has changed.
      notifyListeners();
    }
  }

  /// Marks all current notifications as read by resetting the unread count.
  /// This is called when the user visits the NotificationsPage.
  void markApiNotificationsAsRead() {
    if (_unreadApiNotificationCount > 0) {
      _unreadApiNotificationCount = 0;
      // Notify listeners (like the HeaderNavigationBar) that the count has changed.
      notifyListeners();
      debugPrint('API notifications marked as read. Badge count reset.');
    }
  }

  // --- END: State Management for In-App API Notifications ---

  Future<void> initNotifications(
      GlobalKey<NavigatorState>? navigatorKey) async {
    _navigatorKey = navigatorKey; // Store the navigator key
    tz.initializeTimeZones();

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@drawable/ic_stat_basirah');

    final DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
      onDidReceiveLocalNotification: onDidReceiveLocalNotification,
    );

    final InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
      macOS: initializationSettingsDarwin,
    );

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse:
          (NotificationResponse notificationResponse) {
        onDidReceiveNotificationResponseHandler(
            notificationResponse, _navigatorKey);
      },
      onDidReceiveBackgroundNotificationResponse:
          onDidReceiveBackgroundNotificationResponse,
    );
    debugPrint("Notification Service Initialized.");
  }

  void onDidReceiveLocalNotification(
      int id, String? title, String? body, String? payload) async {
    debugPrint(
        'iOS (Foreground - old): Received local notification: ID $id, Title $title, Payload $payload');
  }

  @pragma('vm:entry-point')
  static void onDidReceiveBackgroundNotificationResponse(
      NotificationResponse notificationResponse) {
    debugPrint(
        'Background/Terminated App - Notification Tapped: Payload: ${notificationResponse.payload}');
  }

  void onDidReceiveNotificationResponseHandler(
      NotificationResponse notificationResponse,
      GlobalKey<NavigatorState>? navigatorKey) async {
    final String? payload = notificationResponse.payload;
    if (payload != null && navigatorKey?.currentState != null) {
      debugPrint(
          'Foreground/Background App - Notification Tapped: Payload: $payload');
      // Navigate to the new notifications page which uses a provider
      navigatorKey!.currentState!.push(MaterialPageRoute(
        builder: (context) => const NotificationsPage(),
      ));
    }
  }

  Future<bool> requestNotificationPermissions(BuildContext? context) async {
    PermissionStatus status = await Permission.notification.request();

    if (status.isGranted) return true;
    if (status.isLimited) return true; // iOS provisional is ok

    if (context != null && context.mounted) {
      String title = 'Permission Denied';
      String content =
          'You have denied notification permissions. Some features may not work as expected.';
      bool showSettings = false;

      if (status.isPermanentlyDenied) {
        title = 'Permission Required';
        content =
            'Notification permissions are required. Please enable them in your app settings.';
        showSettings = true;
      } else if (status.isRestricted) {
        title = 'Permission Restricted';
        content =
            'Notification permissions are restricted on this device (e.g., by parental controls).';
      }
      _showPermissionDialog(context, title, content,
          showSettingsButton: showSettings);
    }
    return false;
  }

  void _showPermissionDialog(BuildContext context, String title, String content,
      {bool showSettingsButton = false}) {
    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
          if (showSettingsButton)
            TextButton(
              onPressed: () {
                openAppSettings();
                Navigator.of(ctx).pop();
              },
              child: const Text('Open Settings'),
            ),
        ],
      ),
    );
  }

  Future<void> showSimpleNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    const AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails(
      'basirah_tv_channel_id',
      'BasirahTV Updates',
      channelDescription:
          'Notifications for updates and new content on BasirahTV.',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'ticker',
    );
    const DarwinNotificationDetails darwinNotificationDetails =
        DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidNotificationDetails,
      iOS: darwinNotificationDetails,
      macOS: darwinNotificationDetails,
    );
    await flutterLocalNotificationsPlugin.show(
      id,
      title,
      body,
      notificationDetails,
      payload: payload ?? 'Default Payload from BasirahTV',
    );
  }

  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required Duration durationFromNow,
    String? payload,
  }) async {
    final tz.TZDateTime scheduledDateTime =
        tz.TZDateTime.now(tz.local).add(durationFromNow);

    await flutterLocalNotificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      scheduledDateTime,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'basirah_tv_scheduled_channel_id',
          'Scheduled BasirahTV Reminders',
          channelDescription:
              'Scheduled reminders and notifications from BasirahTV.',
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: payload ?? 'Scheduled Payload from BasirahTV',
    );
  }

  Future<void> cancelNotification(int id) async {
    await flutterLocalNotificationsPlugin.cancel(id);
    debugPrint('Notification cancelled: id=$id');
  }

  Future<void> cancelAllNotifications() async {
    await flutterLocalNotificationsPlugin.cancelAll();
    debugPrint('All notifications cancelled');
  }

  Future<String?> getInitialNotificationPayload() async {
    final NotificationAppLaunchDetails? notificationAppLaunchDetails =
        await flutterLocalNotificationsPlugin.getNotificationAppLaunchDetails();
    if (notificationAppLaunchDetails?.didNotificationLaunchApp ?? false) {
      debugPrint(
          'App launched via notification: Payload: ${notificationAppLaunchDetails!.notificationResponse?.payload}');
      return notificationAppLaunchDetails.notificationResponse?.payload;
    }
    return null;
  }
}
