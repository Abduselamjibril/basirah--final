<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Str;
use Stripe\Stripe;
use Stripe\Checkout\Session;

class PaymentController extends Controller
{
    /**
     * Handles the initiation of a payment through either Stripe or Chapa.
     */
    public function initiatePayment(Request $request)
    {
        $validator = \Validator::make($request->all(), [
            'gateway' => 'required|string|in:stripe,chapa',
            'plan' => 'required|string|in:six_month,yearly',
        ]);

        if ($validator->fails()) {
            return response()->json(['errors' => $validator->errors()], 422);
        }

        $user = Auth::user();
        $gateway = $request->input('gateway');
        $plan = $request->input('plan');

        // =========================================================================
        // === UPDATED SECTION: Prices are now set to your requirement (100 & 200) ===
        //
        // IMPORTANT: Chapa amounts are in full currency units (Birr), not cents.
        // The comments have been corrected to reflect this.
        // =========================================================================
        $prices = [
            'six_month' => ['usd' => 50,  'etb' => 6000],  // This will charge 100.00 ETB
            'yearly'    => ['usd' => 100, 'etb' => 12000],  // This will charge 200.00 ETB
        ];
        // =========================================================================
        // === END OF UPDATED SECTION ===
        // =========================================================================

        try {
            if ($gateway === 'stripe') {
                Stripe::setApiKey(config('services.stripe.secret'));

                $session = Session::create([
                    'payment_method_types' => ['card'],
                    'line_items' => [[
                        'price_data' => [
                            'currency' => 'usd',
                            'product_data' => [
                                'name' => 'BasirahTV ' . ucfirst(str_replace('_', ' ', $plan)) . ' Plan',
                            ],
                            'unit_amount' => $prices[$plan]['usd'],
                        ],
                        'quantity' => 1,
                    ]],
                    'mode' => 'payment',
                    'success_url' => config('app.url') . '/payment-success.html',
                    'cancel_url' => config('app.url') . '/payment-cancelled.html',
                    'payment_intent_data' => [
                        'metadata' => [
                            'user_id' => $user->id,
                            'plan' => $plan,
                        ]
                    ],
                ]);

                return response()->json([
                    'gateway' => 'stripe',
                    'checkoutUrl' => $session->url,
                ]);
            }

            if ($gateway === 'chapa') {
                $chapaSecretKey = config('services.chapa.secret');
                $tx_ref = 'chapa-' . $user->id . '-' . Str::random(10);

                $response = Http::withHeaders([
                    'Authorization' => 'Bearer ' . $chapaSecretKey,
                    'Content-Type' => 'application/json',
                ])->post('https://api.chapa.co/v1/transaction/initialize', [
                    // It's good practice to send the amount as a string
                    'amount' => (string) $prices[$plan]['etb'],
                    'currency' => 'ETB',
                    'email' => $user->email ?? 'testpayment@gmail.com',
                    'first_name' => $user->first_name,
                    'last_name' => $user->last_name,
                    'phone_number' => $user->phone_number,
                    'tx_ref' => $tx_ref,
                    'callback_url' => config('app.url') . '/api/webhooks/chapa',
                    'return_url' => config('app.url') . '/payment-success.html',
                    'customization' => [
                        'title' => 'BasirahTV Sub',
                        'description' => 'Payment for ' . ucfirst(str_replace('_', ' ', $plan)) . ' Plan',
                    ],
                    'meta' => [
                        'user_id' => $user->id,
                        'plan' => $plan
                    ]
                ]);

                if ($response->successful() && $response->json()['status'] === 'success') {
                    return response()->json([
                        'gateway' => 'chapa',
                        'checkoutUrl' => $response->json()['data']['checkout_url'],
                    ]);
                } else {
                    Log::error('Chapa Initialization Failed', [
                        'response' => $response->body(),
                        'amount_sent' => $prices[$plan]['etb']
                    ]);
                    return response()->json(['message' => 'Failed to initialize payment'], 500);
                }
            }
        } catch (\Exception $e) {
            Log::error('Payment Error', [
                'error' => $e->getMessage(),
                'user' => $user->id,
                'plan' => $plan
            ]);
            return response()->json(['message' => 'Payment processing error'], 500);
        }

        // Fallback in case the gateway is invalid (though the validator should catch this)
        return response()->json(['message' => 'Invalid payment gateway specified.'], 422);
    }
}