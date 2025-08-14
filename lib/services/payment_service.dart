// lib/services/payment_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'auth_http_service.dart';

class PaymentService {
  final AuthHttpService _authHttpService = AuthHttpService();

  final Logger _logger = Logger(
    printer: PrettyPrinter(
        methodCount: 1,
        errorMethodCount: 8,
        lineLength: 120,
        colors: true,
        printEmojis: true,
        printTime: false),
  );

  // =========================================================================
  // === METHOD FOR SUBMITTING MANUAL PAYMENT (FOR SELF) - UNCHANGED
  // =========================================================================
  Future<void> submitManualPayment({
    required String plan, // 'yearly' or 'six_month'
    required String transactionId,
  }) async {
    _logger.i("Submitting manual payment request for plan: '$plan'");

    try {
      // Calls the new endpoint we created in Laravel
      final response = await _authHttpService.post(
        'payment/manual-request',
        {
          'plan': plan,
          'transaction_id': transactionId,
        },
        requireAuth: true,
      );

      // A successful creation returns status 201. We also check for 200 just in case.
      if (response.statusCode != 201 && response.statusCode != 200) {
        final errorData = jsonDecode(response.body);
        _logger.e(
          "Manual Payment Submission Failed: Status ${response.statusCode}",
          errorData['message'] ?? response.body,
        );
        throw Exception(
            errorData['message'] ?? 'Failed to submit payment request.');
      }

      _logger.i("Manual payment request submitted successfully.");
      // No data needs to be returned on success.

    } on AuthException {
      _logger.w("AuthException caught. User not authenticated. Rethrowing.");
      rethrow;
    } catch (e, s) {
      _logger.e(
        'An unexpected error occurred in submitManualPayment',
        e,
        s,
      );
      // Re-throw a more user-friendly message or the original exception.
      if (e is Exception) {
        rethrow;
      }
      throw Exception('An unexpected error occurred. Please try again.');
    }
  }

  // =========================================================================
  // === NEW METHOD FOR SUBMITTING GIFT PURCHASE - ADDED
  // =========================================================================
  Future<void> submitGiftPurchase({
    required String planDuration,
    required int quantity,
    required int totalPrice,
    required String transactionId,
  }) async {
    _logger.i("Submitting gift purchase for $quantity x $planDuration plan(s).");

    try {
      final response = await _authHttpService.post(
        'gift/purchase', // The new endpoint for gift pools
        {
          'plan_duration': planDuration,
          'quantity': quantity,
          'total_price': totalPrice,
          'transaction_id': transactionId,
        },
        requireAuth: true,
      );

      // A successful creation returns status 201
      if (response.statusCode != 201) {
        final errorData = jsonDecode(response.body);
        _logger.e(
          "Gift Purchase Submission Failed: Status ${response.statusCode}",
          errorData['message'] ?? response.body,
        );
        throw Exception(
            errorData['message'] ?? 'Failed to submit gift purchase request.');
      }

      _logger.i("Gift purchase request submitted successfully.");
    } on AuthException {
      _logger.w("AuthException caught during gift submission. User not authenticated. Rethrowing.");
      rethrow;
    } catch (e, s) {
      _logger.e(
        'An unexpected error occurred in submitGiftPurchase',
        e,
        s,
      );
      if (e is Exception) {
        rethrow;
      }
      throw Exception('An unexpected error occurred. Please try again.');
    }
  }
  // =========================================================================
  // === END OF NEW METHOD
  // =========================================================================


  // --- THIS EXISTING METHOD IS COMMENTED OUT BUT KEPT FOR YOUR REFERENCE ---
  /*
  Future<Map<String, dynamic>> initiatePayment({
    required String plan, // 'monthly' or 'yearly'
    required String gateway, // 'stripe' or 'chapa'
  }) async {
    _logger.i("Initiating payment for plan: '$plan' via gateway: '$gateway'");

    try {
      final response = await _authHttpService.post(
        'payment/initiate',
        {
          'plan': plan,
          'gateway': gateway,
        },
        requireAuth: true,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _logger.i("Payment initiation successful. Response data: $data");
        return data;
      } else {
        final errorData = jsonDecode(response.body);
        _logger.e(
          "Payment Initiation Failed: Status ${response.statusCode}",
          "API Response: ${response.body}",
        );
        throw Exception(
            errorData['message'] ?? 'Failed to start payment process.');
      }
    } on AuthException {
      _logger.w(
          "AuthException caught. User is likely not authenticated. Rethrowing.");
      rethrow;
    } catch (e, s) {
      _logger.e(
        'An unexpected error occurred in PaymentService',
        e,
        s,
      );
      throw Exception('An unexpected error occurred. Please try again.');
    }
  }
  */
}