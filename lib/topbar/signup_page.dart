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
                fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white),
            textAlign: TextAlign.center),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(24.0, 0.0, 24.0, 20.0),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final topPadding = MediaQuery.of(context).padding.top;

    // ── Unified colour palette (synced with LoginPage) ──
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
                // ── Logo (synced: 160x160, no AppBar) ──
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
                const SizedBox(height: 24),

                // ── Heading (synced with LoginPage) ──
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Create Account',
                      style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: headingColor,
                          letterSpacing: -0.5)),
                ),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                      'Please fill in the details to create your account.',
                      style: TextStyle(fontSize: 14, color: subtitleColor)),
                ),
                const SizedBox(height: 24),

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
                          controller: _firstNameController,
                          label: 'First Name',
                          icon: Icons.person_outline_rounded,
                          isDark: isDark),
                      const SizedBox(height: 14),
                      _buildTextField(
                          controller: _lastNameController,
                          label: 'Last Name',
                          icon: Icons.person_outline_rounded,
                          isDark: isDark),
                      const SizedBox(height: 14),
                      _buildTextField(
                          controller: _emailController,
                          label: 'Email Address (Optional)',
                          icon: Icons.email_outlined,
                          inputType: TextInputType.emailAddress,
                          isDark: isDark),
                      const SizedBox(height: 14),
                      _buildTextField(
                          controller: _phoneNumberController,
                          label: 'Phone Number',
                          icon: Icons.phone_rounded,
                          inputType: TextInputType.phone,
                          isDark: isDark),
                      const SizedBox(height: 14),
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
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // ── Terms and Agreement ──
                _buildTermsAndAgreementCheckbox(isDark),
                const SizedBox(height: 20),

                // ── Sign Up Button ──
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _register,
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
                        : const Text('Sign Up',
                            style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.3)),
                  ),
                ),
                const SizedBox(height: 24),

                // ── Login Link ──
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
                        style: TextStyle(color: subtitleColor, fontSize: 15),
                        children: [
                          TextSpan(
                              text: "Login",
                              style: TextStyle(
                                  color: linkColor,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),

          // ── Floating back button (synced with LoginPage) ──
          Positioned(
            top: topPadding + 10,
            left: 16,
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: backBtnBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.arrow_back_ios_new_rounded,
                    size: 18, color: backBtnIcon),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Terms & Agreement checkbox ──
  Widget _buildTermsAndAgreementCheckbox(bool isDark) {
    const Color accentGreen = Color(0xFF009B77);
    final linkStyle = TextStyle(
      color: isDark ? const Color(0xFF4DD0B5) : accentGreen,
      fontWeight: FontWeight.w600,
      decoration: TextDecoration.underline,
    );
    final textStyle = TextStyle(
      color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
      fontSize: 13,
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 24,
          height: 24,
          child: Checkbox(
            value: _agreedToTerms,
            onChanged: (bool? value) {
              setState(() {
                _agreedToTerms = value ?? false;
              });
            },
            activeColor: accentGreen,
            checkColor: Colors.white,
            side: BorderSide(
                color: isDark ? Colors.grey.shade600 : Colors.grey.shade400),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: RichText(
              text: TextSpan(
                style: textStyle,
                children: [
                  const TextSpan(text: 'I agree to the '),
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
                  const TextSpan(text: ' and '),
                  TextSpan(
                    text: 'Privacy Policy',
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
        ),
      ],
    );
  }

  // ── Shared text field builder (synced with LoginPage) ──
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
