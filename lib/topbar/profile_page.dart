// lib/topbar/profile_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'login_page.dart';
import '../theme_provider.dart';
import 'about_page.dart';
import 'faq_page.dart';
import '../providers/auth_provider.dart';
import 'change_password_page.dart';
import 'edit_profile_page.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({Key? key}) : super(key: key);

  Future<void> _logout(BuildContext context) async {
    final navigator = Navigator.of(context);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    await authProvider.logout();

    if (navigator.mounted) {
      navigator.pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => LoginPage(),
          settings: const RouteSettings(name: '/login'),
        ),
        (_) => false,
      );
    }
  }

  String _getInitials(String firstName, String lastName) {
    final firstInitial = firstName.isNotEmpty ? firstName[0].toUpperCase() : '';
    final lastInitial = lastName.isNotEmpty ? lastName[0].toUpperCase() : '';
    return firstInitial + lastInitial;
  }

  String _hashPhoneNumber(String phoneNumber) {
    if (phoneNumber == 'N/A' || phoneNumber.length < 4) return phoneNumber;
    return '${'*' * (phoneNumber.length - 4)}${phoneNumber.substring(phoneNumber.length - 4)}';
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;
    final theme = Theme.of(context);
    const Color primaryColor = Color(0xFF009B77);
    final colors = _ProfileColors(
      scaffoldBackground: isDarkMode ? Color(0xFF002147) : Colors.white,
      card: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
      text: isDarkMode ? Colors.white : Color.fromARGB(255, 34, 38, 43),
      subText: isDarkMode ? Colors.white54 : Color.fromARGB(255, 34, 38, 43),
      primary: primaryColor,
      divider: theme.dividerColor,
      error: theme.colorScheme.error,
      onPrimary: Colors.white,
      onError: theme.colorScheme.onError,
    );

    return Scaffold(
      backgroundColor: colors.scaffoldBackground,
      appBar: AppBar(
        leading: IconButton(
            icon: Icon(Icons.arrow_back,
                color: isDarkMode ? colors.text : Colors.white),
            onPressed: () => Navigator.pop(context)),
        title: Text('PROFILE',
            style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? colors.text : Colors.white)),
        centerTitle: false,
        backgroundColor:
            isDarkMode ? const Color(0xFF1E1E1E) : const Color(0xFF009B77),
        elevation: 0,
      ),
      body: SafeArea(
        child: Consumer<AuthProvider>(
          builder: (context, authProvider, child) {
            // This now reliably gets the latest user data from the provider
            final userData = {
              'firstName': authProvider.userFirstName ?? 'User',
              'lastName': authProvider.userLastName ?? '',
              'phoneNumber': authProvider.userPhoneNumber ?? 'N/A'
            };

            return _ProfileContent(
              userData: userData,
              colors: colors,
              onLogout: () => _logout(context),
              hashPhoneNumber: _hashPhoneNumber,
              getInitials: (data) =>
                  _getInitials(data['firstName']!, data['lastName']!),
            );
          },
        ),
      ),
    );
  }
}

class _ProfileColors {
  final Color scaffoldBackground;
  final Color card;
  final Color text;
  final Color subText;
  final Color primary;
  final Color divider;
  final Color error;
  final Color onPrimary;
  final Color onError;
  const _ProfileColors({
    required this.scaffoldBackground,
    required this.card,
    required this.text,
    required this.subText,
    required this.primary,
    required this.divider,
    required this.error,
    required this.onPrimary,
    required this.onError,
  });
}

class _ProfileContent extends StatelessWidget {
  final Map<String, String> userData;
  final _ProfileColors colors;
  final VoidCallback onLogout;
  final String Function(String) hashPhoneNumber;
  final String Function(Map<String, String>) getInitials;
  const _ProfileContent({
    required this.userData,
    required this.colors,
    required this.onLogout,
    required this.hashPhoneNumber,
    required this.getInitials,
  });
  String get displayName =>
      '${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}'.trim();
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ProfileHeader(
                displayName: displayName,
                phoneNumber: hashPhoneNumber(userData['phoneNumber'] ?? 'N/A'),
                initials: getInitials(userData),
                colors: colors),
            const SizedBox(height: 32),
            _ProfileOptions(colors: colors),
            const SizedBox(height: 40),
            _LogoutButton(onPressed: onLogout),
            const SizedBox(height: 24),
          ],
        ));
  }
}

