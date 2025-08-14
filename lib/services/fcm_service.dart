import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_http_service.dart'; // Make sure this path is correct

/// Gets the FCM device token and sends it to the backend to be saved.
Future<void> updateAndSendFcmToken() async {
  // Get the FCM token from Firebase
  String? fcmToken;
  try {
    // For iOS, you might need to request permission first if you haven't already
    // await FirebaseMessaging.instance.requestPermission();
    fcmToken = await FirebaseMessaging.instance.getToken();
  } catch (e) {
    print("FCM_SERVICE: Failed to get FCM token from Firebase: $e");
    return; // Can't proceed without a token
  }

  if (fcmToken == null) {
    print(
        "FCM_SERVICE: Could not get FCM token. User will not receive push notifications.");
    return;
  }

  print("FCM_SERVICE: Obtained FCM Token: $fcmToken");

  // OPTIONAL BUT RECOMMENDED: Check if the token is already saved and is the same.
  // This prevents unnecessary API calls every time the user opens the app.
  final prefs = await SharedPreferences.getInstance();
  final String? savedToken = prefs.getString('saved_fcm_token');
  if (savedToken == fcmToken) {
    print("FCM_SERVICE: Token is already up-to-date on the backend.");
    return;
  }

  // Send the token to the backend
  final authService = AuthHttpService();
  try {
    // --- FIX: Corrected the API endpoint to match routes/api.php ---
    final response = await authService.post(
      'fcm-token', // This now matches `Route::post('/fcm-token', ...)`
      {'fcm_token': fcmToken},
      requireAuth: true, // This MUST be an authenticated request
    );

    if (response.statusCode == 200) {
      // If successful, save the token locally to prevent resending it next time
      await prefs.setString('saved_fcm_token', fcmToken);
      print("FCM_SERVICE: Token successfully registered on the backend.");
    } else {
      print(
          "FCM_SERVICE: Failed to register token. Status: ${response.statusCode}, Body: ${response.body}");
    }
  } on AuthException catch (e) {
    print("FCM_SERVICE: Authorization error sending token: ${e.message}");
  } catch (e) {
    print("FCM_SERVICE: Error sending token to backend: $e");
  }
}
