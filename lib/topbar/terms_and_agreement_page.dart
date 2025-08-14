// lib/topbar/terms_and_agreement_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme_provider.dart';

class TermsAndAgreementPage extends StatelessWidget {
  const TermsAndAgreementPage({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    final Color appBarColor =
        isDark ? const Color(0xFF1E1E1E) : const Color(0xFF009B77);
    final Color scaffoldBgColor =
        isDark ? const Color(0xFF002147) : Colors.white;
    final Color textColor = isDark ? Colors.white70 : Colors.black87;
    final Color headingColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: scaffoldBgColor,
      appBar: AppBar(
        title: const Text('Terms and Agreement',
            style: TextStyle(color: Colors.white)),
        backgroundColor: appBarColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: RichText(
          textAlign: TextAlign.justify,
          text: TextSpan(
            style: TextStyle(color: textColor, fontSize: 16.0, height: 1.5),
            children: [
              TextSpan(
                text: 'Welcome to Basirah TV\n\n',
                style: TextStyle(
                    fontSize: 22.0,
                    fontWeight: FontWeight.bold,
                    color: headingColor),
              ),
              const TextSpan(
                text:
                    'These terms and conditions outline the rules and regulations for the use of Basirah TV\'s Application, located at [Your App Store URL]. By accessing this app, we assume you accept these terms and conditions. Do not continue to use Basirah TV if you do not agree to all of the terms and conditions stated on this page.\n\n',
              ),
              TextSpan(
                text: '1. User Accounts\n\n',
                style: TextStyle(
                    fontSize: 18.0,
                    fontWeight: FontWeight.bold,
                    color: headingColor),
              ),
              const TextSpan(
                text:
                    'When you create an account with us, you must provide information that is accurate, complete, and current at all times. Failure to do so constitutes a breach of the Terms, which may result in immediate termination of your account on our Service. You are responsible for safeguarding the password that you use to access the Service and for any activities or actions under your password.\n\n',
              ),
              TextSpan(
                text: '2. Subscriptions\n\n',
                style: TextStyle(
                    fontSize: 18.0,
                    fontWeight: FontWeight.bold,
                    color: headingColor),
              ),
              const TextSpan(
                text:
                    'Some parts of the Service are billed on a subscription basis. You will be billed in advance on a recurring and periodic basis ("Billing Cycle"). Billing cycles are set either on a monthly or annual basis, depending on the type of subscription plan you select when purchasing a Subscription. Your Subscription will automatically renew under the exact same conditions unless you cancel it or Basirah TV cancels it.\n\n',
              ),
              TextSpan(
                text: '3. Content\n\n',
                style: TextStyle(
                    fontSize: 18.0,
                    fontWeight: FontWeight.bold,
                    color: headingColor),
              ),
              const TextSpan(
                text:
                    'Our Service allows you to access educational content. All content provided is the property of Basirah TV and is protected by copyright laws. You are granted a limited license only for purposes of viewing the material contained on this app.\n\n',
              ),
              TextSpan(
                text: '4. Limitation of Liability\n\n',
                style: TextStyle(
                    fontSize: 18.0,
                    fontWeight: FontWeight.bold,
                    color: headingColor),
              ),
              const TextSpan(
                text:
                    'In no event shall Basirah TV, nor any of its officers, directors, and employees, be held liable for anything arising out of or in any way connected with your use of this app whether such liability is under contract. Basirah TV, including its officers, directors, and employees shall not be held liable for any indirect, consequential, or special liability arising out of or in any way related to your use of this app.\n\n',
              ),
              TextSpan(
                text: '5. Changes to Terms\n\n',
                style: TextStyle(
                    fontSize: 18.0,
                    fontWeight: FontWeight.bold,
                    color: headingColor),
              ),
              const TextSpan(
                text:
                    'We reserve the right, at our sole discretion, to modify or replace these Terms at any time. We will try to provide at least 30 days\' notice prior to any new terms taking effect. What constitutes a material change will be determined at our sole discretion.\n',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