class _ProfileHeader extends StatelessWidget {
  final String displayName;
  final String phoneNumber;
  final String initials;
  final _ProfileColors colors;
  const _ProfileHeader(
      {required this.displayName,
      required this.phoneNumber,
      required this.initials,
      required this.colors});
  @override
  Widget build(BuildContext context) {
    return Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: colors.card,
        child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(children: [
              Container(
                  decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 10,
                        offset: const Offset(0, 4))
                  ]),
                  child: CircleAvatar(
                      radius: 55,
                      backgroundColor: colors.primary,
                      child: Text(initials,
                          style: TextStyle(
                              fontSize: 40,
                              fontWeight: FontWeight.w500,
                              color: colors.onPrimary)))),
              const SizedBox(height: 24),
              Text(displayName.isEmpty ? 'User' : displayName,
                  style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: colors.text)),
              if (phoneNumber != 'N/A') ...[
                const SizedBox(height: 8),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.phone_outlined, size: 18, color: colors.subText),
                  const SizedBox(width: 8),
                  Text(phoneNumber, style: TextStyle(color: colors.subText))
                ])
              ]
            ])));
  }
}

class _ProfileOptions extends StatelessWidget {
  final _ProfileColors colors;
  const _ProfileOptions({required this.colors});
  @override
  Widget build(BuildContext context) {
    return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: colors.card,
        child: Column(children: [
          _ProfileOptionTile(
              icon: Icons.edit_outlined,
              title: 'Edit Profile',
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const EditProfilePage())),
              iconColor: colors.primary,
              textColor: colors.text,
              isFirst: true),
          Divider(color: colors.divider, height: 1, indent: 68, endIndent: 16),
          _ProfileOptionTile(
              icon: Icons.info_outline_rounded,
              title: 'About Basirah',
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const AboutPage())),
              iconColor: colors.primary,
              textColor: colors.text,
              isFirst: false),
          Divider(color: colors.divider, height: 1, indent: 68, endIndent: 16),
          _ProfileOptionTile(
            icon: Icons.quiz_outlined,
            title: 'FAQ',
            onTap: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => FaqPage())),
            iconColor: colors.primary,
            textColor: colors.text,
            isLast: false,
          ),
          Divider(color: colors.divider, height: 1, indent: 68, endIndent: 16),
          _ProfileOptionTile(
              icon: Icons.password_rounded,
              title: 'Change Password',
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const ChangePasswordPage())),
              iconColor: colors.primary,
              textColor: colors.text,
              isLast: true),
        ]));
  }
}

class _ProfileOptionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Color iconColor;
  final Color textColor;
  final bool isFirst;
  final bool isLast;
  const _ProfileOptionTile(
      {required this.icon,
      required this.title,
      required this.onTap,
      required this.iconColor,
      required this.textColor,
      this.isFirst = false,
      this.isLast = false});
  @override
  Widget build(BuildContext context) {
    return Material(
        color: Colors.transparent,
        child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.vertical(
                top: isFirst ? const Radius.circular(16) : Radius.zero,
                bottom: isLast ? const Radius.circular(16) : Radius.zero),
            child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16.0, vertical: 14.0),
                child: Row(children: [
                  Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                          color: iconColor.withOpacity(0.1),
                          shape: BoxShape.circle),
                      child: Icon(icon, color: iconColor, size: 20)),
                  const SizedBox(width: 16),
                  Expanded(
                      child: Text(title,
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: textColor))),
                  Icon(Icons.chevron_right_rounded,
                      color: textColor.withOpacity(0.6), size: 24)
                ]))));
  }
}

class _LogoutButton extends StatelessWidget {
  final VoidCallback onPressed;
  const _LogoutButton({required this.onPressed});
  @override
  Widget build(BuildContext context) {
    const Color redColor = Colors.red;
    return ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
            backgroundColor: redColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            minimumSize: const Size(double.infinity, 50)),
        onPressed: onPressed,
        icon: const Icon(Icons.logout_rounded, size: 20),
        label: const Text('Logout',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)));
  }
}
