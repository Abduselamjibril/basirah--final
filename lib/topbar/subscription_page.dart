import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/payment_service.dart';
import '../theme_provider.dart';
import '../widgets/header_navigation_bar.dart';

class SubscriptionPage extends StatefulWidget {
  const SubscriptionPage({super.key});

  @override
  State<SubscriptionPage> createState() => _SubscriptionPageState();
}

class _SubscriptionPageState extends State<SubscriptionPage> {
  // State variables
  bool _isYearly = true;
  bool _isLoading = false;
  final PaymentService _paymentService = PaymentService();
  final _formKey = GlobalKey<FormState>();
  final _transactionIdController = TextEditingController();
  final _internationalFormKey = GlobalKey<FormState>();
  final _internationalTransactionIdController = TextEditingController();

  @override
  void dispose() {
    // Clean up the controller when the widget is disposed.
    _transactionIdController.dispose();
    _internationalTransactionIdController.dispose();
    super.dispose();
  }

  // --- HELPER METHODS (Unchanged) ---

  void _showErrorDialog(String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Submission Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showSuccessMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: Colors.green,
    ));
  }

  // =========================================================================
  // === UPDATED CORE LOGIC FOR MANUAL PAYMENT
  // =========================================================================

  /// Displays the dialog for manual payment instructions.
  void _showManualPaymentDialog() {
    _transactionIdController.clear();

    final String planTitle = _isYearly ? 'Annual Plan' : '6 Month Plan';
    final String priceETB = _isYearly ? '12,000 ETB' : '6,000 ETB';

    showDialog(
      context: context,
      barrierDismissible: false, // Prevent closing while loading
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Local Payment Instructions'),
              content: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: ListBody(
                    children: <Widget>[
                      Text(
                        'You have selected the $planTitle for $priceETB.',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                          'Please transfer the amount to the account below:'),
                      const SizedBox(height: 8),
                      const Text('Bank: Commercial Bank of Ethiopia',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                        const Text('Account: 1000746793492',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                        const Text('Name: Mr. Fitsum kibrom',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                        const Text('Company: Basirah Tv',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 24),
                      const Text(
                          'After paying, enter the transaction ID from your bank receipt below.'),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _transactionIdController,
                        decoration: const InputDecoration(
                          labelText: 'Transaction ID',
                          border: OutlineInputBorder(),
                          hintText: 'e.g. FT230512ABCDE',
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter a transaction ID.';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: <Widget>[
                // --- CHANGE 1: Added style for Cancel button ---
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red, // Set text color to red
                  ),
                  onPressed: _isLoading ? null : () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
                // --- CHANGE 2: Added style for Submit button ---
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        const Color(0xFF009B77), // Your green color
                    foregroundColor: Colors.white, // Text color for contrast
                  ),
                  onPressed: _isLoading
                      ? null
                      : () async {
                          if (_formKey.currentState!.validate()) {
                            setDialogState(() {
                              _isLoading = true;
                            });

                            final plan = _isYearly ? 'yearly' : 'six_month';
                            final transactionId = _transactionIdController.text;

                            try {
                              await _paymentService.submitManualPayment(
                                  plan: plan, transactionId: transactionId);

                              if (mounted) {
                                Navigator.of(ctx).pop();
                                _showSuccessMessage(
                                    'Request submitted! Your subscription will be activated after admin review.');
                              }
                            } catch (e) {
                              if (mounted) {
                                Navigator.of(ctx).pop();
                                _showErrorDialog(e.toString());
                              }
                            } finally {
                              if (mounted) {
                                setDialogState(() {
                                  _isLoading = false;
                                });
                                setState(() {
                                  _isLoading = false;
                                });
                              }
                            }
                          }
                        },
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Submit for Approval'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Displays the dialog for international payment instructions.
  void _showInternationalPaymentDialog() {
    _internationalTransactionIdController.clear();

    final String planTitle = _isYearly ? 'Annual Plan' : '6 Month Plan';
    final String priceUSD = _isYearly ? '\$100' : '\$50';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('International Payment Instructions'),
              content: Form(
                key: _internationalFormKey,
                child: SingleChildScrollView(
                  child: ListBody(
                    children: <Widget>[
                      Text(
                        'You have selected the $planTitle for $priceUSD.',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Direct Deposit Details',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      const Text('Bank: M&T Bank'),
                      const Text('Account Type: Checking'),
                      const Text('Account Number: 9899088877'),
                      const Text('ABA/Routing Number: 052000113'),
                      const Text('Beneficiary: CAPITOL CARE'),
                      const SizedBox(height: 16),
                      const Text(
                        'After paying, enter the transaction ID from your bank receipt below.',
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _internationalTransactionIdController,
                        decoration: const InputDecoration(
                          labelText: 'Transaction ID',
                          border: OutlineInputBorder(),
                          hintText: 'e.g. WT230512ABCDE',
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter a transaction ID.';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: <Widget>[
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red,
                  ),
                  onPressed: _isLoading ? null : () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF009B77),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _isLoading
                      ? null
                      : () async {
                          if (_internationalFormKey.currentState!.validate()) {
                            setDialogState(() {
                              _isLoading = true;
                            });

                            final plan = _isYearly ? 'yearly' : 'six_month';
                            final transactionId =
                                _internationalTransactionIdController.text;

                            try {
                              await _paymentService.submitManualPayment(
                                  plan: plan, transactionId: transactionId);

                              if (mounted) {
                                Navigator.of(ctx).pop();
                                _showSuccessMessage(
                                    'Request submitted! Your subscription will be activated after admin review.');
                              }
                            } catch (e) {
                              if (mounted) {
                                Navigator.of(ctx).pop();
                                _showErrorDialog(e.toString());
                              }
                            } finally {
                              if (mounted) {
                                setDialogState(() {
                                  _isLoading = false;
                                });
                                setState(() {
                                  _isLoading = false;
                                });
                              }
                            }
                          }
                        },
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Submit for Approval'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- WIDGET BUILD METHODS (Unchanged) ---
  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;
    const primaryColor = Color(0xFF009B77);

    return Scaffold(
      backgroundColor:
          isDarkMode ? const Color(0xFF121212) : const Color(0xFFF8F9FA),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: HeaderNavigationBar(
              onNotificationTapped: () {},
              onProfileTapped: () {},
              onGiftTapped: () {}, // Added required parameter
              onThemeToggle: themeProvider.toggleTheme,
              titleLeftPaddingLight: 0.0,
              titleLeftPaddingDark: 0.0,
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.only(top: 40, bottom: 20),
            sliver: SliverToBoxAdapter(
              child: Column(
                children: [
                  Text(
                    'Upgrade Your Experience',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Choose the perfect plan for your needs',
                    style: TextStyle(
                      fontSize: 16,
                      color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                    ),
                  )
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            sliver: SliverToBoxAdapter(
                child: _buildToggleSwitch(isDarkMode, primaryColor)),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            sliver: SliverToBoxAdapter(
                child: _buildPlanCard(isDarkMode, primaryColor)),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(40),
            sliver: SliverToBoxAdapter(
                child: _buildFeaturesList(isDarkMode, primaryColor)),
          )
        ],
      ),
    );
  }

  Widget _buildToggleSwitch(bool isDarkMode, Color primaryColor) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF2C2C2E) : Colors.grey[200],
        borderRadius: BorderRadius.circular(50),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _isYearly = false),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: !_isYearly ? primaryColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(50),
                ),
                child: Text(
                  '6 Months',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: !_isYearly
                        ? Colors.white
                        : (isDarkMode ? Colors.white : Colors.black),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _isYearly = true),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _isYearly ? primaryColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(50),
                ),
                child: Text(
                  'Yearly',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _isYearly
                        ? Colors.white
                        : (isDarkMode ? Colors.white : Colors.black),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanCard(bool isDarkMode, Color primaryColor) {
    final String planTitle = _isYearly ? 'Annual Plan' : '6 Month Plan';
    final String planDescription = _isYearly
        ? 'Pay once for the whole year.'
        : 'Great value for half a year.';
    final String priceUSD = _isYearly ? '\$100' : '\$50';
    final String priceETBCompact = _isYearly ? '12000' : '6000';
    final String durationText = _isYearly ? '/year' : '/6 months';
    final Color priceTextColor = primaryColor;
    final TextStyle priceTextStyle = TextStyle(
      fontSize: 30,
      fontWeight: FontWeight.w800,
      color: priceTextColor,
      letterSpacing: -0.3,
      shadows: [
        Shadow(
          color: priceTextColor.withOpacity(isDarkMode ? 0.35 : 0.2),
          blurRadius: 12,
          offset: const Offset(0, 3),
        ),
      ],
    );

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 16),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: _isYearly ? Border.all(color: primaryColor, width: 2) : null,
        boxShadow: [
          BoxShadow(
            color: isDarkMode
                ? primaryColor.withOpacity(0.15)
                : primaryColor.withOpacity(0.1),
            blurRadius: 20,
            spreadRadius: 2,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_isYearly)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(50),
                ),
                child: Text(
                  'BEST VALUE',
                  style: TextStyle(
                    color: primaryColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            const SizedBox(height: 16),
            Text(
              planTitle,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              planDescription,
              style: TextStyle(
                fontSize: 14,
                color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      priceUSD,
                      style: priceTextStyle,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      durationText,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      priceETBCompact,
                      style: priceTextStyle,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      durationText,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 32),
            Text(
              'Choose payment method',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDarkMode ? Colors.grey[400] : Colors.grey[700],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _showManualPaymentDialog,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 3, color: Colors.white),
                          )
                        : const Text(
                            'Local Pay',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed:
                        _isLoading ? null : _showInternationalPaymentDialog,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: primaryColor,
                      side: BorderSide(color: primaryColor, width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text(
                      'International Pay',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturesList(bool isDarkMode, Color primaryColor) {
    final features = [
      'Unlimited access to all premium content',
      'Ad-free browsing experience',
      'Priority customer support',
      'Early access to new features',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Premium Features',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : Colors.black,
          ),
        ),
        const SizedBox(height: 16),
        ...features.map((feature) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: primaryColor, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      feature,
                      style: TextStyle(
                        fontSize: 16,
                        color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
                      ),
                    ),
                  ),
                ],
              ),
            )),
      ],
    );
  }
}
