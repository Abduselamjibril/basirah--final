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

  // Form and controller for the payment dialog
  final _formKey = GlobalKey<FormState>();
  final _transactionIdController = TextEditingController();
  final PaymentService _paymentService = PaymentService();

  @override
  void dispose() {
    _transactionIdController.dispose();
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
      margin: const EdgeInsets.only(left: 24.0, right: 24.0, bottom: 80.0),
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
  String get _planName => _isYearly ? '1-Year Gift' : '6-Month Gift';
  String get _planDuration => _isYearly ? 'yearly' : 'six_month';

  /// Displays the dialog for the manual gift payment.
  void _showManualGiftDialog() {
    _transactionIdController.clear();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Manual Payment for Gifts'),
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
                    const Text('Account: 1000123456789',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const Text('Name: Your Company Name Here',
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
            Text(
              '$_totalPrice ETB',
              style: TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.w800,
                  color: primaryColor),
            ),
            Text(
              'for $_quantity x $_planName',
              style: TextStyle(
                  fontSize: 14,
                  color: isDarkMode ? Colors.grey[300] : Colors.grey[700]),
            ),
            const SizedBox(height: 32),

            // Proceed Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _showManualGiftDialog,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Proceed to Pay',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
