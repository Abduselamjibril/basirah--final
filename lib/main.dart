import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'providers/auth_provider.dart';
import 'providers/content_cache_provider.dart';
import 'providers/bookmark_provider.dart';

import 'widgets/bottom_navigation_bar.dart';
import 'bottom_navigation/home_page.dart';
import 'bottom_navigation/library_page.dart';
import 'bottom_navigation/my_learning_page.dart';
import 'bottom_navigation/my_list_page.dart';
import 'widgets/mini_audio_player_bar.dart';
import 'widgets/header_navigation_bar.dart';
import 'topbar/notifications_page.dart';
import 'topbar/account_page.dart';
import 'topbar/login_page.dart';
import 'topbar/signup_page.dart';
import 'topbar/profile_page.dart';
import 'topbar/edit_profile_page.dart';
import 'topbar/faq_page.dart';
import 'splash_screen.dart';
import 'theme_provider.dart';
import 'services/notification_service.dart';
import 'services/auth_http_service.dart';

import 'screens/gift_page.dart';
import 'firebase_options.dart';
import 'package:upgrader/upgrader.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'services/versioning_service.dart';

// Overlay widget to show no internet connection
class NoInternetOverlay extends StatelessWidget {
  const NoInternetOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: AbsorbPointer(
        absorbing: true,
        child: Container(
          color: Colors.black.withOpacity(0.7),
          alignment: Alignment.center,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeInOut,
              padding: const EdgeInsets.all(0),
              child: Card(
                elevation: 16,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        padding: const EdgeInsets.all(18),
                        child: const Icon(Icons.wifi_off,
                            color: Colors.redAccent, size: 56),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'No Internet Connection',
                        style: TextStyle(
                          color: Colors.black87,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'You are offline. Please check your network settings and try again.',
                        style: TextStyle(
                          color: Colors.black54,
                          fontSize: 16,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: 160,
                        child: ElevatedButton.icon(
                          onPressed: null,
                          icon: const Icon(Icons.refresh, color: Colors.white),
                          label: const Text('Reconnect',
                              style: TextStyle(color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                            disabledBackgroundColor: Colors.redAccent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

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
  await runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      FirebaseMessaging.onBackgroundMessage(
          _firebaseMessagingBackgroundHandler);
      await notificationService.initNotifications(navigatorKey);

      runApp(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: themeProvider),
            ChangeNotifierProvider(create: (context) => AuthProvider()),
            ChangeNotifierProvider(create: (context) => ContentCacheProvider()),
            ChangeNotifierProvider(create: (context) => BookmarkProvider()),
            ChangeNotifierProvider.value(value: notificationService),
          ],
          child: const BayyinahCloneApp(),
        ),
      );

      _setupFirebaseListeners();
    },
    (error, stack) {
      // Handle uncaught errors
    },
    zoneSpecification: kReleaseMode
        ? ZoneSpecification(
            print: (self, parent, zone, message) {
              // Do nothing in release mode
            },
          )
        : null,
  );
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

class BayyinahCloneApp extends StatefulWidget {
  const BayyinahCloneApp({super.key});

  @override
  State<BayyinahCloneApp> createState() => _BayyinahCloneAppState();
}

class _BayyinahCloneAppState extends State<BayyinahCloneApp> {
  bool _isOffline = false;
  late final Connectivity _connectivity;
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    _connectivity = Connectivity();
    _connectivitySubscription =
        _connectivity.onConnectivityChanged.listen((result) {
      final offline = result == ConnectivityResult.none;
      if (offline != _isOffline && mounted) {
        setState(() {
          _isOffline = offline;
        });
      }
    });
    _connectivity.checkConnectivity().then((result) {
      final offline = result == ConnectivityResult.none;
      if (offline != _isOffline && mounted) {
        setState(() {
          _isOffline = offline;
        });
      }
    });
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return MaterialApp(
      scaffoldMessengerKey: rootScaffoldMessengerKey,
      navigatorKey: navigatorKey,
      title: 'Basirah TV',
      theme: themeProvider.currentTheme.copyWith(
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
        ),
      ),
      home: SplashScreen(),
      routes: {
        '/signup': (context) => SignUpPage(),
        '/login': (context) => LoginPage(),
        '/account': (context) => AccountPage(),
        '/faq': (context) => FaqPage(),
        '/profile': (context) => const ProfilePage(),
        '/edit-profile': (context) => const EditProfilePage(),
        '/home': (context) => const MainScreen(),
      },
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        return Stack(
          children: [
            ForceUpdateWrapper(child: child!),
            if (_isOffline) const NoInternetOverlay(),
          ],
        );
      },
    );
  }
}

class ForceUpdateWrapper extends StatefulWidget {
  final Widget child;
  const ForceUpdateWrapper({super.key, required this.child});

