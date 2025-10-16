// lib/topbar/signup_page.dart

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'dart:convert';
import '../theme_provider.dart';
import 'dart:async';
import '../services/device_info_service.dart';
import '../main.dart';
import '../services/fcm_service.dart' as fcm_service;
import '../providers/auth_provider.dart';
import 'terms_and_agreement_page.dart';
import 'package:logger/logger.dart';

import 'privacy_policy_page.dart';

class SignUpPage extends StatefulWidget {
  @override
  _SignUpPageState createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final Logger _logger = Logger();

  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneNumberController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _isPasswordVisible = false;
  bool _agreedToTerms = false;
  final DeviceInfoService _deviceInfoService = DeviceInfoService();

  Future<void> _register() async {
    if (_isLoading) return;

    if (!_agreedToTerms) {
      _showNotification(
          'You must agree to the Terms and Privacy Policy to register.',
          Colors.redAccent);
      return;
    }

    final String firstName = _firstNameController.text.trim();
    final String lastName = _lastNameController.text.trim();
    final String email = _emailController.text.trim();
    final String phoneNumber = _phoneNumberController.text.trim();
    final String password = _passwordController.text.trim();

    if (firstName.isEmpty ||
        lastName.isEmpty ||
        phoneNumber.isEmpty ||
        password.isEmpty) {
      _showNotification(
          'Please fill in all required fields', Colors.orangeAccent);
      return;
    }
    if (password.length < 8) {
      _showNotification(
          'Password must be at least 8 characters', Colors.orangeAccent);
      return;
    }

    setState(() => _isLoading = true);

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final navigator = Navigator.of(context);

    String deviceId = "unknown_device_id_reg";
    String deviceName = "Unknown Device Reg";
    try {
      deviceId = await _deviceInfoService.getDeviceId();
      deviceName = await _deviceInfoService.getDeviceModelName();
    } catch (e, s) {
      _logger.e("Error getting device info for registration", e, s);
    }

    final url = Uri.parse('https://admin.basirahtv.com/api/register');
    final headers = {
      "Content-Type": "application/json",
      "Accept": "application/json"
    };
    final body = jsonEncode({
      "first_name": firstName,
      "last_name": lastName,
      "email": email.isEmpty ? null : email,
      "phone_number": phoneNumber,
      "password": password,
      "password_confirmation": password,
      "device_id": deviceId,
      "device_name": deviceName,
    });

    _logger.i("Attempting to register user with phone: $phoneNumber");

    http.Response? response;
    String? errorMessage;

    try {
      response = await http
          .post(url, headers: headers, body: body)
          .timeout(const Duration(seconds: 20));

      if (response.statusCode != 201) {
        _logger.w(
          'Registration failed with status code: ${response.statusCode}',
          'Response Body: ${response.body}',
        );
        try {
          final responseData = jsonDecode(response.body);
          if (responseData['errors'] != null && responseData['errors'] is Map) {
            final errors = responseData['errors'] as Map;
            if (errors.isNotEmpty) {
              final firstErrorList = errors.values.first;
              if (firstErrorList is List && firstErrorList.isNotEmpty) {
                errorMessage = firstErrorList.first;
              }
            }
          }
          if (errorMessage == null && responseData['message'] != null) {
            errorMessage = responseData['message'];
          }
        } catch (e) {
          // Ignore JSON parsing errors
        }
        errorMessage ??= 'Registration failed (Code: ${response.statusCode})';
      }
    } catch (error, stackTrace) {
      _logger.e('An exception occurred during registration', error, stackTrace);
      errorMessage = error is TimeoutException
          ? 'Request timed out. Please check connection.'
          : 'An error occurred. Please try again.';
    }

    if (!mounted) return;

    setState(() => _isLoading = false);

    if (errorMessage != null) {
      _showNotification(errorMessage, Colors.redAccent);
    } else if (response != null) {
      final responseData = jsonDecode(response.body);
      final String? token = responseData['token'];

      if (token != null) {
        _logger.i(
            "Registration API call successful (201). Body: ${response.body}");
        final Map<String, dynamic> newUser_data = {
          "first_name": firstName,
          "last_name": lastName,
          "phone_number": phoneNumber,
          "email": email,
          "is_subscribed_and_active": false,
        };
        authProvider.login(token, newUser_data);

        _logger.i("User logged in, sending FCM token...");
        fcm_service.updateAndSendFcmToken();

        // --- FIX: Navigate to MainScreen and pass the message to it ---
        // This avoids calling ScaffoldMessenger from a disposed context.
        await navigator.pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => MainScreen(
              postLoginMessage: 'Registration successful! Welcome.',
            ),
          ),
          (Route<dynamic> route) => false,
        );
      } else {
        _logger.w(
            "Registration successful but token was null. Response: ${response.body}");
        _showNotification(
            'Registration successful, but auto-login failed. Please login.',
            Colors.orangeAccent);
        if (navigator.canPop()) navigator.pop();
      }
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
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ... rest of your build method is unchanged ...
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
        title: const Text('Sign Up', style: TextStyle(color: Colors.white)),
        backgroundColor: appBarColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      backgroundColor: scaffoldBgColor,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Image.asset('assets/images/logo.png', width: 120, height: 120),
            const SizedBox(height: 3),
            Align(
                alignment: Alignment.centerLeft,
                child: Text('Create Account',
                    style: TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.bold,
                        color: welcomeTextColor))),
            const SizedBox(height: 8.0),
            Align(
                alignment: Alignment.centerLeft,
                child: Text(
                    'Please fill in the details to create your account.',
                    style: TextStyle(fontSize: 13, color: promptTextColor))),
            const SizedBox(height: 20.0),
            _buildTextField(
                controller: _firstNameController,
                label: 'First Name',
                icon: Icons.person_outline_rounded,
                isDark: isDark),
            const SizedBox(height: 12.0),
            _buildTextField(
                controller: _lastNameController,
                label: 'Last Name',
                icon: Icons.person_outline_rounded,
                isDark: isDark),
            const SizedBox(height: 12.0),
            _buildTextField(
                controller: _emailController,
                label: 'Email Address (Optional)',
                icon: Icons.email_outlined,
                inputType: TextInputType.emailAddress,
                isDark: isDark),
            const SizedBox(height: 12.0),
            _buildTextField(
                controller: _phoneNumberController,
                label: 'Phone Number',
                icon: Icons.phone_rounded,
                inputType: TextInputType.phone,
                isDark: isDark),
            const SizedBox(height: 12.0),
            _buildTextField(
              controller: _passwordController,
              label: 'Password (min 8 chars)',
              icon: Icons.lock_outline_rounded,
              isPassword: true,
              isVisible: _isPasswordVisible,
              onToggleVisibility: () =>
                  setState(() => _isPasswordVisible = !_isPasswordVisible),
              isDark: isDark,
            ),
            const SizedBox(height: 20.0),
            _buildTermsAndAgreementCheckbox(isDark),
            const SizedBox(height: 20.0),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _register,
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
                    : Text('Sign Up',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: buttonFgColor)),
              ),
            ),
            const SizedBox(height: 16.0),
            Center(
              child: GestureDetector(
                onTap: () {
                  if (!_isLoading && Navigator.canPop(context)) {
                    Navigator.pop(context);
                  }
                },
                child: RichText(
                  text: TextSpan(
                    text: "Already have an account? ",
                    style: TextStyle(
                        color: isDark ? Colors.grey[400] : Colors.black54,
                        fontSize: 16),
                    children: [
                      TextSpan(
                          text: "Login",
                          style: TextStyle(
                              color: isDark
                                  ? Colors.white70
                                  : Colors
                                      .black, // Adjusted for better visibility in dark mode
                              fontSize: 16,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTermsAndAgreementCheckbox(bool isDark) {
    final linkStyle = TextStyle(
      color: Colors.blue.shade300,
      fontWeight: FontWeight.bold,
      decoration: TextDecoration.underline,
    );
    final textStyle = TextStyle(
      color: isDark ? Colors.white70 : Colors.black54,
      fontSize: 14,
    );

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Checkbox(
          value: _agreedToTerms,
          onChanged: (bool? value) {
            setState(() {
              _agreedToTerms = value ?? false;
            });
          },
          activeColor: const Color(0xFF009B77),
          checkColor: Colors.white,
          side: BorderSide(color: isDark ? Colors.grey[600]! : Colors.grey),
        ),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: textStyle,
              children: [
                const TextSpan(text: 'I have read and agree to the '),
                TextSpan(
                  text: 'Terms and Agreement',
                  style: linkStyle,
                  recognizer: TapGestureRecognizer()
                    ..onTap = () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) =>
                                const TermsAndAgreementPage()),
                      );
                    },
                ),
                const TextSpan(text: ' and the '), // Added "and the"
                TextSpan(
                  text: 'Privacy Policy', // Added Privacy Policy link
                  style: linkStyle,
                  recognizer: TapGestureRecognizer()
                    ..onTap = () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const PrivacyPolicyPage(),
                        ),
                      );
                    },
                ),
              ],
            ),
          ),
        ),
      ],
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
