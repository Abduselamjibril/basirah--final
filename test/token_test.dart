import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<String?> _getToken() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString('auth_token'); // Return the stored token
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    // Initialize SharedPreferences for testing
    SharedPreferences.setMockInitialValues({});
  });

  test('Fetches the token from SharedPreferences', () async {
    // Arrange: Set a token in SharedPreferences
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', 'test_token');

    // Act: Retrieve the token using the _getToken method
    String? token = await _getToken();

    // Assert: Verify that the retrieved token is correct
    expect(token, 'test_token');
  });

  test('Returns null if token does not exist', () async {
    // Act: Attempt to retrieve the token when it has not been set
    String? token = await _getToken();

    // Assert: Verify that the result is null
    expect(token, null);
  });
}
