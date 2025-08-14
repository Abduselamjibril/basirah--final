import 'package:shared_preferences/shared_preferences.dart';

class UserService {
  Future<String?> getPhoneNumber() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('userPhoneNumber');
    } catch (e) {
      print("Error getting phone number: $e");
      return null;
    }
  }

  Future<bool> isUserPremium() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('is_premium') ?? false;
    } catch (e) {
      print("Error getting premium status: $e");
      return false;
    }
  }
}