  @override
  State<ForceUpdateWrapper> createState() => _ForceUpdateWrapperState();
}

class _ForceUpdateWrapperState extends State<ForceUpdateWrapper> {
  bool _needsUpdate = false;
  String? _storeVersion;

  @override
  void initState() {
    super.initState();
    _checkVersion();
  }

  Future<void> _checkVersion() async {
    print('DEBUG: [FORCE_UPDATE] Starting custom version check');
    final packageInfo = await PackageInfo.fromPlatform();
    final installedVersion = packageInfo.version;
    print('DEBUG: [FORCE_UPDATE] Installed Version: $installedVersion');

    final storeVersion = await VersioningService.getLatestVersion();
    print('DEBUG: [FORCE_UPDATE] Store Version: $storeVersion');

    if (storeVersion != null && storeVersion != installedVersion) {
      if (mounted) {
        setState(() {
          _needsUpdate = true;
          _storeVersion = storeVersion;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_needsUpdate) return widget.child;

    return Stack(
      children: [
        widget.child,
        Container(
          color: Colors.black.withOpacity(0.85),
          child: Center(
            child: Card(
              margin: const EdgeInsets.symmetric(horizontal: 32),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.system_update,
                        size: 64, color: Color(0xFF009B77)),
                    const SizedBox(height: 16),
                    const Text(
                      'Update Required',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'A new version ($_storeVersion) is available. Please update to continue using Basirah TV.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16, color: Colors.black54),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          final url = Uri.parse(
                              'https://play.google.com/store/apps/details?id=com.basirahtv.app');
                          if (await canLaunchUrl(url)) {
                            await launchUrl(url,
                                mode: LaunchMode.externalApplication);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF009B77),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('UPDATE NOW',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
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

  late Connectivity _connectivity;
  late Stream<ConnectivityResult> _connectivityStream;
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  bool _isOffline = false;

  final List<Widget> _pages = [
    const HomePage(),
    const LibraryPage(),
    const MyLearningPage(),
    const MyListPage(),
  ];

  void _showCustomSnackBar(SnackBar snackBar) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: snackBar.content,
        backgroundColor: snackBar.backgroundColor,
        duration: snackBar.duration,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(
          left: 24.0,
          right: 24.0,
          bottom: 20.0,
        ),
        shape: snackBar.shape ??
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    authProvider.addListener(_onAuthStateChanged);

    _connectivity = Connectivity();
    _connectivityStream = _connectivity.onConnectivityChanged;
    _connectivitySubscription = _connectivityStream.listen((result) {
      final offline = result == ConnectivityResult.none;
      if (offline != _isOffline && mounted) {
        setState(() {
          _isOffline = offline;
        });
        if (offline) {
          _showCustomSnackBar(
            const SnackBar(
              content:
                  Text('No network connection', textAlign: TextAlign.center),
              backgroundColor: Colors.red,
              duration: Duration(days: 1),
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
        }
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.postLoginMessage != null && mounted) {
        _showCustomSnackBar(
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
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
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
    _connectivitySubscription?.cancel();
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

      Provider.of<BookmarkProvider>(context, listen: false)
          .fetchBookmarks(authProvider.token!);

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
      resizeToAvoidBottomInset: false,
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
      body: Column(
        children: [
          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              children: _pages,
            ),
          ),
          const MiniAudioPlayerBar(),
        ],
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
