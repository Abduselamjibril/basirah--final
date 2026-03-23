import 'dart:convert';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../theme_provider.dart';
import 'verify_otp_page.dart';
import 'contact_info_page.dart';

class ForgotPasswordPage extends StatefulWidget {
  @override
  _ForgotPasswordPageState createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final TextEditingController _emailController = TextEditingController();
  bool _isLoading = false;

  Future<void> _sendResetCode() async {
    if (_isLoading) return;
    if (_emailController.text.trim().isEmpty) {
      _showNotification(
          'Please enter your email address.', Colors.orangeAccent);
      return;
    }
    setState(() => _isLoading = true);

    final url = Uri.parse('https://admin.basirahtv.com/api/forgot-password');
    final headers = {
      "Content-Type": "application/json",
      "Accept": "application/json"
    };
    final body = jsonEncode({"email": _emailController.text.trim()});

    try {
      final response = await http.post(url, headers: headers, body: body);
      if (!mounted) return;

      final responseData = jsonDecode(response.body);
      _showNotification(
          responseData['message'] ?? 'Processing request...', Colors.green);

      if (response.statusCode == 200) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                VerifyOtpPage(email: _emailController.text.trim()),
          ),
        );
      }
    } catch (e) {
      _showNotification(
          'An error occurred. Please try again.', Colors.redAccent);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showNotification(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message,
          textAlign: TextAlign.center,
          style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(24.0, 0.0, 24.0, 20.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final topPadding = MediaQuery.of(context).padding.top;

    // ── Unified colour palette (synced with Login / Signup) ──
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

                // ── Logo (synced: 160x160) ──
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
                Text('Forgot Your Password?',
                    style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: headingColor,
                        letterSpacing: -0.5),
                    textAlign: TextAlign.center),
                const SizedBox(height: 10),
                Text(
                  'Enter your registered email address below.\nWe will send a 6-digit code to reset your password.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 14, color: subtitleColor, height: 1.5),
                ),
                const SizedBox(height: 32),

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
                  child: _buildTextField(
                    controller: _emailController,
                    label: 'Email Address',
                    icon: Icons.email_outlined,
                    inputType: TextInputType.emailAddress,
                    isDark: isDark,
                  ),
                ),
                const SizedBox(height: 28),

                // ── Send Button ──
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _sendResetCode,
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          isDark ? const Color(0xFF4DD0B5) : accentGreen,
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
                                color: Colors.white, strokeWidth: 2.5))
                        : const Text('Send Reset Code',
                            style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.3)),
                  ),
                ),
                const SizedBox(height: 32),

                // ── Contact Support link ──
                Center(
                  child: RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      style: TextStyle(color: subtitleColor, fontSize: 14),
                      children: [
                        const TextSpan(text: "Can't use your email? "),
                        TextSpan(
                          text: 'Contact Support',
                          style: TextStyle(
                            color: linkColor,
                            fontWeight: FontWeight.w700,
                            decoration: TextDecoration.underline,
                          ),
                          recognizer: TapGestureRecognizer()
                            ..onTap = () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) =>
                                        const ContactInfoPage()),
                              );
                            },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Floating back button (synced) ──
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

  // ── Shared text field builder (synced with Login / Signup) ──
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
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
        contentPadding:
            const EdgeInsets.symmetric(vertical: 14.0, horizontal: 12.0),
      ),
    );
  }
}
