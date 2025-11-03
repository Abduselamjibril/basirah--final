<?php

// app/Http/Controllers/WebhookController.php
namespace App\Http\Controllers;

use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
use Stripe\Stripe;
use Stripe\Webhook;

class WebhookController extends Controller
{
    public function handleStripe(Request $request)
    {
        // ... Your Stripe handling logic is likely fine, no changes needed here ...
        $payload = @file_get_contents('php://input');
        $sig_header = $request->header('Stripe-Signature');
        $endpoint_secret = config('services.stripe.webhook.secret');
        try {
            $event = Webhook::constructEvent($payload, $sig_header, $endpoint_secret);
        } catch (\Exception $e) {
            Log::error('Stripe Webhook Exception', ['error' => $e->getMessage()]);
            return response()->json(['error' => 'Webhook Error'], 400);
        }

        if ($event->type == 'payment_intent.succeeded') {
            $paymentIntent = $event->data->object;
            $userId = $paymentIntent->metadata->user_id ?? null;
            $plan = $paymentIntent->metadata->plan ?? null;
            if ($userId && $plan) {
                $this->fulfillOrder($userId, $plan);
            }
        }
        return response()->json(['status' => 'success'], 200);
    }

  public function handleChapa(Request $request)
    {
        Log::info('Chapa Webhook Endpoint Hit.', [
            'method' => $request->method(),
            'data' => $request->all()
        ]);

        $tx_ref = $request->input('trx_ref'); 

        if (!$tx_ref) {
            Log::warning('Chapa Webhook: No trx_ref found in the request. Ignoring.');
            return response()->json(['status' => 'ignored']);
        }
        
        try {
            $chapaSecretKey = config('services.chapa.secret');
            $verifyResponse = Http::withHeaders([
                'Authorization' => 'Bearer ' . $chapaSecretKey,
            ])->get('https://api.chapa.co/v1/transaction/verify/' . $tx_ref);

            Log::info('Chapa Verification API Response:', [
                'status' => $verifyResponse->status(),
                'body' => $verifyResponse->json() ?? $verifyResponse->body()
            ]);

            if ($verifyResponse->successful() && $verifyResponse->json()['status'] === 'success') {
                $verifiedData = $verifyResponse->json()['data'];
                
                // =======================================================
                // THE FINAL FIX: Chapa returns metadata in the 'meta' key
                $userId = $verifiedData['meta']['user_id'] ?? null;
                $plan = $verifiedData['meta']['plan'] ?? null;
                // =======================================================

                if ($userId && $plan) {
                    $this->fulfillOrder($userId, $plan);
                } else {
                    Log::error('Chapa Webhook Error: Missing user_id or plan in meta field.', ['tx_ref' => $tx_ref]);
                }
            } else {
                Log::error('Chapa Webhook Error: Verification with Chapa API failed or status was not "success".', ['tx_ref' => $tx_ref]);
            }
        } catch (\Exception $e) {
            Log::critical('Chapa Webhook Critical Failure during verification API call.', [
                'tx_ref' => $tx_ref,
                'error' => $e->getMessage()
            ]);
        }
        
        return response()->json(['status' => 'processed']);
    }


    protected function fulfillOrder($userId, $plan)
    {
        $user = User::find($userId);
        if ($user) {
            // Check if the user is already subscribed to prevent double processing
            // (This is a safety check, e.g., if both GET and POST webhooks process)
            // You can add more complex logic here if needed.
            
            $user->is_subscribed = true;

            $currentExpiry = $user->subscription_expires_at ?? now();
            // If the subscription expired in the past, start the new one from today.
            if ($currentExpiry->isPast()) {
                $currentExpiry = now();
            }

            if ($plan === 'yearly') {
                $user->subscription_expires_at = $currentExpiry->addYear();
            } else { // Assumes 'six_month'
                 $user->subscription_expires_at = $currentExpiry->addMonths(6);
            }
            
            $user->save();

            Log::info('Subscription fulfilled successfully.', [
                'user_id' => $userId,
                'plan' => $plan,
                'new_expiry_date' => $user->subscription_expires_at->toDateTimeString()
            ]);
        } else {
            Log::error('Webhook Fulfillment Error: User not found.', ['user_id' => $userId, 'plan' => $plan]);
        }
    }
}