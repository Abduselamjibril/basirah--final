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

  Future<void> _login() async {
    if (_isLoading) return;

    final String phoneNumber = _phoneNumberController.text.trim();
    final String password = _passwordController.text.trim();

    if (phoneNumber.isEmpty || password.isEmpty) {
      _showNotification('Please fill in all fields', Colors.redAccent);
      return;
    }

    setState(() => _isLoading = true);

    final navigator = Navigator.of(context);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

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
          authProvider.login(token, userData);

          SharedPreferences prefs = await SharedPreferences.getInstance();
          await prefs.setString('current_session_device_id', deviceId);

          print("Login successful.");
          fcm.updateAndSendFcmToken();

          await navigator.pushReplacement(
            MaterialPageRoute(
              builder: (context) => const MainScreen(
                postLoginMessage: 'Login successful! Welcome back.',
              ),
            ),
          );
        } else {
          _showNotification(
              'Login failed: Invalid server response.', Colors.redAccent);
        }
      } else if (response.statusCode == 401) {
        _showNotification(
            'Invalid phone number or password.', Colors.redAccent);
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
                fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white),
            textAlign: TextAlign.center),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(24.0, 0.0, 24.0, 20.0),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final topPadding = MediaQuery.of(context).padding.top;

    // ── Unified colour palette ──
    const Color accentGreen = Color(0xFF009B77);
    final Color scaffoldBg = isDark ? const Color(0xFF0D1B2A) : const Color(0xFFF7F8FA);
    final Color cardBg = isDark ? const Color(0xFF1B2838) : Colors.white;
    final Color headingColor = isDark ? Colors.white : const Color(0xFF1A1A2E);
    final Color subtitleColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;
    final Color linkColor = isDark ? const Color(0xFF4DD0B5) : accentGreen;
    final Color backBtnBg = isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05);
    final Color backBtnIcon = isDark ? Colors.white : const Color(0xFF1A1A2E);

    return Scaffold(
      backgroundColor: scaffoldBg,
      body: Stack(
        children: [
          // ── Main scrollable content ──
          SingleChildScrollView(
            padding: EdgeInsets.only(
              left: 28.0,
              right: 28.0,
              top: topPadding + 56,
              bottom: 32,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 12),

                // ── Logo (larger, no top bar) ──
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: accentGreen.withOpacity(isDark ? 0.15 : 0.12),
                        blurRadius: 40,
                        spreadRadius: 12,
                      ),
                    ],
                  ),
                  child: Image.asset(
                    isDark ? 'assets/images/logo3.png' : 'assets/images/logo.png',
                    width: 160,
                    height: 160,
                  ),
                ),
                const SizedBox(height: 32),

                // ── Heading ──
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Welcome Back',
                      style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: headingColor,
                          letterSpacing: -0.5)),
                ),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Please log in to continue.',
                      style: TextStyle(fontSize: 14, color: subtitleColor)),
                ),
                const SizedBox(height: 28),

                // ── Form Card ──
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(isDark ? 0.25 : 0.06),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      _buildTextField(
                          controller: _phoneNumberController,
                          label: 'Phone Number',
                          icon: Icons.phone_rounded,
                          inputType: TextInputType.phone,
                          isDark: isDark),
                      const SizedBox(height: 14),
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
                      const SizedBox(height: 10),

                      // ── Forgot Password ──
                      Align(
                        alignment: Alignment.centerRight,
                        child: GestureDetector(
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
                              color: linkColor,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // ── Login Button ──
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark ? const Color(0xFF4DD0B5) : accentGreen,
                      foregroundColor: isDark ? Colors.black : Colors.white,
                      elevation: 2,
                      shadowColor: accentGreen.withOpacity(0.3),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                                strokeWidth: 2.5))
                        : const Text('Login',
                            style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.3)),
                  ),
                ),
                const SizedBox(height: 28),

                // ── Sign Up Link ──
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
                      style: TextStyle(color: subtitleColor, fontSize: 15),
                      children: [
                        TextSpan(
                            text: "Register",
                            style: TextStyle(
                                color: linkColor,
                                fontSize: 15,
                                fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Shared text field builder ──
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
    final Color fieldFillColor = isDark ? const Color(0xFF0D1B2A) : const Color(0xFFF2F4F6);
    final Color fieldBorderColor = isDark ? Colors.grey.shade700 : Colors.grey.shade300;
    const Color fieldFocusedBorderColor = Color(0xFF009B77);
    const Color fieldIconColor = Color(0xFF009B77);
    final Color fieldLabelTextColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;
    final Color fieldInputTextColor = isDark ? Colors.white : Colors.black;

    return TextField(
      controller: controller,
      obscureText: isPassword && !isVisible,
      keyboardType: inputType,
      style: TextStyle(color: fieldInputTextColor, fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: fieldLabelTextColor, fontSize: 14),
        prefixIcon: Icon(icon, color: fieldIconColor, size: 20),
        filled: true,
        fillColor: fieldFillColor,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: fieldBorderColor)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: fieldBorderColor)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                const BorderSide(color: fieldFocusedBorderColor, width: 1.5)),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                    isVisible
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: fieldIconColor.withOpacity(0.6),
                    size: 20),
                onPressed: onToggleVisibility,
              )
            : null,
        contentPadding:
            const EdgeInsets.symmetric(vertical: 14.0, horizontal: 12.0),
      ),
    );
  }
}
