import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_http_service.dart';

class AuthProvider with ChangeNotifier {
  // --- Private state variables ---
  String? _token;
  String? _userPhoneNumber;
  // --- ADDED ---
  String? _userFirstName;
  String? _userLastName;
  // -----------
  bool _isPremium = false;
  bool _isLoggedIn = false;

  // --- Public getters ---
  String? get token => _token;
  String? get userPhoneNumber => _userPhoneNumber;
  // --- ADDED ---
  String? get userFirstName => _userFirstName;
  String? get userLastName => _userLastName;
  // -----------
  bool get isPremium => _isPremium;
  bool get isLoggedIn => _isLoggedIn;

  AuthProvider();

  Future<bool> tryAutoLogin() async {
    final prefs = await SharedPreferences.getInstance();

    final storedToken = prefs.getString('token');
    if (storedToken == null || storedToken.isEmpty) {
      _isLoggedIn = false;
      return false;
    }

    final loginTimestamp = prefs.getInt('login_timestamp');
    if (loginTimestamp == null) {
      await logout();
      return false;
    }

    final loginTime = DateTime.fromMillisecondsSinceEpoch(loginTimestamp);
    final currentTime = DateTime.now();
    final difference = currentTime.difference(loginTime);

    if (difference.inDays >= 3) {
      debugPrint(
          "AuthProvider: Session expired after ${difference.inDays} days. Forcing logout.");
      await logout();
      return false;
    }

    // Load all user data from SharedPreferences
    _token = storedToken;
    _userPhoneNumber = prefs.getString('userPhoneNumber');
    _userFirstName = prefs.getString('userFirstName'); // <-- UPDATED
    _userLastName = prefs.getString('userLastName'); // <-- UPDATED
    _isPremium = prefs.getBool('is_premium') ?? false;
    _isLoggedIn = true;

    notifyListeners();
    debugPrint("AuthProvider: Auto-login successful. Session restored.");
    return true;
  }

  Future<void> login(String token, Map<String, dynamic> userData) async {
    if (token.isEmpty) return;

    _token = token;
    _userPhoneNumber = userData['phone_number'];
    _userFirstName = userData['first_name']; // <-- UPDATED
    _userLastName = userData['last_name']; // <-- UPDATED
    _isPremium = userData['is_subscribed_and_active'] ?? false;
    _isLoggedIn = true;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);
    await prefs.setString('userPhoneNumber', userData['phone_number']);
    await prefs.setBool('is_premium', _isPremium);
    await prefs.setString('userFirstName', userData['first_name']);
    await prefs.setString('userLastName', userData['last_name']);
    await prefs.setBool('isLoggedIn', true);

    await prefs.setInt(
        'login_timestamp', DateTime.now().millisecondsSinceEpoch);

    notifyListeners();
  }

  // --- NEW METHOD to be called from EditProfilePage ---
  /// Updates the user's profile data in the provider and SharedPreferences.
  Future<void> updateUserProfile(Map<String, dynamic> updatedUserData) async {
    _userFirstName = updatedUserData['first_name'] as String?;
    _userLastName = updatedUserData['last_name'] as String?;
    _userPhoneNumber = updatedUserData['phone_number'] as String?;

    final prefs = await SharedPreferences.getInstance();
    if (_userFirstName != null) {
      await prefs.setString('userFirstName', _userFirstName!);
    }
    if (_userLastName != null) {
      await prefs.setString('userLastName', _userLastName!);
    }
    if (_userPhoneNumber != null) {
      await prefs.setString('userPhoneNumber', _userPhoneNumber!);
    }

    notifyListeners();
    debugPrint("AuthProvider: User profile updated and state notified.");
  }
  // --------------------------------------------------------

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
    _userFirstName = null; // <-- UPDATED
    _userLastName = null; // <-- UPDATED
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
