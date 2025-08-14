// lib/topbar/login_page.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'signup_page.dart';
import '../theme_provider.dart';
import '../services/device_info_service.dart';
import 'forgot_password_page.dart';
import '../main.dart';
import '../services/fcm_service.dart' as fcm;
import '../providers/auth_provider.dart';

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _phoneNumberController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isPasswordVisible = false;
  final DeviceInfoService _deviceInfoService = DeviceInfoService();

  // --- THIS IS THE UPDATED LOGIN FUNCTION ---
  Future<void> _login() async {
    if (_isLoading) return;

    final String phoneNumber = _phoneNumberController.text.trim();
    final String password = _passwordController.text.trim();

    if (phoneNumber.isEmpty || password.isEmpty) {
      _showNotification('Please fill in all fields', Colors.redAccent);
      return;
    }

    setState(() => _isLoading = true);

    String deviceId = "unknown_device_id";
    String deviceName = "Unknown Device";
    try {
      deviceId = await _deviceInfoService.getDeviceId();
      deviceName = await _deviceInfoService.getDeviceModelName();
    } catch (e) {
      print("Error getting device info for login: $e");
    }

    final url = Uri.parse('https://admin.basirahtv.com/api/login');
    final headers = {
      "Content-Type": "application/json",
      "Accept": "application/json"
    };
    final body = jsonEncode({
      "phone_number": phoneNumber,
      "password": password,
      "device_id": deviceId,
      "device_name": deviceName,
    });

    try {
      final response = await http
          .post(url, headers: headers, body: body)
          .timeout(const Duration(seconds: 20));

      if (!mounted) return;

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final String? token = responseData['token'];
        final Map<String, dynamic>? userData = responseData['user'];

        if (token != null && userData != null) {
          Provider.of<AuthProvider>(context, listen: false)
              .login(token, userData);

          SharedPreferences prefs = await SharedPreferences.getInstance();
          await prefs.setString('userName',
              '${userData['first_name'] ?? ''} ${userData['last_name'] ?? ''}');
          await prefs.setString('current_session_device_id', deviceId);

          print("Login successful.");
          fcm.updateAndSendFcmToken();

          _showNotification('Login successful', Colors.green);

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => MainScreen()),
          );
        } else {
          _showNotification(
              'Login failed: Invalid server response.', Colors.redAccent);
        }
      } else if (response.statusCode == 401) {
        _showNotification(
            'Invalid phone number or password.', Colors.redAccent);
        // --- THIS IS THE FIX ---
        // Handle the new "Device Limit Reached" error from the backend.
      } else if (response.statusCode == 403) {
        final message = responseData['message'] ??
            'Device limit reached. Please log out from another device.';
        _showNotification(message, Colors.orangeAccent);
      } else {
        String errorMessage = responseData['message'] ??
            'Login failed (Code: ${response.statusCode})';
        _showNotification(errorMessage, Colors.redAccent);
      }
    } catch (error) {
      if (!mounted) return;
      _showNotification(
          error is TimeoutException
              ? 'Request timed out. Please check your connection.'
              : 'An error occurred. Please try again.',
          Colors.redAccent);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showNotification(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message,
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
            textAlign: TextAlign.center),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 100.0),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
        duration:
            const Duration(seconds: 4), // Increased duration for readability
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    final Color primaryColor =
        isDark ? const Color(0xFF1E1E1E) : const Color(0xFF009B77);
    final Color scaffoldBgColor =
        isDark ? const Color(0xFF002147) : Colors.white;
    final Color appBarColor = primaryColor;
    final Color welcomeTextColor = isDark ? Colors.white : Colors.black87;
    final Color promptTextColor = isDark ? Colors.grey[400]! : Colors.black54;
    final Color buttonBgColor = primaryColor;
    final Color buttonFgColor = Colors.white;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Login', style: TextStyle(color: Colors.white)),
        backgroundColor: appBarColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      backgroundColor: scaffoldBgColor,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // --- MODIFIED: Increased logo size ---
            Image.asset('assets/images/logo.png', width: 150, height: 150),
            const SizedBox(height: 30),
            Align(
                alignment: Alignment.centerLeft,
                child: Text('Welcome Back',
                    style: TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.bold,
                        color: welcomeTextColor))),
            const SizedBox(height: 8.0),
            Align(
                alignment: Alignment.centerLeft,
                child: Text('Please log in to continue.',
                    style: TextStyle(fontSize: 13, color: promptTextColor))),
            const SizedBox(height: 32.0),
            _buildTextField(
                controller: _phoneNumberController,
                label: 'Phone Number',
                icon: Icons.phone_rounded,
                inputType: TextInputType.phone,
                isDark: isDark),
            const SizedBox(height: 16.0),
            _buildTextField(
              controller: _passwordController,
              label: 'Password',
              icon: Icons.lock_outline_rounded,
              isPassword: true,
              isVisible: _isPasswordVisible,
              onToggleVisibility: () =>
                  setState(() => _isPasswordVisible = !_isPasswordVisible),
              isDark: isDark,
            ),
            const SizedBox(height: 32.0),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _login,
                style: ElevatedButton.styleFrom(
                    backgroundColor: buttonBgColor,
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.0))),
                child: _isLoading
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                            strokeWidth: 3))
                    : Text('Login',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: buttonFgColor)),
              ),
            ),
            const SizedBox(height: 16.0),
            GestureDetector(
              onTap: () {
                if (!_isLoading) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => ForgotPasswordPage()),
                  );
                }
              },
              child: Text(
                'Forgot Password?',
                style: TextStyle(
                  color: Colors.grey[600]!,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 24.0),
            GestureDetector(
              onTap: () {
                if (!_isLoading) {
                  Navigator.push(context,
                      MaterialPageRoute(builder: (context) => SignUpPage()));
                }
              },
              child: RichText(
                text: TextSpan(
                  text: "Don't have an account? ",
                  style: TextStyle(color: promptTextColor, fontSize: 16),
                  children: [
                    TextSpan(
                        text: "Register",
                        style: TextStyle(
                            color: Colors.grey[600]!,
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isPassword = false,
    bool isVisible = false,
    VoidCallback? onToggleVisibility,
    TextInputType inputType = TextInputType.text,
    required bool isDark,
  }) {
    final Color fieldFillColor = isDark ? Colors.grey[850]! : Colors.grey[100]!;
    final Color fieldBorderColor =
        isDark ? Colors.grey[700]! : Colors.grey[300]!;
    final Color fieldFocusedBorderColor = const Color(0xFF009B77);
    final Color fieldIconColor = const Color(0xFF009B77);
    final Color fieldLabelTextColor =
        isDark ? Colors.grey[400]! : Colors.grey[600]!;
    final Color fieldInputTextColor = isDark ? Colors.white : Colors.black;
    final Color visibilityIconColor = fieldIconColor.withOpacity(0.7);

    return TextField(
      controller: controller,
      obscureText: isPassword && !isVisible,
      keyboardType: inputType,
      style: TextStyle(color: fieldInputTextColor),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: fieldLabelTextColor),
        prefixIcon: Icon(icon, color: fieldIconColor),
        filled: true,
        fillColor: fieldFillColor,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10.0),
            borderSide: BorderSide(color: fieldBorderColor)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10.0),
            borderSide: BorderSide(color: fieldBorderColor)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10.0),
            borderSide: BorderSide(color: fieldFocusedBorderColor, width: 1.5)),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                    isVisible
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: visibilityIconColor),
                onPressed: onToggleVisibility,
              )
            : null,
        contentPadding:
            const EdgeInsets.symmetric(vertical: 15.0, horizontal: 12.0),
      ),
    );
  }
}
