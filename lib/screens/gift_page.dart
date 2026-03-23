import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../theme_provider.dart';
import '../widgets/header_navigation_bar.dart';
import '../services/payment_service.dart';

class GiftPage extends StatefulWidget {
  const GiftPage({super.key});

  @override
  State<GiftPage> createState() => _GiftPageState();
}

class _GiftPageState extends State<GiftPage> {
  // State variables for the gift page
  bool _isYearly = true;
  int _quantity = 1;
  bool _isLoading = false;

  // Pricing constants
  static const int _sixMonthPrice = 6000;
  static const int _yearlyPrice = 12000;
  static const int _sixMonthPriceUsd = 50;
  static const int _yearlyPriceUsd = 100;

  // Form and controller for the payment dialog
  final _formKey = GlobalKey<FormState>();
  final _transactionIdController = TextEditingController();
  final _internationalFormKey = GlobalKey<FormState>();
  final _internationalTransactionIdController = TextEditingController();
  final PaymentService _paymentService = PaymentService();

  @override
  void dispose() {
    _transactionIdController.dispose();
    _internationalTransactionIdController.dispose();
    super.dispose();
  }

  // --- HELPER METHODS for dialogs ---
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
              child: const Text('OK'))
        ],
      ),
    );
  }

  void _showSuccessMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: Colors.green,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.only(left: 24.0, right: 24.0, bottom: 20.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      duration: const Duration(seconds: 3),
    ));
  }

  // --- CORE LOGIC for Gifting ---
  void _incrementQuantity() => setState(() => _quantity++);
  void _decrementQuantity() => setState(() {
        if (_quantity > 1) _quantity--;
      });

  int get _totalPrice =>
      (_isYearly ? _yearlyPrice : _sixMonthPrice) * _quantity;
    int get _totalPriceUsd =>
      (_isYearly ? _yearlyPriceUsd : _sixMonthPriceUsd) * _quantity;
  String get _planName => _isYearly ? '1-Year Gift' : '6-Month Gift';
  String get _planDuration => _isYearly ? 'yearly' : 'six_month';
    String get _planDurationText => _isYearly ? '/year' : '/6 months';

  /// Displays the dialog for the manual gift payment.
  void _showManualGiftDialog() {
    _transactionIdController.clear();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Local Payment for Gifts'),
            content: Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: ListBody(
                  children: <Widget>[
                    Text(
                      'You are purchasing $_quantity x $_planName for a total of $_totalPrice ETB.',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                        'Please transfer the total amount to the account below:'),
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
                        'After paying, enter the transaction ID from your bank.'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _transactionIdController,
                      decoration: const InputDecoration(
                          labelText: 'Transaction ID',
                          border: OutlineInputBorder(),
                          hintText: 'e.g. FT230512ABCDE'),
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
                        if (_formKey.currentState!.validate()) {
                          setDialogState(() => _isLoading = true);

                          try {
                            await _paymentService.submitGiftPurchase(
                              planDuration: _planDuration,
                              quantity: _quantity,
                              totalPrice: _totalPrice,
                              transactionId: _transactionIdController.text,
                            );

                            if (mounted) {
                              Navigator.of(ctx).pop();
                              _showSuccessMessage(
                                  'Gift purchase submitted for review!');
                            }
                          } catch (e) {
                            if (mounted) {
                              Navigator.of(ctx).pop();
                              _showErrorDialog(e.toString());
                            }
                          } finally {
                            if (mounted) {
                              setDialogState(() => _isLoading = false);
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
        });
      },
    );
  }

  /// Displays the dialog for the international gift payment.
  void _showInternationalGiftDialog() {
    _internationalTransactionIdController.clear();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('International Payment for Gifts'),
            content: Form(
              key: _internationalFormKey,
              child: SingleChildScrollView(
                child: ListBody(
                  children: <Widget>[
                    Text(
                      'You are purchasing $_quantity x $_planName for a total of \$$_totalPriceUsd.',
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
                        'After paying, enter the transaction ID from your bank.'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _internationalTransactionIdController,
                      decoration: const InputDecoration(
                          labelText: 'Transaction ID',
                          border: OutlineInputBorder(),
                          hintText: 'e.g. WT230512ABCDE'),
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
                          setDialogState(() => _isLoading = true);

                          try {
                            await _paymentService.submitGiftPurchase(
                              planDuration: _planDuration,
                              quantity: _quantity,
                              totalPrice: _totalPrice,
                              transactionId:
                                  _internationalTransactionIdController.text,
                            );

                            if (mounted) {
                              Navigator.of(ctx).pop();
                              _showSuccessMessage(
                                  'Gift purchase submitted for review!');
                            }
                          } catch (e) {
                            if (mounted) {
                              Navigator.of(ctx).pop();
                              _showErrorDialog(e.toString());
                            }
                          } finally {
                            if (mounted) {
                              setDialogState(() => _isLoading = false);
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
        });
      },
    );
  }

  // --- WIDGET BUILD METHODS ---
  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;
    const primaryColor = Color(0xFF009B77);

    return Scaffold(
      // --- CHANGE: Updated dark mode background color ---
      backgroundColor:
          isDarkMode ? const Color(0xFF002147) : const Color(0xFFF8F9FA),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: HeaderNavigationBar(
              onNotificationTapped: () {/* TODO: Implement navigation */},
              onProfileTapped: () {/* TODO: Implement navigation */},
              onGiftTapped: () {/* Already on this page, do nothing */},
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
                    'Gift a Subscription',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Share the gift of knowledge with friends and family',
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
                child: _buildGiftCard(isDarkMode, primaryColor)),
          ),
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
                child: Text('6 Months',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: !_isYearly
                          ? Colors.white
                          : (isDarkMode ? Colors.white : Colors.black),
                      fontWeight: FontWeight.bold,
                    )),
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
                child: Text('Yearly',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _isYearly
                          ? Colors.white
                          : (isDarkMode ? Colors.white : Colors.black),
                      fontWeight: FontWeight.bold,
                    )),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGiftCard(bool isDarkMode, Color primaryColor) {
    final TextStyle priceTextStyle = TextStyle(
      fontSize: 30,
      fontWeight: FontWeight.w800,
      color: primaryColor,
      letterSpacing: -0.3,
      shadows: [
        Shadow(
          color: primaryColor.withOpacity(isDarkMode ? 0.35 : 0.2),
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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Quantity Selector
            Text('How many gifts?',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : Colors.black87)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: isDarkMode ? const Color(0xFF2C2C2E) : Colors.grey[200],
                borderRadius: BorderRadius.circular(50),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: Icon(Icons.remove, color: primaryColor),
                    onPressed: _decrementQuantity,
                  ),
                  Text('$_quantity',
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.white : Colors.black)),
                  IconButton(
                    icon: Icon(Icons.add, color: primaryColor),
                    onPressed: _incrementQuantity,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Divider(color: isDarkMode ? Colors.grey[700] : Colors.grey[300]),
            const SizedBox(height: 24),

            // Total Price Display
            Text('Total Price',
                style: TextStyle(
                    fontSize: 16,
                    color: isDarkMode ? Colors.grey[400] : Colors.grey[600])),
            const SizedBox(height: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '\$$_totalPriceUsd',
                      style: priceTextStyle,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _planDurationText,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color:
                            isDarkMode ? Colors.grey[300] : Colors.grey[700],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '$_totalPrice',
                      style: priceTextStyle,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _planDurationText,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color:
                            isDarkMode ? Colors.grey[300] : Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            Text(
              'for $_quantity x $_planName',
              style: TextStyle(
                  fontSize: 14,
                  color: isDarkMode ? Colors.grey[300] : Colors.grey[700]),
            ),
            const SizedBox(height: 32),

            // Proceed Button
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
                    onPressed: _isLoading ? null : _showManualGiftDialog,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 3, color: Colors.white),
                          )
                        : const Text('Local Pay',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed:
                        _isLoading ? null : _showInternationalGiftDialog,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: primaryColor,
                      side: BorderSide(color: primaryColor, width: 1.5),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('International Pay',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
