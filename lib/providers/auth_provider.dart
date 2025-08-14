// lib/providers/auth_provider.dart

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_http_service.dart';

class AuthProvider with ChangeNotifier {
  // --- Private state variables ---
  String? _token;
  String? _userPhoneNumber;
  bool _isPremium = false;
  bool _isLoggedIn = false;

  // --- Public getters ---
  String? get token => _token;
  String? get userPhoneNumber => _userPhoneNumber;
  bool get isPremium => _isPremium;
  bool get isLoggedIn => _isLoggedIn;

  // --- MODIFICATION: The constructor is now empty. ---
  // The logic is moved to `tryAutoLogin` to give the splash screen full control.
  AuthProvider();

  // --- NEW METHOD to handle auto-login on startup ---
  /// Checks SharedPreferences on app startup to restore a valid, non-expired session.
  /// This is called EXPLICITLY by the splash screen.
  /// Returns `true` if the user is successfully logged in, `false` otherwise.
  Future<bool> tryAutoLogin() async {
    final prefs = await SharedPreferences.getInstance();

    final storedToken = prefs.getString('token');
    if (storedToken == null || storedToken.isEmpty) {
      _isLoggedIn = false;
      return false; // No token, definitely not logged in.
    }

    final loginTimestamp = prefs.getInt('login_timestamp');
    if (loginTimestamp == null) {
      await logout(); // Clean up inconsistent state if there's a token but no timestamp.
      return false;
    }

    final loginTime = DateTime.fromMillisecondsSinceEpoch(loginTimestamp);
    final currentTime = DateTime.now();
    final difference = currentTime.difference(loginTime);

    // This is your core 3-day expiration logic. It is correct.
    if (difference.inDays >= 3) {
      debugPrint(
          "AuthProvider: Session expired after ${difference.inDays} days. Forcing logout.");
      await logout(); // Full logout to clear backend and local data.
      return false; // Session expired.
    }

    // If we reach here, the session is valid. Let's load the user data.
    final storedPhoneNumber = prefs.getString('userPhoneNumber');
    final storedIsPremium = prefs.getBool('is_premium') ?? false;

    _token = storedToken;
    _userPhoneNumber = storedPhoneNumber;
    _isPremium = storedIsPremium;
    _isLoggedIn = true;

    // Notify listeners so UI can update if needed, but the primary navigation
    // will be handled by the splash screen that called this method.
    notifyListeners();

    debugPrint("AuthProvider: Auto-login successful. Session restored.");
    return true; // Successfully restored the session.
  }

  /// Saves session state and login timestamp after a successful API login.
  Future<void> login(String token, Map<String, dynamic> userData) async {
    if (token.isEmpty) return;

    _token = token;
    _userPhoneNumber = userData['phone_number'];
    _isPremium = userData['is_subscribed_and_active'] ?? false;
    _isLoggedIn = true;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);
    await prefs.setString('userPhoneNumber', userData['phone_number']);
    await prefs.setBool('is_premium', _isPremium);
    await prefs.setString('userFirstName', userData['first_name']);
    await prefs.setString('userLastName', userData['last_name']);
    await prefs.setBool('isLoggedIn', true);

    // Set the timestamp that `tryAutoLogin` will check
    await prefs.setInt(
        'login_timestamp', DateTime.now().millisecondsSinceEpoch);

    notifyListeners();
  }

  /// Performs a full logout: invalidates the session on the backend
  /// and then clears all local user data.
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    final tokenForApiCall = prefs.getString('token');

    if (tokenForApiCall != null && tokenForApiCall.isNotEmpty) {
      try {
        final authService = AuthHttpService();
        await authService.post('logout', {}, requireAuth: true);
        debugPrint(
            "AuthProvider: Backend session invalidation call successful.");
      } catch (e) {
        debugPrint(
            "AuthProvider: Backend logout call failed (this is non-fatal): $e");
      }
    }

    // Clear state from memory
    _token = null;
    _userPhoneNumber = null;
    _isPremium = false;
    _isLoggedIn = false;

    // Clear all local data from persistent storage
    await prefs.remove('token');
    await prefs.remove('userPhoneNumber');
    await prefs.remove('userFirstName');
    await prefs.remove('userLastName');
    await prefs.remove('is_premium');
    await prefs.remove('current_session_device_id');
    await prefs.remove('isLoggedIn');
    await prefs.remove('login_timestamp');
    await prefs.remove('saved_fcm_token');

    notifyListeners();
  }
}
