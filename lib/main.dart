import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'providers/auth_provider.dart';
import 'providers/content_cache_provider.dart';

import 'widgets/bottom_navigation_bar.dart';
import 'bottom_navigation/home_page.dart';
import 'bottom_navigation/library_page.dart';
import 'bottom_navigation/my_learning_page.dart';
import 'bottom_navigation/my_list_page.dart';
import 'widgets/header_navigation_bar.dart';
import 'topbar/notifications_page.dart';
import 'topbar/account_page.dart';
import 'topbar/login_page.dart';
import 'topbar/signup_page.dart';
import 'topbar/profile_page.dart';
import 'topbar/edit_profile_page.dart'; // <-- ADDED IMPORT
import 'topbar/faq_page.dart';
import 'splash_screen.dart';
import 'theme_provider.dart';
import 'services/notification_service.dart';
import 'services/auth_http_service.dart';

import 'package:basirah/screens/gift_page.dart';
import 'firebase_options.dart';

final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  print("Handling a background message: ${message.messageId}");

  final notificationService = NotificationService();
  await notificationService.initNotifications(null);

  final data = message.data;
  final title = data['title'] ?? 'New Message';
  final body = data['body'] ?? 'You have a new update.';

  notificationService.showSimpleNotification(
    id: message.hashCode,
    title: title,
    body: body,
    payload: json.encode(data),
  );
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final NotificationService notificationService = NotificationService();
final AuthHttpService authHttpService = AuthHttpService();
final ThemeProvider themeProvider = ThemeProvider();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  await notificationService.initNotifications(navigatorKey);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: themeProvider),
        ChangeNotifierProvider(create: (context) => AuthProvider()),
        ChangeNotifierProvider(create: (context) => ContentCacheProvider()),
        ChangeNotifierProvider.value(value: notificationService),
      ],
      child: const BayyinahCloneApp(),
    ),
  );

  _setupFirebaseListeners();
}

void _setupFirebaseListeners() {
  FirebaseMessaging.instance.requestPermission();

  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    print('Got a message whilst in the foreground!');

    final data = message.data;
    final title = data['title'] ?? 'New Notification';
    final body = data['body'] ?? 'You have a new update.';

    notificationService.showSimpleNotification(
      id: DateTime.now().millisecondsSinceEpoch.toSigned(31),
      title: title,
      body: body,
      payload: json.encode(message.data),
    );

    final context = navigatorKey.currentContext;
    if (context != null) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.isLoggedIn) {
        notificationService.fetchApiNotifications(token: authProvider.token);
      }
    }
  });

  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    print(
        'Notification tapped to open app from background: ${message.messageId}');
    if (navigatorKey.currentState != null) {
      navigatorKey.currentState!.push(MaterialPageRoute(
        builder: (context) => const NotificationsPage(),
      ));
    }
  });
}

void updateAndSendFcmToken() async {
  try {
    String? token = await FirebaseMessaging.instance.getToken();
    if (token != null) {
      print("Firebase FCM Token: $token");
      await authHttpService.post('fcm-token', {'fcm_token': token});
      print("FCM token successfully sent to backend.");
    }
  } catch (e) {
    print("Error getting or sending FCM token: $e");
  }
}

class BayyinahCloneApp extends StatelessWidget {
  const BayyinahCloneApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return MaterialApp(
      scaffoldMessengerKey: rootScaffoldMessengerKey,
      navigatorKey: navigatorKey,
      title: 'Basirah tv',
      theme: themeProvider.currentTheme,
      home: SplashScreen(),
      routes: {
        '/signup': (context) => SignUpPage(),
        '/login': (context) => LoginPage(),
        '/account': (context) => AccountPage(),
        '/faq': (context) => FaqPage(),
        '/profile': (context) => const ProfilePage(),
        '/edit-profile': (context) =>
            const EditProfilePage(), // <-- ADDED ROUTE
        '/home': (context) => const MainScreen(),
      },
      debugShowCheckedModeBanner: false,
    );
  }
}

class MainScreen extends StatefulWidget {
  final String? postLoginMessage;

  const MainScreen({
    super.key,
    this.postLoginMessage,
  });

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const HomePage(),
    const LibraryPage(),
    const MyLearningPage(),
    const MyListPage(),
  ];

  @override
  void initState() {
    super.initState();
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    authProvider.addListener(_onAuthStateChanged);

    // This logic correctly shows the post-login message safely
    // after the MainScreen has been built.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.postLoginMessage != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.postLoginMessage!,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white),
              textAlign: TextAlign.center,
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            margin:
                const EdgeInsets.symmetric(horizontal: 24.0, vertical: 100.0),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10.0)),
            duration: const Duration(seconds: 4),
          ),
        );
      }

      _triggerInitialDataFetch();
    });
  }

  @override
  void dispose() {
    Provider.of<AuthProvider>(context, listen: false)
        .removeListener(_onAuthStateChanged);
    super.dispose();
  }

  void _onAuthStateChanged() {
    _triggerInitialDataFetch();
  }

  void _triggerInitialDataFetch() {
    if (!mounted) return;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    if (authProvider.isLoggedIn && authProvider.token != null) {
      Provider.of<ContentCacheProvider>(context, listen: false)
          .fetchAllContent(token: authProvider.token!);

      Provider.of<NotificationService>(context, listen: false)
          .fetchApiNotifications(token: authProvider.token);
    }
  }

  void _switchToBottomNavPage(int index) {
    if (!mounted || _currentIndex == index) return;
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      appBar: HeaderNavigationBar(
        onNotificationTapped: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const NotificationsPage(),
            ),
          );
        },
        onProfileTapped: () {
          Navigator.pushNamed(context, '/profile');
        },
        onGiftTapped: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const GiftPage()),
          );
        },
        onThemeToggle: themeProvider.toggleTheme,
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBarWidget(
        currentIndex: _currentIndex,
        onTap: (index) {
          _switchToBottomNavPage(index);
        },
      ),
    );
  }
}
